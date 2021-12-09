using Dates
using CodeTracking
using JLD2
using FileIO
using Logging

# Config files
# TOML is in base in version > 1.6
if VERSION > v"1.6"
    using TOML
else
    using Pkg.TOML
end

using JSON

struct FileSave
    save_dir::String
end # for user controlled save procedure

struct SQLSave
    database::String
end # for sql saving

get_database_name(sql_save::SQLSave) = sql_save.database


IN_SLURM() = ("SLURM_JOBID" ∈ keys(ENV)) && ("SLURM_NTASKS" ∈ keys(ENV))

function get_comp_env()
    if "SLURM_JOBID" ∈ keys(ENV) && "SLURM_NTASKS" ∈ keys(ENV)
        SlurmParallel(parse(Int, ENV["SLURM_NTASKS"]))
    elseif "SLURM_ARRAY_TASK_ID" ∈ keys(ENV)
        SlurmTaskArray(parse(Int, ENV["SLURM_ARRAY_TASK_ID"]))
    elseif "RP_TASK_ID" ∈ keys(ENV)
        LocalTask(parse(Int, ENV["RP_TASK_ID"]))
    else
        LocalParallel()
    end
end


get_task_id(comp_env) = comp_env.id
is_task_env(comp_env) = false

struct SlurmTaskArray
    id::Int
end

is_task_env(comp_env::SlurmTaskArray) = true

struct SlurmParallel
    num_procs::Int
end

struct LocalTask
    id::Int
end

is_task_env(comp_env::LocalTask) = true

struct LocalParallel
end


# what does experiment do? Can it be simplified? Can parts of it be decomposed?

struct JobMetadata
    file::String
    module_name::Symbol
    func_name::Symbol
end

struct Metadata{ST, CE}
    save_type::ST
    comp_env::CE
    details_loc::String
    hash::UInt64
    config::Union{String, Nothing}
end

struct Experiment{MD<:Metadata, I}
    job_metadata::JobMetadata
    metadata::MD
    args_iter::I
end

function Experiment(dir, file, module_name, func_name, save_type, args_iter, config=nothing; comp_env=get_comp_env())

    job_comp = JobMetadata(file, Symbol(module_name), Symbol(func_name))
    exp_hash = hash(string(arg_iter))
    md = Metadata(save_type, comp_env, dir, exp_hash, config)
    
    Experiment(job_comp, md, args_iter)
end

function Experiment(config_path, save_path; comp_env=get_comp_env())
    # need to deal with parsing config file.
    ext = splitext(config_path)[end]
    dict = if ext == ".toml"
        TOML.parsefile(config_path)
    elseif ext == ".json"
        JSON.Parser.parsefile(config_path)
    else
        throw(ErrorException("Experiment currently doesn't support $(ext) files."))
    end

    cdict = dict["config"]

    detail_loc = joinpath(save_path, cdict["save_dir"])
    
    exp_file = cdict["exp_file"]
    exp_module_name = cdict["exp_module_name"]
    exp_func_name = cdict["exp_func_name"]

    iter_type = cdict["arg_iter_type"]


    save_type = if "mysql_database" ∈ keys(cdict)
        SQLSave(cdict["mysql_database"])
    else
        FileSave(joinpath(details_loc, "data"))
    end

    static_args_dict = get(dict, "static_args", Dict{String, Any}())

    # Soon save_dir will be deprecated
    static_args_dict["save_dir"] = joinpath(details_loc, "data")
    static_args_dict["save"] = save_type

    args_iter = if iter_type == "iter"

        arg_order = get(cdict, "arg_list_order", nothing)

        @assert arg_order isa Nothing || all(sort(arg_order) .== sort(collect(keys(dict["sweep_args"]))))
        
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
        
        args_dict_list = if "loop_args" ∈ keys(dict)
            [dict["loop_args"][k] for k ∈ keys(dict["loop_args"])]
        elseif "arg_file" ∈ keys(cdict)
            d = FileIO.load(cdict["arg_file"])
            d["args"]
        end

        run_param = cdict["run_param"]
        run_list = cdict["run_list"]

        if run_list isa String
            run_list = eval(Meta.parse(run_list))
        end
        
        ArgLooper(args_dict_list, static_args_dict, run_param, run_list)
        
    else
        throw("$(iter_type) not supported.")
    end
    
    Experiment(detail_loc,
               exp_file,
               exp_module_name,
               exp_func_name,
               save_type,
               args_iter,
               config;
               comp_env=get_comp_env())
end

function pre_experiment(exp::Experiment; kwargs...)
    pre_experiment(exp.metadata.save_type, exp; kwargs...)
end

function pre_experiment(file_save::FileSave, exp; kwargs...)
    create_experiment_dir(exp.metadata.details_loc)
    create_data_dir(file_save.save_dir)
    add_experiment(exp)
end

function pre_experiment(sql_save::SQLSave, exp; kwargs...)
    create_experiment_dir(exp.metadata.details_loc)
    create_database_and_tables(sql_save, exp)
    add_experiment(exp)
end

function create_experiment_dir(exp_dir)
    
    mkdir_fn = occursin("/", exp_dir) ? _safe_mkpath : _safe_mkdir
    
    if isdir(exp_dir)
        @info "directory $(exp_dir) already created - told replacement is forbidden..."
        return
    else
        @info "creating experiment directory"
        mkdir_fn(exp_dir)
    end
end

function create_data_dir(save_dir)
    if isdir(save_dir)
        @info "data directory already created - told to not replace..."
    else
        @info "creating experiment directory"
        _safe_mkdir(save_dir)
    end
end

function create_database_and_tables(sql_save::SQLSave, exp::Experiment)

    if :sql_infofile ∈ keys(kwargs)
        dbm = DBManager(get(kwargs, "sql_infofile"))
    else
        dbm = DBManager()
    end

    db_name = get_database_name(sql_save)
    # Create and switch to database. This checks to see if database exists before creating
    create_and_switch_to_database(dbm, db_name)

    #=
    If the param table exists assume all tables exixst, don't try to create them. 
    Otherwise, we need to create the tables.
    =#
    if !table_exists(dbm, get_param_table_name())
        # create params table
        experiment_file = exp.JobMetadata.experiment_file
        @everywhere begin
            include($experiment_file)
        end
        example_prms = first(exp.arg_iter)

        create_param_table(dbm, params)

        module_names = names(exp.job_metadata.module_name; all=true)
        if :get_result_type_dict ∈ module_names
            results_type_dicts = getfield(exp.job_metadata.module_name, :get_result_type_dict)
            rtd = results_type_dicts(example_prms) # Get results type dict.... How?
            create_results_tables(dbm, rtd)
        elseif :RESULT_TYPE_DICT ∈ module_names
            rtd = getfield(exp.job_metadata.module_name, :RESULT_TYPE_DICT)
            create_results_tables(dbm, rtd)
        else
            # We will be relying on the idea that the table can be created
            # by the first job to save to the database...
        end
    end 

    # tables and database should be created.
end

get_settings_dir(details_loc="") = joinpath(details_loc, "settings")
get_settings_file(hash::UInt) = "settings_0x"*string(hash, base=16)*".jld2"
get_config_copy_file(hash::UInt) = "config_0x"*string(hash, base=16)*".jld2"

function add_experiment(exp::Experiment)

    if is_task_env(exp.comp_env)
        if get_task_id(exp.comp_env) != 1
            task_id = exp.comp_env.id
            @info "Only add experiment for task id == 1... id : $(task_id) $(task_id == 1)"
            return
        end
    end

    @info "Adding Experiment to $(exp_dir)"

    exp_dir = get_details_loc(exp)
    
    settings_dir = get_settings_dir_loc(exp_dir)
    _safe_mkdir(settings_dir)

    settings_file = joinpath(settings_dir, "settings_0x"*string(hash, base=16)*".jld2")
    
    jldopen(settings_file, "w") do file
        file["args_iter"] = args_iter
    end
    
    config = exp.metadata.config
    
    if !(config isa Nothing)
        config_file = joinpath(settings_dir, "config_0x"*string(hash, base=16)*splitext(config)[end])
        cp(config, config_file; force=true)
    end

end

function post_experiment(exp::Experiment, job_ret)
    # post_experiment(exp.comp_env, exp, job_ret)
end

@deprecate exception_file(args...) save_exception(args...)

function save_exception(exc_file, job_id, exception, trace)

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

