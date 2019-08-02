

struct ArgLooper
    dict_list::Vector{Vector{String}}
    runs_iter::AbstractArray
    stable_arg::Vector{String}
    done::Bool
    run_name::String
    ArgLooper(list, stable_arg, runs_iter, run_name="--run") = new(list, runs_iter, stable_arg, false, run_name)
end

function make_arguments(iter::ArgLooper, state)
    arg_list = Vector{String}()
    arg_list = [iter.dict_list[state[2][1]]; [iter.run_name, string(iter.runs_iter[state[2][2]])]; iter.stable_arg]
    return arg_list
end

function Base.iterate(iter::ArgLooper)
    state = (1, [1, 1])
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function next_state(iter::ArgLooper, _state)
    state = _state[2]
    n_state = _state[1]

    state[2] += 1
    if state[2] > length(iter.runs_iter)
        state[2] = 1
        state[1] += 1
    end
    return (n_state+1, state)
    
end

function Base.iterate(iter::ArgLooper, state)
    if state[2][1] > length(iter.dict_list)
        return nothing
    end
    arg_list = make_arguments(iter, state)
    return (state[1], arg_list), next_state(iter, state)
end

function Base.length(iter::ArgLooper)
    return length(iter.dict_list)*length(iter.runs_iter)
end
