IN_SLURM() = ("SLURM_JOBID" ∈ keys(ENV)) && ("SLURM_NTASKS" ∈ keys(ENV))

struct TaskJob
    id::Int
end

struct LocalParallel
    num_tasks::Int
    threads_per_task::Int
end

struct SlurmParallel
    num_tasks::Int
    threads_per_task::Int
    job_name::String
end

struct SlurmTaskArray
    array_idx::Int
    task_dispatcher::Union{TaskJob, LocalParallel, SlurmParallel} # task arrays
    array_size::Int
    job_name::String
end

get_job_name(comp_env) = "job"
get_job_name(comp_env::SlurmParallel) = comp_env.job_name
get_job_name(comp_env::SlurmTaskArray) = comp_env.job_name * "_$(comp_env.array_idx)"

function get_comp_env(; kwargs...) 
    if IN_SLURM()
        get_slurm_comp_env(; kwargs...)
    else
        get_local_comp_env(; kwargs...)
    end
end

function get_local_comp_env(; num_workers=Sys.CPU_THREADS - 1, threads_per_worker=1, kwargs...)

    if "RP_TASK_ID" ∈ keys(ENV)
        TaskJob(parse(Int, "RP_TASK_ID"))
    else
        ntasks = parse(Int, get(ENV, "RP_NTASKS", string(num_workers)))
        threads_per_task = parse(Int, get(ENV, "RP_CPUS_PER_TASK", string(threads_per_worker)))
        LocalParallel(ntasks, threads_per_task)
    end
    
end

function get_slurm_comp_env(; kwargs...)
    if "SLURM_ARRAY_TASK_ID" ∈ keys(ENV)

        array_id = parse(Int, ENV["SLURM_ARRAY_TASK_ID"])
        array_size = if "RP_CUSTOM_ARRAY_TASK_COUNT" ∈ keys(ENV)
            parse(Int, ENV["RP_CUSTOM_ARRAY_TASK_COUNT"])
        else
            parse(Int, ENV["SLURM_ARRAY_TASK_COUNT"])
        end
        ntasks = parse(Int, ENV["SLURM_NTASKS"])
        cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"])

        prl = if ntasks == 1
            # check if RP_ONE_PARAM is set
            if "RP_TASK_ID" ∈ keys(ENV) || cpus_per_task > 1
                TaskJob(parse(Int, "RP_TASK_ID"))
            else
                # otherwise do local parallel (i.e. only on a signle node!).
                LocalParallel(ntasks, cpus_per_task)
            end
        else
            SlurmParallel(ntasks, cpus_per_task, ENV["SLURM_JOB_NAME"])
        end
        SlurmTaskArray(array_id, prl, array_size, ENV["SLURM_JOB_NAME"])
    else
        SlurmParallel(parse(Int, ENV["SLURM_NTASKS"]),
                      parse(Int, ENV["SLURM_CPUS_PER_TASK"]),
                      ENV["SLURM_JOB_NAME"])
    end
end
