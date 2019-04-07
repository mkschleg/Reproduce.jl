
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
    parsed = parse_args(args, arg_settings, saveloc)
    j = 0
    sleep(0.1*(parsed["opt1"]^4))
    @save joinpath(parsed["_SAVE"], "data.jld2") args

    return j
end
