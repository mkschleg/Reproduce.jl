


function job(comp_env::TaskJob
             experiment::Experiment;
             project=".",
             extra_args=[],
             store_exceptions=true,
             verbose=false,
             skip_exceptions=false,
             expand_args=false)
    
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
