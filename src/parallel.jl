



# First include cluster managers:
include("parallel/slurm.jl")
using .ClusterManagers


#=
Dealing with exceptions in a reasonble way
=#

@deprecate exception_file(args...) save_exception(args...)

"""
    save_exception

This function saves an exception file with args:
- `config` The job config that failed.
- `exc_file` the file where the job should be saved.
- `job_id` the id of the job being run (typically the idx of the job in the iterator).
- `exception` the exception thrown by the job.
- `trace` the stack trace of the raised exception.
"""
function save_exception(config, exc_file, job_id, exception, trace)

    if isfile(exc_file)
        @warn "$(exc_file) already exists. Overwriting..."
    end

    open(exc_file, "w") do f
        exception_string = "Exception for job_id: $(job_id)\n\n"
        exception_string *= "Config: \n" * string(config) * "\n\n"
        exception_string *= "Exception: \n" * string(exception) * "\n\n"

        write(f, exception_string)
        Base.show_backtrace(f, trace)
    end

    return
end

function save_exception(exc_file, job_id, exception, trace)

    @warn "Please pass config to exception." maxlog=1
    if isfile(exc_file)
        @warn "$(exc_file) already exists. Overwriting..."
    end

    open(exc_file, "w") do f
        exception_string =
            "Exception for job_id: $(job_id)\n\n" * string(exception) * "\n\n"

        write(f, exception_string)
        Base.show_backtrace(f, trace)
    end

    return
    
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

function job(comp_env::Union{LocalParallel, SlurmParallel},
             experiment::Experiment; kwargs...)
             # project=".",
             # extra_args=[],
             # store_exceptions=true,
             # verbose=false,
             # skip_exceptions=false,
             # expand_args=false)

    #######
    #
    # Preamble - Get detail locations, add processes, initialized shared memory
    #
    ######
    exp_dir = experiment.metadata.details_loc
    exp_hash = experiment.metadata.hash
    exp_dir_name = "exp_0x$(string(exp_hash, base=16))"
    if get_job_name(comp_env) == "job"
        job_file_dir = joinpath(experiment.metadata.job_log_dir, exp_dir_name)
    else
        job_file_dir = joinpath(experiment.metadata.job_log_dir, get_job_name(comp_env))
    end
    
    exception_dir = joinpath(exp_dir, "except", exp_dir_name)
    checkpoint_file = joinpath(exp_dir, "checkpoints", exp_dir_name * ".jld2")

    ######
    #
    # Run Parallel Job.
    #
    ######
    parallel_job_inner(comp_env,
                       experiment,
                       exp_dir_name,
                       checkpoint_file,
                       exception_dir,
                       job_file_dir;
                       kwargs...)
end

function job(comp_env::SlurmTaskArray, experiment::Experiment; kwargs...)
    job_array(comp_env.task_dispatcher, comp_env, experiment; kwargs...)
end


function job_array(comp_env::Union{SlurmParallel, LocalParallel},
                   tsk_array::SlurmTaskArray,
                   experiment::Experiment; kwargs...)
    exp_dir = experiment.metadata.details_loc
    exp_hash = experiment.metadata.hash
    exp_dir_name = "exp_0x$(string(exp_hash, base=16))" * "$(tsk_array.array_idx)"
    job_file_dir = joinpath(experiment.metadata.job_log_dir, get_job_name(tsk_array))
    exception_dir = joinpath(exp_dir, "except", get_job_name(experiment))
    checkpoint_file = joinpath(exp_dir, "checkpoints", exp_dir_name * ".jld2")

    # args_iter = Iterators.partition(experiment.args_iter,
    #                                 Int(ceil(length(experiment.args_iter)/tsk_array.array_size)))
    
    # I Need to modify the experiment args iter.
    # Only do the sequence tsk_array.array_idx:tsk_array.array_size:n
    parallel_job_inner(comp_env,
                       experiment,
                       exp_dir_name,
                       checkpoint_file,
                       exception_dir,
                       job_file_dir;
                       sub_seq=tsk_array.array_idx:tsk_array.array_size:length(experiment.args_iter),
                       kwargs...)
    
end

# function job(comp_env::SlurmParallel, exp; kwargs...)
#     job(exp; kwargs...)
# end

# function job(comp_env::LocalParallel, exp; kwargs...)
#     job(exp; kwargs...)
# end

# function job(comp_env::SlurmTaskArray, exp; kwargs...)
#     task_job(exp; kwargs...)
# end

# function job(comp_env::LocalTask, exp; kwargs...)
#     task_job(exp; kwargs...)
# end

include("parallel/parallel_job.jl")



