#!/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Core/julia/1.5.2/bin/julia
#SBATCH --mail-user=mkschleg@ualberta.ca
#SBATCH --mail-type=ALL
#SBATCH -o reproduce_test.out # Standard output
#SBATCH -e reproduce_test.err # Standard error
#SBATCH --mem-per-cpu=2000M # Memory request of 2 GB
#SBATCH --time=0:05:00 # Running time of 12 hours
#SBATCH --ntasks=4
#SBATCH --account=rrg-whitem

using Pkg
Pkg.activate(".")

using Reproduce
const config_file = "examples/arg_iter_config.toml"

function test_experiment()

    experiment = Experiment(config_file)

    pre_experiment(experiment; tldr="hello tldr")
    ret = job(experiment; num_workers=6)
    post_experiment(experiment, ret)

end

test_experiment()
