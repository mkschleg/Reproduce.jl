import ArgParse, Git, JLD2
import ArgParse.@add_arg_table
import ArgParse.ArgParseSettings

export
    parse_args,
    @add_arg_table,
    ArgParseSettings


HASHER(x) = hash(x)
HASH_KEY="_HASH"
SAVE_NAME_KEY="_SAVE"
GIT_INFO_KEY="_GIT_INFO"

# println("Hello Parse!")

function parse_args(settings::ArgParseSettings; kw...)
    # println(ARGS)
    parse_args(ARGS, settings; kw...)
end

make_save_name(hashed, git_info; head="RP") = "$(head)_$(git_info)_0x$(string(hashed,base=16))"
# make_save_name(hashed) = make_save_name(hashed, 0)

# function parse_args
function parse_args(arg_list::Array{String}, settings::ArgParseSettings;
                    save_settings_dir="RP_settings",
                    as_symbols::Bool = false, filter_keys::Array{String,1} = Array{String,1}(),
                    use_git_info = false, custom_folder_name = "RP")

    parsed_args = ArgParse.parse_args(arg_list, settings; as_symbols=as_symbols)
    # Now if we are using symbols
    KEY_TYPE = String
    if as_symbols
        KEY_TYPE = Symbol
    end
    unused_keys = [KEY_TYPE(keys) for str in filter_keys]
    hash_key = KEY_TYPE(HASH_KEY)
    save_name_key = KEY_TYPE(SAVE_NAME_KEY)
    git_info_key = KEY_TYPE(GIT_INFO_KEY)

    hash_args = filter(k->(!(k[1] in unused_keys)), parsed_args)
    used_keys=keys(hash_args)

    hashed = HASHER(hash_args)

    parsed_args[hash_key] = hashed

    git_info = "0"
    if use_git_info
        git_info = Git.head()
    end
    parsed_args[git_info_key] = git_info

    save_name = make_save_name(hashed, git_info; head=custom_folder_name)
    parsed_args[save_name_key] = save_name

    save_settings_path = joinpath(save_settings_dir, save_name)

    if !isdir(save_settings_path)
        mkpath(save_settings_path)
    else
        println("Settings already exists! Overwriting data.")
    end

    save_settings_file = joinpath(save_settings_path, "settings.jld")
    JLD2.@save save_settings_file parsed_args used_keys

    return parsed_args

end
