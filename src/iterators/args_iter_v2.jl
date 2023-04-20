

"""
    ArgIteratorV2

This is the second version of the Argument Iterator. The old version is kept for posterity, and to ensure compatibility of old config files. To use this iterator use:
`arg_iter_type="iterV2` in the `config` portion of your configuration file when using [`parse_experiment_from_config`](@ref). This iterator does a product over all the arguments found in the `sweep_args` nested section. For example:

```toml
[config]
...
arg_iter_type="iterV2"

[static_args]
network_sizes = [10, 30, 100]
log_freq = 100_000
arg_1 = 1
arg_2 = 1

[sweep_args]
seed = [1,2,3,4,5]
eta = "0.15.^(-10:2:0)"
network_sizes.2 = [10, 30, 50, 70]
arg_1+arg_2 = [[1,1], [2,2], [3,3]]

```

produces a set of 360 argument settings. The seed parameter is straight forward, where the iterator iterates over the list. `eta`'s string will be parsed by the julia interpreter. This is dangerous and means arbitrary code can be run, so be careful! `network_size.2` goes through and sets the second element of the network_sizes array to be in the list. Finally `arg_1+arg_2` sweeps over both arg_1 and arg_2 simultaneously (i.e. doesn't do a product over these).

Sweep args special characters:
- "+": This symbol sweeps over a vector of vectors and sets the arguments according to the values of the inner vectors in the order specified.
- ".": This symbol is an "access" symbol and accesses nested structures in the set of arguments.
- "*": This symbol is similar to "+" but instead sets all the keys to be the top level value in the sweep vector.


"""
struct ArgIteratorV2
    sweep_args::Dict
    static_args::Dict{String, Any}
    arg_order::Vector{String}
    done::Bool
end

function ArgIteratorV2(sweep_args, static_arg::Dict=Dict(); arg_order=nothing)
    ArgIteratorV2(sweep_args,
                  Dict{String, Any}(static_arg),
                  arg_order==nothing ? collect(keys(sweep_args)) : arg_order,
                  false)
end

set_save_dir!(iter::ArgIteratorV2, path) = iter.static_args["save_dir"] = path

int_parse_or_not(a::AbstractString) = isnothing(tryparse(Int, a)) ? a : parse(Int, a)

function set_argument!(d, args::Vector, v)
    if length(args) == 1
        set_argument!(d, args[1], v)
    elseif occursin("+", args[1])
        ks = int_parse_or_not.(split(args[1], "+"))
        for (i, k) ∈ enumerate(ks)
            set_argument!(d[k], args[2:end], v[i])
        end
    elseif occursin("*", args[1])
        ks = int_parse_or_not.(split(args[1], "*"))
        for (i, k) ∈ enumerate(ks)
            set_argument!(d[k], args[2:end], v)
        end
    else
        set_argument!(d[args[1]], args[2:end], v)
    end
end

function set_argument!(d, arg::Integer, v)
    d[arg] = v
end

function set_argument!(d, arg::AbstractString, v)
    if (startswith(arg, "[") &&
        endswith(arg, "]") &&
        occursin(r"\[.*\]", arg) &&
        !occursin(".", arg))
        
        str_idxs = findall(r"\[[0-9_a-z_A-Z_\__+]*\]")
        idxs = [int_parse_or_not(arg[idx[1]+1:idx[2]-1])  for idx in str_idxs]
        set_argument!(d, idxs, v)
    elseif occursin(r"\[.*\]", arg)
        idx = findfirst("[", arg)[1]
        set_argument!(d[arg[1:idx-1]], arg[idx:end], v)
    elseif occursin(".", arg)
        # sets into collections of things.
        sarg = split(arg, ".")
        arg_vec = int_parse_or_not.(sarg)
        set_argument!(d, arg_vec, v)
    elseif occursin("+", arg)
        # sweeps over set of keys with a set of values
        ks = split(arg, "+")
        for (i, k) ∈ enumerate(ks)
            d[k] = v[i]
        end
    elseif occursin("*", arg)
        # sets all the keys to be the same value
        ks = int_parse_or_not.(split(args[1], "*"))
        for (i, k) ∈ enumerate(ks)
            set_argument!(d[k], args[2:end], v)
        end
    else
        d[arg] = v
    end
end

function make_arguments(iter::ArgIteratorV2, state)
    d = Dict{String, Any}()
    d = deepcopy(iter.static_args)
    for (arg_idx, arg) in enumerate(iter.arg_order)
        set_argument!(d, arg, iter.sweep_args[arg][state[2][arg_idx]])
    end
    d
end

function Base.iterate(iter::ArgIteratorV2)
    state = (1, ones(Int64, length(iter.arg_order)))
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function next_state(iter::ArgIteratorV2, _state)
    state = _state[2]
    n_state = _state[1]

    state[end] += 1

    for (arg_idx, arg) in Iterators.reverse(enumerate(iter.arg_order))
        if arg_idx == 1
            return (n_state+1, state)
        end

        if state[arg_idx] > length(iter.sweep_args[arg])
            state[arg_idx] = 1
            state[arg_idx - 1] += 1
        end
    end
end

function Base.iterate(iter::ArgIteratorV2, state)
    if state[2][1] > length(iter.sweep_args[iter.arg_order[1]])
        return nothing
    end
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function Base.length(iter::ArgIteratorV2)
    return *([length(iter.sweep_args[key]) for key in iter.arg_order]...)
end
