
# actual in job utilities

function reproduce_config_experiment(config_file::AbstractString; tldr="", save_path="")
    experiment = Experiment(config_file, save_path)
    create_experiment_dir(experiment; tldr=tldr)
    add_experiment(experiment)
    ret = job(experiment)
    post_experiment(experiment, ret)
end

# Save setup for the old file system.
function save_setup(parsed;
                    save_dir_key="save_dir",
                    def_save_file="results.jld2",
                    filter_keys=["verbose",
                                 "working",
                                 "exp_loc",
                                 "visualize",
                                 "progress",
                                 "synopsis"])
    savefile = def_save_file
    Reproduce.create_info!(parsed,
                           parsed[save_dir_key];
                           filter_keys=filter_keys)
    savepath = Reproduce.get_save_dir(parsed)
    joinpath(savepath, def_save_file)
end

function save_results(savefile, results)
    JLD2.@save savefile results
end

function check_save_file_loadable(savefile)
    try
        JLD2.@load savefile results
    catch
        return false
    end
    return true
end

function experiment_wrapper(exp_func::Function, parsed, working; overwrite=false)
    savefile = save_setup(parsed)
    if isfile(savefile) && check_save_file_loadable(savefile) && !overwrite
        return
    end

    ret = exp_func(parsed)

    if working
        ret
    elseif ret isa NamedTuple
        save_results(savefile, ret.save_results)
    else
        save_results(savefile, ret)
    end
end
