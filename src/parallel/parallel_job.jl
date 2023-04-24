

using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates
using Parallelism

function add_procs(comp_env::SlurmParallel, project, color_opt, job_file_dir)
    num_workers = comp_env.num_tasks
    addprocs(SlurmManager(num_workers);
             exeflags=["--project=$(project)", "--color=$(color_opt)"],
             job_file_loc=job_file_dir)
end

function add_procs(comp_env::LocalParallel, project, color_opt, job_file_dir)
    addprocs(comp_env.num_tasks;
             exeflags=["--project=$(project)", "--color=$(color_opt)"])
end

function create_procs(comp_env, project, job_file_dir)
    # assume started fresh julia instance...
    
    exc_opts = Base.JLOptions()
    color_opt = "no"
    if exc_opts.color == 1
        color_opt = "yes"
    end

    pids = add_procs(comp_env, project, color_opt, job_file_dir)
    
    fetch(pids)
    
end


"""
    parallel_job_inner

Run a parallel job over the arguments presented by args_iter. `args_iter` can be a enumeration OR ArgIterator. Each job will be dedicated to a specific
task. The experiment *must* save its own data! As this is not handled by this function (although could be added in the future.)
"""
function parallel_job_inner(comp_env,
                            experiment,
                            exp_dir_name,
                            checkpoint_file,
                            exception_dir,
                            job_file_dir;
                            project=".",
                            extra_args=[],
                            store_exceptions=true,
                            verbose=false,
                            skip_exceptions=false,
                            expand_args=false,
                            sub_seq=nothing)

    checkpointing = true
    
    if !isdir(job_file_dir)
        mkpath(job_file_dir)
    end
    if store_exceptions && !isdir(exception_dir)
        mkpath(exception_dir)
    end
    if !isdir(dirname(checkpoint_file))
        mkpath(dirname(checkpoint_file))
    end
    
    job_md = experiment.job_metadata
    metadata = experiment.metadata

    exp_dir = metadata.details_loc

    save_back_end = metadata.save_type

    args_iter = if isnothing(sub_seq)
        experiment.args_iter
    else
        # Hack, should be made better, I guess....
        c = filter((a)-> a[1] ∈ sub_seq, collect(experiment.args_iter)) 
        [(i, arg[2]) for (i, arg) in enumerate(c)]
    end

    # Check the Checkpoint
    n = length(args_iter)
    finished_jobs_arr = fill(false, n)
    if isfile(checkpoint_file)
        JLD2.@load checkpoint_file finished_jobs_arr
    else
        JLD2.@save checkpoint_file finished_jobs_arr
    end

    done_jobs = finished_jobs_arr

    @info "Number of Jobs left: $(n - sum(done_jobs))/$(n)"
    num_jobs_left = n - sum(done_jobs)

    if all(done_jobs)
        @info "All jobs finished!"
        return findall((x)->x==false, finished_jobs_arr)
    end
    
    # Experiment Details
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
    pids = create_procs(comp_env, project, job_file_dir)
    threads_per_task = comp_env.threads_per_task
    
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
            ENV["RP_NUM_THREADS"] = string($threads_per_task)
        end

        pgm = ProgressMeter.Progress(num_jobs_left)
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
                        # if we are in local parallel hijak the logger.
                        finished = run_experiment(Main.RP_exp_func,
                                                  job_id,
                                                  args,
                                                  extra_args,
                                                  exception_dir;
                                                  expand_args=expand_args,
                                                  verbose=verbose,
                                                  store_exceptions=store_exceptions,
                                                  skip_exceptions=skip_exceptions)
                        if finished
                            Distributed.put!(job_id_channel, job_id)
                        end
                        Distributed.put!(prg_channel, true)
                    end
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
