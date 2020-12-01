
using Distributed
using ProgressMeter
using Logging
using SharedArrays
using JLD2
using Dates
# using Config

include("slurm.jl")
using .ClusterManagers

IN_SLURM() = return "SLURM_JOBID" ∈ keys(ENV)


"""
    job(experiment::Experiment; kwargs...)
    job(experiment_file, exp_dir, args_iter; kwargs...)
    job(experiment::Experiment, job_id; kwargs...)
    job(experiment_file, exp_dir, args_iter, job_id; kwargs...)

Run a job specified by the experiment.
"""
job(exp::Experiment, args...; kwargs...) =
    job(exp.file,
        exp.dir,
        exp.args_iter;
        exp_module_name=exp.module_name,
        exp_func_name=exp.func_name,
        exception_dir="$(exp.dir)/except/exp_0x$(string(exp.hash, base=16))",
        checkpoint_name="$(exp.dir)/checkpoints/exp_0x$(string(exp.hash, base=16))",
        kwargs...)

function job(experiment_file,
             exp_dir,
             args_iter;
             kwargs...)
    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "This is an array Job! Time to get task and start job."
        task_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
        @time task_job(experiment_file,
                       exp_dir,
                       args_iter,
                       task_id;
                       kwargs...)
    else
        @time parallel_job(experiment_file,
                           exp_dir,
                           args_iter;
                           kwargs...)
    end
end


function job(experiment_file::AbstractString,
             exp_dir::AbstractString,
             args_iter,
             job_id;
             kwargs...)
    @info "This is a task job! ID is $(job_id)"
    @time task_job(experiment_file,
                   exp_dir,
                   args_iter,
                   job_id;
                   kwargs...)
end


function create_procs(num_workers, project, job_file_dir)
    # assume started fresh julia instance...
    
    pids = Array{Int64, 1}()
    exc_opts = Base.JLOptions()
    color_opt = "no"
    if exc_opts.color == 1
        color_opt = "yes"
    end

    if IN_SLURM()
        num_add_workers = parse(Int64, ENV["SLURM_NTASKS"])
        if num_add_workers != 0
            pids = addprocs(SlurmManager(num_add_workers);
                            exeflags=["--project=$(project)", "--color=$(color_opt)"],
                            job_file_loc=job_file_dir)
        end
    else 
        if nworkers() == 1
            pids = addprocs(num_workers;
                            exeflags=["--project=$(project)", "--color=$(color_opt)"])
        elseif nworkers() < num_workers
            pids = addprocs((num_workers) - nworkers();
                            exeflags=["--project=$(project)", "--color=$(color_opt)"])
        else
            pids = procs()
        end
    end
    return fetch(pids)
end

function run_experiment(exp_func, job_id, args, extra_args, exception_loc;
                         expand_args=false,
                         verbose=false,
                         store_exceptions=true,
                         skip_exceptions=false)

    run_exp = !(isfile(joinpath(exception_loc, "job_$(job_id).exc")))

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
                exception_file(
                    joinpath(exception_loc, "job_$(job_id).exc"),
                    job_id, ex, stacktrace(catch_backtrace()))
            end
            return false
        end
    elseif verbose
        @warn  "Not running job for $(job_id)"
    end

    return true

end



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
                      num_workers=Sys.CPU_THREADS - 1,
                      project=".",
                      extra_args=[],
                      exception_dir="except",
                      job_file_dir="",
                      checkpoint_name="",
                      store_exceptions=true,
                      verbose=false,
                      skip_exceptions=false,
                      expand_args=false)

    #######
    #
    # Preamble - Add processes, initialized shared memory
    #
    ######
    if job_file_dir == ""
        job_file_dir = joinpath(exp_dir, "jobs")
    end

    if exception_dir == "except"
        exception_dir = joinpath(exp_dir, exception_dir)
    end
    if store_exceptions && !isdir(exception_dir)
        mkpath(exception_dir)
    end

    checkpointing = true
    checkpoint_file = checkpoint_name
    if checkpoint_name == ""
        checkpointing = false
    elseif splitext(checkpoint_file)[end] != ".jld2"
        checkpoint_file = checkpoint_file * ".jld2"
    end

    n = length(args_iter)

    finished_jobs_arr = fill(false, n)
    if checkpointing
        if !isdir(dirname(checkpoint_file))
            mkpath(dirname(checkpoint_file))
        end
        if isfile(checkpoint_file)
            JLD2.@load checkpoint_file finished_jobs_arr
        else
            JLD2.@save checkpoint_file finished_jobs_arr
        end
    end
    done_jobs = finished_jobs_arr

    @info "Number of Jobs left: $(n - sum(done_jobs))/$(n)"

    if all(done_jobs)
        @info "All jobs finished!"
        return findall((x)->x==false, finished_jobs_arr)
    end

    #########
    #
    # Meaty middle: Compiling code, running jobs, managing which jobs fail.
    #
    ########

    # job_id_channel: a job id will appear here if a job is finished.
    job_id_channel = RemoteChannel(()->Channel{Int}(length(args_iter)), 1)

    # Include on first proc for pre-compiliation
    @info "pre-compile"
    @everywhere begin
        include($experiment_file)
    end

    # create processes.
    pids = create_procs(num_workers, project, job_file_dir)
    println(nworkers(), " ", pids)

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
            mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
            const global RP_exp_func = getfield(mod, Symbol($func_str))
            @info "Experiment built on process $(myid())"
        end

        ProgressMeter.@showprogress pmap(args_iter) do (job_id, args)
            if !checkpointing || !done_jobs[job_id]
                finished = run_experiment(Main.RP_exp_func, job_id, args, extra_args, exception_dir;
                                          expand_args=expand_args,
                                          verbose=verbose,
                                          store_exceptions=store_exceptions,
                                          skip_exceptions=skip_exceptions)
                if finished
                    Distributed.put!(job_id_channel, job_id)
                end
                
                if checkpointing && myid() == 2
                    # Deal w/ job_id_channel...
                    JLD2.@load checkpoint_file finished_jobs_arr
                    while isready(job_id_channel)
                        new_job_id = take!(job_id_channel)
                        finished_jobs_arr[new_job_id] = true
                    end
                    JLD2.@save checkpoint_file finished_jobs_arr
                end
            end
        end

        if checkpointing
            JLD2.@load checkpoint_file finished_jobs_arr
            return findall((x)->x==false, finished_jobs_arr)
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



function task_job(experiment_file::AbstractString,
                  exp_dir::AbstractString,
                  args_iter, task_id::Integer;                  
                  exp_module_name::Union{String, Symbol}=:Main,
                  exp_func_name::Union{String, Symbol}=:main_experiment,
                  project=".",
                  extra_args=[],
                  exception_dir="except",
                  checkpoint_name="",
                  store_exceptions=true,
                  verbose=false,
                  skip_exceptions=false,
                  expand_args=false)


    if exception_dir == "except"
        exception_dir = joinpath(exp_dir, exception_dir)
    end
    if store_exceptions && !isdir(exception_dir)
        _safe_mkpath(exception_dir)
    end

    checkpointing = false
    checkpoint_folder = checkpoint_name
    if checkpoint_folder != ""
        _safe_mkpath(checkpoint_folder)
        checkpointing = true
        open(joinpath(checkpoint_folder, "job_$(task_id)"), "w") do f
            write(f, "Not Done")
        end
    end
    
    mod_str = string(exp_module_name)
    func_str = string(exp_func_name)

    @everywhere begin
        include($experiment_file)
        mod = $mod_str=="Main" ? Main : getfield(Main, Symbol($mod_str))
        const global exp_func = getfield(mod, Symbol($func_str))
    end
    
    job_id = task_id
    args = collect(args_iter)[task_id][2]
    ret = @sync @async begin
        run_experiment(Main.exp_func, job_id, args, extra_args, exception_dir;
                       expand_args=expand_args,
                       verbose=verbose,
                       store_exceptions=store_exceptions,
                       skip_exceptions=skip_exceptions)
    end

    if checkpointing
        rm(joinpath(checkpoint_folder, "job_$(task_id)"))
        if ret == false
            open(joinpath(checkpoint_folder, "job_$(task_id)"), "w") do f
                write(f, "exception while running job! Check exceptions for more details.")
            end
        end
    end
    
    return true
end

