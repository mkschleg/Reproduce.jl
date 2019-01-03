

using Glob
using JLD2

export ItemCollection, search, details

struct Item
    folder_str::String
    parsed_args
    hash_keys
end

function Item(settings_file::AbstractString)
    @load settings_file parsed_args used_keys
    return Item(settings_file, parsed_args, used_keys)
end

mutable struct ItemCollection
    items::Array{Item,1}
end

function ItemCollection(dir::AbstractString)

    dir_list = readdir(glob"*/settings.jld", dir)
    items = Array{Item,1}()
    for p in dir_list
        append!(items, [Item(p)])
    end

    return ItemCollection(items)
end

function search(dir::AbstractString, search_dict)

    itemCollection = ItemCollection(dir)

    dict_keys = keys(search_dict)
    found_items = Item[]
    hash_codes = UInt64[]
    save_dirs = String[]
    for item in itemCollection.items
        if search_dict == filter(k->((k[1] in dict_keys)), item.parsed_args)
            push!(found_items, item)
            push!(hash_codes, item.parsed_args["_HASH"])
            push!(save_dirs, item.parsed_args["_SAVE"])
        end
    end
    return hash_codes, save_dirs, found_items

end

function details(dir::AbstractString)
    itemCollection = ItemCollection(dir)

    for item in itemCollection.items
        args = ["$(k):$(item.parsed_args[k])" for k in item.hash_keys]
        println(item.parsed_args["_SAVE"], " ", join(args, " "))
    end
end

