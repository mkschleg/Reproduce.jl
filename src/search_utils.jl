
module search_utils

"""
    best_settings

This function takes an experiment directory and finds the best setting for the product of arguments
with keys specified by product_args. To see a list of viable arguments use
    `ic = ItemCollection(exp_loc); diff(ic.items)`

If a save_loc is provided, this will save to the file specified. The fmt must be supported by FileIO and be able to take dicts.

Additional kwargs are passed to order_settings.

"""


function best_settings(exp_loc, product_args::Vector{String};
                       save_loc="", kwargs...)

    ic = ItemCollection(exp_loc)
    diff_dict = diff(ic.items)

    args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    settings_dict = Dict()
    for (arg_idx, arg) in enumerate(args)
        search_dict = Dict([product_args[idx]=>key for (idx, key) in enumerate(arg)]...)
        ret = order_settings(exp_loc; set_args=search_dict, ic=ic, kwargs...)
        settings_dict[search_dict] = ret[1]
    end

    
    if save_loc != ""
        save(save_loc, Dict("best_settings"=>settings_dict))
    else
        return settings_dict
    end
    
end


"""
    order_settings

    This provides a mechanism to order the settings of an experiment.

    kwargs:
        `set_args(=Dict{String, Any}())`: narrowing the search parameters. See best_settings for an example of use.

        `clean_func(=identity)`: The function used to clean the loaded data
        `runs_func(=mean)`: The function which takes a vector of floats and produces statistics. Must return either a Float64 or Dict{String, Float64}. (WIP, any container/primitive which implements get_index).

        `lt(=<)`: The less than comparator.
        `sort_idx(=1)`: The idx of the returned `runs_func` structure used for sorting.
        `run_key(=run)`: The key used to specify an ind run for an experiment.

        `results_file(=\"results.jld2\")`: The string of the file containing experimental results.
        `save_loc(=\"\")`: The save location (returns settings_vec if not provided).
        `ic(=ItemCollection([])`: Optional item_collection, not needed in normal use.
"""

function order_settings(exp_loc;
                        results_file="results.jld2",
                        clean_func=identity, runs_func=mean,
                        lt=<, sort_idx=1, run_key="run",
                        set_args=Dict{String, Any}(),
                        ic=ItemCollection([]), save_loc="")

    if exp_loc[end] == '/'
        exp_loc = exp_loc[1:end-1]
    end

    exp_path = dirname(exp_loc)
    if length(ic.items) == 0
        ic = ItemCollection(exp_loc)
    end
    diff_dict = diff(ic.items)
    product_args = collect(filter((k)->(k!=run_key && k∉keys(set_args)), keys(diff_dict)))

    args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    settings_vec =
        Vector{Tuple{Union{Float64, Vector{Float64}, Dict{String, Float64}}, Dict{String, Any}}}(undef, length(args))

    #####
    # Populate settings Vector
    #####
    @showprogress 0.1 "Setting: " for (arg_idx, arg) in enumerate(args)

        search_dict = merge(
            Dict([product_args[idx]=>key for (idx, key) in enumerate(arg)]...),
            set_args)
        _, hashes, _ = search(ic, search_dict)
        μ_runs = zeros(length(hashes))
        for (idx_d, d) in enumerate(hashes)
            if isfile(joinpath(exp_path, d, results_file))
                results = load(joinpath(exp_path, d, results_file))
                μ_runs[idx_d] = clean_func(results)
            else
                μ_runs[idx_d] = Inf
            end
        end
        settings_vec[arg_idx] = (runs_func(μ_runs), search_dict)
    end

    #####
    # Sort settings vector
    #####
    sort!(settings_vec; lt=lt, by=(tup)->tup[1][sort_idx])

    #####
    # Save
    #####
    if save_loc != ""
        save(save_loc, Dict("settings"=>settings_vec))
    else
        return settings_vec
    end
end

end # module search_utils
