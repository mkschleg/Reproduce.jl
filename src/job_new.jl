
using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates
using Parallelism
# using Config

include("slurm.jl")
using .ClusterManagers

# IN_SLURM() = ("SLURM_JOBID" ∈ keys(ENV)) && ("SLURM_NTASKS" ∈ keys(ENV))


"""
    job(experiment::Experiment; kwargs...)
    job(experiment_file, exp_dir, args_iter; kwargs...)
    job(experiment::Experiment, job_id; kwargs...)
    job(experiment_file, exp_dir, args_iter, job_id; kwargs...)

Run a job specified by the experiment.
"""
function job(exp::Experiment; kwargs...)
    comp_env = exp.metadata.comp_env
    job(comp_env, exp; kwargs...)
end
# job(exp.file,
#     exp.dir,
#     exp.args_iter;
#     exp_module_name=exp.module_name,
#     exp_func_name=exp.func_name,
#     exception_dir="$(exp.dir)/except/exp_0x$(string(exp.hash, base=16))",
#     checkpoint_name="$(exp.dir)/checkpoints/exp_0x$(string(exp.hash, base=16))",
#     kwargs...)

function job(comp_env::SlurmParallel, exp; kwargs...)
    parallel_job(exp; kwargs...)
end

function job(comp_env::SlurmTaskArray, exp; kwargs...)
    task_job(exp; kwargs...)
end

function job(comp_env::LocalParallel, exp; kwargs...)
    parallel_job(exp; kwargs...)
end

function job(comp_env::LocalTask, exp; kwargs...)
    task_job(exp; kwargs...)
end

# function job(exp, job_id; kwargs...)
#     task_job(exp, job_id; kwargs...)
# end

function add_procs(comp_env::SlurmParallel, num_workers, project, color_opt, job_file_dir)
    num_workers = comp_env.num_procs
    addprocs(SlurmManager(num_workers);
             exeflags=["--project=$(project)", "--color=$(color_opt)"],
             job_file_loc=job_file_dir)
end

function add_procs(comp_env::LocalParallel, num_workers, project, color_opt, job_file_dir)
    if comp_env.num_procs == 0
        addprocs(num_workers;
                 exeflags=["--project=$(project)", "--color=$(color_opt)"])
    else
        addprocs(comp_env.num_procs;
                 exeflags=["--project=$(project)", "--color=$(color_opt)"])
    end
end

function create_procs(comp_env, num_workers, project, job_file_dir)
    # assume started fresh julia instance...
    
    exc_opts = Base.JLOptions()
    color_opt = "no"
    if exc_opts.color == 1
        color_opt = "yes"
    end

    pids = add_procs(comp_env, num_workers, project, color_opt, job_file_dir)
    
    fetch(pids)
    
end

function run_experiment(exp_func,
                        job_id,
                        args,
                        extra_args,
                        exception_loc;
                        expand_args=false,
                        verbose=false,
                        store_exceptions=true,
                        skip_exceptions=false,
                        kwargs...)


    run_exp = !(isfile(joinpath(exception_loc, "job_$(job_id).exc")))

    # if the exception doesn't exist and we haven't set skip_exceptions
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
                save_exception(
                    joinpath(exception_loc, "job_$(job_id).exc"),
                    job_id, ex, stacktrace(catch_backtrace()))
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
function parallel_job(
    experiment::Experiment;
    num_workers=Sys.CPU_THREADS - 1,
    project=".",
    extra_args=[],
    # job_file_dir="",
    store_exceptions=true,
    verbose=false,
    skip_exceptions=false,
    expand_args=false)
    
    # experiment_file::AbstractString,
    # exp_dir::AbstractString,
    # args_iter;
    # exp_module_name::Union{String, Symbol}=:Main,
    # exp_func_name::Union{String, Symbol}=:main_experiment,
    # num_workers=Sys.CPU_THREADS - 1,
    # project=".",
    # extra_args=[],
    # exception_dir="except",
    # job_file_dir="",
    # checkpoint_name="",
    # store_exceptions=true,
    # verbose=false,
    # skip_exceptions=false,
    # expand_args=false)

    job_md = experiment.job_metadata
    metadata = experiment.metadata
    comp_env = metadata.comp_env
    exp_dir = metadata.details_loc

    args_iter = experiment.args_iter
    
    #######
    #
    # Preamble - Get detail locations, add processes, initialized shared memory
    #
    ######
    exp_hash = metadata.hash
    
    exp_dir_name = "exp_0x$(string(exp_hash, base=16))"

    job_file_dir = joinpath(exp_dir, "jobs", exp_dir_name)

    exception_dir = joinpath(exp_dir, "except", exp_dir_name)
    if store_exceptions && !isdir(exception_dir)
        mkpath(exception_dir)
    end

    checkpointing = true
    checkpoint_file = joinpath(exp_dir, "checkpoints", exp_dir_name * ".jld2")

    
    n = length(args_iter)

    finished_jobs_arr = fill(false, n)

    if !isdir(dirname(checkpoint_file))
        mkpath(dirname(checkpoint_file))
    end
    if isfile(checkpoint_file)
        JLD2.@load checkpoint_file finished_jobs_arr
    else
        JLD2.@save checkpoint_file finished_jobs_arr
    end

    done_jobs = finished_jobs_arr

    @info "Number of Jobs left: $(n - sum(done_jobs))/$(n)"

    if all(done_jobs)
        @info "All jobs finished!"
        return findall((x)->x==false, finished_jobs_arr)
    end

    experiment_file = job_md.file
    exp_module_name = job_md.module_name
    exp_func_name = job_md.func_name

    if !(isabspath(experiment_file))
        experiment_file = abspath(experiment_file)
    end

    #########
    #
    # Meaty middle: Compiling code, running jobs, managing which jobs fail.
    #
    ########

    # job_id_channel: a job id will appear here if a job is finished.
    job_id_channel = RemoteChannel(()->Channel{Int}(min(1000, length(args_iter))), 1)
    prg_channel = RemoteChannel(()->Channel{Bool}(min(1000, length(args_iter))), 1)

    # Include on first proc for pre-compiliation
    @info "pre-compile"
    @everywhere begin
        include($experiment_file)
    end

    # create processes.
    pids = create_procs(comp_env, num_workers, project, job_file_dir)

    try

        mod_str = string(exp_module_name)
        func_str = string(exp_func_name)

        @everywhere const global RP_exp_file=$experiment_file

        @everywhere begin
            eval(:(using Reproduce))
            eval(:(using Distributed))
            eval(:(using SharedArrays))

            include(RP_exp_file)
            @info "$(RP_exp_file) included on process $(myid())"
            mod = $mod_str == "Main" ? Main : getfield(Main, Symbol($mod_str))
            const global RP_exp_func = getfield(mod, Symbol($func_str))
            @info "Experiment built on process $(myid())"
        end

        pgm = ProgressMeter.Progress(length(args_iter))

        @sync begin
            @async while Distributed.take!(prg_channel)
                ProgressMeter.next!(pgm)
                JLD2.@load checkpoint_file finished_jobs_arr
                while isready(job_id_channel)
                    new_job_id = take!(job_id_channel)
                    finished_jobs_arr[new_job_id] = true
                end
                JLD2.@save checkpoint_file finished_jobs_arr
            end

            @sync begin
                robust_pmap(args_iter) do (job_id, args)
                    if !checkpointing || !done_jobs[job_id]
                        finished = run_experiment(Main.RP_exp_func, job_id, args, extra_args, exception_dir;
                                                  expand_args=expand_args,
                                                  verbose=verbose,
                                                  store_exceptions=store_exceptions,
                                                  skip_exceptions=skip_exceptions)
                        if finished
                            Distributed.put!(job_id_channel, job_id)
                        end
                    end
                    Distributed.put!(prg_channel, true)
                    yield()
                end
                Distributed.put!(prg_channel, false)
            end
        end

        if checkpointing
            JLD2.@load checkpoint_file finished_jobs_arr
            return findall((x)->x==false,  finished_jobs_arr)
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



function task_job(experiment_file::AbstractString,
                  exp_dir::AbstractString,
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
        run_experiment(Main.exp_func, job_id, args, extra_args, exception_dir;
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
