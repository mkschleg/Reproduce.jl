
module Reproduce

"""
    _safe_fileop

Not entirely safe, but manages the interaction between whether a folder has already been created before
another process. Kinda important for a multi-process workflow.

Can't really control what the user will do...
"""
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

"""
    _safe_mkdir

`mkdir` guarded by [`_safe_fileop`](@ref).
"""
_safe_mkdir(exp_dir) = 
    _safe_fileop(()->mkdir(exp_dir), ()->!isdir(exp_dir))

"""
    _safe_mkpath

`mkpath` guarded by [`_safe_fileop`](@ref).
"""
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
# export HDF5Manager, BSONManager, JLD2Manager, TOMLManager, save, save!, load
include("save.jl")


include("iterators.jl")

include("comp_envs.jl")


export Experiment,
    create_experiment_dir,
    add_experiment,
    pre_experiment,
    post_experiment
include("experiment.jl")

include("git_utils.jl")

include("parse.jl")

export job
include("parallel.jl")

include("utils/exp_util.jl")

include("macros.jl")

end # module
