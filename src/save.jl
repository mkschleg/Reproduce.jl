

struct FileSave
    save_dir::String
    manager::SaveManager
end # for file saving

mutable struct SQLSave
    database::String
    connection_file::String
    dbm::Union{DBManager, Nothing}
end # for sql saving

SQLSave(database, connection_file=SQLCONNECTIONFILE) = SQLSave(database, connection_file, nothing)

get_database_name(sql_save::SQLSave) = sql_save.database

function connect!(sqlsave::SQLSave)
    if isnothing(sqlsave.dbm) || MySQL.isopen(sqlsave.dbm)
        while true
            try
                sqlsave.dbm = DBManager(sqlsave.connection_file; database=sqlsave.database)
                break
            catch err
                if err isa MySQL.API.Error && err.errno == 1007
                    sleep(1)
                end
            end
        end
    end
end

function DBInterface.close!(sqlsave::SQLSave)
    close(sqlsave.dbm)
    sqlsave.dbm = nothing
end


function save_setup(args::Dict; kwargs...)

    if !(SAVE_KEY in keys(args)) # no save information!
        if isinteractive()
            @warn "No arg at \"$(SAVE_KEY)\". Assume testing in interactive" maxlog=1
        else
            @error "No arg found at $(SAVE_KEY). Something went wrong."
        end
    elseif args[SAVE_KEY] isa String
        # assume file save
        @warn """Using key "$(SAVE_KEY)" as a string in args args is deprecated. Use new SaveTypes instead.""" maxlog=1
        save_dir = args[SAVE_KEY]
        fs = FileSave(save_dir, JLD2Manager())
        save_setup(fs, args; kwargs...)
    else
        save_setup(args[SAVE_KEY], args; kwargs...)
    end
    
end

function save_setup(save_type::FileSave, args::Dict; filter_keys=String[], use_git_info=true)

    save_dir = save_type.save_dir

    settings_file= "settings" * extension(save_type.manager)
    
    KEY_TYPE = keytype(args)

    unused_keys = KEY_TYPE.(filter_keys)
    hash_args = filter(k->(!(k[1] in unused_keys)), args)
    used_keys=keys(hash_args)

    hash_key = KEY_TYPE(HASH_KEY)
    git_info_key = KEY_TYPE(GIT_INFO_KEY)

    hashed = hash(hash_args)
    git_info = use_git_info ? git_head() : "0"
    save_path = joinpath(save_dir, make_save_name(hashed, git_info))

    save_settings_path = save_path
    save_settings_file = joinpath(save_settings_path, settings_file)
    
    if !isdir(save_settings_path)
        mkpath(save_settings_path)
    else
        if replace
            @warn "Hash Conflict in Reproduce create_info! Overwriting data."
        else
            throw("Hash Conflict in Reproduce create_into. Told not to overwrite data.")
        end
    end

    # JLD2.@save save_settings_file args used_keys
    save(save_type.manager, save_settings_file, Dict("args"=>args, "used_keys"=>used_keys))

    joinpath(save_path, "results" * extension(save_type.manager))
    
end

function save_results(save_type::FileSave, path, results)
    save(save_type.manager, path, results)
end


function save_setup(save_type::SQLSave, args; filter_keys=String[], use_git_info=true) #filter_keys=String[], use_git_info=true)

    connect!(save_type)
    
    schema_args = filter(k->(!(k[1] in get_param_ignore_keys())), args)
    exp_hash = save_params(save_type.dbm,
                           schema_args;
                           filter_keys=get_param_ignore_keys(),
                           use_git_info=use_git_info)

    
    exp_hash
end


function save_results(sqlsave::SQLSave, exp_hash, results)
    connect!(sqlsave)
    if !table_exists(sqlsave.dbm, get_results_table_name())
        create_results_tables(sqlsave.dbm, results)
    end
    save_results(sqlsave.dbm, exp_hash, results)
end

