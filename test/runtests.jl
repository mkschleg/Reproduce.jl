# test/runtests.jl
using Reproduce, Test, FileIO, Git

include("parse.jl")
include("search.jl")
include("args_iter.jl")

function tests()

    PARSE_TESTS.@testparse
    SEARCH_TESTS.@testsearch

end

tests()
