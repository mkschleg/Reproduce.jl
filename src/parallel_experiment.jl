
using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates
using Config

include("slurm.jl")
using .ClusterManagers

IN_SLURM() = return "SLURM_JOBID" ∈ keys(ENV)


"""
job

"""
function job(experiment_file::AbstractString,
             exp_dir::AbstractString,
             args_iter;
             exp_module_name::Union{String, Symbol}=:Main,
             exp_func_name::Union{String, Symbol}=:main_experiment,
             num_workers::Integer=5,
             expand_args::Bool=false,
             extra_args = [],
             store_exceptions=true,
             skip_exceptions=false,
             exception_dir="except",
             job_file_dir="")
    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "This is an array Job! Time to get task and start job."
        task_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
        @time task_job(experiment_file, exp_dir, args_iter, task_id;
                       exp_module_name=exp_module_name,
                       exp_func_name=exp_func_name,
                       expand_args=expand_args,
                       extra_args=extra_args,
                       store_exceptions=store_exceptions,
                       exception_dir=exception_dir)
    else
        @time parallel_job(experiment_file, exp_dir, args_iter;
                           exp_module_name=exp_module_name,
                           exp_func_name=exp_func_name,
                           num_workers=num_workers,
                           expand_args=expand_args,
                           extra_args=extra_args,
                           store_exceptions=store_exceptions,
                           exception_dir=exception_dir,
                           job_file_dir=job_file_dir,
                           skip_exceptions=skip_exceptions)
    end
end

function job(experiment_file::AbstractString,
             exp_dir::AbstractString,
             args_iter,
             task_id::Integer;
             exp_module_name::Union{String, Symbol}=:Main,
             exp_func_name::Union{String, Symbol}=:main_experiment,
             num_workers::Integer=5,
             expand_args::Bool=false,
             extra_args = [],
             store_exceptions=true,
             skip_exceptions=false,
             exception_dir="except")
    @info "This is a task job! ID is $(task_id)"
    @time task_job(experiment_file, exp_dir, args_iter, task_id;
                   exp_module_name=exp_module_name,
                   exp_func_name=exp_func_name,
                   expand_args=expand_args,
                   extra_args=extra_args,
                   store_exceptions=store_exceptions,
                   exception_dir=exception_dir)
end

function config_job(config_file::AbstractString, dir::AbstractString, num_runs::Int; data_manager=Config.HDF5Manager(), kwargs...)
    cfg = ConfigManager(config_file, dir, data_manager)
    exp_module_name = cfg.config_dict["config"]["exp_module_name"]
    exp_file = cfg.config_dict["config"]["exp_file"]
    exp_func_name = cfg.config_dict["config"]["exp_func_name"]
    if IN_SLURM()
        if !isdir(joinpath(dir, "jobs"))
            mkdir(joinpath(dir, "jobs"))
        end
        if !isdir(joinpath(dir, "jobs", cfg.config_dict["save_path"]))
            mkdir(joinpath(dir, "jobs", cfg.config_dict["save_path"]))
        end
    end
    job(exp_file, dir, Config.iterator(cfg, num_runs);
        exp_module_name=Symbol(exp_module_name),
        exp_func_name=Symbol(exp_func_name),
        exception_dir = joinpath("except", cfg.config_dict["save_path"]),
        job_file_dir = joinpath(dir, "jobs", cfg.config_dict["save_path"]),
        kwargs...)
end


job(exp::Experiment; exception_dir="except", kwargs...) =
    job(exp.file, exp.dir, exp.args_iter;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exception_dir)/exp_0x$(string(exp.hash, base=16))", kwargs...)

job(exp::Experiment, job_id::Integer; exception_dir="except", kwargs...) =
    job(exp.file, exp.dir, exp.args_iter, job_id;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exception_dir)/exp_0x$(string(exp.hash, base=16))", kwargs...)


function create_procs(num_workers, project, job_file_dir)
    pids = Array{Int64, 1}()
    exc_opts = Base.JLOptions()
    color_opt = "no"
    if exc_opts.color == 1
        color_opt = "yes"
    end

    if IN_SLURM()
        num_add_workers = parse(Int64, ENV["SLURM_NTASKS"])
        if num_add_workers != 0
            # assume started fresh julia instance...
            pids = addprocs(SlurmManager(num_add_workers);
                            exeflags=["--project=$(project)", "--color=$(color_opt)"],
                            job_file_loc=job_file_dir)
            print("\n")
        end
    else 
        if nworkers() == 1
            pids = addprocs(num_workers;
                            exeflags=["--project=$(project)", "--color=$(color_opt)"])
        elseif nworkers() < num_workers
            pids = addprocs((num_workers) - nworkers();
                            exeflags=["--project=$(project)", "--color=$(color_opt)"])
        else
            pids = procs()
        end
    end
    return pids
end



"""
    parallel_job

Run a parallel job over the arguments presented by args_iter. `args_iter` can be a enumeration OR ArgIterator. Each job will be dedicated to a specific
task. The experiment *must* save its own data! As this is not handled by this function (although could be added in the future.)
"""
function parallel_job(experiment_file::AbstractString,
                      exp_dir::AbstractString,
                      args_iter;
                      exp_module_name::Union{String, Symbol}=:Main,
                      exp_func_name::Union{String, Symbol}=:main_experiment,
                      num_workers=1,
                      expand_args=false,
                      project=".",
                      extra_args=[],
                      store_exceptions=true,
                      verbose=false,
                      skip_exceptions=false,
                      exception_dir="except",
                      job_file_dir="")

    #######
    #
    # Preamble - Add processes, initialized shared memory
    #
    ######



    if job_file_dir == ""
        job_file_dir = joinpath(exp_dir, "jobs")
    end

    pids = create_procs(num_workers, project, job_file_dir)
    println(nworkers(), " ", pids)

    n = length(args_iter)

    #########
    #
    # Meaty middle: Compiling code, running jobs, managing which jobs fail.
    #
    ########

    job_id_channel = RemoteChannel(()->Channel{Int}(length(args_iter)), 1)

    done_channel = RemoteChannel(()->Channel{Bool}(1), 1)

    try

        mod_str = string(exp_module_name)
        func_str = string(exp_func_name)

        try
            @everywhere const global exp_file=$experiment_file
            @everywhere const global expand_args=$expand_args
            @everywhere const global extra_args=$extra_args
            @everywhere const global store_exceptions=$store_exceptions
            @everywhere const global exception_loc = joinpath($exp_dir, $exception_dir)

            @everywhere begin
                eval(:(using Reproduce))
                eval(:(using Distributed))
                eval(:(using SharedArrays))
                include(exp_file)
                @info "$(exp_file) included on process $(myid())"
                mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
                const global exp_func = getfield(mod, Symbol($func_str))
                experiment(args) = exp_func(args)
                @info "Experiment built on process $(myid())"
            end
        catch ex
            println(ex)
        end

        @info "Number of Jobs: $(n)"
        exception_loc = joinpath(exp_dir, exception_dir)
        if store_exceptions && !isdir(exception_loc)
            mkpath(exception_loc)
        end
            
           
        ProgressMeter.@showprogress pmap(args_iter) do (job_id, args)

            run_exp = if args isa ConfigManager
                !(isfile(joinpath(Config.get_logdir(args), "exception.txt")))
            else
                !(isfile(joinpath(exception_loc, "job_$(job_id).exc")))
            end
            
            if run_exp || !skip_exceptions
                try
                    if expand_args
                        Main.exp_func(args..., extra_args...)
                    else
                        Main.exp_func(args, extra_args...)
                    end
                catch ex
                    if isa(ex, InterruptException)
                        throw(InterruptException())
                    end
                    if verbose
                        @warn "Exception encountered for job: $(job_id)"
                    end
                    if store_exceptions
                        if args isa ConfigManager
                            exception_file(
                                joinpath(Config.get_logdir(args), "exception.txt"),
                                job_id, ex, stacktrace(catch_backtrace()))
                            exception_file(
                                joinpath(exception_loc, join(["run_", args["run"], "_param_setting_", args["param_setting"], ".exc"])),
                                job_id, ex, stacktrace(catch_backtrace()))
                        else
                            exception_file(
                                joinpath(exception_loc, "job_$(job_id).exc"),
                                job_id, ex, stacktrace(catch_backtrace()))
                        end
                    end
                end
            elseif verbose
                @warn  "Not running job for $(job_id)"
            end
            Distributed.put!(job_id_channel, job_id)
        end

    catch ex
        println(ex)
        Distributed.interrupt()
    end

    finished_jobs_bool = fill(false, n)
    while isready(job_id_channel)
        job_id = take!(job_id_channel)
        finished_jobs_bool[job_id] = true
    end
    return findall((x)->x==false, finished_jobs_bool)

end



function task_job(experiment_file::AbstractString, exp_dir::AbstractString,
                  args_iter, task_id::Integer;
                  exp_module_name::Union{String, Symbol}=:Main,
                  exp_func_name::Union{String, Symbol}=:main_experiment,
                  expand_args::Bool=false,
                  extra_args=[],
                  store_exceptions=true,
                  exception_dir="except")

    mod_str = string(exp_module_name)
    func_str = string(exp_func_name)

    @everywhere begin
        include($experiment_file)
        mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
        const global exp_func = getfield(mod, Symbol($func_str))
    end

    args = collect(args_iter)[task_id][2]
    @sync @async begin
        try
            if expand_args
                Main.exp_func(args..., extra_args...)
            else
                Main.exp_func(args, extra_args...)
            end
        catch ex
            @warn "Exception encountered for job: $(task_id)"
            if store_exceptions
                exception_loc = joinpath(exp_dir, exception_dir)
                if !isdir(exception_loc)
                    try
                        mkpath(exception_loc)
                    catch
                        sleep(1)
                    end
                end
                exception_file(
                    joinpath(exception_loc, "job_$(task_id).exc"),
                    task_id, ex, stacktrace(catch_backtrace()))
                return false
            end
            throw(ex)
        end
    end
    return true
end

