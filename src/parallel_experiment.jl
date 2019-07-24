using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates

IN_SLURM = "SLURM_JOBID" in keys(ENV)
IN_SLURM && include("slurm.jl")
IN_SLURM && using .ClusterManagers

"""
job
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
             exception_dir="except",
             job_file_dir=".")
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
        if IN_SLURM
            @time slurm_parallel_job(experiment_file, exp_dir, args_iter;
                                     exp_module_name=exp_module_name,
                                     exp_func_name=exp_func_name,
                                     expand_args=expand_args,
                                     extra_args=extra_args,
                                     store_exceptions=store_exceptions,
                                     exception_dir=exception_dir,
                                     job_file_dir=job_file_dir)
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

end

function job(experiment_file::AbstractString,
             exp_dir::AbstractString,
             args_iter,
             task_id::Integer;
             exp_module_name::Union{String, Symbol}=:Main,
             exp_func_name::Union{String, Symbol}=:main_experiment,
             num_workers::Integer=5,
             expand_args::Bool=false,
             extra_args = [],
             store_exceptions=true,
             exception_dir="except")
    @info "This is a task job! ID is $(task_id)"
    @time task_job(experiment_file, exp_dir, args_iter, task_id;
                   exp_module_name=exp_module_name,
                   exp_func_name=exp_func_name,
                   expand_args=expand_args,
                   extra_args=extra_args,
                   store_exceptions=store_exceptions,
                   exception_dir=exception_dir)
end


job(exp::Experiment; exception_dir="except", kwargs...) =
    job(exp.file, exp.dir, exp.args_iter;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exception_dir)/exp_0x$(string(exp.hash, base=16))", kwargs...)

job(exp::Experiment, job_id::Integer; exception_dir="except", kwargs...) =
    job(exp.file, exp.dir, exp.args_iter, job_id;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exception_dir)/exp_0x$(string(exp.hash, base=16))", kwargs...)


"""
parallel_job

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
                      exception_dir="except", verbose=false)

    #######
    #
    # Preamble - Add processes, initialized shared memory
    #
    ######

    num_add_workers = num_workers - 1
    pids = Array{Int64, 1}

    args_list = collect(args_iter)
    exc_opts = Base.JLOptions()
    color_opt = "no"
    if exc_opts.color == 1
        color_opt = "yes"
    end
    if num_add_workers != 0
        println(num_workers, " ", nworkers())
        if nworkers() == 1
            pids = addprocs(num_workers; exeflags=["--project=$(project)", "--color=$(color_opt)"])
        elseif nworkers() < num_workers
            pids = addprocs((num_workers) - nworkers(); exeflags=["--project=$(project)", "--color=$(color_opt)"])
        else
            pids = procs()
        end
    end

    println(nworkers(), " ", pids)

    n = length(args_iter)
    job_ids = SharedArray{Int64, 1}(n)
    finished_jobs = SharedArray(fill(false, n))

    #########
    #
    # Meaty middle: Compiling code, running jobs, managing which jobs fail.
    #
    ########

    try

        channel = RemoteChannel(()->Channel{Bool}(length(args_iter)), 1)

        mod_str = string(exp_module_name)
        func_str = string(exp_func_name)

        try
            @everywhere const global exp_file=$experiment_file
            @everywhere const global expand_args=$expand_args
            @everywhere const global extra_args=$extra_args
            @everywhere const global store_exceptions=$store_exceptions
            @everywhere const global exception_loc = joinpath($exp_dir, $exception_dir)

            @everywhere begin
                eval(:(using Reproduce))
                eval(:(using Distributed))
                eval(:(using SharedArrays))
                include(exp_file)
                @info "$(exp_file) included on process $(myid())"
                mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
                const global exp_func = getfield(mod, Symbol($func_str))
                experiment(args) = exp_func(args)
                @info "Experiment built on process $(myid())"
            end
        catch ex
            println(ex)
        end

        @info "Number of Jobs: $(n)"
        exception_loc = joinpath(exp_dir, exception_dir)
        if store_exceptions && !isdir(exception_loc)
            mkpath(exception_loc)
        end

        ProgressMeter.@showprogress pmap(args_iter) do (job_id, args)
            try
                if expand_args
                    Main.exp_func(args..., extra_args...)
                else
                    Main.exp_func(args, extra_args...)
                end
                finished_jobs[job_id] = true
            catch ex
                if isa(ex, InterruptException)
                    throw(InterruptException())
                end
                if verbose
                    @warn "Exception encountered for job: $(job_id)"
                end
                if store_exceptions
                    exception_file(
                        joinpath(exception_loc, "job_$(job_id).exc"),
                        job_id, ex, stacktrace(catch_backtrace()))
                end
            end
            Distributed.put!(channel, true)
            job_ids[job_id] = myid()
        end

    catch ex
        println(ex)
        Distributed.interrupt()
    end

    ########
    #
    # Finished. Return which jobs were unsuccessful.
    #
    ########

    println(job_ids)

    return findall((x)->x==false, finished_jobs)

end

function slurm_parallel_job(experiment_file::AbstractString,
                            exp_dir::AbstractString,
                            args_iter;
                            exp_module_name::Union{String, Symbol}=:Main,
                            exp_func_name::Union{String, Symbol}=:main_experiment,
                            expand_args=false,
                            project=".",
                            extra_args=[],
                            store_exceptions=true,
                            exception_dir="except", verbose=false, job_file_dir=".")

    #######
    #
    # Preamble - Add processes, initialized shared memory
    #
    ######

    println("SLURM PARALLEL JOB")
    num_add_workers = parse(Int64, ENV["SLURM_NTASKS"])
    pids = Array{Int64, 1}

    args_list = collect(args_iter)
    exc_opts = Base.JLOptions()
    color_opt = "no"
    if exc_opts.color == 1
        color_opt = "yes"
    end
    if num_add_workers != 0
        # assume started fresh julia instance...
	      println("Adding Slurm Jobs!!!")
        pids = addprocs(SlurmManager(num_add_workers); exeflags=["--project=$(project)", "--color=$(color_opt)"], job_file_loc=job_file_dir)
        print("\n")
    end

    println(nworkers(), " ", pids)
    n = length(args_iter)

    #########
    #
    # Meaty middle: Compiling code, running jobs, managing which jobs fail.
    #
    ########

    finished_jobs = RemoteChannel(()->Channel{Int}(n), 1)

    try

        channel = RemoteChannel(()->Channel{Bool}(length(args_iter)), 1)

        mod_str = string(exp_module_name)
        func_str = string(exp_func_name)
        try
            @everywhere const global exp_file=$experiment_file
            @everywhere const global expand_args=$expand_args
            @everywhere const global extra_args=$extra_args
            @everywhere const global store_exceptions=$store_exceptions
            @everywhere const global exception_loc = joinpath($exp_dir, $exception_dir)

            @everywhere begin
                eval(:(using Reproduce))
                eval(:(using Distributed))
                eval(:(using SharedArrays))
                include(exp_file)
                @info "$(exp_file) included on process $(myid())"
                mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
                const global exp_func = getfield(mod, Symbol($func_str))
                experiment(args) = exp_func(args)
                @info "Experiment built on process $(myid())"
            end
        catch ex
            println(ex)
        end

        @info "Number of Jobs: $(n)"
        exception_loc = joinpath(exp_dir, exception_dir)
        if store_exceptions && !isdir(exception_loc)
            mkpath(exception_loc)
        end

        ProgressMeter.@showprogress pmap(args_iter) do (job_id, args)
            try
                if expand_args
                    Main.exp_func(args..., extra_args...)
                else
                    Main.exp_func(args, extra_args...)
                end
                Distributed.put!(finished_jobs, job_id)
            catch ex
                if isa(ex, InterruptException)
                    throw(InterruptException())
                end
                if verbose
                    @warn "Exception encountered for job: $(job_id)"
                end
                if store_exceptions
                    exception_file(
                        joinpath(exception_loc, "job_$(job_id).exc"),
                        job_id, ex, stacktrace(catch_backtrace()))
                end
            end
            Distributed.put!(channel, true)
        end

    catch ex
        println(ex)
        Distributed.interrupt()
    end

    #########
    #
    # Finished: get from channel which jobs succeeded.
    #
    ########

    finished_jobs_bool = fill(false, n)
    while isready(finished_jobs)
        job_id = take!(finished_jobs)
        finished_jobs_bool[job_id] = true
    end
    return findall((x)->x==false, finished_jobs_bool)
end




function task_job(experiment_file::AbstractString, exp_dir::AbstractString,
                  args_iter, task_id::Integer;
                  exp_module_name::Union{String, Symbol}=:Main,
                  exp_func_name::Union{String, Symbol}=:main_experiment,
                  expand_args::Bool=false,
                  extra_args=[],
                  store_exceptions=true,
                  exception_dir="except")

    mod_str = string(exp_module_name)
    func_str = string(exp_func_name)

    @everywhere begin
        include($experiment_file)
        mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
        const global exp_func = getfield(mod, Symbol($func_str))
    end

    args = collect(args_iter)[task_id][2]
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
                        mkpath(exception_loc)
                    catch
                        sleep(1)
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

