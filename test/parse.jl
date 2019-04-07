module PARSE_TESTS
using Reproduce, Test, Git, FileIO

TEST_DIR = "TEST_DIR"

function arg_parse(args; use_git_info=false, as_symbols=false)

    s = ArgParseSettings()
    @add_arg_table s begin
        "--a"
        help = "a file to save the results to"
        arg_type = Int64
        required = true
    end

    @add_arg_table s begin
        "--b"
        help = "a file to save the results to"
        arg_type = String
        required = true
    end
    parsed = parse_args(args, s, TEST_DIR;
                        use_git_info=use_git_info,
                        as_symbols=as_symbols)
    return parsed
end

function reset_tests()
    working_dir = pwd()
    rm(joinpath(working_dir, TEST_DIR); recursive=true)
end

function parse_test()

    test_dict = Dict("a"=>1, "b"=>"1.jld")
    args=["--a", "1", "--b", "1.jld"]
    parsed = arg_parse(args)

    reset_tests()

    return hash(test_dict) == parsed["_HASH"]
end

function track_test()

    used_keys = ["a", "b"]
    parsed_dicts = Dict{UInt64, Dict}()
    for i in 1:10
        args=["--a", "$(i)", "--b", "$(i).jld"]
        parsed = arg_parse(args)
        parsed_dicts[parsed["_HASH"]] = filter(k->(k[1] in used_keys), parsed)
    end
    dirs = (TEST_DIR*"/").*joinpath.(readdir(TEST_DIR), "settings.jld2")
    tests = fill(false, 10)
    for i in 1:10
        dict = FileIO.load(dirs[i])
        parsed_args = dict["parsed_args"]
        used_keys = dict["used_keys"]
        tests[i] = filter(k->(k[1] in used_keys), parsed_args) == parsed_dicts[parsed_args["_HASH"]]
    end

    reset_tests()
    return all(tests)
end

function track_symbols_test()

    used_keys = [:a, :b]
    parsed_dicts = Dict{UInt64, Dict}()
    for i in 1:10
        args=["--a", "$(i)", "--b", "$(i).jld"]
        parsed = arg_parse(args; as_symbols=true)
        parsed_dicts[parsed[:_HASH]] = filter(k->(k[1] in used_keys), parsed)
    end
    dirs = (TEST_DIR*"/").*joinpath.(readdir(TEST_DIR), "settings.jld2")
    tests = fill(false, 10)
    for i in 1:10
        dict = FileIO.load(dirs[i])
        parsed_args = dict["parsed_args"]
        used_keys = dict["used_keys"]
        tests[i] = filter(k->(k[1] in used_keys), parsed_args) == parsed_dicts[parsed_args[:_HASH]]
    end

    reset_tests()
    return all(tests)
end

function track_with_git_test()

    git_head = Git.head()
    used_keys = ["a", "b"]
    parsed_dicts = Dict{UInt64, Dict}()
    for i in 1:10
        args=["--a", "$(i)", "--b", "$(i).jld"]
        parsed = arg_parse(args; use_git_info=true)
        parsed_dicts[parsed["_HASH"]] = parsed
    end
    dirs = (TEST_DIR*"/").*joinpath.(readdir(TEST_DIR), "settings.jld2")
    tests = fill(false, 10)
    for i in 1:10
        # @load dirs[i] parsed_args used_keys
        dict = FileIO.load(dirs[i])
        parsed_args = dict["parsed_args"]
        used_keys = dict["used_keys"]
        tests[i] = (==(filter(k->(k[1] in used_keys), parsed_args),
                       filter(k->(k[1] in used_keys), parsed_dicts[parsed_args["_HASH"]]))
                    &
                    (parsed_args["_GIT_INFO"] == parsed_dicts[parsed_args["_HASH"]]["_GIT_INFO"] == git_head))
    end

    reset_tests()
    return all(tests)
end


macro testparse()
    @testset "Parse Tests" begin
        @test parse_test() == true
        @test track_test() == true
        @test track_symbols_test() == true
        @test track_with_git_test() == true
    end
end

end
