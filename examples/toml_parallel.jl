#!/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Core/julia/1.8.5/bin/julia
#SBATCH --mail-user=mkschleg@ualberta.ca
#SBATCH --mail-type=ALL
#SBATCH -o job_out/%x_%a.out # Standard output
#SBATCH -e job_out/%x_%a.err # Standard error
#SBATCH --account=def-whitem


using Pkg
Pkg.activate(".")

using Reproduce
using ArgParse

function main()

    as = ArgParseSettings()
    @add_arg_table as begin
        "config"
        arg_type=String
        "--path"
        arg_type=String
        default="results"
        "--numworkers"
        arg_type=Int
        default=4
        "--threads_per_worker"
        arg_type=Int
        default=1
        "--numjobs"
        action=:store_true
    end
    parsed = parse_args(as)
    
    experiment = Reproduce.parse_experiment_from_config(parsed["config"], parsed["path"]; num_workers=parsed["numworkers"], num_threads_per_worker=parsed["threads_per_worker"])

    pre_experiment(experiment)
    ret = job(experiment)
    post_experiment(experiment, ret)

end

main()
