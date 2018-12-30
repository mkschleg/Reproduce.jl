
using Reproduce

# function algorithm_args(settings::ArgParseSettings)
# end

function arg_parse(args)

    s = ArgParseSettings()
    @add_arg_table s begin
        # Basic Arguments
        "--savefile"
        help = "a file to save the results to"
        required = true
    end

    @add_arg_table s begin
        # Basic Arguments
        "--loadfile"
        help = "a file to save the results to"
        required = true
    end
    # println(args)
    parsed = parse_args(args, s; use_git_info=true)
    return parsed
end

function main()

    args=["--savefile", "hello_world.jld", "--loadfile", "hello_world.jld"]
    # args=["--savefile", "hello_world.jld"]
    # println(typeof(args))
    parsed = arg_parse(args)
    println(parsed)

end


