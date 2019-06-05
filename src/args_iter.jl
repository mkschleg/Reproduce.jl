


struct ArgIterator
    dict::Dict
    stable_arg::Vector{String}
    arg_list::Vector{String}
    done::Bool
    make_args
    ArgIterator(dict, stable_arg; arg_list=nothing, make_args=nothing) = new(dict, stable_arg, arg_list==nothing ? collect(keys(dict)) : arg_list, false, make_args)
end

function make_arguments(iter::ArgIterator, state)
    arg_list = Vector{String}()

    if iter.make_args == nothing
        new_ret_list = Vector{String}()
        for (arg_idx, arg) in enumerate(iter.arg_list)
            push!(new_ret_list, arg)
            push!(new_ret_list, string(iter.dict[arg][state[2][arg_idx]]))
        end
        arg_list = [new_ret_list; iter.stable_arg]
    else
        d = Dict{String, Union{String, Tuple}}()
        for (arg_idx, arg) in enumerate(iter.arg_list)
            if iter.dict[arg][state[2][arg_idx]] <: Tuple
                d[arg] = string.(iter.dict[arg][state[2][arg_idx]])
            else
                d[arg] = string(iter.dict[arg][state[2][arg_idx]])
            end
        end
        arg_list = [iter.make_args(d); iter.stable_arg]
    end
end

function Base.iterate(iter::ArgIterator)
    state = (1, ones(Int64, length(iter.arg_list)))
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function next_state(iter::ArgIterator, _state)
    state = _state[2]
    n_state = _state[1]

    state[end] += 1

    for (arg_idx, arg) in Iterators.reverse(enumerate(iter.arg_list))
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
    if state[2][1] > length(iter.dict[iter.arg_list[1]])
        return nothing
    end
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function Base.length(iter::ArgIterator)
    return *([length(iter.dict[key]) for key in iter.arg_list]...)
end
