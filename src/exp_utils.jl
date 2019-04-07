using Dates
using CodeTracking


function create_experiment_dir(exp_dir::String;
                               org_file=true, replace=false)

    if isdir(exp_dir)
        if !replace
            @info "directory already created - told to not replace..."
            return
        else
            @info "directory already created - told to replace..."
            rm(joinpath(exp_dir, "notes.org"))
        end
    else
        @info "creating experiment directory"
        mkdir(exp_dir)
    end

    f = open(joinpath(exp_dir, "notes.org"), "w")
    write(f, "#+title: Experimental Notes for $(exp_dir)\n\n\n")
    close(f)

    return
end

function get_settings_file(args_iterator::ArgIterator)
    ai_str = string(args_iterator)
    return "settings_0x"*string(hash(ai_str), base=16)*".jld2"
end


function add_experiment(exp_dir::AbstractString,
                        experiment_file::AbstractString,
                        exp_module_name::AbstractString,
                        exp_func_name::AbstractString,
                        args_iter::ArgIterator;
                        settings_dir="", add_all_tasks=false)

    if "SLURM_ARRAY_TASK_ID" in keys(ENV)
        if parse(Int64, ENV["SLURM_ARRAY_TASK_ID"]) != 1 || !add_all_tasks
            @info "Told to not add all experiments..."
            return
        end
    end

    @info "Adding Experiment to $(exp_dir)"

    settings_dir = joinpath(exp_dir, settings_dir)

    if settings_dir != "" && !isdir(settings_dir)
        mkdir(settings_dir)
    end

    settings_file = joinpath(settings_dir, get_settings_file(args_iter))

    date_str = Dates.format(now(), dateformat"<yyyy-mm-dd e HH:MM:SS>")
    tab = "\t"

    make_args_str = "nothing"
    if args_iter.make_args != nothing
        m = CodeTracking.@which args_iter.make_args(Dict{String, String}())
        make_args_str, line1 = definition(String, m)
    end


    open(joinpath(exp_dir, "notes.org"), "a") do f
        exp_str = "* " * date_str * "\n\n" *
            tab*"experiment file: $(experiment_file)\n" *
            tab*"experiment module: $(string(exp_module_name))\n" *
            tab*"experiment function: $(string(exp_func_name))\n\n" *
            tab*"settings file: $(settings_dir)\n\n" *
            tab*"#+BEGIN_SRC julia\n" *
            tab*"dict = $(args_iter.dict)\n" *
            tab*"arg_list = $(args_iter.arg_list)\n" *
            tab*"stable_arg = $(args_iter.stable_arg)\n\n" *
            tab*"#Make Arguments" *
            tab*make_args_str *
            tab*"#+END_SRC"
        write(f, exp_str)
    end

    @save settings_file args_iter make_args_str

end

