
module ExpModule

# const RESULTS_DICT = Dict()
using Reproduce

function main_experiment(parsed::Dict, extra_arg = nothing)

    j = 0
    if parsed["opt1"] == 2
        throw("Oh No!!!")
    end

    dbm = Reproduce.DBManager(parsed["database"])
    Reproduce.save_experiment(dbm, parsed, parsed)


    return j
end

end
