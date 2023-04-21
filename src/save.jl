


get_param_ignore_keys() = [SAVE_KEY, "save_dir"]


function save_setup(args::Dict; kwargs...)

    if args[SAVE_KEY] isa String
        # assume file save
        @warn """Using key "$(SAVE_KEY)" as a string in args is deprecated. Use new SaveTypes instead.""" maxlog=1
        save_dir = args[SAVE_KEY]
        args[SAVE_KEY] = FileSave(save_dir, JLD2Manager())
        save_setup(args[SAVE_KEY], args; kwargs...)
    else
        save_setup(args[SAVE_KEY], args; kwargs...)
    end
    
end

struct NoSave end
save_setup(::NoSave, args...; kwargs...) = nothing
save_results(::NoSave, args...; kwargs...) = nothing

include("save/file_save.jl")
include("save/sql_save.jl")
