
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

function main_experiment(args::Vector{String}, saveloc::AbstractString="default_save_loc")
    arg_settings = arg_parse_settings()
    parsed = parse_args(args, arg_settings)
    main_experiment(parsed, saveloc)
end

function main_experiment(parsed::Dict, saveloc = nothing)
    if saveloc isa Nothing
        create_info!(parsed, parsed["save_dir"])
    else
        create_info!(parsed, saveloc)
    end
    j = 0
    if parsed["opt1"] == 2
        throw("Oh No!!!")
    end

    @save joinpath(parsed["_SAVE"], "data.jld2") parsed

    return j
end

# function main_experiment(parsed::Dict)
#     if saveloc isa Nothing
#         create_info!(parsed, parsed["save_dir"])
#     else
#         create_info!(parsed, saveloc)
#     end
#     j = 0
#     if parsed["opt1"] == 2
#         throw("Oh No!!!")
#     end

#     @save joinpath(parsed["_SAVE"], "data.jld2") parsed

#     return j
# end


# When using Config.jl as a config manager.
function main_experiment(cfg::ConfigManager, saveloc::String="default_save_loc")
    j = 0
    if cfg["args"]["opt1"] == 2
        throw("Oh No!!!")
    end

    args = Dict(
        "opt1"=>cfg["args"]["opt1"],
        "opt2"=>cfg["args"]["opt2"],
        "run"=>cfg["run"],
        "saveloc"=>saveloc
    )
    
    save(cfg, args)
    return j 
end

