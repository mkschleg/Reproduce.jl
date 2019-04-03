using Logging

import ArgParse, Git, FileIO
import ArgParse.@add_arg_table
import ArgParse.ArgParseSettings

export
    parse_args,
    @add_arg_table,
    ArgParseSettings


# HASHER(x) = hash(x)
HASH_KEY="_HASH"
SAVE_NAME_KEY="_SAVE"
GIT_INFO_KEY="_GIT_INFO"

# println("Hello Parse!")


make_save_name(hashed, git_info; head="RP") = "$(head)_$(git_info)_0x$(string(hashed,base=16))"
# make_save_name(hashed) = make_save_name(hashed, 0)

"""
    parse_args(arg_list, settings, save_settings_dir[; as_symbols, filter_keys, use_git_info, custom_folder_name])

"""
function parse_args(arg_list::Array{String}, settings::ArgParseSettings,
                    save_dir::String="RP_results";
                    as_symbols::Bool = false, filter_keys::Array{String,1} = Array{String,1}(),
                    use_git_info = false, custom_folder_name = "RP", HASHER=hash, replace=true,
                    settings_file="settings.jld2")

    parsed_args = ArgParse.parse_args(arg_list, settings; as_symbols=as_symbols)
    # Now if we are using symbols
    KEY_TYPE = String
    if as_symbols
        KEY_TYPE = Symbol
    end

    unused_keys = KEY_TYPE.(filter_keys)
    hash_args = filter(k->(!(k[1] in unused_keys)), parsed_args)
    used_keys=keys(hash_args)

    hash_key = KEY_TYPE(HASH_KEY)
    save_name_key = KEY_TYPE(SAVE_NAME_KEY)
    git_info_key = KEY_TYPE(GIT_INFO_KEY)

    hashed = HASHER(hash_args)
    parsed_args[hash_key] = hashed

    git_info = use_git_info ? Git.head() : "0"
    parsed_args[git_info_key] = git_info

    save_name = joinpath(save_dir, make_save_name(hashed, git_info; head=custom_folder_name))
    parsed_args[save_name_key] = save_name

    save_settings_path = save_name

    if !isdir(save_settings_path)
        mkpath(save_settings_path)
    else
        if replace
            @warn "Hash Conflict in Reproduce parse_args! Overwriting data."
        else
            @info "Told not to replace. Exiting Experiment."
            exit(0)
        end
    end

    settings_dict = Dict("parsed_args"=>parsed_args, "used_keys"=>used_keys)
    save_settings_file = joinpath(save_settings_path, settings_file)
    settings_dict |> FileIO.save(save_settings_file)

    return parsed_args

end

"""
   parse_args(settings; kw...)

Parses args from the command line. For a full list of key word arguments see ArgParse.

"""
function parse_args(settings::ArgParseSettings, save_dir::String; kw...)
    parse_args(ARGS, settings, save_dir; kw...)
end


function default_save_str(parsed, use_keys; save_dir="RP")
    strs = collect(zip(
        [string(key) for key in use_keys],
        [string(parsed[key]) for key in use_keys]))
    dir = joinpath(homedir, strs...)
    return dir
end

function custom_parse_args(arg_list::Array{String}, settings::ArgParseSettings, save_dir::String="RP_results";
                           as_symbols::Bool = false, use_keys::Array{String,1} = Array{String,1}(),
                           make_save_str=default_save_str, replace=true, settings_file="settings.jld2")

    parsed_args = ArgParse.parse_args(arg_list, settings; as_symbols=as_symbols)
    KEY_TYPE = String
    if as_symbols
        KEY_TYPE = Symbol
    end

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

    settings_dict = Dict("parsed_args"=>parsed_args, "used_keys"=>used_keys)
    save_settings_file = joinpath(save_path, settings_file)
    settings_dict |> FileIO.save(save_settings_file)
end
