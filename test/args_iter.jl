module ARGSITER_TESTS

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

function test_args_iter()

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
    
    arg_iter = ArgIterator(args_dict, String[]; make_args=make_args)
    return all([answer[arg[1]] == arg for arg in arg_iter])
end

function test_args_loop()

    answer = [(1, ["--c1", "1", "--seed", "2", "--s1", "hello"]),
              (2, ["--c1", "1", "--seed", "3", "--s1", "hello"]),
              (3, ["--c1", "1", "--seed", "4", "--s1", "hello"]),
              (4, ["--c1", "1", "--seed", "5", "--s1", "hello"]),
              (5, ["--c1", "1", "--seed", "6", "--s1", "hello"]),
              (6, ["--c1", "2", "--seed", "2", "--s1", "hello"]),
              (7, ["--c1", "2", "--seed", "3", "--s1", "hello"]),
              (8, ["--c1", "2", "--seed", "4", "--s1", "hello"]),
              (9, ["--c1", "2", "--seed", "5", "--s1", "hello"]),
              (10, ["--c1", "2", "--seed", "6", "--s1", "hello"])]

    arg_loop = ArgLooper([["--c1", "1"], ["--c1", "2"]], ["--s1", "hello"], 2:6, "--seed")
    return all([answer[arg[1]] == arg for arg in arg_loop])
end

function test_args_loop_dict()

    answer = [(1, Dict(["c1"=>1, "seed"=> 2, "s1"=>"hello"])),
              (2, Dict(["c1"=>1, "seed"=> 3, "s1"=>"hello"])),
              (3, Dict(["c1"=>1, "seed"=> 4, "s1"=>"hello"])),
              (4, Dict(["c1"=>1, "seed"=> 5, "s1"=>"hello"])),
              (5, Dict(["c1"=>1, "seed"=> 6, "s1"=>"hello"])),
              (6, Dict(["c1"=>2, "seed"=> 2, "s1"=>"hello"])),
              (7, Dict(["c1"=>2, "seed"=> 3, "s1"=>"hello"])),
              (8, Dict(["c1"=>2, "seed"=> 4, "s1"=>"hello"])),
              (9, Dict(["c1"=>2, "seed"=> 5, "s1"=>"hello"])),
              (10, Dict(["c1"=>2, "seed"=> 6, "s1"=>"hello"]))]

    arg_loop = ArgLooper([Dict(["c1"=>1]), Dict(["c1"=>2])], Dict(["s1"=>"hello"]), 2:6, "seed")
    return all([answer[arg[1]] == arg for arg in arg_loop])
end





macro tests()
    @testset "ArgIterator Tests" begin
        setup_tests()
        @test test_args_iter() == true
        @test test_args_loop() == true
        @test test_args_loop_dict() == true
        reset_tests()
    end
end


end
