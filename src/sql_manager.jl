

### Requires the functions from sql_utils.jl

get_param_table_name() = "params"
get_results_table_name() = "results"
get_results_subtable_name(key) = "results_$(key)"



get_hash_type() = "BIGINT UNSIGNED UNIQUE"


function setup_experiment_tables(dbm::DBManager, params, results)
    create_param_table(dbm, params)
    create_results_tables(dbm, results)
end


"""
    create_param_table(dbm::DBManager, example_params)

Create the parameter table for an experiment.

"""
function create_param_table(dbm::DBManager, params)
    tbl_name = get_param_table_name()
    names, types = get_param_schema(params)
    create_table(dbm, tbl_name, names, types)
end

function get_param_schema(params)

    names, types = get_sql_schemas(params)

    if HASH_KEY ∉ names
        push!(names, HASH_KEY)
        push!(types, get_hash_type())
    end
    if GIT_INFO_KEY ∉ names
        push!(names, GIT_INFO_KEY)
        push!(types, "VARCHAR(50)")
    end
    names, types
end


"""
    create_results_table(dbm::DBManager, results)

Create the tables to store the results.
"""
function create_results_tables(dbm::DBManager, results)
    
    tbl_name = get_results_table_name()
    if table_exists(dbm, tbl_name)
        return
    end

    # sql_dtypes = Pair{Symbol, DataType}[]
    names = String[]
    types = String[]

    # add Hash
    push!(names, HASH_KEY)
    push!(types, get_hash_type())
    
    for k in keys(results)
        if results[k] isa AbstractVector
            # Do crazy things...
            push!(names, string(k))
            push!(types, "BOOLEAN NOT NULL DEFAULT 0")

            # create table
            create_results_subtable(dbm, k, eltype(results[k]))

        elseif results[k] isa DataType && results[k] <: AbstractVector

            push!(names, string(k))
            push!(types, "BOOLEAN NOT NULL DEFAULT 0")
            
            create_results_subtable(dbm, k, results[k].parameters[1])
            
        else # add to types

            nms, dtys = get_sql_schema(string(k), results[k])
            append!(names, nms isa String ? [nms] : nms)
            append!(types, dtys isa String ? [dtys] : dtys)
            
        end
    end

    create_table(dbm, tbl_name, names, types)
end

function create_results_subtable(dbm::DBManager, key, elt)

    tbl_name = get_results_subtable_name(key)
    if table_exists(dbm, tbl_name)
        return
    end
    
    create_vector_table(dbm, tbl_name, elt)

end

function create_vector_table(dbm::DBManager, tbl_name, data_elt::DataType)

    # creates table in current db.
    sql = """CREATE TABLE $(tbl_name) (_HASH BIGINT UNSIGNED, data $(get_sql_type(data_elt)), step INT UNSIGNED, INDEX (_HASH));"""
    
    try
        close!(execute(dbm, sql))
    catch err
        if !(err isa MySQL.API.Error && err.errno == 1050)
            throw(err)
        else
            sleep(1)
        end
    end

end

function save_experiment(dbm::DBManager, params, results; filter_keys=String[], use_git_info=true)

    pms_hash = save_params(dbm, params; filter_keys=filter_keys, use_git_info=use_git_info)
    save_results(dbm, pms_hash, results)

end

function save_params(dbm::DBManager, params; filter_keys = String[], use_git_info = true) # returns hash

    p_names, p_values = get_sql_names_values(params)
    
    
    # hash key
    pms_hash = hash_params(params; filter_keys=filter_keys)
    push!(p_names, HASH_KEY)
    push!(p_values, "$(pms_hash)")

    # git_info
    # git_info = use_git_info ? git_head() : "0"
    git_info = git_head()
    push!(p_names, GIT_INFO_KEY)
    push!(p_values, git_info)

    # check if params exist before saving
    # connect!(save_type)
    if table_exists(dbm, get_param_table_name()) && isempty(select_row_where(dbm, get_param_table_name(), HASH_KEY, pms_hash))
        append_row(dbm, get_param_table_name(), p_names, p_values)
    end # else this parameter setting already exists, and should be left alone.

    pms_hash
end

function save_results(dbm::DBManager, pms_hash, results)

    names = "($(HASH_KEY), "
    values = "($(pms_hash), "

    ks = collect(keys(results))
    for k in ks
        if results[k] isa AbstractVector

            # save to sub table
            save_sub_results(dbm, pms_hash, k, results[k])
            
            names *= "$(k)"
            values *= "true"

        else # add to types

            ns, vs = get_sql_name_value(k, results[k])

            if ns isa Tuple
                for (n, v) in zip(ns, vs)
                    names *= "$(n)"
                    values *= v isa String ? "'$(v)'" : "$(v)"

                    if n != ns[end]
                        names *= ", "
                        values *= ", "
                    end
                end
            else
                names *= "$(ns)"
                values *= vs isa String ? "'$(vs)'" : "$(vs)"
            end
        end

        if k == ks[end]
            names *= ")"
            values *= ")"
        else
            names *= ", "
            values *= ", "
        end
    end

    append_row(dbm, get_results_table_name(), names, values)
    
end


function save_sub_results(dbm::DBManager, pms_hash, key, results)

    tbl_name = get_results_subtable_name(key)
    for (idx, v) in enumerate(results)
        names = "(" * HASH_KEY * ", " * "step, data)"
        values = "($(pms_hash), $(idx), $(v))"
        append_row(dbm, tbl_name, names, values)
    end
    
end
