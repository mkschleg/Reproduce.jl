
include("data_manager.jl")

struct FileSave
    save_dir::String
    manager::SaveManager
end # for file saving


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

    args[hash_key] = hashed
    args[git_info_key] = git_info
    
    save_settings_path = save_path
    save_settings_file = joinpath(save_settings_path, settings_file)
    
    if !isdir(save_settings_path)
        mkpath(save_settings_path)
    end

    # JLD2.@save save_settings_file args used_keys
    save(save_type.manager, save_settings_file, Dict("args"=>args, "used_keys"=>used_keys))

    joinpath(save_path, "results" * extension(save_type.manager))
    
end

function save_results(save_type::FileSave, path, results)
    save(save_type.manager, path, results)
end
