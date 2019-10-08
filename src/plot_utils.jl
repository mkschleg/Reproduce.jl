

using Plots
using Statistics
using ProgressMeter
using FileIO
using JLD2

# These functions are for grid searches.



"""
    sensitivity

plots a sensitivity curve over sweep arg with all settings producted according to product_args
"""
function sensitivity(exp_loc,
                     sweep_arg::String,
                     product_args::Vector{String};
                     results_file="results.jld2",
                     clean_func=identity,
                     ci_const = 1.96,
                     sweep_args_clean=identity,
                     save_dir="sensitivity",
                     ylim=nothing)

    gr()

    if exp_loc[end] == '/'
        exp_loc = exp_loc[1:end-1]
    end
    head_dir = dirname(exp_loc)

    ic = ItemCollection(exp_loc)
    diff_dict = diff(ic.items)
    args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    p1 = ProgressMeter.Progress(length(args), 0.1, "Args: ", offset=0)

    for arg in args

        plt=nothing
        μ = zeros(length(diff_dict[sweep_arg]))
        σ = zeros(length(diff_dict[sweep_arg]))

        p2 = ProgressMeter.Progress(length(diff_dict[sweep_arg]), 0.1, "$(sweep_arg): ", offset=1)
        for (idx, s_a) in enumerate(diff_dict[sweep_arg])
            search_dict = Dict(sweep_arg=>s_a, [product_args[idx]=>key for (idx, key) in enumerate(arg)]...)
            _, hashes, _ = search(ic, search_dict)
            # println(search_dict)
            # println(length(hashes))
            μ_runs = zeros(length(hashes))
            for (idx_d, d) in enumerate(hashes)

                if isfile(joinpath(head_dir, d, results_file))
                    results = load(joinpath(head_dir, d, results_file))
                    μ_runs[idx_d] = clean_func(results)
                # catch e
                else
                    # println(joinpath(head_dir, d, results_file))
                    μ_runs[idx_d] = Inf
                end

            end
            μ[idx] = mean(μ_runs)
            # println(μ)
            σ[idx] = ci_const * std(μ_runs)/sqrt(length(μ_runs))
            next!(p2)
        end

        if plt == nothing
            plt = plot(sweep_args_clean(diff_dict[sweep_arg]), μ, yerror=σ, ylim=ylim)
        else
            plot!(plt, sweep_args_clean(diff_dict[sweep_arg]), μ, yerror=σ)
        end

        if !isdir(joinpath(exp_loc, save_dir))
            mkdir(joinpath(exp_loc, save_dir))
        end

        save_file_name = join(["$(key)_$(arg[idx])" for (idx, key) in enumerate(product_args)], "_")

        savefig(plt, joinpath(exp_loc, save_dir, "$(save_file_name).pdf"))
        next!(p1)
    end


end


"""
    sensitivity_multiline

plots a sensitivity curve over sweep arg with all settings producted according to product_args with lines with args according to line_arg
"""
function sensitivity_multiline(exp_loc, sweep_arg::String, line_arg::String, product_args::Vector{String};
                               results_file="results.jld2", clean_func=identity,
                               sweep_args_clean=identity, save_dir="sensitivity_line",
                               ylim=nothing, ci_const = 1.96, kwargs...)

    gr()

    if exp_loc[end] == '/'
        exp_loc = exp_loc[1:end-1]
    end
    head_dir = dirname(exp_loc)
    
    ic = ItemCollection(exp_loc)
    diff_dict = diff(ic.items)
    args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    p1 = ProgressMeter.Progress(length(args), 0.1, "Args: ", offset=0)

    for arg in args

        plt=nothing

        p2 = ProgressMeter.Progress(length(diff_dict[line_arg]), 0.1, "$(line_arg): ", offset=1)

        for (idx_line, l_a) in enumerate(diff_dict[line_arg])

            μ = zeros(length(diff_dict[sweep_arg]))
            σ = zeros(length(diff_dict[sweep_arg]))

            p3 = ProgressMeter.Progress(length(diff_dict[sweep_arg]), 0.1, "$(sweep_arg): ", offset=2)
            for (idx, s_a) in enumerate(diff_dict[sweep_arg])
                search_dict = Dict(sweep_arg=>s_a, line_arg=>l_a, [product_args[idx]=>key for (idx, key) in enumerate(arg)]...)
                _, hashes, _ = search(ic, search_dict)
                μ_runs = zeros(length(hashes))
                for (idx_d, d) in enumerate(hashes)
                    if isfile(joinpath(head_dir, d, results_file))
                        results = load(joinpath(head_dir, d, results_file))
                        μ_runs[idx_d] = clean_func(results)
                        # catch e
                    else
                        # println(joinpath(head_dir, d, results_file))
                        μ_runs[idx_d] = Inf
                    end
                end
                μ[idx] = mean(μ_runs)
                σ[idx] = ci_const * std(μ_runs)/sqrt(length(μ_runs))
                next!(p3)
            end

            if plt == nothing
                plt = plot(sweep_args_clean(diff_dict[sweep_arg]), μ, yerror=σ, ylim=ylim, label="$(line_arg)=$(l_a)"; kwargs...)
            else
                plot!(plt, sweep_args_clean(diff_dict[sweep_arg]), μ, yerror=σ, label="$(line_arg)=$(l_a)"; kwargs...)
            end
            next!(p2)
        end

        if !isdir(joinpath(exp_loc, save_dir))
            mkdir(joinpath(exp_loc, save_dir))
        end

        save_file_name = join(["$(key)_$(arg[idx])" for (idx, key) in enumerate(product_args)], "_")

        savefig(plt, joinpath(exp_loc, save_dir, "$(save_file_name).pdf"))
        next!(p1)
    end


end

"""
    sensitivity_best_arg

plots a sensitivity curve over sweep arg with all settings producted according to product_args selecting the best over best_arg
"""
function sensitivity_best_arg(exp_loc,
                              sweep_arg::String,
                              best_arg::String,
                              product_args::Vector{String};
                              results_file="results.jld2",
                              clean_func=identity,
                              sweep_args_clean=identity,
                              compare=(new, old)->new<old,
                              save_dir="sensitivity_best",
                              ylim=nothing, ci_const = 1.96, kwargs...)

    gr()

    if exp_loc[end] == '/'
        exp_loc = exp_loc[1:end-1]
    end
    head_dir = dirname(exp_loc)
    
    ic = ItemCollection(exp_loc)
    diff_dict = diff(ic.items)
    args = Iterators.product([diff_dict[arg] for arg in product_args]...)

    p1 = ProgressMeter.Progress(length(args), 0.1, "Args: ", offset=0)

    for arg in args

        plt=nothing

        p2 = ProgressMeter.Progress(length(diff_dict[best_arg]), 0.1, "$(best_arg): ", offset=1)

        μ = zeros(length(diff_dict[sweep_arg]))
        fill!(μ, Inf)
        σ = zeros(length(diff_dict[sweep_arg]))

        for (idx_line, b_a) in enumerate(diff_dict[best_arg])

            p3 = ProgressMeter.Progress(length(diff_dict[sweep_arg]), 0.1, "$(sweep_arg): ", offset=2)
            for (idx, s_a) in enumerate(diff_dict[sweep_arg])
                search_dict = Dict(sweep_arg=>s_a, best_arg=>b_a, [product_args[idx]=>key for (idx, key) in enumerate(arg)]...)
                _, hashes, _ = search(ic, search_dict)
                μ_runs = zeros(length(hashes))
                for (idx_d, d) in enumerate(hashes)
                    if isfile(joinpath(head_dir, d, results_file))
                        results = load(joinpath(head_dir, d, results_file))
                        μ_runs[idx_d] = clean_func(results)
                        # catch e
                    else
                        # println(joinpath(head_dir, d, results_file))
                        μ_runs[idx_d] = Inf
                    end
                end
                if compare(mean(μ_runs), μ[idx])
                    μ[idx] = mean(μ_runs)
                    σ[idx] = ci_const * std(μ_runs)/sqrt(length(μ_runs))
                end
                next!(p3)
            end

            next!(p2)
        end

        if plt == nothing
            plt = plot(sweep_args_clean(diff_dict[sweep_arg]), μ, yerror=σ, ylim=ylim; kwargs...)
        else
            plot!(plt, sweep_args_clean(diff_dict[sweep_arg]), μ, yerror=σ; kwargs...)
        end

        if !isdir(joinpath(exp_loc, save_dir))
            mkdir(joinpath(exp_loc, save_dir))
        end

        save_file_name = join(["$(key)_$(arg[idx])" for (idx, key) in enumerate(product_args)], "_")

        savefig(plt, joinpath(exp_loc, save_dir, "$(save_file_name).pdf"))
        next!(p1)
    end


end



function plot_sens_files(file_list, line_settings_list, save_file="tmp.pdf", ci = 1.97; plot_back=gr, kwargs...)

    plot_back()

    plt = nothing

    for (idx, f) in enumerate(file_list)

        ret = load(f)
        println(ret)

        if plt == nothing
            plt = plot(ret["sens"], ret["avg"], ribbon=ci.*ret["std_err"]; line_settings_list[idx]..., kwargs...)
        else
            plot!(plt, ret["sens"], ret["avg"], ribbon=ci.*ret["std_err"]; line_settings_list[idx]..., kwargs...)
        end
    end

    savefig(plt, save_file)

end

function plot_lc_files(file_list, line_settings_list; save_file="tmp.pdf", ci=1.97, n=1, clean_func=identity, plot_back=gr, ignore_nans=false, kwargs...)

    plot_back()

    plt = nothing

    for (idx, f) in enumerate(file_list)

        ret = load(f)
        l = length(clean_func(ret["results"][1]))

        filtered = ret["results"]
        if ignore_nans
            filtered = filter(x->mean(x)!=NaN, ret["results"])
        end
        avg = mean([mean(reshape(clean_func(v), n, Int64(l/n)); dims=1) for v in filtered])'
        std_err = (std([mean(reshape(clean_func(v), n, Int64(l/n)); dims=1) for v in filtered])./sqrt(length(filtered)))'

        x = 0:n:l

        if plt == nothing
            plt = plot(avg, ribbon=ci.*std_err; line_settings_list[idx]..., kwargs...)
        else
            plot!(plt, avg, ribbon=ci.*std_err; line_settings_list[idx]..., kwargs...)
        end
    end

    savefig(plt, save_file)
    
end


