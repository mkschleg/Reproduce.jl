



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


include("parallel/job.jl")



