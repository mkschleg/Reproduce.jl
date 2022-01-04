
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

function _safe_fileop(f::Function, check::Function)
    if check()
        try
            f()
        catch ex
            if isa(ex, SystemError) && ex.errnum == 17
                sleep(0.1) # Other Process Made folder. Waiting...
            else
                throw(ex)
            end
        end
    end
end

_safe_mkdir(exp_dir) = 
    _safe_fileop(()->mkdir(exp_dir), ()->!isdir(exp_dir))

_safe_mkpath(exp_dir) = 
    _safe_fileop(()->mkpath(exp_dir), ()->!isdir(exp_dir))


export
    create_info!,
    create_info,
    create_custom_info!,
    create_custom_info,
    get_save_dir,
    get_hash,
    get_git_info

include("param_info.jl")

export ItemCollection, search, details
include("search.jl")

# Saving utils in Config.jl are really nice. Just reusing and pirating a new type until I figure out what FileIO can and can't do.
export HDF5Manager, BSONManager, JLD2Manager, TOMLManager, save, save!, load
include("data_manager.jl")


# SQL Management...
include("sql_utils.jl")
include("sql_manager.jl")

include("save.jl")

abstract type AbstractArgIter end



export ArgIterator, ArgLooper
include("args_iter.jl")
include("args_looper.jl")


export Experiment, create_experiment_dir, add_experiment, pre_experiment, post_experiment
include("experiment.jl")

include("parse.jl")

export job
include("job.jl")


include("exp_util.jl")

end # module
