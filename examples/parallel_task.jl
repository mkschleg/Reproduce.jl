#!/cvmfs/soft.computecanada.ca/easybuild/software/2017/avx2/Compiler/gcc7.3/julia/1.3.0/bin/julia
#SBATCH --array=1-200
#SBATCH --mail-user=mkschleg@ualberta.ca
#SBATCH --mail-type=ALL
#SBATCH -o reproduce_test.%A_%a.out # Standard output
#SBATCH -e reproduce_test.%A_%a.err # Standard error
#SBATCH --mem-per-cpu=512M # Memory request of 2 GB
#SBATCH --time=0:01:00 # Running time of 12 hours
#SBATCH --account=rrg-whitem

using Pkg
Pkg.activate(".")

using Reproduce
const config_file = "./examples/arg_iter_config.toml"

function test_experiment()

    as = ArgParseSettings()
    @add_arg_table as begin
        "task_id"
        arg_type=Int
    end
    parsed = parse_args(as)
    
    experiment = Experiment(config_file)
    create_experiment_dir(experiment; tldr="hello tldr")
    ret = job(experiment, parsed["task_id"])
end

test_experiment()
