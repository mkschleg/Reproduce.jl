
using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates
using Parallelism
# using Config


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
                    args,
                    joinpath(exception_loc, "job_$(job_id).exc"),
                    job_id,
                    ex,
                    stacktrace(catch_backtrace()))
            end
            return false
        end
    elseif verbose
        @warn  "Not running job for $(job_id)"
    end

    return true

end





function task_job(exp::Experiment; kwargs...)
    throw("Task job not quite implemented yet...")
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
