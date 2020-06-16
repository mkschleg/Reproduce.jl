module SEARCH_TESTS

using Reproduce, Test, Git, FileIO

const TEST_DIR = "TEST_DIR"

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
        arg_type = Int64
        required = true
    end
    parsed = create_info(args, s, TEST_DIR;
                         use_git_info=use_git_info,
                         as_symbols=as_symbols)
    return parsed
end

function setup_tests()
    used_keys = ["a", "b"]
    parsed_dicts = Dict{UInt64, Dict}()
    for i in 1:5
        for j in 1:5
            args=["--a", "$(i)", "--b", "$(j)"]
            parsed = arg_parse(args)
            parsed_dicts[parsed["_HASH"]] = filter(k->(k[1] in used_keys), parsed)
        end
    end
end

function reset_tests()
    working_dir = pwd()
    rm(joinpath(working_dir, TEST_DIR); recursive=true)
end

function item_collection_test()

    ic = ItemCollection(TEST_DIR)
    tests = fill(false, 5, 5)
    for item in ic.items
        tests[item.parsed_args["a"], item.parsed_args["b"]] = true
    end

    return all(tests)
end

function search_test()
    search_dict = Dict("a"=>1)
    ic = search(ItemCollection(TEST_DIR), search_dict)
    tests = fill(false, 1, 5)
    for item in ic
        tests[1, item.parsed_args["b"]] = true
    end
    return all(tests)
end

function diff_test()
    ic = ItemCollection(TEST_DIR)
    diff_dict = diff(ic)
    return diff_dict["a"] == [1,2,3,4,5] && diff_dict["b"] == [1,2,3,4,5]
end

macro testsearch()
    @testset "Search Tests" begin
        setup_tests()
        @test item_collection_test() == true
        @test search_test() == true
        @test diff_test() == true
        reset_tests()
    end
end

end

