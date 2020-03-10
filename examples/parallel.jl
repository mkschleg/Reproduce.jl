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

const save_loc = "test_exp"
const exp_file = "examples/experiment.jl"
const exp_module_name = :Main
const exp_func_name = :main_experiment

# What arguments get swept over.
arg_dict = Dict(
    "opt1"=>1:50,
    "opt2"=>[5,6,7,8]
)
# The order of the arguments in the sweep (optional)
arg_order = ["opt2", "opt1"]

static_args = Dict("steps" => 102902)

args_iterator = ArgIterator(arg_dict,
                            static_args;
                            arg_order=arg_order)

# Don't name anything in global scope `experiment`!!!
exp = Experiment(save_loc,
                 exp_file,
                 exp_module_name,
                 exp_func_name,
                 args_iterator)

pre_experiment(exp; tldr="Hello tldr")
ret = job(exp; num_workers=6, extra_args=[1])
post_experiment(exp, ret)

