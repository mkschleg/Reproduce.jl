
module TestExperiment

import Reproduce:
    Reproduce,
    experiment_wrapper,
    @generate_config_funcs,
    @generate_working_function,
    @param_from



@generate_config_funcs begin
    info"""
    This is an example use of the `@generate_config_funcs`. This macro helps you generate documentation for your configs and generates a bunch of useful functions for generating simple config files and associated documentation for said functions.

    - `opt1::Int`: The first argument. Experiment errors on `opt1 == 2`
    - `opt2::Int`: The second argument.
    - `opt2::String`: The Third argument. This is required to be a string
    - `opt4::Int`: The fourth argument.
    """
    opt1 => 1
    opt2 => 2
    opt3 => "hello"
    opt4 => 4
end

@generate_working_function

function main_experiment(config::Dict, extra_arg = nothing; progress=false, testing=false)

    Reproduce.experiment_wrapper(config; use_git_info=true) do config
        j = 0

        @param_from opt1 config
        @param_from opt2 config
        @param_from opt3::String config
        @param_from opt4 config

        if opt1 == 2
            throw("Oh No!!!")
        end

        Dict("mean"=>0.1,
             "vec"=>rand(100),
             "mat"=>rand(10, 10),
             "vec_vec"=>[rand(10) for _ in 1:10],
             "3darr"=>reshape(collect(1:27), 3, 3, 3),
        )
    end
end

end
