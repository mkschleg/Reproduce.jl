# test/runtests.jl
using Reproduce, Test, FileIO

include("parse.jl")
include("search.jl")
include("args_iter.jl")

function tests()
    
    PARSE_TESTS.@testparse
    SEARCH_TESTS.@testsearch
    ARGSITER_TESTS.@tests
end

tests()
