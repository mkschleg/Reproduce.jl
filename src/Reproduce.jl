
module Reproduce

import Git

function git_head()
    s = read(`$(Git.git()) rev-parse HEAD`, String)
    s[1:end-1]
end

function git_branch()
    s = read(`$(Git.git()) rev-parse --symbolic-full-name --abbrev-ref HEAD`, String)
    s[1:end-1]
end


export
    create_info!,
    create_info,
    create_custom_info!,
    create_custom_info,
    get_save_dir,
    get_hash,
    get_git_info

include("parse.jl")

export ItemCollection, search, details
include("search.jl")

# Saving utils in Config.jl are really nice. Just reusing and pirating a new type until I figure out what FileIO can and can't do.
export HDF5Manager, BSONManager, JLD2Manager, TOMLManager, save, save!, load
include("data_manager.jl")

abstract type AbstractArgIter end

export ArgIterator, ArgLooper
include("args_iter.jl")
include("args_looper.jl")

export Experiment, create_experiment_dir, add_experiment, pre_experiment, post_experiment
include("experiment.jl")

export job
include("parallel.jl")

end # module
