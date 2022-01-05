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

SaveManager(::Val{T}) where T = begin
    @warn """$(T) not supported by SaveManager, implement `SaveManager(::Val{:$(T)})`. Defaulting to jld2."""
    JLD2Manager()
end

SaveManager(::Val{:hdf5}) = HDF5Manager()
SaveManager(::Val{:h5}) = HDF5Manager()
SaveManager(::Val{:jld2}) = JLD2Manager()
SaveManager(::Val{:bson}) = BSONManager()

# ===============
# --- H D F 5 ---
# ===============

struct HDF5Manager <: SaveManager end

extension(::HDF5Manager) = ".h5"

# Saving/Loading data
function _save(::HDF5Manager, path, data, writeMode)
    HDF5.h5open(path, writeMode) do f
      for (k,v) in data
          write(f, k, v)
      end
    end
end

save!(::HDF5Manager, path, data) = _save(data_manager, path, data, "cw")
save(::HDF5Manager, path, data) = _save(data_manager, path, data, "w")

function load(::HDF5Manager, path)
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

extension(::BSONManager) = ".bson"

function save(::BSONManager, path, data)
    BSON.bson(path, data)
end

function save!(::BSONManager, path, data)
    try
        priorData = BSON.load(path)
        newData = merge(data, BSON.load(path))
        BSON.bson(path, newData)
    catch
        BSON.bson(path, data)
    end
end

function load(::BSONManager, path)
    return BSON.load(path)
end

# ===============
# --- J L D 2 ---
# ===============

struct JLD2Manager <: SaveManager end

extension(::JLD2Manager) = ".jld2"

save(::JLD2Manager, path, results) = JLD2.@save path results # JLD2.@save 
# function save!(::JLD2Manager, path, data)
#     try
#         priorData = load(manager, path)
#         merge!(priorData, data)
#         save(manager, path, priorData)
#     catch
#         save(manager, path, data)
#     end
# end

load(::JLD2Manager, path) = FileIO.load(path)

# ===============
# --- T O M L ---
# ===============

struct TOMLManager <: SaveManager end

extension(::TOMLManager) = ".toml"

function save(::TOMLManager, path, data)
    open(path) do io
        TOML.print(io, data)
    end
end

load(::TOMLManager, path) = TOML.parsefile(path)

