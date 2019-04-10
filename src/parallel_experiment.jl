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

function job(experiment_file::AbstractString,
             exp_dir::AbstractString,
             args_iter;
             exp_module_name::Union{String, Symbol}=:Main,
             exp_func_name::Union{String, Symbol}=:main_experiment,
             num_workers::Integer=5,
             expand_args::Bool=false,
             extra_args = [],
             store_exceptions=true,
             exception_dir="except")
    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "This is an array Job! Time to get task and start job."
        task_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
        @time task_job(experiment_file, exp_dir, args_iter, task_id;
                       exp_module_name=exp_module_name,
                       exp_func_name=exp_func_name,
                       expand_args=expand_args,
                       extra_args=extra_args,
                       store_exceptions=store_exceptions,
                       exception_dir=exception_dir)
    else
        @time parallel_job(experiment_file, exp_dir, args_iter;
                           exp_module_name=exp_module_name,
                           exp_func_name=exp_func_name,
                           num_workers=num_workers,
                           expand_args=expand_args,
                           extra_args=extra_args,
                           store_exceptions=store_exceptions,
                           exception_dir=exception_dir)
    end

end


"""
parallel_job(experiment_file::AbstractString, args_iter; exp_module_name::Union, exp_func_name, num_workers, expand_args, project)

Run a parallel job over the arguments presented by args_iter. `args_iter` can be a enumeration OR ArgIterator. Each job will be dedicated to a specific
task. The experiment *must* save its own data! As this is not handled by this function (although could be added in the future.)
"""

function parallel_job(experiment_file::AbstractString,
                      exp_dir::AbstractString,
                      args_iter;
                      exp_module_name::Union{String, Symbol}=:Main,
                      exp_func_name::Union{String, Symbol}=:main_experiment,
                      num_workers=1,
                      expand_args=false,
                      project=".",
                      extra_args=[],
                      store_exceptions=true,
                      exception_dir="except")

    num_add_workers = num_workers - 1
    pids = Array{Int64, 1}

    if num_add_workers != 0
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
    end

    println(nworkers(), " ", pids)

    n = length(args_iter)
    job_id = SharedArray{Int64, 1}(n)
    finished_jobs = SharedArray(fill(false, n))


    try

        p = Progress(length(args_iter))
        channel = RemoteChannel(()->Channel{Bool}(length(args_iter)), 1)
        exception_channel = RemoteChannel(()->Channel{Tuple{Int64, Array{String, 1}}}(length(args_iter)), 1)

        mod_str = string(exp_module_name)
        func_str = string(exp_func_name)
        @everywhere const global exp_file=$experiment_file
        @everywhere const global expand_args=$expand_args
        @everywhere const global extra_args=$extra_args
        @everywhere const global store_exceptions=$store_exceptions
        @everywhere const global exception_loc = joinpath($exp_dir, $exception_dir)
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

        @info "Number of Jobs: $(n)"
        exception_loc = joinpath(exp_dir, exception_dir)
        if store_exceptions && !isdir(exception_loc)
            mkdir(exception_loc)
        end

        @sync begin

            @async begin
                # println("Begin progress")
                i = 0
                while i < n
                    while isready(channel)
                        take!(channel)
                        ProgressMeter.next!(p)
                        i += 1
                    end
                    yield()
                    # sleep(1)
                end
            end

            # @async begin
            @async @sync for (args_idx, args) in collect(args_iter) @spawn begin
                try
                    if expand_args
                        Main.exp_func(args..., extra_args...)
                    else
                        Main.exp_func(args, extra_args...)
                    end
                    finished_jobs[args_idx] = true
                catch ex
                    # @error "Exception Caught for job $(args_idx)\n" * string(ex)
                    if isa(ex, InterruptException)
                        # Distributed.interrupt()
                        throw(InterruptException())
                    end

                    if store_exceptions
                        trace = stacktrace(catch_backtrace())
                        exception_file(
                            joinpath(exception_loc, "job_$(arg_idx).exc"),
                            arg_idx, ex, trace)
                    end
                    # Distributed.put!(exception_channel, (args_idx, ex))
                end
                Distributed.put!(channel, true)
                job_id[args_idx] = myid()
            end
            end

        end

        return findall((x)->x==false, finished_jobs)

    catch ex
        println(ex)
        Distributed.interrupt()
        println("Here")
        return findall((x)->x==false, finished_jobs)
    end

end

function task_job(experiment_file::AbstractString, exp_dir::AbstractString,
                  args_iter, task_id::Integer;
                  exp_module_name::Union{String, Symbol}=:Main,
                  exp_func_name::Union{String, Symbol}=:main_experiment,
                  expand_args::Bool=false,
                  extra_args=[],
                  store_exceptions=true,
                  exception_dir="except")



    # @everywhere const global exp_file=$experiment_file
    # @everywhere const global extra_args=$extra_args
    # @everywhere id = myid()
    mod_str = string(exp_module_name)
    func_str = string(exp_func_name)

    @everywhere begin
        include($experiment_file)
        mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
        const global exp_func = getfield(mod, Symbol($func_str))
        println(exp_func)
    end

    # @everywhere begin
    #     include(experiment_file)
    #     exp_func = exp_func_name
    # end

    args = collect(args_iter)[task_id][2]
    println("Here")
    @sync @async begin
        try
            if expand_args
                Main.exp_func(args..., extra_args...)
            else
                Main.exp_func(args, extra_args...)
            end
        catch ex
            @warn "Exception encountered for job: $(task_id)"
            if store_exceptions
                exception_loc = joinpath(exp_dir, exception_dir)
                if !isdir(exception_loc)
                    try
                        mkdir(exception_loc)
                    catch
                        sleep(1)
                        mkdir(exception_loc)
                    end
                end
                exception_file(
                    joinpath(exception_loc, "job_$(task_id).exc"),
                    task_id, ex, stacktrace(catch_backtrace()))
                return false
            end
            throw(ex)
        end
    end
    return true
end

