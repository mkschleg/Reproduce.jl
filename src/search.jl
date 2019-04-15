

using Glob
using FileIO, JLD2

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
    settings_dict = FileIO(settings_file)
    dict = settings_dict
    if "settings_dict" ∈ keys(settings_dict)
        dict = settings_dict["settings_dict"]
    end
    parsed_args = dict["parsed_args"]
    used_keys = dict["used_keys"]
    return Item(settings_file, parsed_args, used_keys)
end

"""
    ItemCollection
A collection of items. Mostly helpful, but not really used yet.
"""
mutable struct ItemCollection
    items::Array{Item,1}
end

function ItemCollection(dir::AbstractString; settings_file="settings.jld2")
    dir_list = glob(joinpath(dir, "*", settings_file))
    items = Array{Item,1}()
    for p in dir_list
        append!(items, [Item(p)])
    end

    return ItemCollection(items)
end

"""
    search

Search for specific entries, or a number of entries.
"""
function search(dir::AbstractString, search_dict; settings_file="settings.jld2")

    itemCollection = ItemCollection(dir; settings_file=settings_file)

    dict_keys = keys(search_dict)
    found_items = Array{Item, 1}()
    hash_codes = Array{UInt64, 1}()
    save_dirs = Array{String, 1}()
    for (item_idx, item) in enumerate(itemCollection.items)
        if search_dict == filter(k->((k[1] in dict_keys)), item.parsed_args)
            push!(found_items, item)
            push!(hash_codes, item.parsed_args["_HASH"])
            push!(save_dirs, item.parsed_args["_SAVE"])
        end
    end
    return hash_codes, save_dirs, found_items

end

"""
    details

get details of the pointed directory
"""
function details(dir::AbstractString; settings_file="settings.jld2")
    itemCollection = ItemCollection(dir; settings_file=settings_file)

    for item in itemCollection.items
        args = ["$(k):$(item.parsed_args[k])" for k in item.hash_keys]
        println(item.parsed_args["_SAVE"], " ", join(args, " "))
    end
end

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
function diff(items::Array{Reproduce.Item, 1};
              exclude_keys::Union{Array{String,1}, Array{Symbol,1}} = Array{String, 1}(),
              exclude_parse_values::Bool=true)
    kt = keytype(items[1].parsed_args)
    exclude_keys = kt.(exclude_keys)
    if exclude_parse_values == true
        exclude_keys = [exclude_keys; kt.([HASH_KEY, SAVE_NAME_KEY, GIT_INFO_KEY])]
    end
    diff_parsed = Dict{kt, Array}()
    for item in items
        tmp_dict = items[1] - item
        for key in filter((k)->k ∉ exclude_keys, keys(tmp_dict))
            if key ∉ keys(diff_parsed)
                diff_parsed[key] = Array{typeof(items[1].parsed_args[key]), 1}()
            end
            if tmp_dict[key][1] ∉ diff_parsed[key]
                push!(diff_parsed[key], tmp_dict[key][1])
            end
            if tmp_dict[key][2] ∉ diff_parsed[key]
                push!(diff_parsed[key], tmp_dict[key][2])
            end
        end
    end
    for key in keys(diff_parsed)
        sort!(diff_parsed[key])
    end
    return diff_parsed
end





