module ARGSITER_TESTS

using Reproduce, Test, FileIO

const ARGS_DICT = Dict(
    "a"=>[1,2,3,4],
    "b"=>["1", "2"],
    "c1+c2"=>[("1", 103.0), ("2", 2034.0)]
)

function setup_tests()
end

function reset_tests()
end

function test_args_iter()

        answer = [(1,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>1, "b"=>"1"]))
                  (2,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>2, "b"=>"1"]))
                  (3,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>3, "b"=>"1"]))
                  (4,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>4, "b"=>"1"]))
                  (5,  Dict(["c1"=>"2", "c2"=>2034.0, "a"=>1, "b"=>"1"]))
                  (6, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>2, "b"=>"1"]))
                  (7, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>3, "b"=>"1"]))
                  (8, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>4, "b"=>"1"]))
                  (9,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>1, "b"=>"2"]))
                  (10,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>2, "b"=>"2"]))
                  (11,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>3, "b"=>"2"]))
                  (12,  Dict(["c1"=>"1", "c2"=>103.0,  "a"=>4, "b"=>"2"]))
                  (13, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>1, "b"=>"2"]))
                  (14, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>2, "b"=>"2"]))
                  (15, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>3, "b"=>"2"]))
                  (16, Dict(["c1"=>"2", "c2"=>2034.0, "a"=>4, "b"=>"2"]))]
    
    arg_iter = ArgIterator(ARGS_DICT)
    return all([answer[arg[1]] == arg for arg in arg_iter])
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

    arg_loop = ArgLooper([Dict(["c1"=>1]), Dict(["c1"=>2])], Dict(["s1"=>"hello"]), "seed", 2:6)
    return all([answer[arg[1]] == arg for arg in arg_loop])
end





macro tests()
    @testset "ArgIterator Tests" begin
        setup_tests()
        @test test_args_iter() == true
        @test test_args_loop_dict() == true
        reset_tests()
    end
end


end
