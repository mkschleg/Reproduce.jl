# test/runtests.jl
using Reproduce, Test, FileIO


# include("search.jl")
include("args_iter.jl")

function tests()
    
    # SEARCH_TESTS.@testsearch
    ARGSITER_TESTS.@tests
end

tests()
