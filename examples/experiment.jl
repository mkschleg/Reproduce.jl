
using Reproduce
using JLD2
using Config

function arg_parse_settings(as::ArgParseSettings = ArgParseSettings())

    @add_arg_table as begin
        "--opt1"
        arg_type=Int64
        "--opt2"
        arg_type=Int64
        "--steps"
        arg_type=Int64
    end
    return as
end

function main_experiment(args::Vector{String}, extra_arg)
    arg_settings = arg_parse_settings()
    parsed = parse_args(args, arg_settings)
    main_experiment(parsed, extra_arg)
end

function main_experiment(parsed::Dict, extra_arg = nothing)

    create_info!(parsed, parsed["save_dir"])

    j = 0
    if parsed["opt1"] == 2
        throw("Oh No!!!")
    end

    @save joinpath(parsed["_SAVE"], "data.jld2") parsed

    return j
end

# When using Config.jl as a config manager.
function main_experiment(cfg::ConfigManager, extra_arg)
    j = 0
    if cfg["args"]["opt1"] == 2
        throw("Oh No!!!")
    end

    args = Dict(
        "opt1"=>cfg["args"]["opt1"],
        "opt2"=>cfg["args"]["opt2"],
        "run"=>cfg["run"],
        "extra_arg"=>extra_arg)
    
    save(cfg, args)
    return j 
end

