
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


function check_experiment_done(save_type::SQLSave, save_setup_ret)

    # hash
    exp_hash = save_setup_ret.exp_hash
    dbm = save_setup_ret.dbmanager

    !isempty(select_row_where(dbm, get_results_table_name(), HASH_KEY, exp_hash))
    
end

function check_save_file_loadable(save_mgr, savefile)
    try
        load(save_mgr, savefile)
    catch
        return false
    end
    return true
end

function experiment_wrapper(exp_func::Function, parsed; filter_keys=String[], use_git_info=true, working=false)

    save_setup_ret = save_setup(parsed; filter_keys=filter_keys, use_git_info=use_git_info)
    if check_experiment_done(parsed, save_setup_ret)
        return
    end

    ret = exp_func(parsed)

    if working
        ret
    elseif ret isa NamedTuple
        save_results(parsed[SAVE_KEY], save_setup_ret, ret.save_results)
    else
        save_results(parsed[SAVE_KEY], save_setup_ret, ret)
    end
    
end





