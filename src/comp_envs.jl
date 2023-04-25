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


"""
    get_comp_env

This derives the computational environment from the ENV variables. If in a slurm job the [`get_slurm_comp_env`](@ref) is used, if not [`get_local_comp_env`](@ref) is used.
"""
function get_comp_env(; kwargs...) 
    if IN_SLURM()
        get_slurm_comp_env(; kwargs...)
    else
        get_local_comp_env(; kwargs...)
    end
end

"""
    get_local_comp_env

This checks to see if `RP_TASK_ID` is set in the environment. If so, a Task Job with `ID=parse(Int, "RP_TASK_ID")` will be returned. Otherwise, LocalParallel will be used. The kwargs (`num_workers` and `threads_per_worker`) give the job defaults for the number of parallel jobs and the number of threads per task. You can also use the `ENV` variables "RP_NTASKS" and "RP_CPUS_PER_TASK" to override these. The `ENV` variables will take precedence.
"""
function get_local_comp_env(; num_workers=Sys.CPU_THREADS - 1, threads_per_worker=1, kwargs...)

    if "RP_TASK_ID" ∈ keys(ENV)
        TaskJob(parse(Int, "RP_TASK_ID"))
    else
        ntasks = parse(Int, get(ENV, "RP_NTASKS", string(num_workers)))
        threads_per_task = parse(Int, get(ENV, "RP_CPUS_PER_TASK", string(threads_per_worker)))
        LocalParallel(ntasks, threads_per_task)
    end
    
end


"""
    get_slurm_comp_env

This is significantly more complex than a local environment to enable using slurm task arrays efficiently.

In a job scheduled as:
```sh
sbatch -J test_rep_argiter --ntasks 4 --cpus-per-task 1 --mem-per-cpu=2000M --time=0:10:00 toml_parallel.jl configs/arg_iter_config.toml --path /home/mkschleg/scratch/reproduce
```
Then the comp_env will return a `SlurmParallel` env which uses `srun` to create julia instances.

For
```sh
sbatch -J test_rep_argiter -N 1 --ntasks 1 --cpus-per-task 4 --mem-per-cpu=2000M --time=0:10:00 toml_parallel.jl configs/arg_iter_config.toml --path /home/mkschleg/scratch/reproduce
```
The comp env will be a local parallel job using just default julia parallel utilities. It is necessary to make sure all resources are on single node if using this.

For
```sh
sbatch -J test_rep_argiter --array=1-4 --ntasks 4 --cpus-per-task 1 --mem-per-cpu=2000M --time=0:05:00 toml_parallel.jl configs/arg_iter_config.toml --path /home/mkschleg/scratch/reproduce
```
The comp env will be a SlurmTaskArray which will choose either LocalParallel, or SlurmParallel following the above protocol.

*Notes:*
1. If no `SLURM_CPUS_PER_TASK` is set then we assume a single cpu per task.
2. If you are re-running only parts of an array task you need to use "RP_CUSTOM_ARRAY_TASK_COUNT" to let Reproduce know what the original task array looked like to schedule the jobs correctly.


"""
function get_slurm_comp_env(; kwargs...)
    if "SLURM_ARRAY_TASK_ID" ∈ keys(ENV)

        array_id = parse(Int, ENV["SLURM_ARRAY_TASK_ID"])
        array_size = if "RP_CUSTOM_ARRAY_TASK_COUNT" ∈ keys(ENV)
            parse(Int, ENV["RP_CUSTOM_ARRAY_TASK_COUNT"])
        else
            parse(Int, ENV["SLURM_ARRAY_TASK_COUNT"])
        end
        ntasks = parse(Int, ENV["SLURM_NTASKS"])
        cpus_per_task = parse(Int, get(ENV, "SLURM_CPUS_PER_TASK", "1"))

        prl = if ntasks == 1
            # check if RP_TASK_ID is set or there is only a single cpu in the task
            if "RP_TASK_ID" ∈ keys(ENV) || cpus_per_task == 1
                TaskJob(parse(Int, "RP_TASK_ID"))
            else
                # otherwise do local parallel (i.e. only on a signle node!).
                LocalParallel(cpus_per_task, 1)
            end
        else
            SlurmParallel(ntasks, cpus_per_task, ENV["SLURM_JOB_NAME"])
        end
        SlurmTaskArray(array_id, prl, array_size, ENV["SLURM_JOB_NAME"])
    else
        ntasks = parse(Int, ENV["SLURM_NTASKS"])
        cpus_per_task = parse(Int, get(ENV, "SLURM_CPUS_PER_TASK", "1"))
        if ntasks == 1
            LocalParallel(cpus_per_task, 1)
        else
            SlurmParallel(ntasks,
                          cpus_per_task,
                          ENV["SLURM_JOB_NAME"])
        end
    end
end
