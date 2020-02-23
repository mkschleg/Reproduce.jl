using Dates
using CodeTracking
using Git
using JLD2
using Logging

# Config files
using Pkg.TOML
using JSON

"""
    Experiment

This is a struct which encapsulates the idea of an experiment.

"""
struct Experiment{I}
    dir::AbstractString
    file::AbstractString
    module_name::Symbol
    func_name::Symbol
    args_iter::I
    hash::UInt64
    config::Union{String, Nothing}
    function Experiment(dir::AbstractString,
                        file::AbstractString,
                        module_name::Union{String, Symbol},
                        func_name::Union{String, Symbol},
                        args_iter,
                        config=nothing)
        new{typeof(args_iter)}(dir, file, Symbol(module_name), Symbol(func_name), args_iter, hash(string(args_iter)), config)
    end
end

function Experiment(config::AbstractString, save_path = "")

    
    dict = if splitext(config)[end] == ".toml"
        TOML.parsefile(config)
    elseif splitext(config)[end] == ".json"
        JSON.Parser.parsefile(config)
    end

    cdict = dict["config"]
    save_dir = joinpath(save_path, cdict["save_dir"])
    exp_file = cdict["exp_file"]
    exp_module_name = cdict["exp_module_name"]
    exp_func_name = cdict["exp_func_name"]

    iter_type = cdict["arg_iter_type"]


    args = if iter_type == "iter"
        arg_list = get(cdict, "arg_list_order", nothing)

        @assert arg_list isa Nothing || all(sort(arg_list) .== sort(collect(keys(dict["sweep_args"]))))
        
        static_args_dict = get(dict, "static_args", Dict{String, Any}())
        static_args_dict["save_dir"] = joinpath(save_dir, "data")
        sweep_args_dict = dict["sweep_args"]
        for key ∈ keys(sweep_args_dict)
            if sweep_args_dict[key] isa String
                sweep_args_dict[key] = eval(Meta.parse(sweep_args_dict[key]))
            end
        end
        ArgIterator(sweep_args_dict,
                    static_args_dict,
                    arg_list=arg_list)
    elseif iter_type == "looper"
        static_args_dict = get(dict, "static_args", Dict{String, Any}())
        static_args_dict["save_dir"] = joinnpath(save_dir, "data")
        args_dict_list = [dict["loop_args"][k] for k ∈ keys(dict["loop_args"])]
        run_param = cdict["run_param"]
        num_runs = cdict["num_runs"]
        ArgLooper(args_dict_list, static_args_dict, 1:num_runs, run_param)
    else
        throw("$(iter_type) not supported.")
    end

    experiment = Experiment(save_dir,
                            exp_file,
                            exp_module_name,
                            exp_func_name,
                            args, config)
    
end

function _safe_mkdir(exp_dir)
    if !isdir(exp_dir)
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
end

function _safe_mkpath(exp_dir)
    if !isdir(exp_dir)
        try
            mkpath(exp_dir)
        catch ex
            @info "Somebody else created directory... Waiting"
            if isa(ex, SystemError) && ex.errnum == 17
                sleep(0.1) # Other Process Made folder. Waiting...
            else
                throw(ex)
            end
        end
    end
end

"""
    create_experiment_dir(exp_dir::AbstractString; org_file=true, replace=false, tldr="")

This creates an experiment directory and sets up a notes file.

"""
function create_experiment_dir(exp_dir::AbstractString;
                               org_file=true,
                               replace=false,
                               tldr="")

    if isdir(exp_dir)
        if !replace
            @info "directory already created - told to not replace..."
            return
        else
            @info "directory already created - told to replace..."
            rm(exp_dir; force=true, recursive=true)
            _safe_mkdir(exp_dir)
        end
    else
        @info "creating experiment directory"
        _safe_mkdir(exp_dir)
    end

    if isdir(joinpath(exp_dir, "data"))
        if !replace
            @info "data directory already created - told to not replace..."
            return
        else
            @info "directory already created - told to replace..."
            # rm(exp_dir; force=true, recursive=true)
            _safe_mkdir(joinpath(exp_dir, "data"))
        end
    else
        @info "creating experiment directory"
        _safe_mkdir(joinpath(exp_dir, "data"))
    end

    if org_file
        open(joinpath(exp_dir, "notes.org"), "w") do f
            write(f, "#+title: Experimental Notes for $(exp_dir)\n\n")
            write(f, "TL;DR: $(tldr)\n\n")
        end
    end

    return
end

function create_experiment_dir(exp::Experiment;
                               kwargs...)
    create_experiment_dir(exp.dir; kwargs...)
    return
end


function add_experiment(exp_dir::AbstractString,
                        experiment_file::AbstractString,
                        exp_module_name::AbstractString,
                        exp_func_name::AbstractString,
                        args_iter::AbstractArgIter,
                        hash::UInt64,
                        config=nothing;
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
    _safe_mkdir(settings_dir)

    settings_file = joinpath(settings_dir, "settings_0x"*string(hash, base=16)*".jld2")
    config_file = if config isa Nothing
        nothing
    else
        joinpath(settings_dir, "config_0x"*string(hash, base=16)*splitext(config)[end])
    end

    date_str = Dates.format(now(), dateformat"<yyyy-mm-dd e HH:MM:SS>")
    tab = "\t"

    make_args_str = "nothing"
    if typeof(args_iter) == ArgIterator && args_iter.make_args != nothing
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
            tab*"settings file: $(basename(settings_file))\n" *
            (!(config isa Nothing) ? tab*"config file: $(basename(config_file))\n\n" : "\n") *
            tab*"#+BEGIN_src julia\n" *
            (args_iter isa ArgIterator ? tab*"dict = $(args_iter.dict)\n" : tab*"runs_iter=$(args_iter.runs_iter)\n") *
            (args_iter isa ArgIterator ? tab*"arg_list = $(args_iter.arg_list)\n" : tab*"arg_list = $(args_iter.dict_list)\n") *
            tab*"static_arg = $(args_iter.static_args)\n\n" *
            tab*"#Make Arguments\n" *
            tab*make_args_str*"\n" *
            tab*"#+END_src\n\n"
        write(f, exp_str)
    end

    jldopen(settings_file, "w") do file
        file["args_iter"]=args_iter
        file["make_args_str"]=make_args_str
    end

    if !(config isa Nothing)
        cp(config, config_file; force=true)
    end

end

function add_experiment(exp::Experiment;
                        kwargs...)
    add_experiment(exp.dir,
                   exp.file,
                   String(exp.module_name),
                   String(exp.func_name),
                   exp.args_iter,
                   exp.hash,
                   exp.config;
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

