
module search_utils


function save_settings(save_loc, settings_vec)
    if split(basename(save_loc), ".")[end] == "txt"
        open(save_loc, "w") do f
            for v in settings_vec
                write(f, string(v)*"\n")
            end
        end
    else
        @save save_loc Dict("settings"=>settings_vec)
    end
end


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


function collect_data(exp_loc;
                      run_arg="run",
                      results_file="results.jld2", settings_file="settings.jld2", clean_func=identity,
                      save_dir="collected")
                      

    if exp_loc[end] == '/'
        exp_loc = exp_loc[1:end-1]
    end
    head_dir = dirname(exp_loc)

    if !isdir(joinpath(exp_loc, save_dir))
        mkdir(joinpath(exp_loc, save_dir))
    end

    ic = ItemCollection(exp_loc)
    diff_dict = diff(ic.items)
    # args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    search_dict = Dict(run_arg=>diff_dict[run_arg][1])

    _, hashes, _ = search(ic, search_dict)

    settings_vec = Vector{Dict}(undef, length(hashes))

    # collect the parameter settings run
    for (idx, h) in enumerate(hashes)
        sett = load(joinpath(head_dir, h, settings_file))["parsed_args"]
        settings_vec[idx] = Dict(k=>sett[k] for k in filter(v -> v != run_arg, keys(diff_dict)))
    end

    @showprogress for (idx, stngs) in enumerate(settings_vec)
        # println(length(search(ic, stngs)[2]))
        hashes = search(ic, stngs)[2]

        v = Vector{Any}(undef, length(hashes))
        for (idx, h) in enumerate(hashes)
            v[idx] = clean_func(load(joinpath(head_dir, h, results_file)))
        end
        save(joinpath(exp_loc, save_dir, join(["$(k)_$(stngs[k])" for k in keys(stngs)], '_')*".jld2"), Dict("results"=>v, "settings"=>stngs))
    end

end

function collect_sens_data(exp_loc, sens_param, product_args;
                           run_arg="run",
                           results_file="results.jld2", settings_file="settings.jld2", clean_func=identity,
                           save_dir="collected_sens", ignore_nans=false, ignore_sens=nothing)

    if exp_loc[end] == '/'
        exp_loc = exp_loc[1:end-1]
    end
    head_dir = dirname(exp_loc)

    if !isdir(joinpath(exp_loc, save_dir))
        mkdir(joinpath(exp_loc, save_dir))
    end

    ic = ItemCollection(exp_loc)
    diff_dict = diff(ic.items)
    if ignore_sens != nothing
        diff_dict[sens_param] = filter(x->x!=ignore_sens, diff_dict[sens_param])
        println(diff_dict[sens_param])
    end
    args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    println(collect(args))

    for arg in collect(args)

        println([k=>arg[k_idx] for (k_idx, k) in enumerate(product_args)])
        
        search_dict = Dict(run_arg=>diff_dict[run_arg][1], [k=>arg[k_idx] for (k_idx, k) in enumerate(product_args)]...)

        _, hashes, _ = search(ic, search_dict)

        settings_vec = Vector{Dict}(undef, length(hashes))

        # collect the parameter settings run
        for (idx, h) in enumerate(hashes)
            sett = load(joinpath(head_dir, h, settings_file))["parsed_args"]
            settings_vec[idx] = Dict([k=>sett[k] for k in filter(v -> v ∉ keys(search_dict), keys(diff_dict))]..., [k=>arg[k_idx] for (k_idx, k) in enumerate(product_args)]...)
        end

        avg_res = zeros(length(diff_dict[sens_param]))
        std_err = zeros(length(diff_dict[sens_param]))
        
        for (idx, stngs) in enumerate(settings_vec)
            # println(length(search(ic, stngs)[2]))
            hashes = search(ic, stngs)[2]
            
            v = zeros(length(hashes))
            for (idx, h) in enumerate(hashes)
                v[idx] = clean_func(load(joinpath(head_dir, h, results_file)))
            end


            sens_idx = findfirst(x->x==stngs[sens_param], diff_dict[sens_param])
            if sens_idx != nothing
                filtered = filter(x->!isnan(x), v)
                println(stngs, ": ", filtered)
                avg_res[sens_idx] = mean(filtered)
                std_err[sens_idx] = std(filter(x->!isnan(x), v))/sqrt(length(filter(x->!isnan(x), v)))
            end

        end

   p     save(joinpath(exp_loc, save_dir, "collect_"*join(["$(k)_$(arg[k_idx])" for (k_idx, k) in enumerate(product_args)], '_')*".jld2"), Dict("avg"=>avg_res, "std_err"=>std_err, "sens"=>diff_dict[sens_param], "settings"=>Dict([k=>arg[k_idx] for (k_idx, k) in enumerate(product_args)])))
    end
end

end # module search_utils
