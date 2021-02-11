using Logging
using Reexport

import GitCommand, JLD2
@reexport using ArgParse



const HASH_KEY="_HASH"
const SAVE_NAME_KEY="_SAVE"
const GIT_INFO_KEY="_GIT_INFO"

make_save_name(hashed, git_info; head="RP") = "$(head)_$(git_info)_0x$(string(hashed,base=16))"

get_save_dir(parsed::Dict) = parsed[keytype(parsed)(SAVE_NAME_KEY)]
get_hash(parsed::Dict) = parsed[keytype(parsed)(HASH_KEY)]
get_git_info(parsed::Dict) = parsed[keytype(parsed)(GIT_INFO_KEY)]

function git_head()
    s = ""
    GitCommand.git() do git
        s = read(`$git rev-parse HEAD`, String)
    end
    s[1:end-1]
end

"""
    create_info!
"""
function create_info!(parsed_args::Dict,
                      save_dir::String;
                      filter_keys::Array{String,1} = Array{String,1}(),
                      use_git_info = false,
                      custom_folder_name = "RP",
                      HASHER=hash,
                      replace=true,
                      settings_file="settings.jld2")

    KEY_TYPE = keytype(parsed_args)

    unused_keys = KEY_TYPE.(filter_keys)
    hash_args = filter(k->(!(k[1] in unused_keys)), parsed_args)
    used_keys=keys(hash_args)

    hash_key = KEY_TYPE(HASH_KEY)
    save_name_key = KEY_TYPE(SAVE_NAME_KEY)
    git_info_key = KEY_TYPE(GIT_INFO_KEY)

    hashed = HASHER(hash_args)
    parsed_args[hash_key] = hashed

    git_info = use_git_info ? git_head() : "0"
    parsed_args[git_info_key] = git_info

    save_name = joinpath(save_dir, make_save_name(hashed, git_info; head=custom_folder_name))
    parsed_args[save_name_key] = save_name

    save_settings_path = save_name

    if !isdir(save_settings_path)
        mkpath(save_settings_path)
    else
        if replace
            @warn "Hash Conflict in Reproduce create_info! Overwriting data."
        else
            @info "Told not to replace. Exiting Experiment."
            throw("Hash Conflict.")
        end
    end

    # settings_dict = Dict("parsed_args"=>parsed_args, "used_keys"=>used_keys)
    save_settings_file = joinpath(save_settings_path, settings_file)
    JLD2.@save save_settings_file parsed_args used_keys
end

function create_info(arg_list::Vector{String},
                     settings::ArgParseSettings,
                     save_dir::AbstractString;
                     filter_keys::Array{String,1} = Array{String,1}(),
                     use_git_info = false,
                     custom_folder_name = "RP",
                     HASHER=hash,
                     replace=true,
                     settings_file="settings.jld2", kwargs...)
    parsed = parse_args(arg_list, settings; kwargs...)
    create_info!(parsed, save_dir;
                 filter_keys=filter_keys,
                 use_git_info=use_git_info,
                 HASHER=HASHER,
                 custom_folder_name=custom_folder_name,
                 replace=replace,
                 settings_file=settings_file)
    return parsed
end


function default_save_str(parsed, use_keys; save_dir="RP")
    strs = collect(zip(
        [string(key) for key in use_keys],
        [string(parsed[key]) for key in use_keys]))
    dir = joinpath(homedir, strs...)
    return dir
end

function create_custom_info!(parsed_args::Dict,
                             save_dir::String;
                             use_keys::Array{String,1} = Array{String,1}(),
                             make_save_str=default_save_str,
                             replace=true,
                             settings_file="settings.jld2")

    KEY_TYPE = keytype(parsed_args)

    save_name_key = KEY_TYPE(SAVE_NAME_KEY)
    save_path = make_save_str(parsed_args, KEY_TYPE.(use_keys); save_dir=save_dir)
    parsed_args[save_name_key] = save_path

    if !isdir(save_path)
        mkpath(save_path)
    else
        if replace
            @warn "Dir Conflict in Reproduce parse_args! Overwriting data."
        else
            @info "Told not to replace. Exiting Experiment."
            exit(0)
        end
    end

    # settings_dict = Dict("parsed_args"=>parsed_args, "used_keys"=>used_keys)
    save_settings_file = joinpath(save_path, settings_file)
    JLD2.@save save_settings_file parsed_args used_keys
end

function create_custom_info(arg_list::Vector{String},
                            settings::ArgParseSettings,
                            save_dir::AbstractString;
                            use_keys::Array{String,1} = Array{String,1}(),
                            make_save_str=default_save_str,
                            replace=true,
                            settings_file="settings.jld2", kwargs...)
    parsed = parse_args(arg_list, settings; kwargs...)
    create_custom_info!(parsed, save_dir;
                        use_keys=use_keys,
                        make_save_str=make_save_str,
                        replace=replace,
                        settings_file=settings_file)
    return parsed
end

