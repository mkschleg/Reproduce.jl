# Running a parallel job


I include an example file for running parallel jobs locally and in a SLURM environment. There are several paths this experiment can be used, all with automatic checkpointing so jobs can be resumed.

There are four main functions that you need to be aware of for running parallel jobs from a config file:
[`parse_experiment_from_config`](@ref), [`pre_experiment`](@ref), [`job`](@ref), [`post_experiment`](@ref).

## Parsing the experiment

Using the config specification and argument specifications found through the parse docs, you use [`parse_experiment_from_config`](@ref) to parse your config and point Reproduce to where the base directory will be located. On HPC clusters this will usually be a scratch directory. This will be the home directory for the directory listed in the config file, not the root directory of all the job files.

There are some kwargs which are optional. One is `comp_env` which should only be set if you have a particular need and know what you are doing. Otherwise `comp_env` will be automatically set by [`get_comp_env`](@ref).


## pre_experiment

This function does all the setup, and needs to be done on the bash script node. There could be overlap if not.

## job

This runs the job using the comp_env decided on when parsing the experiment (see above).

## post_experiment

This is meant to do cleanup, but doesn't do anything right now.




