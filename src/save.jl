

# const HASH_KEY="_HASH"
# const SAVE_NAME_KEY="_SAVE"
# const SAVE_KEY="_SAVE"
# const GIT_INFO_KEY="_GIT_INFO"

get_param_ignore_keys() = [SAVE_KEY, "save_dir"]

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
    if isnothing(sqlsave.dbm) || !Base.isopen(sqlsave.dbm)
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

    if args[SAVE_KEY] isa String
        # assume file save
        @warn """Using key "$(SAVE_KEY)" as a string in args is deprecated. Use new SaveTypes instead.""" maxlog=1
        save_dir = args[SAVE_KEY]
        args[SAVE_KEY] = FileSave(save_dir, JLD2Manager())
        save_setup(args[SAVE_KEY], args; kwargs...)
    else
        save_setup(args[SAVE_KEY], args; kwargs...)
    end
    
end

save_setup(::Nothing, args...; kwargs...) = nothing

function save_setup(save_type::FileSave, args::Dict;
                    filter_keys=String[],
                    use_git_info=true,
                    hash_exclude_save_dir=true)

    save_dir = save_type.save_dir

    settings_file= "settings" * extension(save_type.manager)
    
    KEY_TYPE = keytype(args)

    filter_keys = if hash_exclude_save_dir
        [filter_keys; [SAVE_KEY, "save_dir"]] # add SAVE_KEY to filter keys automatically.
    else
        @warn "hash_exclude_save_dir=false is deprecated due to hash consistency issues." maxlog=1
        [filter_keys; [SAVE_KEY]] # add SAVE_KEY to filter keys automatically.
    end
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
    end

    # JLD2.@save save_settings_file args used_keys
    save(save_type.manager, save_settings_file, Dict("args"=>args, "used_keys"=>used_keys))

    joinpath(save_path, "results" * extension(save_type.manager))
    
end

function save_setup(save_type::SQLSave, args; filter_keys=String[], use_git_info=true, hash_exclude_save_dir=true) #filter_keys=String[], use_git_info=true)

    connect!(save_type)

    filter_keys = if hash_exclude_save_dir
        [filter_keys; get_param_ignore_keys()] # add SAVE_KEY to filter keys automatically.
    else
        @warn "hash_exclude_save_dir=false is deprecated due to hash consistency issues." maxlog=1
        [filter_keys; [SAVE_KEY]] # add SAVE_KEY to filter keys automatically.
    end
    
    schema_args = filter(k->(!(k[1] in get_param_ignore_keys())), args)
    exp_hash = save_params(save_type.dbm,
                           schema_args;
                           filter_keys=get_param_ignore_keys(),
                           use_git_info=use_git_info)

    # close!(save_type)
    
    exp_hash
end


save_results(::Nothing, args...; kwargs...) = nothing

function save_results(save_type::FileSave, path, results)
    save(save_type.manager, path, results)
end

function save_results(sqlsave::SQLSave, exp_hash, results)
    connect!(sqlsave)
    if !table_exists(sqlsave.dbm, get_results_table_name())
        create_results_tables(sqlsave.dbm, results)
    end
    ret = save_results(sqlsave.dbm, exp_hash, results)
    # close!(save_type)
    ret
end

