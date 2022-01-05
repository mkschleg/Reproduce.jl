#!/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Core/julia/1.6.2/bin/julia
#SBATCH --mail-user=mkschleg@ualberta.ca
#SBATCH --mail-type=ALL
#SBATCH -o test_sql.out # Standard output
#SBATCH -e test_sql.err # Standard error
#SBATCH --ntasks=8
#SBATCH --mem-per-cpu=2000M # Memory request of 2 GB
#SBATCH --time=0:10:00 # Running time of 24 hours
#SBATCH --account=def-whitem

using Pkg
Pkg.activate(".")

using Reproduce

const CONFIGFILE = "examples/configs/arg_iter_config_sql_slurm.toml"
const DETAILSPATH = "/home/mkschleg/scratch/reproduce"

function main()

    
    experiment = Reproduce.parse_experiment_from_config(CONFIGFILE, DETAILSPATH)

    pre_experiment(experiment)
    ret = job(experiment)
    post_experiment(experiment, ret)

end

main()
