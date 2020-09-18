using Dates
using CodeTracking
using Git
using JLD2
using Logging

# Config files
using Pkg.TOML
using JSON

"""
    Experiment(dir, file, module_name, func_name, args_iter, config=nothing; modify_save_path=true)

This is a struct which encapsulates the idea of an experiment.
# Arguments
- `dir`: The directory associated w/ this experiment
- `file`: The path to the file containing the experiment module
- `module_name`: The module encapsulating your experiment (either a string or symbol)
- `func_name`: The function inside the module which runs your experiment
- `args_iter`: The settings your want to iterate over. This can be any iterator which returns `(job_id, params)`
- `config`: [Optional] The path of the config file your experiment was built from. See [`Experiment(config_path, save_path="")`](@ref)
- `modify_save_path`: If true and you are using ArgIterator or ArgLooper the arg_iter added to the experiment will have a new static_arg "save_dir" added.

"""
struct Experiment{I}
    dir::String
    file::String
    module_name::Symbol
    func_name::Symbol
    args_iter::I
    hash::UInt64
    config::Union{String, Nothing}
end

function Experiment(dir, file, module_name, func_name, arg_iter, config=nothing; modify_save_path=true)
    arg_iter = if modify_save_path
        cp_arg_iter = deepcopy(arg_iter)
        set_save_dir!(cp_arg_iter, joinpath(dir, "data"))
        cp_arg_iter
    else
        arg_iter
    end
    Experiment(dir, file, Symbol(module_name), Symbol(func_name), arg_iter, hash(string(arg_iter)), config)
end


"""
    Experiment(config_path, save_path="")

Build and experiment from either a toml file or a json.
"""
function Experiment(config_path, save_path="")

    ext = splitext(config_path)[end]
    dict = if ext == ".toml"
        TOML.parsefile(config_path)
    elseif ext == ".json"
        JSON.Parser.parsefile(config_path)
    else
        throw(ErrorException("Experiment currently doesn't support $(ext) files."))
    end

    cdict = dict["config"]
    save_dir = joinpath(save_path, cdict["save_dir"])
    exp_file = cdict["exp_file"]
    exp_module_name = cdict["exp_module_name"]
    exp_func_name = cdict["exp_func_name"]

    iter_type = cdict["arg_iter_type"]


    args = if iter_type == "iter"
        arg_order = get(cdict, "arg_list_order", nothing)

        @assert arg_order isa Nothing || all(sort(arg_order) .== sort(collect(keys(dict["sweep_args"]))))
        
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
                    arg_order=arg_order)
    elseif iter_type == "looper"
        static_args_dict = get(dict, "static_args", Dict{String, Any}())
        static_args_dict["save_dir"] = joinpath(save_dir, "data")
        args_dict_list = [dict["loop_args"][k] for k ∈ keys(dict["loop_args"])]
        run_param = cdict["run_param"]
        num_runs = cdict["num_runs"]
        ArgLooper(args_dict_list, static_args_dict, 1:num_runs, run_param)
    else
        throw("$(iter_type) not supported.")
    end

    set_save_dir!(args, joinpath(save_dir, "data"))
    
    experiment = Experiment(save_dir,
                            exp_file,
                            exp_module_name,
                            exp_func_name,
                            args,
                            config_path)
    
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
    pre_experiment(exp::Experiment; kwargs...)

Experiment setup phase. This helps deal with all the setup that needs to occur to setup an experiment folder.
"""
function pre_experiment(exp::Experiment; kwargs...)
    create_experiment_dir(exp; kwargs...)
    add_experiment(exp)
end



"""
    create_experiment_dir(exp_dir; org_file=false, replace=false, tldr="")
    create_experiment_dir(exp::Experiment; kwargs...)

This creates an experiment directory and sets up a notes file (if org_file is true). It is recommended to use [`pre_experiment(exp::Experiment; kwargs...)`](@ref).

# Arguments
- `org_file=false`: Indicator on whether to create an org file w/ notes on the job (experimental).
- `replace=false`: If true the directory will be deleted. This is not recommended when calling create_experiment_dir from multiple jobs.
- `tldr=""`: A TLDR which will be put into the org file.

"""
function create_experiment_dir(exp_dir;
                               org_file=false,
                               replace=false,
                               tldr="")
    mkdir_fn = occursin("/", exp_dir) ? _safe_mkpath : _safe_mkdir
    if isdir(exp_dir)
        if !replace
            @info "directory already created - told to not replace..."
            return
        else
            @info "directory already created - told to replace..."
            rm(exp_dir; force=true, recursive=true)
            mkdir_fn(exp_dir)
        end
    else
        @info "creating experiment directory"
        mkdir_fn(exp_dir)
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


function append_experiment_notes_file(
    exp_dir,
    experiment_file,
    exp_module_name,
    exp_func_name,
    settings_file,
    config_file,
    args_iter,
    config)

    if isfile(joinpath(exp_dir, "notes.org"))
        
        date_str = Dates.format(now(), dateformat"<yyyy-mm-dd e HH:MM:SS>")
        tab = "    "
        make_args_str = "nothing"
        if typeof(args_iter) == ArgIterator && args_iter.make_args !== nothing
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
                (args_iter isa ArgIterator ? tab*"arg_order = $(args_iter.arg_order)\n" : tab*"arg_list = $(args_iter.dict_list)\n") *
                tab*"static_arg = $(args_iter.static_args)\n\n" *
                tab*"# Make Arguments\n" *
                tab*make_args_str*"\n" *
                tab*"#+END_src\n\n"
            write(f, exp_str)
        end
    end

end

"""
    add_experiment(exp_dir, experiment_file, exp_module_name, exp_func_name, args_iter, hash, config)
    add_experiment(exp::Experiment)

Set up details of experiment in `exp_dir`. This includes saving settings and config files, etc...
It is recommended to use [`pre_experiment(exp::Experiment; kwargs...)`](@ref).
"""
function add_experiment(exp_dir,
                        experiment_file,
                        exp_module_name,
                        exp_func_name,
                        args_iter,
                        hash::UInt64,
                        config=nothing)

    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        if parse(Int64, ENV["SLURM_ARRAY_TASK_ID"]) != 1
            job_id = parse(Int64, ENV["SLURM_ARRAY_TASK_ID"])
            @info "Told to not add all experiments... job_id : $(job_id) $(job_id == 1)"
            return
        end
    end

    @info "Adding Experiment to $(exp_dir)"

    settings_dir = "settings"
    settings_dir = joinpath(exp_dir, settings_dir)
    _safe_mkdir(settings_dir)

    settings_file = joinpath(settings_dir, "settings_0x"*string(hash, base=16)*".jld2")
    config_file = if config isa Nothing
        nothing
    else
        joinpath(settings_dir, "config_0x"*string(hash, base=16)*splitext(config)[end])
    end

    append_experiment_notes_file(
        exp_dir,
        experiment_file,
        exp_module_name,
        exp_func_name,
        settings_file,
        config_file,
        args_iter,
        config)
    
    make_args_str = "nothing"
    if typeof(args_iter) == ArgIterator && args_iter.make_args !== nothing
        m = CodeTracking.@which args_iter.make_args(Dict{String, String}())
        make_args_str, line1 = definition(String, m)
    end

    jldopen(settings_file, "w") do file
        file["args_iter"]=args_iter
        file["make_args_str"]=make_args_str
    end

    if !(config isa Nothing)
        cp(config, config_file; force=true)
    end

end

function add_experiment(exp::Experiment)
    add_experiment(exp.dir,
                   exp.file,
                   String(exp.module_name),
                   String(exp.func_name),
                   exp.args_iter,
                   exp.hash,
                   exp.config)
end


function post_experiment(exp_dir::AbstractString, canceled_jobs::Array{Int64, 1})

    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        @info "Post_experiment doesn't work with slurm job arrays."
        return
    end


    if isfile(joinpath(exp_dir, "notes.org"))
        tab = "\t"
        date_str = Dates.format(now(), dateformat"<yyyy-mm-dd e HH:MM:SS>")
        
        open(joinpath(exp_dir, "notes.org"), "a") do f

            post_exp_str = tab*"Post Experiment: \n" *
                tab*"Canceled Jobs: $(canceled_jobs)\n" *
                tab*"Ended: $(date_str)\n"
            write(f, post_exp_str)
        end
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

