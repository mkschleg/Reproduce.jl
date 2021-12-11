#!/home/mkschleg/opt/bin/julia
#SBATCH -o test_err.out # Standard output
#SBATCH -e test_out.err # Standard error
#SBATCH --mem-per-cpu=1000M # Memory request of 1 GB
#SBATCH --time=01:00:00 # Running time of 10 minutes
#SBATCH --ntasks=10
#SBATCH --cpus-per-task
#SBATCH --account=def-whitem

using Pkg
Pkg.activate(".")

using Reproduce

const save_loc = "test_exp_loop"
const exp_file = "examples/experiment.jl"
const exp_module_name = :Main
const exp_func_name = :main_experiment

function test_experiment()

    arg_list = [
    ["--opt1", "47"]]

    static_args = ["--steps", "102902"]

    args_iterator = ArgLooper(arg_list, static_args, 5:8, "--opt2")


    experiment = Experiment(save_loc,
                            exp_file,
                            exp_module_name,
                            exp_func_name,
                            args_iterator)

    create_experiment_dir(experiment)
    add_experiment(experiment; settings_dir="settings")
    ret = job(experiment; num_workers=6, extra_args=[save_loc])
    post_experiment(experiment, ret)

end

test_experiment()
