
struct ArgLooper{SA, SB, RI}  <: AbstractArgIter
    dict_list::Vector{SA}
    runs_iter::RI
    stable_arg::SB
    done::Bool
    run_name::String
end

function ArgLooper(dict_list::Vector{<:Dict}, stable_arg::Dict, run_param, runs_iter)
    ArgLooper(dict_list, runs_iter, stable_arg, false, run_param)
end

set_save_dir!(iter::ArgLooper, path) = iter.stable_arg["save_dir"] = path

function make_arguments(iter::ArgLooper{SA, RI}, state) where {SA<:Vector{String}, RI}
    arg_list = Vector{String}()
    arg_list = [iter.dict_list[state[2][1]]; [iter.run_name, string(iter.runs_iter[state[2][2]])]; iter.stable_arg]
    return arg_list
end

function make_arguments(iter::ArgLooper{SA, RI}, state) where {SA<:Dict, RI}
    arg_list = Vector{String}()
    arg_list = merge(iter.dict_list[state[2][1]], iter.stable_arg)
    arg_list[iter.run_name] = iter.runs_iter[state[2][2]]
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
