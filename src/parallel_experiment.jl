using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates

const IN_SLURM = "SLURM_JOBID" in keys(ENV)
IN_SLURM && using ClusterManagers


"""
job(experiment_file, args_iter; exp_module_name, exp_func_name, num_workers, expand_args)
Interface into running a job.
"""

function job(experiment_file::AbstractString, args_iter;
             exp_module_name::Union{String, Symbol}=:Main,
             exp_func_name::Union{String, Symbol}=:main_experiment,
             num_workers::Integer=5,
             expand_args::Bool=false,
             extra_args = [])
    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "This is an array Job! Time to get task and start job."
        task_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
        @time task_job(experiment_file, args_iter, task_id;
                       exp_module_name=exp_module_name,
                       exp_func_name=exp_func_name,
                       expand_args=expand_args,
                       extra_args=extra_args)
    else
        @time parallel_job(experiment_file, args_iter;
                           exp_module_name=exp_module_name,
                           exp_func_name=exp_func_name,
                           num_workers=num_workers,
                           expand_args=expand_args,
                           extra_args=extra_args)
    end

end


"""
parallel_job(experiment_file::AbstractString, args_iter; exp_module_name::Union, exp_func_name, num_workers, expand_args, project)

Run a parallel job over the arguments presented by args_iter. `args_iter` can be a enumeration OR ArgIterator. Each job will be dedicated to a specific
task. The experiment *must* save its own data! As this is not handled by this function (although could be added in the future.)
"""

function parallel_job(experiment_file::AbstractString,
                      args_iter;
                      exp_module_name::Union{String, Symbol}=:Main,
                      exp_func_name::Union{String, Symbol}=:main_experiment,
                      num_workers=5,
                      expand_args=false,
                      project=".",
                      extra_args=[])

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
        @everywhere const global extra_args=$extra_args
        # @everywhere const global extra_args=$extra_args
        # @everywhere id = myid()

        @everywhere begin
            eval(:(using Reproduce))
            eval(:(using Distributed))
            eval(:(using SharedArrays))
            # eval(:(using ProgressMeter))
            # println(extra_args)
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
            @async begin
                i = 0
                while take!(channel)
                    ProgressMeter.next!(p)
                    i += 1
                    if i == n
                        break
                    end
                end
            end

            @async begin
                # Distributed.@distributed for (args_idx, args) in collect(args_iter)
                for (args_idx, args) in collect(args_iter) @spawn begin
                    if expand_args
                        Main.exp_func(args..., extra_args...)
                    else
                        Main.exp_func(args, extra_args...)
                    end
                    Distributed.put!(channel, true)
                    sleep(0.01)
                    job_id[args_idx] = myid()
                end
                end
            end
        end

        return job_id

    catch ex
        println(ex)
        Distributed.interrupt()
    end

end

function task_job(experiment_file::AbstractString, args_iter, task_id::Integer;
                  exp_module_name::Union{String, Symbol}=:Main,
                  exp_func_name::Union{String, Symbol}=:main_experiment,
                  expand_args::Bool=false,
                  extra_args=[])

    include(experiment_file)
    @info "$(experiment_file) included for Job $(task_id)"
    mod = String(exp_module_name)=="Main" ? Main : getfield(Main, Symbol(exp_module_name))
    exp_func = getfield(mod, Symbol(exp_func_name))
    @info "Running $(task_id)"
    args = collect(args_iter)[task_id][2]
    if expand_args
        exp_func(args..., extra_args...)
    else
        exp_func(args, extra_args...)
    end

end

