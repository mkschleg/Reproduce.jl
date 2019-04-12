
using Reproduce
using FileIO, JLD2

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


function main_experiment(args::Vector{String}, saveloc::String="default_save_loc")


    arg_settings = arg_parse_settings()
    parsed = parse_args(args, arg_settings)
    create_info!(parsed, saveloc)
    j = 0
    if parsed["opt1"] == 2
        throw("Oh No!!!")
    end
    # sleep(0.1*(parsed["opt1"]^4))
    for i in 1:parsed["opt1"]^3
        j += i
    end
    @save joinpath(parsed["_SAVE"], "data.jld2") args

    return j
end
