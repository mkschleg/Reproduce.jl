


using Pkg
Pkg.activate(".")

using Reproduce
const config_file = "examples/arg_looper_config.toml"

function test_experiment()

    experiment = Reproduce.parse_experiment_from_config(config_file, "results")

    pre_experiment(experiment; tldr="hello tldr")
    ret = job(experiment; num_workers=6)
    post_experiment(experiment, ret)

end

test_experiment()
