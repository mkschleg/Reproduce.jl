using Dates
using CodeTracking
using Git
using FileIO, JLD2
using Logging


struct Experiment
    dir::AbstractString
    file::AbstractString
    module_name::Union{String, Symbol}
    func_name::Union{String, Symbol}
    args_iter::ArgIterator
    hash::UInt64
    function Experiment(dir::AbstractString,
                        file::AbstractString,
                        module_name::Union{String, Symbol},
                        func_name::Union{String, Symbol},
                        args_iter::ArgIterator)
        new(dir, file, module_name, func_name, args_iter, hash(string(args_iter)))
    end
end


function create_experiment_dir(exp_dir::String;
                               org_file=true, replace=false)

    if isdir(exp_dir)
        if !replace
            @info "directory already created - told to not replace..."
            return
        else
            @info "directory already created - told to replace..."
            rm(joinpath(exp_dir, "notes.org"))
        end
    else
        @info "creating experiment directory"
        # mkdir(exp_dir)
        try
            mkdir(exp_dir)
        catch ex
            @info "Somebody else created directory... Waiting"
            if isa(ex, SystemError) && ex.errnum == 17
                sleep(0.1) # Other Process Made folder. Waiting...
            else
                throw(ex)
            end
        end
    end

    f = open(joinpath(exp_dir, "notes.org"), "w")
    write(f, "#+title: Experimental Notes for $(exp_dir)\n\n\n")
    close(f)

    return
end

function create_experiment_dir(exp::Experiment;
                               kwargs...)
    create_experiment_dir(exp.dir, kwargs...)
    return
end


function add_experiment(exp_dir::AbstractString,
                        experiment_file::AbstractString,
                        exp_module_name::AbstractString,
                        exp_func_name::AbstractString,
                        args_iter::ArgIterator,
                        hash::UInt64;
                        settings_dir="", add_all_tasks=false)

    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        if parse(Int64, ENV["SLURM_ARRAY_TASK_ID"]) != 1 && !add_all_tasks
            job_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
            @info "Told to not add all experiments... job_id : $(job_id) $(job_id == 1)"
            return
        end
    end

    @info "Adding Experiment to $(exp_dir)"

    settings_dir = joinpath(exp_dir, settings_dir)

    if settings_dir != "" && !isdir(settings_dir)
        try
            mkdir(settings_dir)
        catch ex
            if isa(ex, SystemError) && ex.errnum == 17
                sleep(0.1) # Other Process Made folder. Waiting...
            else
                throw(ex)
            end
        end
    end

    settings_file = joinpath(settings_dir, "settings_0x"*string(hash, base=16)*".jld2")

    date_str = Dates.format(now(), dateformat"<yyyy-mm-dd e HH:MM:SS>")
    tab = "\t"

    make_args_str = "nothing"
    if args_iter.make_args != nothing
        m = CodeTracking.@which args_iter.make_args(Dict{String, String}())
        make_args_str, line1 = definition(String, m)
    end


    open(joinpath(exp_dir, "notes.org"), "a") do f
        exp_str = "* " * date_str * "\n\n" *
            tab*"Git-head: $(Git.head())\n" *
            tab*"Git-branch: $(Git.branch())\n" *
            tab*"experiment file: $(experiment_file)\n" *
            tab*"experiment module: $(string(exp_module_name))\n" *
            tab*"experiment function: $(string(exp_func_name))\n\n" *
            tab*"settings file: $(settings_dir)\n\n" *
            tab*"#+BEGIN_SRC julia\n" *
            tab*"dict = $(args_iter.dict)\n" *
            tab*"arg_list = $(args_iter.arg_list)\n" *
            tab*"stable_arg = $(args_iter.stable_arg)\n\n" *
            tab*"#Make Arguments\n" *
            tab*make_args_str *
            tab*"#+END_SRC\n\n"
        write(f, exp_str)
    end

    FileIO.save(settings_file,
                Dict{String, Any}(
                    "args_iter"=>args_iter,
                    "make_args_str"=>make_args_str))

end

function add_experiment(exp::Experiment;
                        kwargs...)

    add_experiment(exp.dir,
                   exp.file,
                   String(exp.module_name),
                   String(exp.func_name),
                   exp.args_iter,
                   exp.hash;
                   kwargs...)

end

function post_experiment(exp_dir::AbstractString, canceled_jobs::Array{Int64, 1})

    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "Post_experiment doesn't work with slurm job arrays."
        return
    end

    tab = "\t"
    date_str = Dates.format(now(), dateformat"<yyyy-mm-dd e HH:MM:SS>")
    open(joinpath(exp_dir, "notes.org"), "a") do f

        post_exp_str = tab*"Post Experiment: \n" *
            tab*"Canceled Jobs: $(canceled_jobs)\n" *
            tab*"Ended: $(date_str)\n"
        write(f, post_exp_str)
    end
end

function post_experiment(exp_dir::AbstractString, finished_job::Bool)
    @info "Post_experiment not supported with task jobs."
end

function post_experiment(exp::Experiment, job_ret)
    post_experiment(exp.dir, job_ret)
end

function exception_file(exc_file::AbstractString, job_id, exception, trace)

    if isfile(exc_file)
        @warn "$(exc_file) already exists. Overwriting..."
    end

    open(exc_file, "w") do f
        exception_string =
            "Exception for job_id: $(job_id)\n\n" * string(exception) * "\n\n"

        write(f, exception_string)
        Base.show_backtrace(f, trace)
    end

    return
end



