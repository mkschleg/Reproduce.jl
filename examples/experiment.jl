
using Reproduce

function main_experiment(parsed::Dict, extra_arg = nothing)

    Reproduce.experiment_wrapper(parsed; use_git_info=true) do parsed

        j = 0
        if parsed["opt1"] == 2
            throw("Oh No!!!")
        end

        parsed
        
    end

end
