module ARGSITER_TEST

using Reproduce, Test, Git, FileIO

args_dict = Dict(
    "a"=>[1,2,3,4],
    "b"=>["1", "2"],
    "c"=>[("1", 103.0), ("2", 2034.0)]
)



function make_args(args::Dict{String, Union{String, Tuple}})
    ["--c1", args["c"][1],
     "--c2", args["c"][2],
     "--a", args["a"],
     "--b", args["b"]]
end

function setup_tests()
end

function reset_tests()
end

function test_func_1()

        answer = [(1, ["--c1", "1", "--c2", "103.0", "--a", "1", "--b", "1"])
                  (2, ["--c1", "1", "--c2", "103.0", "--a", "2", "--b", "1"])
                  (3, ["--c1", "1", "--c2", "103.0", "--a", "3", "--b", "1"])
                  (4, ["--c1", "1", "--c2", "103.0", "--a", "4", "--b", "1"])
                  (5, ["--c1", "1", "--c2", "103.0", "--a", "1", "--b", "2"])
                  (6, ["--c1", "1", "--c2", "103.0", "--a", "2", "--b", "2"])
                  (7, ["--c1", "1", "--c2", "103.0", "--a", "3", "--b", "2"])
                  (8, ["--c1", "1", "--c2", "103.0", "--a", "4", "--b", "2"])
                  (9, ["--c1", "2", "--c2", "2034.0", "--a", "1", "--b", "1"])
                  (10, ["--c1", "2", "--c2", "2034.0", "--a", "2", "--b", "1"])
                  (11, ["--c1", "2", "--c2", "2034.0", "--a", "3", "--b", "1"])
                  (12, ["--c1", "2", "--c2", "2034.0", "--a", "4", "--b", "1"])
                  (13, ["--c1", "2", "--c2", "2034.0", "--a", "1", "--b", "2"])
                  (14, ["--c1", "2", "--c2", "2034.0", "--a", "2", "--b", "2"])
                  (15, ["--c1", "2", "--c2", "2034.0", "--a", "3", "--b", "2"])
                  (16, ["--c1", "2", "--c2", "2034.0", "--a", "4", "--b", "2"])]
    
    arg_iter = ArgIterator(args_dict, []; make_args=make_args)
    return all([answer[arg[1]] == arg for arg in arg_iter])
end


macro test_args_iter()
    @testset "Search Tests" begin
        setup_tests()
        test_func_1()
        reset_tests()
    end
end


end
