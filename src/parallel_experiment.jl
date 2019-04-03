using Distributed
using Random
using ProgressMeter
using Logging

const IN_SLURM = "SLURM_JOBID" in keys(ENV)
IN_SLURM && using ClusterManagers


function job(experiment_file, args_iter; exp_module_name=:Main, exp_func_name=:main_experiment, num_workers=5, expand_args=false)
    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "This is an array Job! Time to get task and start job."
        task_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
        @time task_job(experiment_file, args_iter, task_id;
                       exp_module_name=exp_module_name,
                       exp_func_name=exp_func_name,
                       expand_args=expand_args)
    else
        @time parallel_job(experiment_file, args_iter;
                           exp_module_name=exp_module_name,
                           exp_func_name=exp_func_name,
                           num_workers=num_workers,
                           expand_args=expand_args)
    end

end


function parallel_job(experiment_file, args_iter; exp_module_name=:Main, exp_func_name=:main_experiment, num_workers=5, expand_args=false)

    pids = Array{Int64, 1}
    if IN_SLURM
        # assume started fresh julia instance...
        pids = addprocs(SlurmManager(parse(Int, ENV["SLURM_NTASKS"])))
        print("\n")
    else
        println(num_workers, " ", nworkers())
        if nworkers() == 1
            pids = addprocs(num_workers;exeflags="--project=.")
        elseif nworkers() < num_workers
            pids = addprocs((num_workers) - nworkers();exeflags="--project=.")
        else
            pids = procs()
        end
    end

    println(nworkers(), " ", pids)

    try

        p = Progress(length(args_iter))
        channel = RemoteChannel(()->Channel{Bool}(length(args_iter)), 1)

        mod_str = string(exp_module_name)
        func_str = string(exp_func_name)
        @everywhere global exp_file=$experiment_file
        @everywhere global expand_args=$expand_args
        # @everywhere global exp_mod_name=$str
        # @everywhere global exp_f_name=$exp_func_name
        @everywhere begin
            include(exp_file)
            @info "$(exp_file) included on process $(myid())"
            exp_func = getfield(getfield(Main, Symbol($mod_str)), Symbol($func_str))
            experiment(args) = exp_func(args)
            @info "Experiment built on process $(myid())"
        end

        n = length(args_iter)
        println(n)

        @sync begin
            @async while take!(channel)
                ProgressMeter.next!(p)
            end

            @async begin
                @distributed (+) for (args_idx, args) in collect(args_iter)
                    if expand_args
                        experiment(args...)
                    else
                        experiment(args)
                    end
                    sleep(0.01)
                    put!(channel,true)
                    0
                end
                put!(channel, false)
            end
        end

    catch ex
        println(ex)
        Distributed.interrupt()
    end

end

function task_job(experiment_file, args_iter, task_id; exp_module_name=:Main, exp_func_name=:main_experiment, expand_args=false)

    include(exp_file)
    @info "$(exp_file) included for Job $(task_id)"
    exp_func = getfield(getfield(Main, Symbol(exp_module_name)), Symbol(exp_func_name))
    @info "Running $(task_it)"
    args = collect(args_iter)[task_id]
    if expand_args
        exp_func(args...)
    else
        exp_func(args)
    end

end


