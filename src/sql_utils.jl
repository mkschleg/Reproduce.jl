

import MySQL: MySQL, DBInterface
import DBInterface: execute, connect
import DataFrames: DataFrame

const SQLCONNECTIONFILE = joinpath(homedir(), "mysql_connection_info.toml")

struct DBManager
    connection::MySQL.Connection
end

function DBManager(infofile::String = SQLCONNECTIONFILE; database = "")
    connection_info = TOML.parsefile(infofile)
    dbm = DBManager(
        DBInterface.connect(
            MySQL.Connection,
            connection_info["host"],
            connection_info["user"],
            connection_info["password"])
    )
    if database != ""
        create_and_switch_to_database(dbm, database)
    end
    dbm
end

execute(dbm::DBManager, args...) = execute(dbm.connection, args...)

function show_tables(dbm)
    DataFrame(execute(dbm, "SHOW TABLES;"))
end


function database_exists(dbm::DBManager, db_name)
    !isempty(execute(dbm, """SHOW DATABASES like '$(db_name)';"""))
end

function switch_to_database(dbm::DBManager, db_name)
    if !database_exists(dbm, db_name)
        @error "Database doesn't exist yet. Try `create_and_switch_to_database`"
    end
    execute(dbm, """USE $(db_name);""")
end

function create_database(dbm::DBManager, db_name)
    if !database_exists(dbm, db_name)
        execute(dbm, """CREATE DATABASE $(db_name);""")
    end
end

function create_and_switch_to_database(dbm::DBManager, db_name)
    if !database_exists(dbm, db_name)
        execute(dbm, """CREATE DATABASE $(db_name);""")
    end
    execute(dbm, """USE $(db_name);""")
end

function table_exists(dbm::DBManager, tbl_name)
    !isempty(execute(dbm, """SHOW TABLES like '$(tbl_name)';"""))
end

function create_table(dbm::DBManager, tbl_name, names, types)
    # creates table in current db.
    sql = """CREATE TABLE $(tbl_name) ("""
    for (k, dt) in zip(names, types)
        sql *= "$(k) $(dt)" * (k == names[end] ? ");" : ", ")
    end
    execute(dbm, sql)
end

function create_table(dbm::DBManager, tbl_name; kwargs...)
    @assert eltype(typeof(kwargs).parameters[end]) isa DataType
    names, types = get_sql_schemas(kwargs)
    create_table(dbm, tbl_name, names, types)
end

function append_row(dbm::DBManager, tbl_name, names::String, values::String)
    sql = """INSERT INTO $(tbl_name) $(names) VALUES $(values)"""
    execute(dbm, sql)
end

function append_row(dbm::DBManager, tbl_name, names::AbstractVector, values::AbstractVector)
    append_row(dbm, tbl_name, make_names_values_string(names, values)...)
end

function append_row(dbm::DBManager, tbl_name; params...)
    append_row(dbm, tbl_name, make_names_values_string(params)...)
end

function make_names_values_string(names, values)
    names_str = "("
    values_str = "("

    for (ns, vs) in zip(names, values)
        if ns isa Tuple
            for (n, v) in zip(ns, vs)
                names_str *= "$(n)"
                values_str *= v isa String ? "'$(v)'" : "$(v)"

                if n != ns[end]
                    names_str *= ", "
                    values_str *= ", "
                end
            end
        else
            names_str *= "$(ns)"
            values_str *= vs isa String ? "'$(vs)'" : "$(vs)"
        end

        if ns == names[end]
            names_str *= ")"
            values_str *= ")"
        else
            names_str *= ", "
            values_str *= ", "
        end
    end
    names_str, values_str
end

function make_names_values_string(params)
    names, values = get_sql_names_values(params)
    make_names_values_string(names, values)
end


# SQL Database for an experiment
# will be named
# Inside will have table associated with different configs.
### DESCTBL: - Hash -> ConfigFileName
### HASHTBL: Params, results (pointers to sub tables for vector results), finished (Bool)

function get_sql_schemas(params)

    ks = sort(collect(keys(params)))

    names = String[]
    types = String[]
    
    for k in ks
        nm, typ = get_sql_schema(k, params[k])
        if nm isa Tuple
            append!(names, nm)
            append!(types, typ)
        else
            push!(names, nm)
            push!(types, typ)
        end
    end

    names, types
end

function get_sql_names_values(params)
    ks = sort(collect(keys(params)))

    names = String[]
    values = []

    for k in ks
        nm, value = get_sql_name_value(k, params[k])
        if nm isa Tuple
            push!(names, nm...)
            push!(values, value...)
        else
            push!(names, nm)
            push!(values, value)
        end
    end
    names, values
end


"""
    get_sql_schema(name, param)
"""
function get_sql_schema(name, param)
    get_sql_name(name, param), get_sql_type(param)
end

function get_sql_name_value(name, param)
    get_sql_name(name, param), get_sql_value(param)
end



"""
    get_sql_name(name, param)

Returns the name used for a column. 
For a single value (i.e. String, Float, Integer, etc...)
return name
For a Tuple or a Vector
return (name_1, name_2, ..., name_n)
For a NamedTuple
return (name_(prop1), name_(prop2), ...)
where the props are sorted.
"""
get_sql_name(name, param) = string(name)

function get_sql_name(name, param::Union{Tuple, Vector})
    ("$(name)_$(i)" for i in 1:length(param))
end

function get_sql_name(name, param::Union{NamedTuple, AbstractDict})
    ks = sort(collect(keys(param)))
    ("$(name)_$(k)" for k in ks)
end


"""
    get_sql_type(x)

Return the corresponding SQL Type. This is to be used for params.
"""
get_sql_type(x) = get_sql_type(typeof(x))
get_sql_type(x::DataType) = @error "Type $(x) not supported. Please implement Reproduce.get_sql_type"

function get_sql_type(tpl::Union{Tuple, Vector})
    (get_sql_type(x) for x in tpl)
end

function get_sql_type(ntpl::NamedTuple)
    ks = sort(collect(keys(ntpl)))
    (get_sql_type(x) for x in ntpl[ks])
end

function get_sql_type(dict::AbstractDict)
    ks = sort(collect(keys(dict)))
    (get_sql_type(x) for x in dict[ks])
end

get_sql_type(::Type{Float32}) = "FLOAT"
get_sql_type(::Type{Float64}) = "DOUBLE"

get_sql_type(::Type{Int64}) = "BIGINT"
get_sql_type(::Type{UInt64}) = "BIGINT UNSIGNED"

get_sql_type(::Type{Int32}) = "INT"
get_sql_type(::Type{UInt32}) = "INT UNSIGNED"

get_sql_type(::Type{<:AbstractString}) = "VARCHAR(100)"


"""
    get_sql_value(x)

Return the value for the collection. If xi is a named tuple this returns the 
elements in alphabetical order wrt the element names. Otherwise, just return x.
"""
get_sql_value(x) = x
function get_sql_value(X::NamedTuple)
    ks = sort(collect(keys(X)))
    (v for v in X[ks])
end
