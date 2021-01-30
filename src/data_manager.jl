"""
Data managers for saving and loading data. Stolen from [Config.jl](https://github.com/ajjacobs/Config.jl)

"""

import FileIO
import HDF5, BSON, JLD2
import Pkg.TOML

"""
    DataManger

Abstract type for various filetype managers.
"""
abstract type SaveManager end

# get manager filetype extension
extension(data_manager::SaveManager) = extension(typeof(data_manager))

# save data, overwriting existing
save(data_manager::SaveManager, path, data) = save(typeof(data_manager), path, data)

# save data, adding to existing
save!(data_manager::SaveManager, path, data) = save!(typeof(data_manager), path, data)

# load data
load(data_manager::SaveManager, path) = load(typeof(data_manager), path)
# load(data_manager::SaveManager, path::String) = raise(DomainError("loand() not defined!"))



# ===============
# --- H D F 5 ---
# ===============

struct HDF5Manager <: SaveManager end

extension(data_manager::Type{HDF5Manager}) = ".h5"

# Saving/Loading data
function _save(data_manager::Type{HDF5Manager}, path, data, writeMode)
    HDF5.h5open(path, writeMode) do f
      for (k,v) in data
          write(f, k, v)
      end
    end
end

save!(data_manager::Type{HDF5Manager}, path, data) = _save(data_manager, path, data, "cw")
save(data_manager::Type{HDF5Manager}, path, data) = _save(data_manager, path, data, "w")

function load(data_manager::Type{HDF5Manager}, path)
    data = Dict()
    HDF5.h5open(path) do f
        keys = names(f)
        for k in keys
            data[k] = read(f[k])
        end
    end
    return data
end

# ===============
# --- B S O N ---
# ===============

struct BSONManager <: SaveManager end

extension(data_manager::Type{BSONManager}) = ".bson"

function save(data_manager::Type{BSONManager}, path, data)
    BSON.bson(path, data)
end

function save!(data_manager::Type{BSONManager}, path, data)
    try
        priorData = BSON.load(path)
        newData = merge(data, BSON.load(path))
        BSON.bson(path, newData)
    catch
        BSON.bson(path, data)
    end
end

function load(data_manager::Type{BSONManager}, path)
    return BSON.load(path)
end

# ===============
# --- J L D 2 ---
# ===============

struct JLD2Manager <: SaveManager end

extension(manager::Type{JLD2Manager}) = ".jld2"

save(manager::Type{JLD2Manager}, path, data) = FileIO.save(path, data) # JLD2.@save 
function save!(manager::Type{JLD2Manager}, path, data)
    try
        priorData = load(manager, path)
        merge!(priorData, data)
        save(manager, path, priorData)
    catch
        save(manager, path, data)
    end
end

load(manager::Type{JLD2Manager}, path) = FileIO.load(path)

# ===============
# --- T O M L ---
# ===============

struct TOMLManager <: SaveManager end

extension(manager::Type{TOMLManager}) = ".toml"

function save(manager::Type{TOMLManager}, path, data)
    open(path) do io
        TOML.print(io, data)
    end
end

load(manager::Type{TOMLManager}, path) = TOML.parsefile(path)

