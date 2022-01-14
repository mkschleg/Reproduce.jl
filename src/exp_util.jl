
# actual in job utilities

function parallel_from_config(config_file::AbstractString; save_path="")
    experiment = Experiment(config_file, save_path)

    pre_experiment(experiment)
    ret = job(experiment)
    post_experiment(experiment, ret)
end

# Save setup for the old file system.

check_experiment_done(parsed, save_setup_ret) = check_experiment_done(parsed[SAVE_KEY], save_setup_ret)


check_experiment_done(save_type::FileSave, savefile) = 
    isfile(savefile) && check_save_file_loadable(save_type.manager, savefile)


function check_experiment_done(save_type::SQLSave, exp_hash)

    # hash
    exp_hash
    connect!(save_type)
    if table_exists(save_type.dbm, get_results_table_name())
        !isempty(select_row_where(save_type.dbm, get_results_table_name(), HASH_KEY, exp_hash))
    else
        false
    end
    
end

function check_save_file_loadable(save_mgr, savefile)
    try
        load(save_mgr, savefile)
    catch
        return false
    end
    return true
end

post_save_setup(sqlsave::SQLSave) = close!(sqlsave)
post_save_setup(args...) = nothing
post_save_setup(::Nothing) = nothing

post_save_results(sqlsave::SQLSave) = close!(sqlsave)
post_save_results(args...) = nothing
post_save_results(::Nothing) = nothing

function experiment_wrapper(exp_func::Function, parsed; filter_keys=String[], use_git_info=true, hash_exclude_save_dir=true)

    save_setup_ret = if SAVE_KEY ∉ keys(parsed)
        if isinteractive()
            @warn "No arg at \"$(SAVE_KEY)\". Assume testing in repl." maxlog=1
            parsed[SAVE_KEY] = nothing
        else
            @error "No arg found at $(SAVE_KEY). Please use savetypes here."
        end
        nothing
    else
        save_setup_ret = save_setup(parsed;
                                    filter_keys=filter_keys,
                                    use_git_info=use_git_info,
                                    hash_exclude_save_dir=hash_exclude_save_dir)
        
        if check_experiment_done(parsed, save_setup_ret)
            post_save_setup(parsed[SAVE_KEY])
            return
        end
        save_setup_ret
    end

    post_save_setup(parsed[SAVE_KEY])

    ret = exp_func(parsed)

    if ret isa NamedTuple
        save_results(parsed[SAVE_KEY], save_setup_ret, ret.save_results)
    else
        save_results(parsed[SAVE_KEY], save_setup_ret, ret)
    end
    
    post_save_results(parsed[SAVE_KEY])
    
    if isinteractive()
        ret
    end
end





