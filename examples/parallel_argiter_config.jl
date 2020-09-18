#!/cvmfs/soft.computecanada.ca/easybuild/software/2017/avx2/Compiler/gcc7.3/julia/1.3.0/bin/julia
#SBATCH --mail-user=mkschleg@ualberta.ca
#SBATCH --mail-type=ALL
#SBATCH -o reproduce_test.out # Standard output
#SBATCH -e reproduce_test.err # Standard error
#SBATCH --mem-per-cpu=512M # Memory request of 2 GB
#SBATCH --time=0:10:00 # Running time of 12 hours
#SBATCH --ntasks=8
#SBATCH --account=rrg-whitem

using Pkg
Pkg.activate(".")

using Reproduce
const config_file = "./examples/arg_iter_config.toml"

function test_experiment()

    experiment = Experiment(config_file)

    pre_experiment(experiment; tldr="hello tldr")
    ret = job(experiment; num_workers=6)
    post_experiment(experiment, ret)

end

test_experiment()
