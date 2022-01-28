
# Parse experiment config toml.

if VERSION > v"1.6"
    using TOML
else
    using Pkg.TOML
end

using JSON

#=
get_save_backend
=#
"""
    get_save_backend(cdict)

Get the save_backend.
"""
function get_save_backend(cdict)
    if "save_backend" ∈ keys(cdict)
        get_save_backend(Val(Symbol(cdict["save_backend"])), cdict)
    elseif "database" ∈ keys(cdict)
        get_save_backend(Val(:mysql), cdict)
    elseif "file_type" ∈ keys(cdict)
        get_save_backend(Val(:file), cdict)
    else
        get_save_backend(Val(:jld2), cdict)
    end
end

function get_save_backend(::Val{:mysql}, cdict)
    if "connection_file" ∈ keys(cdict)
        SQLSave(cdict["database"], cdict["connection_file"])
    else
        SQLSave(cdict["database"])
    end
end

function get_save_backend(::Val{:file}, cdict)
    file_type = Val(Symbol(cdict["file_type"]))
    get_save_backend(file_type, cdict)
end

function get_save_backend(ft::Union{Val{:jld2}, Val{:hdf5}, Val{:bson}}, cdict)
    FileSave(joinpath(cdict["save_dir"], "data"), SaveManager(ft))
end



#= #######

get_arg_iter

=# #######
"""
    get_arg_iter(cdict)
    get_arg_iter(::Val{T}, cdict) where T

get_arg_iter parses cdict to get the correct argument iterator. "arg_iter_type" needs to have a string value in the cdict (where the cdict is the config dict, often from a config file).
Reproduce has two iterators:
- T=:iter: ArgIterator which does a grid search over arguments
- T=:looper: ArgLooper which loops over a vector of dictionaries which can be loaded from an arg_file.

To implement a custom arg_iter you must implement `Reproduce.get_arg_iter(::Val{:symbol}, cdict)` where :symbol is the value arg_iter_type will take.
"""
function get_arg_iter(dict)
    iter_type = dict["config"]["arg_iter_type"]
    get_arg_iter(Val(Symbol(iter_type)), dict)
end

get_arg_iter(::Val{T}, cdict) where T = error("Can't parse $(T) from dict. Implement `get_arg_iter` for $(T).")

function get_static_args(dict)

    save_type = get_save_backend(dict["config"])
    
    static_args_dict = get(dict, "static_args", Dict{String, Any}())
    static_args_dict[SAVE_NAME_KEY] = save_type
    static_args_dict["save_dir"] = joinpath(dict["config"]["save_dir"], "data")

    static_args_dict
end

function get_arg_iter(::Val{:iter}, dict)

    static_args_dict = get_static_args(dict)
    cdict = dict["config"]
    
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
end

function get_arg_iter(::Val{:looper}, dict)

    static_args_dict = get_static_args(dict)
    cdict = dict["config"]
    
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
end


#=
Experiment
=#


function parse_config_file(path)
    ext = splitext(path)[end][2:end]
    parse_config_file(Val(Symbol(ext)), path)
end

parse_config_file(::Val{ext}, path) where {ext} = throw(ErrorException("Experiment currently doesn't support $(ext) files."))
parse_config_file(::Val{:toml}, path) = TOML.parsefile(path)
parse_config_file(::Val{:json}, path) = JSON.Parser.parsefile(path)



function parse_experiment_from_config(config_path, save_path=""; comp_env=get_comp_env())
    
    # need to deal with parsing config file.

    dict = parse_config_file(config_path)
    
    cdict = dict["config"]

    details_loc = joinpath(save_path, cdict["save_dir"])
    cdict["save_dir"] = details_loc
    
    exp_file = cdict["exp_file"]
    exp_module_name = cdict["exp_module_name"]
    exp_func_name = cdict["exp_func_name"]

    save_type = get_save_backend(cdict)
    
    arg_iter = get_arg_iter(dict)
    
    
    Experiment(details_loc,
               exp_file,
               exp_module_name,
               exp_func_name,
               save_type,
               arg_iter,
               config_path;
               comp_env=get_comp_env())
end



