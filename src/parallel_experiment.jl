
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
             args_iter; kwargs...)
    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "This is an array Job! Time to get task and start job."
        task_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
        @time task_job(experiment_file, exp_dir, args_iter, task_id;
                       kwargs...)
    else
        @time parallel_job(experiment_file, exp_dir, args_iter;
                           kwargs...)
    end
end

function job(experiment_file::AbstractString,
             exp_dir::AbstractString,
             args_iter,
             task_id::Int;
             kwargs...)
    @info "This is a task job! ID is $(task_id)"
    @time task_job(experiment_file, exp_dir, args_iter, task_id;
                   kwargs...)
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


job(exp::Experiment; kwargs...) =
    job(exp.file, exp.dir, exp.args_iter;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exp.dir)/except/exp_0x$(string(exp.hash, base=16))",
        checkpoint_name="$(exp.dir)/checkpoints/exp_0x$(string(exp.hash, base=16))", kwargs...)

job(exp::Experiment, job_id::Integer; kwargs...) =
    job(exp.file, exp.dir, exp.args_iter, job_id;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exp.dir)/except/exp_0x$(string(exp.hash, base=16))",
        checkpoint_name="$(exp.dir)/checkpoints/exp_0x$(string(exp.hash, base=16))", kwargs...)

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

function _run_experiment(exp_func, job_id, args, extra_args, exception_loc;
                         expand_args=false,
                         verbose=false,
                         store_exceptions=true,
                         skip_exceptions=false)

    run_exp = if args isa ConfigManager
        !(isfile(joinpath(Config.get_logdir(args), "exception.txt")))
    else
        !(isfile(joinpath(exception_loc, "job_$(job_id).exc")))
    end

    if run_exp || !skip_exceptions
        try
            if expand_args
                exp_func(args..., extra_args...)
            else
                exp_func(args, extra_args...)
            end
            return true
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
            return false
        end
    elseif verbose
        @warn  "Not running job for $(job_id)"
    end

    return true

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
                      num_workers=2,
                      project=".",
                      extra_args=[],
                      exception_dir="except",
                      job_file_dir="",
                      checkpoint_name="",
                      store_exceptions=true,
                      verbose=false,
                      skip_exceptions=false,
                      expand_args=false)

    #######
    #
    # Preamble - Add processes, initialized shared memory
    #
    ######

    if job_file_dir == ""
        job_file_dir = joinpath(exp_dir, "jobs")
    end

    if exception_dir == "except"
        exception_dir = joinpath(exp_dir, exception_dir)
    end
    if store_exceptions && !isdir(exception_dir)
        mkpath(exception_dir)
    end

    checkpointing = true
    checkpoint_file = checkpoint_name
    if checkpoint_name == ""
        # checkpoint_name = joinpath(exp_dir, "checkpoints.jld2")
        checkpointing = false
    else
        if splitext(checkpoint_file)[end] != ".jld2"
            checkpoint_file = checkpoint_file * ".jld2"
        end
    end

    pids = create_procs(num_workers, project, job_file_dir)
    println(nworkers(), " ", pids)

    n = length(args_iter)

    finished_jobs_arr = fill(false, n)
    if checkpointing
        if !isdir(dirname(checkpoint_file))
            mkpath(dirname(checkpoint_file))
        end
        if isfile(checkpoint_file)
            JLD2.@load checkpoint_file finished_jobs_arr
        else
            JLD2.@save checkpoint_file finished_jobs_arr
        end
    end
    @show finished_jobs_arr
    done_jobs = finished_jobs_arr

    @info "Number of Jobs: $(n)"

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

        @everywhere const global exp_file=$experiment_file
        @everywhere const global expand_args=$expand_args
        @everywhere const global extra_args=$extra_args
        @everywhere const global store_exceptions=$store_exceptions
        @everywhere const global exception_dir=$exception_dir
        @everywhere const global checkpoint_file = $checkpoint_file
        @everywhere const global checkpointing=$checkpointing
        @everywhere const global done_jobs=$finished_jobs_arr

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

        ProgressMeter.@showprogress pmap(args_iter) do (job_id, args)
            if !checkpointing || !done_jobs[job_id]
                _run_experiment(Main.exp_func, job_id, args, extra_args, exception_dir;
                                expand_args=expand_args,
                                verbose=verbose,
                                store_exceptions=store_exceptions,
                                skip_exceptions=skip_exceptions)
                Distributed.put!(job_id_channel, job_id)
                if checkpointing && myid() == 2
                    # Deal w/ job_id_channel...
                    JLD2.@load checkpoint_file finished_jobs_arr
                    while isready(job_id_channel)
                        new_job_id = take!(job_id_channel)
                        finished_jobs_arr[new_job_id] = true
                    end
                    JLD2.@save checkpoint_file finished_jobs_arr
                end
            end
        end

        if checkpointing
            JLD2.@load checkpoint_file finished_jobs_arr
            return findall((x)->x==false, finished_jobs_arr)
        else
            finished_jobs_bool = fill(false, n)
            while isready(job_id_channel)
                job_id = take!(job_id_channel)
                finished_jobs_bool[job_id] = true
            end
            return findall((x)->x==false, finished_jobs_bool)
        end
        
    catch ex
        Distributed.interrupt()
        rethrow()
    end
end



function task_job(experiment_file::AbstractString, exp_dir::AbstractString,
                  args_iter, task_id::Integer;                  
                  exp_module_name::Union{String, Symbol}=:Main,
                  exp_func_name::Union{String, Symbol}=:main_experiment,
                  project=".",
                  extra_args=[],
                  exception_dir="except",
                  checkpoint_name="",
                  store_exceptions=true,
                  verbose=false,
                  skip_exceptions=false,
                  expand_args=false)


    if exception_dir == "except"
        exception_dir = joinpath(exp_dir, exception_dir)
    end
    if store_exceptions && !isdir(exception_dir)
        _safe_mkpath(exception_dir)
    end

    checkpointing = false
    checkpoint_folder = checkpoint_name
    if checkpoint_folder != ""
        # checkpoint_name = joinpath(exp_dir, "checkpoints.jld2")
        # @warn "Checkpointing not available for task jobs."
        _safe_mkpath(checkpoint_folder)
        checkpointing = true
        open(joinpath(checkpoint_folder, "job_$(task_id)"), "w") do f
            write(f, "Not Done")
        end
    end
    
    mod_str = string(exp_module_name)
    func_str = string(exp_func_name)

    @everywhere begin
        include($experiment_file)
        mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
        const global exp_func = getfield(mod, Symbol($func_str))
    end
    
    job_id = task_id
    args = collect(args_iter)[task_id][2]
    ret = @sync @async begin
        _run_experiment(Main.exp_func, job_id, args, extra_args, exception_dir;
                        expand_args=expand_args,
                        verbose=verbose,
                        store_exceptions=store_exceptions,
                        skip_exceptions=skip_exceptions)
    end

    if checkpointing
        rm(joinpath(checkpoint_folder, "job_$(task_id)"))
        if ret == false
            open(joinpath(checkpoint_folder, "job_$(task_id)"), "w") do f
                write(f, "exception while running job! Check exceptions for more details.")
            end
        end
    end
    
    return true
end

