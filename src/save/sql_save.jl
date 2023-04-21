
include("sql_utils.jl")
include("sql_manager.jl")

mutable struct SQLSave
    database::String
    connection_file::String
    dbm::Union{DBManager, Nothing}
end # for sql saving

SQLSave(database, connection_file=SQLCONNECTIONFILE) = SQLSave(database, connection_file, nothing)

get_database_name(sql_save::SQLSave) = sql_save.database

function connect!(sqlsave::SQLSave)
    if isnothing(sqlsave.dbm) || !Base.isopen(sqlsave.dbm)
        while true
            try
                sqlsave.dbm = DBManager(sqlsave.connection_file; database=sqlsave.database)
                break
            catch err
                if err isa MySQL.API.Error && err.errno == 1007
                    sleep(1)
                end
            end
        end
    end
end

function DBInterface.close!(sqlsave::SQLSave)
    close(sqlsave.dbm)
    sqlsave.dbm = nothing
end

function save_setup(save_type::SQLSave, args;
                    filter_keys=String[],
                    use_git_info=true,
                    hash_exclude_save_dir=true)

    connect!(save_type)

    filter_keys = if hash_exclude_save_dir
        [filter_keys; get_param_ignore_keys()] # add SAVE_KEY to filter keys automatically.
    else
        @warn "hash_exclude_save_dir=false is deprecated due to hash consistency issues." maxlog=1
        [filter_keys; [SAVE_KEY]] # add SAVE_KEY to filter keys automatically.
    end
    
    schema_args = filter(k->(!(k[1] in get_param_ignore_keys())), args)
    exp_hash = save_params(save_type.dbm,
                           schema_args;
                           filter_keys=get_param_ignore_keys(),
                           use_git_info=use_git_info)

    # close!(save_type)
    
    exp_hash
end

function save_results(sqlsave::SQLSave, exp_hash, results)
    connect!(sqlsave)
    if !table_exists(sqlsave.dbm, get_results_table_name())
        create_results_tables(sqlsave.dbm, results)
    end
    ret = save_results(sqlsave.dbm, exp_hash, results)
    # close!(save_type)
    ret
end
