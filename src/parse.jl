
# Parse experiment config toml.

@static if VERSION > v"1.6"
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
- T=:iterV2: ArgIteratorV2 which is the second version of the original ArgIterator, and currently recommended.

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
    
    ArgLooper(args_dict_list,
              static_args_dict,
              run_param,
              run_list)
end

"""
    get_arg_iter(::Val{:iterV2}, dict)

This is the function which parses [`ArgIteratorV2`](@ref) from a config file dictionary.
It expects the following nested dictionaries:
- `config`: This has all the various components to help detail the expeirment (see [`parse_experiment_from_config`](@ref) for more details.)
    - `arg_list_order::Vector{String}`: inside the config dict is the order on which to do your sweeps. For example, if seed is first, the scheduler will make sure to run all the seeds for a particular setting before moving to the next set of parameters.
- `sweep_args`: These are all the arguments that the args iter will sweep over (doing a cross product to produce all the parameters). See [`ArgIteratorV2`](@ref) for supported features.
- `static_args`: This is an optional component which contains all the arguments which are static. If not included, all elements in the top level of the dictionary will be assumed to be static args (excluding config and sweep_args).
"""
function get_arg_iter(iter_type::Val{:iterV2}, dict)

    static_args_dict = get_static_args(iter_type, dict)
    cdict = dict["config"]
    
    arg_order = get(cdict, "arg_list_order", nothing)

    sweep_args_dict = prepare_sweep_args(dict["sweep_args"])
    
    @assert arg_order isa Nothing || all(sort(arg_order) .== sort(collect(keys(sweep_args_dict))))

    ArgIteratorV2(sweep_args_dict,
                  static_args_dict,
                  arg_order=arg_order)
end

function get_static_args(::Val{:iterV2}, dict)

    static_args_dict = if "static_args" ∈ keys(dict)
        dict["static_args"]
    else
        filter(dict) do kv
            kv.first ∉ ["sweep_args", "config"]
        end
    end
    
    save_type = get_save_backend(dict["config"])
    static_args_dict[Reproduce.SAVE_NAME_KEY] = save_type
    static_args_dict["save_dir"] = joinpath(dict["config"]["save_dir"], "data")

    static_args_dict
end

function prepare_sweep_args(sweep_args)
    new_dict = Dict{String, Any}()
    ks = keys(sweep_args)
    for key ∈ ks
        if sweep_args[key] isa String
            new_dict[key] = eval(Meta.parse(sweep_args[key]))
        elseif sweep_args[key] isa Dict
            d = prepare_sweep_args(sweep_args[key])
            for k in keys(d)
                # dot syntax for ArgsIteratorV2
                new_dict[key*"."*k] = d[k] 
            end
        else
            new_dict[key] = sweep_args[key]
        end
    end
    new_dict
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


"""
    parse_experiment_from_config

This function creates an experiment from a config file. 

## args
- `config_path::String` the path to the config.
- `[save_path::String]` a save path which dictates where the base savedir for the job will be (prepend dict["config"]["save_dir"]).
## kwargs
- `comp_env` a computational environment which dispatchers when job is called.

The config file needs to be formated in a certain way. I use toml examples below:
```toml
[config]
save_dir="location/to/save" # will be prepended by save_path
exp_file="file/containing/experiment.jl" # The file containing your experiment function
exp_module_name = "ExperimentModule" # The module of your experiment in the experiment file
exp_func_name = "main_experiment" # The function to call in the experiment module.
arg_iter_type = "iterV2"

# These are specific to what arg_iter_type you are using 
[static_args]
...
[sweep_args]
...
```
"""
function parse_experiment_from_config(config_path, save_path=""; num_workers=1, num_threads_per_worker=1, comp_env=get_comp_env(;num_workers=num_workers, threads_per_worker=num_threads_per_worker))
    
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
               comp_env=comp_env)
end



