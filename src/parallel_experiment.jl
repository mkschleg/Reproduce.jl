using Distributed
using ProgressMeter
using Logging
using SharedArrays

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


function parallel_job(experiment_file, args_iter; exp_module_name=:Main, exp_func_name=:main_experiment, num_workers=5, expand_args=false, project=".")

    pids = Array{Int64, 1}
    if IN_SLURM
        # assume started fresh julia instance...
        pids = addprocs(SlurmManager(parse(Int, ENV["SLURM_NTASKS"])))
        print("\n")
    else
        println(num_workers, " ", nworkers())
        if nworkers() == 1
            pids = addprocs(num_workers;exeflags=["--project=$(project)", "--color=yes"])
        elseif nworkers() < num_workers
            pids = addprocs((num_workers) - nworkers();exeflags=["--project=$(project)", "--color=yes"])
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
        @everywhere const global exp_file=$experiment_file
        @everywhere const global expand_args=$expand_args
        # @everywhere id = myid()

        @everywhere begin
            eval(:(using Reproduce))
            eval(:(using Distributed))
            eval(:(using SharedArrays))
            # eval(:(using ProgressMeter))
            include(exp_file)
            @info "$(exp_file) included on process $(myid())"
            mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
            const global exp_func = getfield(mod, Symbol($func_str))
            experiment(args) = exp_func(args)
            @info "Experiment built on process $(myid())"
        end

        n = length(args_iter)
        println(n)

        job_id = SharedArray{Int64, 1}(n)

        @sync begin
            @async while take!(channel)
                ProgressMeter.next!(p)
            end

            @async begin
                # Distributed.@distributed for (args_idx, args) in collect(args_iter)
                for (args_idx, args) in collect(args_iter) @spawn begin
                    if expand_args
                        Main.exp_func(args...)
                    else
                        Main.exp_func(args)
                    end
                    Distributed.put!(channel,true)
                    job_id[args_idx] = myid()
                end
                end
                Distributed.put!(channel, false)
            end
        end
        return println(job_id)

    catch ex
        println(ex)
        Distributed.interrupt()
    end

end

function task_job(experiment_file, args_iter, task_id; exp_module_name=:Main, exp_func_name=:main_experiment, expand_args=false)

    include(experiment_file)
    @info "$(experiment_file) included for Job $(task_id)"
    mod = String(exp_module_name)=="Main" ? Main : getfield(Main, Symbol(exp_module_name))
    exp_func = getfield(mod, Symbol(exp_func_name))
    @info "Running $(task_id)"
    args = collect(args_iter)[task_id][2]
    if expand_args
        exp_func(args...)
    else
        exp_func(args)
    end

end


function create_experiment_dir(res_dir::String,
                               experiment_file::String,
                               args_iter;
                               exp_module_name=:Main,
                               exp_func_name=:main_experiment,
                               org_file=true, replace=false)

    if isdir(res_dir)
        if !replace
            @info "directory already created - told to not replace..."
            return
        else
            @info "directory already created - told to replace..."
            rm(joinpath(res_dir, "notes.org"))
        end
    else
        @info "creating experiment directory"
        mkdir(res_dir)
    end

    f = open(joinpath(res_dir, "notes.org"), "w")

    write(f, "#+title: Experimental Notes for $(experiment_file)\n\n\n")
    write(f, "experiment module: $(string(exp_module_name))\n")
    write(f, "experiment function: $(string(exp_func_name))\n\n")
    write(f, "#+BEGIN_SRC julia\n")
    write(f, "dict = $(args_iter.dict)\n")
    write(f, "arg_list = $(args_iter.arg_list)\n")
    write(f, "stable_arg = $(args_iter.stable_arg)\n")
    write(f, "#+END_SRC")
    close(f)

    return
end
