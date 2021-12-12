using Dates
using CodeTracking
using JLD2
using Logging
using Distributed

# Config files
# TOML is in base in version > 1.6




IN_SLURM() = ("SLURM_JOBID" ∈ keys(ENV)) && ("SLURM_NTASKS" ∈ keys(ENV))

function get_comp_env()
    if "SLURM_JOBID" ∈ keys(ENV) && "SLURM_NTASKS" ∈ keys(ENV)
        SlurmParallel(parse(Int, ENV["SLURM_NTASKS"]))
    elseif "SLURM_ARRAY_TASK_ID" ∈ keys(ENV)
        SlurmTaskArray(parse(Int, ENV["SLURM_ARRAY_TASK_ID"]))
    elseif "RP_TASK_ID" ∈ keys(ENV)
        LocalTask(parse(Int, ENV["RP_TASK_ID"]))
    else
        if "RP_NTASKS" ∈ keys(ENV)
            LocalParallel(parse(Int, ENV["RP_NTASKS"]))
        else
            LocalParallel(0)
        end
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
    num_procs::Int
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
    exp_hash = hash(string(args_iter))
    md = Metadata(save_type, comp_env, dir, exp_hash, config)
    
    Experiment(job_comp, md, args_iter)
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

    # if :sql_infofile ∈ keys(kwargs)
    # else
    #     dbm = DBManager()
    # end
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

get_settings_dir(details_loc="") = joinpath(details_loc, "settings")
get_settings_file(hash::UInt) = "settings_0x"*string(hash, base=16)*".jld2"
get_config_copy_file(hash::UInt) = "config_0x"*string(hash, base=16)*".jld2"

function add_experiment(exp::Experiment)

    comp_env = exp.metadata.comp_env
    if is_task_env(comp_env)
        if get_task_id(comp_env) != 1
            task_id = comp_env.id
            @info "Only add experiment for task id == 1... id : $(task_id) $(task_id == 1)"
            return
        end
    end

    exp_dir = exp.metadata.details_loc

    @info "Adding Experiment to $(exp_dir)"
    
    settings_dir = get_settings_dir(exp_dir)
    _safe_mkdir(settings_dir)

    exp_hash = exp.metadata.hash
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

