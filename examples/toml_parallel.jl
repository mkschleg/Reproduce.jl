using Pkg
Pkg.activate(".")

using Reproduce

function main()

    as = ArgParseSettings()
    @add_arg_table as begin
        "config"
        arg_type=String
        "--numworkers"
        arg_type=Int
        default=4
        "--numjobs"
        action=:store_true
    end
    parsed = parse_args(as)
    
    experiment = Reproduce.parse_experiment_from_config(parsed["config"]) #Experiment(config_file)

    pre_experiment(experiment)
    ret = job(experiment; num_workers=parsed["numworkers"])
    post_experiment(experiment, ret)

end

main()
