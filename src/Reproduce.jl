
module Reproduce

using Config

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
export HDF5Manager, BSONManager, JLD2Manager, save, save!, load

# Adding JLD2 manager:
import JLD2

struct JLD2Manager <: Config.DataManager
    replace
    JLD2Manager(replace=true) = new(replace)
end

Config.extension(manager::JLD2Manager) = ".jld2"

Config.save(manager::JLD2Manager, path::AbstractString, results) = JLD2.@save path results
function Config.save!(manager::JLD2Manager, path::AbstractString, results)
    if manager.replace
        JLD2.@save path results
    else
        @warn "There is data already here, and I was told not to replace. Saving to -> temp.jld2"
        JLD2.@save joinpath(dirname(path), "temp.jld2") results
    end
end


abstract type AbstractArgIter end

export ArgIterator, ArgLooper
include("args_iter.jl")
include("args_looper.jl")

export Experiment, create_experiment_dir, add_experiment, pre_experiment, post_experiment
include("experiment.jl")

export job, config_job
include("parallel.jl")

end # module
