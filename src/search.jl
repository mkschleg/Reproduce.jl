

# using Glob
import FileIO
using JLD2

using DataFrame

function ic_to_df(ic::Reproduce.ItemCollection; filter=["_GIT_INFO", "_SAVE", "save_dir"])
    dlist = [merge(item.parsed_args, Dict("folder_str"=>item.folder_str)) for item in ic]
    doa = Dict()
    for k in keys(dlist[1])
	if filter isa Nothing || !(k in filter)
	    doa[k] = [datum[k] for datum in dlist]
	end
    end
    DataFrame(doa)
end

function files_to_ic_to_df(files::Vector{String}; kwargs...)
    ic_arr = [ItemCollection(at(file)) for file in files]
    ic_to_df(ItemCollection(vcat(getfield.(ic_arr, :items)...)); kwargs...)
end


function load_settings_file(settings_file)
    dict = FileIO.load(settings_file)
    if "settings_dict" ∈ keys(dict)
        dict = dict["settings_dict"]
    end
    parsed_args = dict["parsed_args"]
    used_keys = dict["used_keys"]
    (parsed_args=parsed_args[used_keys], folder_str=basename(dirname(settings_file)))
end


function settings_dataframe(folders::Vector{<:AbstractString}; kwargs...)
    dfs = [build_dataframe(folder; kwargs...) for folder in folders]
    for i in 2:length(dfs)
	append!(dfs[1], dfs[i])
    end
    dfs[1]
end

function settings_dataframe(folder::AbstractString; 
			 filter=nothing, 
			 force=false, 
			 settings_file="settings.jld2")
    
    dir = splitpath(folder)[end] == "data" ? folder : joinpath(folder, "data")
    dir_list = readdir(dir)

    cache_loc = joinpath(dir, "data_frame.jld2")
    id = hash(string(dir_list))
    if isfile(cache_loc)
        data = FileIO.load(cache_loc)
        if id == data["id"] && !force
            return data["data"]
        end
    end

    # df = DataFrame()
    doa = Dict()
    item = load_settings_file(joinpath(dir, dir_list[1], settings_file))
    dlist = merge(item.parsed_args, Dict("folder_str"=>item.folder_str))
    
    for (k,v) in dlist
        if isnothing(filter) || k ∉ filter
            doa[k] = [v]
        end
    end
    
    for p in dir_list
	if basename(p) ∈ ["item_col.jld2", "data_frame.jld2"]
	    continue
	end
        item = load_settings_file(joinpath(dir, p, settings_file))
        dlist = merge(item.parsed_args, Dict("folder_str"=>item.folder_str))
        for k in keys(doa)
           push!(doa[k], dlist[k])
        end
    end

    df = DataFrame(doa)
    FileIO.save(cache_loc, "data", df, "id", id)
    
    return df
end




export ItemCollection, search, details

"""
    Item
An Item in the experiment. Contains the parsed arguments.
"""
struct Item
    folder_str::String
    parsed_args::Dict
    hash_keys
end

function Item(settings_file::AbstractString)
    dict = FileIO.load(settings_file)
    if "settings_dict" ∈ keys(dict)
        dict = dict["settings_dict"]
    end
    parsed_args = dict["parsed_args"]
    used_keys = dict["used_keys"]
    return Item(dirname(settings_file), parsed_args, used_keys)
end

"""
    ItemCollection
A collection of items. Mostly helpful, but not really used yet.
"""
struct ItemCollection
    items::Array{Item,1}
    dir_hash::UInt64
end

ItemCollection(items::Array{Item, 1}) = ItemCollection(items, 0x0)

@deprecate ItemCollection(::AbstractString) settings_dataframe(::AbstractString)

function ItemCollection(dir::AbstractString; settings_file="settings.jld2", data_folder="data")

    dir = splitpath(dir)[end] == data_folder ? dir : joinpath(dir, data_folder)
    dir_list = readdir(dir)

    d = joinpath(dir, "item_col.jld2")
    id = hash(string(dir_list))
    if isfile(d)
        ic = FileIO.load(d)["ic"]
        if ic.dir_hash == id
            return ic
        end
    end
    
    items = Array{Item,1}()
    for p in dir_list
        if isfile(joinpath(dir, p, settings_file))
            push!(items, Item(joinpath(dir, p, settings_file)))
        end
    end


    ic = ItemCollection(items, id)
    FileIO.save(d, "ic", ic)
    
    return ic
end

Base.show(io::IO, ic::ItemCollection) =
    print(io, "ItemCollection(Size: ", length(ic), ", Dir Hash: ", ic.dir_hash, ")")

# Iterator
Base.eltype(::Type{ItemCollection}) = Item
Base.length(ic::ItemCollection) = length(ic.items)
Base.getindex(ic::ItemCollection, idx) = ic.items[idx]
Base.firstindex(ic::ItemCollection, idx) = firstindex(ic.items)
Base.lastindex(ic::ItemCollection, idx) = lastindex(ic.items)

Base.iterate(ic::ItemCollection, state=1) = state > length(ic) ? nothing : (ic[state], state + 1)


"""
    search

Search for specific entries, or a number of entries.
"""
function search(itemCollection::ItemCollection, search_dict)

    dict_keys = keys(search_dict)
    found_items = Array{Item, 1}()
    for (item_idx, item) in enumerate(itemCollection.items)
        if search_dict == filter(k->((k[1] in dict_keys)), item.parsed_args)
            push!(found_items, item)
        end
    end
    return ItemCollection(found_items)

end

function search(f::Function, ic::ItemCollection)
    found_items = Vector{Reproduce.Item}()
    for (item_idx, item) in enumerate(ic.items)
        if f(item)
            push!(found_items, item)
        end
    end
    return ItemCollection(found_items)
end

"""
    details

get details of the pointed directory
"""
function details(itemCollection::ItemCollection)
    # itemCollection = ItemCollection(dir; settings_file=settings_file)

    for item in itemCollection.items
        args = ["$(k):$(item.parsed_args[k])" for k in item.hash_keys]
        println(item.parsed_args["_SAVE"], " ", join(args, " "))
    end
end

details(dir::AbstractString; settings_file="settings.jld2") =
    details(ItemCollection(dir; settings_file=settings_file))

import Base.-
"""
    -(l::Dict{K,T}, r::Dict{K,T}) where {K, T}

Get the difference between two dictionaries. Helper function for diff
"""
function -(l::Dict{K, V}, r::Dict{K, V}) where {K, V}
    ret = Dict{K, V}()
    for key in keys(l)
        if l[key] != r[key]
            ret[key] = (l[key], r[key])
        end
    end
    return ret
end

-(l::Item, r::Item) = l.parsed_args - r.parsed_args

"""
    diff

get difference of the list of items.
"""
function Base.diff(items::Array{Item, 1};
                   exclude_keys::Union{Array{String,1}, Array{Symbol,1}} = Array{String, 1}(),
                   exclude_parse_values::Bool=true)

    kt = keytype(items[1].parsed_args)
    exclude_keys = kt.(exclude_keys)
    if exclude_parse_values == true
        exclude_keys = [exclude_keys; kt.([Reproduce.HASH_KEY, Reproduce.SAVE_NAME_KEY, Reproduce.GIT_INFO_KEY])]
    end
    diff_parsed = Dict{kt, Array}()
    for item in items
        tmp_dict = items[1] - item
        for key in filter((k)->k ∉ exclude_keys, keys(tmp_dict))
            if key ∉ keys(diff_parsed)
		diff_parsed[key] = Array{Any, 1}()
            end
			
            if tmp_dict[key][1] ∉ diff_parsed[key]
                push!(diff_parsed[key], tmp_dict[key][1])
				new_type = typeof(tmp_dict[key])
            end
            if tmp_dict[key][2] ∉ diff_parsed[key]
                push!(diff_parsed[key], tmp_dict[key][2])
            end
        end
    end
    for key in keys(diff_parsed)
	diff_parsed[key] = collect(promote(diff_parsed[key]...))
        sort!(diff_parsed[key])
    end
    return diff_parsed
end

Base.diff(itemCollection::ItemCollection; kwargs...) =
    Base.diff(itemCollection.items; kwargs...)


