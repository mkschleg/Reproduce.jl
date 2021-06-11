
struct ArgIterator <: AbstractArgIter
    dict::Dict
    static_args::Dict{String, Any}
    arg_order::Vector{String}
    done::Bool
end

function ArgIterator(dict, static_arg::Dict; arg_order=nothing)
    ArgIterator(dict,
                Dict{String, Any}(static_arg),
                arg_order==nothing ? collect(keys(dict)) : arg_order,
                false)
end

set_save_dir!(iter::ArgIterator, path) = iter.static_args["save_dir"] = path

function make_arguments(iter::ArgIterator, state)
    d = Dict{String, Any}()
    for (arg_idx, arg) in enumerate(iter.arg_order)
        if contains(arg, "+")
            ks = split(arg, "+")
            for (idx, k) ∈ enumerate(ks)
                d[k] = iter.dict[arg][state[2][arg_idx]][idx]
            end
        else
            d[arg] = iter.dict[arg][state[2][arg_idx]]
        end
    end
    merge!(d, iter.static_args)
    d
end

function Base.iterate(iter::ArgIterator)
    state = (1, ones(Int64, length(iter.arg_order)))
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function next_state(iter::ArgIterator, _state)
    state = _state[2]
    n_state = _state[1]

    state[end] += 1

    for (arg_idx, arg) in Iterators.reverse(enumerate(iter.arg_order))
        if arg_idx == 1
            return (n_state+1, state)
        end

        if state[arg_idx] > length(iter.dict[arg])
            state[arg_idx] = 1
            state[arg_idx - 1] += 1
        end
    end
end

function Base.iterate(iter::ArgIterator, state)
    if state[2][1] > length(iter.dict[iter.arg_order[1]])
        return nothing
    end
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function Base.length(iter::ArgIterator)
    return *([length(iter.dict[key]) for key in iter.arg_order]...)
end
