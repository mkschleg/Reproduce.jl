
module Reproduce



export create_info!, create_info, create_custom_info!, create_custom_info
include("parse.jl")

export ItemCollection, search, details
include("search.jl")

export ArgIterator
include("args_iter.jl")

export Experiment, create_experiment_dir, add_experiment, post_experiment
include("exp_utils.jl")

export job
include("parallel_experiment.jl")
# greeting() = println("Hello World!")



end # module
