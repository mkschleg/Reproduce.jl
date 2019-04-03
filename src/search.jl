

using Glob
using FileIO

export ItemCollection, search, details

struct Item
    folder_str::String
    parsed_args
    hash_keys
end

function Item(settings_file::AbstractString)
    dict = load(settings_file)
    parsed_args = dict["parsed_args"]
    used_keys = dict["used_keys"]
    return Item(settings_file, parsed_args, used_keys)
end

mutable struct ItemCollection
    items::Array{Item,1}
end

function ItemCollection(dir::AbstractString; settings_file="settings.jld2")

    dir_list = readdir(glob"*/"*settings_file, dir)
    items = Array{Item,1}()
    for p in dir_list
        append!(items, [Item(p)])
    end

    return ItemCollection(items)
end

function search(dir::AbstractString, search_dict; settings_file="settings.jld2")

    itemCollection = ItemCollection(dir; settings_file=settings_file)

    dict_keys = keys(search_dict)
    found_items = Array{Item, 1}(undef, length(itemCollection.items))
    hash_codes = Array{UInt64, 1}(undef, length(itemCollection.items))
    save_dirs = Array{String, 1}(undef, length(itemCollection.items))
    for (item_idx, item) in enumerate(itemCollection.items)
        if search_dict == filter(k->((k[1] in dict_keys)), item.parsed_args)
            found_items[item_idx] = item
            hash_codes[item_idx] = item.parsed_args["_HASH"]
            save_dirs[item_idx] = item.parsed_args["_SAVE"]
        end
    end
    return hash_codes, save_dirs, found_items

end

function details(dir::AbstractString; settings_file="settings.jld2")
    itemCollection = ItemCollection(dir; settings_file=settings_file)

    for item in itemCollection.items
        args = ["$(k):$(item.parsed_args[k])" for k in item.hash_keys]
        println(item.parsed_args["_SAVE"], " ", join(args, " "))
    end
end

