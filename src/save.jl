

struct FileSave
    save_dir::String
    manager::SaveManager
end # for file saving

mutable struct SQLSave
    database::String
    connection_file::String
    dbm::Union{DBManager, Nothing}
end # for sql saving

SQLSave(database, connection_file) = SQLSave(database, connection_file, nothing)

get_database_name(sql_save::SQLSave) = sql_save.database

function save_setup(args::Dict; kwargs...)

    if !(args[SAVE_KEY] isa String)
        save_setup(args[SAVE_KEY], args; kwargs...)
    else
        # assume user save
        @warn """Using key "$(SAVE_KEY)" as a string in args args is deprecated. Use new SaveTypes instead."""
        fs = FileSave(save_dir, JLD2Manager())
        save_setup(fs, args; kwargs...)
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
    if isnothing(save_type.dbm)
        save_type.dbm = DBManager(; database=save_type.database)
    end
    
    save_params(save_type.dbm,
                args;
                filter_keys=filter_keys,
                use_git_info=use_git_info)
end



