using Dates
using CodeTracking
using JLD2
using Logging
using Distributed

# Config files
# TOML is in base in version > 1.6







# what does experiment do? Can it be simplified? Can parts of it be decomposed?

struct JobMetadata
    file::String
    module_name::Symbol
    func_name::Symbol
end

struct Metadata{ST, CE}
    name::String
    save_type::ST
    comp_env::CE
    details_loc::String
    hash::UInt64
    config::Union{String, Nothing}
    job_log_dir::String
end

get_jobs_dir(comp_env, details_loc) = joinpath(details_loc, "jobs")#, get_job_name(comp_env))

function Metadata(save_type, comp_env, dir, exp_hash, config)
    name = get_job_name(comp_env)
    job_log_dir = get_jobs_dir(comp_env, dir)
    Metadata(name, save_type, comp_env, dir, exp_hash, config, job_log_dir)
end

struct Experiment{MD<:Metadata, I}
    job_metadata::JobMetadata
    metadata::MD
    args_iter::I
end

"""
    Experiment

The structure used to embody a reproduce experiment. This is usually constructed through the [`parse_experiment_from_config`](@ref), but can be used without config files.

- `dir`: the base directory of the experiment (where the info files are saved).
- `file`: The file containing the experiment function described by `func_name` and `module_name`
- `module_name`: Module name containing the experiment function.
- `func_name`: Function name of the experiment.
- `save_type`: The save structure to deal with saving data passed by the experiment.
- `args_iter`: The args iterator which contains the configs to pass to the experiment.
- `[confg]`: The config file parsed to create the experiment (optional)
# kwarg
- `[comp_env]`: The computational environment used by the experiment.
"""
function Experiment(dir, file, module_name, func_name, save_type, args_iter, config=nothing; comp_env=get_comp_env())

    job_comp = JobMetadata(file, Symbol(module_name), Symbol(func_name))
    exp_hash = hash(string(args_iter))
    md = Metadata(save_type, comp_env, dir, exp_hash, config)
    
    Experiment(job_comp, md, args_iter)
end


"""
    pre_experiment(exp::Experiment; kwargs...)
    pre_experiment(file_save::FileSave, exp; kwargs...)
    pre_experiment(sql_save::SQLSave, exp; kwargs...)

This function does all the setup required to successfully run an experiment. It is dispatched on the save structure in the experiment.

This function:
- Creates the base experiment directory.
- Runs [`experiment_save_init`](@ref) to initialize the details for each save type.
- runs [`experiment_dir_setup`](@ref)
"""
function pre_experiment(exp::Experiment; kwargs...)
    create_experiment_dir(exp.metadata.details_loc)
    experiment_save_init(exp.metadata.save_type, exp; kwargs...)
    experiment_dir_setup(exp)
end

"""
    experiment_save_init(save::FileSave, exp::Experiment; kwargs...)
    experiment_save_init(save::SQLSave, exp::Experiment; kwargs...)

Setups the necessary compoenents to save data for the jobs. This is run by [`pre_experiment`](@ref). The `FileSave` creates the data directory where all the data is stored for an experiment. The `SQLSave` ensures the databases and tables are created necessary to successfully run an experiment.
"""
function experiment_save_init(file_save::FileSave, exp; kwargs...)
    create_data_dir(file_save.save_dir)
end
function experiment_save_init(sql_save::SQLSave, exp; kwargs...)
    create_database_and_tables(sql_save, exp)
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

    dbm = DBManager(sql_save.connection_file)
    db_name = get_database_name(sql_save)

    # Create and switch to database. This checks to see if database exists before creating
    create_and_switch_to_database(dbm, db_name)

    #=
    If the param table exists assume all tables exixst, don't try to create them. 
    Otherwise, we need to create the tables.
    =#
    if !table_exists(dbm, get_param_table_name())
        # create params table
        experiment_file = abspath(exp.job_metadata.file)
        
        @everywhere begin
            include($experiment_file)
        end
        example_prms = first(exp.args_iter)[end]

        filter_keys = get_param_ignore_keys()
        schema_args = filter(k->(!(k[1] in filter_keys)), example_prms)
        
        create_param_table(dbm, schema_args)

        module_names = names(getfield(Main, exp.job_metadata.module_name); all=true)
        
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

get_settings_dir(details_loc) = joinpath(details_loc, "settings")
get_settings_file(hash::UInt) = "settings_0x"*string(hash, base=16)*".jld2"
get_config_copy_file(hash::UInt) = "config_0x"*string(hash, base=16)*".jld2"

"""
    experiment_dir_setup

Sets up all the needed directories to run a parallel experiment.
"""
function experiment_dir_setup(exp::Experiment)
    experiment_dir_setup(exp.metadata.comp_env, exp)
end

function experiment_dir_setup(comp_env::LocalParallel, exp::Experiment)
    exp_dir = exp.metadata.details_loc
    create_jobs_folder(exp)
    save_experiment_settings(exp)
end

function experiment_dir_setup(comp_env::SlurmParallel, exp::Experiment)
    exp_dir = exp.metadata.details_loc
    create_jobs_folder(exp)
    save_experiment_settings(exp)
end

function experiment_dir_setup(comp_env::SlurmTaskArray, exp::Experiment)
    exp_dir = exp.metadata.details_loc
    create_jobs_folder(exp)
    array_idx = comp_env.array_idx
    if array_idx != 1
        @info "Only save settings for array index == 1: array index = $(array_idx)"
        return
    end
    save_experiment_settings(exp)
end

function experiment_dir_setup(comp_env::TaskJob, exp::Experiment)
    task_id = comp_env.id
    if task_id != 1
        @info "Only add experiment for task id == 1... id : $(task_id) $(task_id == 1)"
        return
    end
    exp_dir = exp.metadata.details_loc
    save_experiment_settings(exp)
end

function create_jobs_folder(exp::Experiment)
     _safe_mkpath(exp.metadata.job_log_dir)
end

function save_experiment_settings(exp::Experiment)# exp_dir, exp_hash)
    exp_dir = exp.metadata.details_loc
    exp_hash = exp.metadata.hash
    
    settings_dir = get_settings_dir(exp_dir)
    _safe_mkdir(settings_dir)

    settings_file = joinpath(settings_dir, "settings_0x"*string(exp_hash, base=16)*".jld2")

    args_iter = exp.args_iter
    
    jldopen(settings_file, "w") do file
        file["args_iter"] = args_iter
    end
    
    config = exp.metadata.config
    
    if !(config isa Nothing)
        config_file = joinpath(settings_dir, "config_0x"*string(exp_hash, base=16)*splitext(config)[end])
        cp(config, config_file; force=true)
    end
    
end


"""
    post_experiment

This doesn't do anything.
"""
function post_experiment(exp::Experiment, job_ret)
    # I'm not sure what to put here.
end



