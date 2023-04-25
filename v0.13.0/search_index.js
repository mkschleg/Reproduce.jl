var documenterSearchIndex = {"docs":
[{"location":"manual/parallel/#Running-a-parallel-job","page":"Parallel Jobs","title":"Running a parallel job","text":"","category":"section"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"I include an example file for running parallel jobs locally and in a SLURM environment. There are several paths this experiment can be used, all with automatic checkpointing so jobs can be resumed.","category":"page"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"There are four main functions that you need to be aware of for running parallel jobs from a config file: Reproduce.parse_experiment_from_config, Reproduce.pre_experiment, Reproduce.job, Reproduce.post_experiment.","category":"page"},{"location":"manual/parallel/#Parsing-the-experiment","page":"Parallel Jobs","title":"Parsing the experiment","text":"","category":"section"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"Using the config specification and argument specifications found through the parse docs, you use Reproduce.parse_experiment_from_config to parse your config and point Reproduce to where the base directory will be located. On HPC clusters this will usually be a scratch directory. This will be the home directory for the directory listed in the config file, not the root directory of all the job files.","category":"page"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"There are some kwargs which are optional. One is comp_env which should only be set if you have a particular need and know what you are doing. Otherwise comp_env will be automatically set by Reproduce.get_comp_env.","category":"page"},{"location":"manual/parallel/#pre_experiment","page":"Parallel Jobs","title":"pre_experiment","text":"","category":"section"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"This function does all the setup, and needs to be done on the bash script node. There could be overlap if not.","category":"page"},{"location":"manual/parallel/#job","page":"Parallel Jobs","title":"job","text":"","category":"section"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"This runs the job using the comp_env decided on when parsing the experiment (see above).","category":"page"},{"location":"manual/parallel/#post_experiment","page":"Parallel Jobs","title":"post_experiment","text":"","category":"section"},{"location":"manual/parallel/","page":"Parallel Jobs","title":"Parallel Jobs","text":"This is meant to do cleanup, but doesn't do anything right now.","category":"page"},{"location":"docs/iterators/#Iterators","page":"Iterators","title":"Iterators","text":"","category":"section"},{"location":"docs/iterators/","page":"Iterators","title":"Iterators","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/iterators/","page":"Iterators","title":"Iterators","text":"Modules = [Reproduce]\nPages   = [\"iterators.jl\", \n           \"iterators/args_iter.jl\", \n           \"iterators/args_iter_v2.jl\", \n           \"iterators/args_looper.jl\"]","category":"page"},{"location":"docs/iterators/#Reproduce.ArgIteratorV2","page":"Iterators","title":"Reproduce.ArgIteratorV2","text":"ArgIteratorV2\n\nThis is the second version of the Argument Iterator. The old version is kept for posterity, and to ensure compatibility of old config files. To use this iterator use: arg_iter_type=\"iterV2 in the config portion of your configuration file when using parse_experiment_from_config. This iterator does a product over all the arguments found in the sweep_args nested section. For example:\n\n[config]\n...\narg_iter_type=\"iterV2\"\n\n[static_args]\nnetwork_sizes = [10, 30, 100]\nlog_freq = 100_000\narg_1 = 1\narg_2 = 1\n\n[sweep_args]\nseed = [1,2,3,4,5]\neta = \"0.15.^(-10:2:0)\"\nnetwork_sizes.2 = [10, 30, 50, 70]\narg_1+arg_2 = [[1,1], [2,2], [3,3]]\n\n\nproduces a set of 360 argument settings. The seed parameter is straight forward, where the iterator iterates over the list. eta's string will be parsed by the julia interpreter. This is dangerous and means arbitrary code can be run, so be careful! network_size.2 goes through and sets the second element of the networksizes array to be in the list. Finally `arg1+arg2` sweeps over both arg1 and arg_2 simultaneously (i.e. doesn't do a product over these).\n\nSweep args special characters:\n\n\"+\": This symbol sweeps over a vector of vectors and sets the arguments according to the values of the inner vectors in the order specified.\n\".\": This symbol is an \"access\" symbol and accesses nested structures in the set of arguments.\n\"*\": This symbol is similar to \"+\" but instead sets all the keys to be the top level value in the sweep vector.\n\n\n\n\n\n","category":"type"},{"location":"docs/experiment/#Experiment.jl","page":"Experiment","title":"Experiment.jl","text":"","category":"section"},{"location":"docs/experiment/","page":"Experiment","title":"Experiment","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/experiment/","page":"Experiment","title":"Experiment","text":"Modules = [Reproduce]\nPages   = [\"experiment.jl\"]","category":"page"},{"location":"docs/experiment/#Reproduce.Experiment","page":"Experiment","title":"Reproduce.Experiment","text":"Experiment\n\nThe structure used to embody a reproduce experiment. This is usually constructed through the parse_experiment_from_config, but can be used without config files.\n\ndir: the base directory of the experiment (where the info files are saved).\nfile: The file containing the experiment function described by func_name and module_name\nmodule_name: Module name containing the experiment function.\nfunc_name: Function name of the experiment.\nsave_type: The save structure to deal with saving data passed by the experiment.\nargs_iter: The args iterator which contains the configs to pass to the experiment.\n[confg]: The config file parsed to create the experiment (optional)\n\nkwarg\n\n[comp_env]: The computational environment used by the experiment.\n\n\n\n\n\n","category":"type"},{"location":"docs/experiment/#Reproduce.experiment_dir_setup-Tuple{Experiment}","page":"Experiment","title":"Reproduce.experiment_dir_setup","text":"experiment_dir_setup\n\nSets up all the needed directories to run a parallel experiment.\n\n\n\n\n\n","category":"method"},{"location":"docs/experiment/#Reproduce.experiment_save_init-Tuple{Reproduce.FileSave, Any}","page":"Experiment","title":"Reproduce.experiment_save_init","text":"experiment_save_init(save::FileSave, exp::Experiment; kwargs...)\nexperiment_save_init(save::SQLSave, exp::Experiment; kwargs...)\n\nSetups the necessary compoenents to save data for the jobs. This is run by pre_experiment. The FileSave creates the data directory where all the data is stored for an experiment. The SQLSave ensures the databases and tables are created necessary to successfully run an experiment.\n\n\n\n\n\n","category":"method"},{"location":"docs/experiment/#Reproduce.post_experiment-Tuple{Experiment, Any}","page":"Experiment","title":"Reproduce.post_experiment","text":"post_experiment\n\nThis doesn't do anything.\n\n\n\n\n\n","category":"method"},{"location":"docs/experiment/#Reproduce.pre_experiment-Tuple{Experiment}","page":"Experiment","title":"Reproduce.pre_experiment","text":"pre_experiment(exp::Experiment; kwargs...)\npre_experiment(file_save::FileSave, exp; kwargs...)\npre_experiment(sql_save::SQLSave, exp; kwargs...)\n\nThis function does all the setup required to successfully run an experiment. It is dispatched on the save structure in the experiment.\n\nThis function:\n\nCreates the base experiment directory.\nRuns experiment_save_init to initialize the details for each save type.\nruns experiment_dir_setup\n\n\n\n\n\n","category":"method"},{"location":"docs/save/#Save","page":"Save","title":"Save","text":"","category":"section"},{"location":"docs/save/","page":"Save","title":"Save","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/save/","page":"Save","title":"Save","text":"Modules = [Reproduce]\nPages   = [\"save.jl\", \n           \"save/data_manager.jl\",\n           \"save/file_save.jl\",\n           \"save/sql_manager.jl\",\n           \"save/sql_save.jl\",\n           \"save/sql_utils.jl\"]\n","category":"page"},{"location":"docs/save/#Reproduce.SaveManager","page":"Save","title":"Reproduce.SaveManager","text":"DataManger\n\nAbstract type for various filetype managers.\n\n\n\n\n\n","category":"type"},{"location":"docs/save/#Reproduce.create_param_table-Tuple{Reproduce.DBManager, Any}","page":"Save","title":"Reproduce.create_param_table","text":"create_param_table(dbm::DBManager, example_params)\n\nCreate the parameter table for an experiment.\n\n\n\n\n\n","category":"method"},{"location":"docs/save/#Reproduce.create_results_tables-Tuple{Reproduce.DBManager, Any}","page":"Save","title":"Reproduce.create_results_tables","text":"create_results_table(dbm::DBManager, results)\n\nCreate the tables to store the results.\n\n\n\n\n\n","category":"method"},{"location":"docs/save/#Reproduce.get_sql_name-Tuple{Any, Any}","page":"Save","title":"Reproduce.get_sql_name","text":"get_sql_name(name, param)\n\nReturns the name used for a column.  For a single value (i.e. String, Float, Integer, etc...) return name For a Tuple or a Vector return (name1, name2, ..., namen) For a NamedTuple return (name(prop1), name_(prop2), ...) where the props are sorted.\n\n\n\n\n\n","category":"method"},{"location":"docs/save/#Reproduce.get_sql_schema-Tuple{Any, Any}","page":"Save","title":"Reproduce.get_sql_schema","text":"get_sql_schema(name, param)\n\n\n\n\n\n","category":"method"},{"location":"docs/save/#Reproduce.get_sql_type-Tuple{Any}","page":"Save","title":"Reproduce.get_sql_type","text":"get_sql_type(x)\n\nReturn the corresponding SQL Type. This is to be used for params.\n\n\n\n\n\n","category":"method"},{"location":"docs/save/#Reproduce.get_sql_value-Tuple{Any}","page":"Save","title":"Reproduce.get_sql_value","text":"get_sql_value(x)\n\nReturn the value for the collection. If xi is a named tuple this returns the  elements in alphabetical order wrt the element names. Otherwise, just return x.\n\n\n\n\n\n","category":"method"},{"location":"docs/exp_utils/#Experiment-Utilities","page":"Experiment Utilities","title":"Experiment Utilities","text":"","category":"section"},{"location":"docs/exp_utils/","page":"Experiment Utilities","title":"Experiment Utilities","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/exp_utils/","page":"Experiment Utilities","title":"Experiment Utilities","text":"Modules = [Reproduce]\nPages   = [\"utils/exp_util.jl\", \"macros.jl\"]","category":"page"},{"location":"docs/exp_utils/#Reproduce.@generate_config_funcs-Tuple{Any}","page":"Experiment Utilities","title":"Reproduce.@generate_config_funcs","text":"@generate_config_funcs default_config\n\nGenerate a documented function default_config() which returns a default configuration Dict for an experiment. The default configuration Dict is built using the default_config argument, which should have the following form:\n\n.\n.\n.\ninfo\"\"\"\nDOCUMENTATION\n\"\"\"\nDICTIONARY ELEMENTS\n.\n.\n.\n\nWhere 'DOCUMENTATION' is a documentation for each element included in DICTIONARY ELEMENTS. 'DICTIONARY ELEMENTS' is a newline separated list of key => value pairs to be included in the default configuration dictionary. See the Examples section for more detail.\n\nExamples\n\njulia> @generate_config_funcs begin\n    info\"\"\"\n    Experiment details.\n    --------------------\n    - `seed::Int`: seed of RNG\n    - `steps::Int`: Number of steps taken in the experiment\n    \"\"\"\n    seed => 1\n    steps => 200000\n\n    info\"\"\"\n    Agent details\n    -------------\n    - `latent_size::Int`: The size of the hidden layers in the RNN.\n    \"\"\"\n    latent_size => 64\n\n    info\"\"\"\n    ### Optimizer details\n    Flux optimizers are used. See flux documentation.\n    - Parameters defined by the optimizer.\n    \"\"\"\n    eta => 0.001\n\n    info\"\"\"\n    ### Learning update and replay details including:\n    - Replay:\n        - `replay_size::Int`: How many transitions are stored in the replay.\n        - `warm_up::Int`: How many steps for warm-up (i.e. before learning begins).\n    \"\"\"\n    replay_size => 10000\n    warm_up => 1000\n\n    info\"\"\"\n    - Update details:\n        - `lupdate::String`: Learning update name\n        - `gamma::Float`: the discount for learning update.\n        - `batch_size::Int`: size of batch\n        - `truncation::Int`: Length of sequences used for training.\n        - `update_wait::Int`: Time between updates (counted in agent interactions)\n        - `target_update_wait::Int`: Time between target network updates (counted in agent interactions)\n        - `hs_strategy::String`: Strategy for dealing w/ hidden state in buffer.\n    \"\"\"\n    update => \"QLearningMSE\"\n    gamma => 1.0\n    batch_size=>32\n    hist => 1\n    epsilon => 0.1\n    update_freq => 1\n    target_update_wait => 100\nend\n\njulia> default_config()\nDict{String, Any} with 13 entries:\n  \"steps\"              => 200000\n  \"warm_up\"            => 1000\n  \"batch_size\"         => 32\n  \"replay_size\"        => 10000\n  \"eta\"                => 0.001\n  \"hist\"               => 1\n  \"target_update_wait\" => 100\n  \"latent_size\"        => 64\n  \"update\"             => \"QLearningMSE\"\n  \"update_freq\"        => 1\n  \"epsilon\"            => 0.1\n  \"gamma\"              => 1.0\n  \"seed\"               => 1\n\n\n\n\n\n","category":"macro"},{"location":"docs/exp_utils/#Reproduce.@generate_working_function-Tuple{}","page":"Experiment Utilities","title":"Reproduce.@generate_working_function","text":"@generate_working_function\n\nGenerate a documented function working_experiment() which wraps the main experiment function (main_experiment()) of a module and sets the arguments progress=true and testing=true, and uses the default experiment configuration (see @generate_config_funcs).\n\n\n\n\n\n","category":"macro"},{"location":"docs/exp_utils/#Reproduce.@param_from-Tuple{Any, Any}","page":"Experiment Utilities","title":"Reproduce.@param_from","text":"@param_from param config_dict\n\nSet the value of variable param to config_dict[string(param)]. There is also the capability to assign a type (or abstract type) you expect to recieve from the config for the key.\n\nExamples\n\njulia> d = Dict(\n           \"key1\" => 1,\n           \"key2\" => 2\n       )\nDict{String, Int64} with 2 entries:\n  \"key2\" => 2\n  \"key1\" => 1\n\njulia> @param_from key1 d\n1\n\njulia> @param_from key2::Int d\n2\n\njulia> println(key1, \" \", key2)\n1 2\n\njulia> println(key1 + key2)\n3\n\n\n\n\n\n","category":"macro"},{"location":"docs/parse/#parse.jl","page":"Parser","title":"parse.jl","text":"","category":"section"},{"location":"docs/parse/","page":"Parser","title":"Parser","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/parse/","page":"Parser","title":"Parser","text":"Modules = [Reproduce]\nPages   = [\"parse.jl\"]","category":"page"},{"location":"docs/parse/#Reproduce.get_arg_iter-Tuple{Any}","page":"Parser","title":"Reproduce.get_arg_iter","text":"get_arg_iter(cdict)\nget_arg_iter(::Val{T}, cdict) where T\n\ngetargiter parses cdict to get the correct argument iterator. \"argitertype\" needs to have a string value in the cdict (where the cdict is the config dict, often from a config file). Reproduce has two iterators:\n\nT=:iter: ArgIterator which does a grid search over arguments\nT=:looper: ArgLooper which loops over a vector of dictionaries which can be loaded from an arg_file.\nT=:iterV2: ArgIteratorV2 which is the second version of the original ArgIterator, and currently recommended.\n\nTo implement a custom argiter you must implement `Reproduce.getargiter(::Val{:symbol}, cdict)` where :symbol is the value argiter_type will take.\n\n\n\n\n\n","category":"method"},{"location":"docs/parse/#Reproduce.get_arg_iter-Tuple{Val{:iterV2}, Any}","page":"Parser","title":"Reproduce.get_arg_iter","text":"get_arg_iter(::Val{:iterV2}, dict)\n\nThis is the function which parses ArgIteratorV2 from a config file dictionary. It expects the following nested dictionaries:\n\nconfig: This has all the various components to help detail the expeirment (see parse_experiment_from_config for more details.)\narg_list_order::Vector{String}: inside the config dict is the order on which to do your sweeps. For example, if seed is first, the scheduler will make sure to run all the seeds for a particular setting before moving to the next set of parameters.\nsweep_args: These are all the arguments that the args iter will sweep over (doing a cross product to produce all the parameters). See ArgIteratorV2 for supported features.\nstatic_args: This is an optional component which contains all the arguments which are static. If not included, all elements in the top level of the dictionary will be assumed to be static args (excluding config and sweep_args).\n\n\n\n\n\n","category":"method"},{"location":"docs/parse/#Reproduce.get_save_backend-Tuple{Any}","page":"Parser","title":"Reproduce.get_save_backend","text":"get_save_backend(cdict)\n\nGet the save_backend.\n\n\n\n\n\n","category":"method"},{"location":"docs/parse/#Reproduce.parse_experiment_from_config","page":"Parser","title":"Reproduce.parse_experiment_from_config","text":"parse_experiment_from_config\n\nThis function creates an experiment from a config file. \n\nargs\n\nconfig_path::String the path to the config.\n[save_path::String] a save path which dictates where the base savedir for the job will be (prepend dict[\"config\"][\"save_dir\"]).\n\nkwargs\n\ncomp_env a computational environment which dispatchers when job is called.\n\nThe config file needs to be formated in a certain way. I use toml examples below:\n\n[config]\nsave_dir=\"location/to/save\" # will be prepended by save_path\nexp_file=\"file/containing/experiment.jl\" # The file containing your experiment function\nexp_module_name = \"ExperimentModule\" # The module of your experiment in the experiment file\nexp_func_name = \"main_experiment\" # The function to call in the experiment module.\narg_iter_type = \"iterV2\"\n\n# These are specific to what arg_iter_type you are using \n[static_args]\n...\n[sweep_args]\n...\n\n\n\n\n\n","category":"function"},{"location":"docs/parallel/#parallel.jl","page":"Parallel","title":"parallel.jl","text":"","category":"section"},{"location":"docs/parallel/","page":"Parallel","title":"Parallel","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/parallel/","page":"Parallel","title":"Parallel","text":"Modules = [Reproduce]\nPages   = [\"parallel.jl\", \"comp_envs.jl\", \"parallel/parallel_job.jl\"]","category":"page"},{"location":"docs/parallel/#Reproduce.job-Tuple{Experiment}","page":"Parallel","title":"Reproduce.job","text":"job(experiment::Experiment; kwargs...)\njob(experiment_file, exp_dir, args_iter; kwargs...)\njob(experiment::Experiment, job_id; kwargs...)\njob(experiment_file, exp_dir, args_iter, job_id; kwargs...)\n\nRun a job specified by the experiment.\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#Reproduce.save_exception-NTuple{5, Any}","page":"Parallel","title":"Reproduce.save_exception","text":"save_exception\n\nThis function saves an exception file with args:\n\nconfig The job config that failed.\nexc_file the file where the job should be saved.\njob_id the id of the job being run (typically the idx of the job in the iterator).\nexception the exception thrown by the job.\ntrace the stack trace of the raised exception.\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#Reproduce.get_comp_env-Tuple{}","page":"Parallel","title":"Reproduce.get_comp_env","text":"get_comp_env\n\nThis derives the computational environment from the ENV variables. If in a slurm job the get_slurm_comp_env is used, if not get_local_comp_env is used.\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#Reproduce.get_local_comp_env-Tuple{}","page":"Parallel","title":"Reproduce.get_local_comp_env","text":"get_local_comp_env\n\nThis checks to see if RP_TASK_ID is set in the environment. If so, a Task Job with ID=parse(Int, \"RP_TASK_ID\") will be returned. Otherwise, LocalParallel will be used. The kwargs (num_workers and threads_per_worker) give the job defaults for the number of parallel jobs and the number of threads per task. You can also use the ENV variables \"RPNTASKS\" and \"RPCPUSPERTASK\" to override these. The ENV variables will take precedence.\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#Reproduce.get_slurm_comp_env-Tuple{}","page":"Parallel","title":"Reproduce.get_slurm_comp_env","text":"get_slurm_comp_env\n\nThis is significantly more complex than a local environment to enable using slurm task arrays efficiently.\n\nIn a job scheduled as:\n\nsbatch -J test_rep_argiter --ntasks 4 --cpus-per-task 1 --mem-per-cpu=2000M --time=0:10:00 toml_parallel.jl configs/arg_iter_config.toml --path /home/mkschleg/scratch/reproduce\n\nThen the comp_env will return a SlurmParallel env which uses srun to create julia instances.\n\nFor\n\nsbatch -J test_rep_argiter -N 1 --ntasks 1 --cpus-per-task 4 --mem-per-cpu=2000M --time=0:10:00 toml_parallel.jl configs/arg_iter_config.toml --path /home/mkschleg/scratch/reproduce\n\nThe comp env will be a local parallel job using just default julia parallel utilities. It is necessary to make sure all resources are on single node if using this.\n\nFor\n\nsbatch -J test_rep_argiter --array=1-4 --ntasks 4 --cpus-per-task 1 --mem-per-cpu=2000M --time=0:05:00 toml_parallel.jl configs/arg_iter_config.toml --path /home/mkschleg/scratch/reproduce\n\nThe comp env will be a SlurmTaskArray which will choose either LocalParallel, or SlurmParallel following the above protocol.\n\nNotes:\n\nIf no SLURM_CPUS_PER_TASK is set then we assume a single cpu per task.\nIf you are re-running only parts of an array task you need to use \"RPCUSTOMARRAYTASKCOUNT\" to let Reproduce know what the original task array looked like to schedule the jobs correctly.\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#Reproduce.parallel_job_inner-NTuple{6, Any}","page":"Parallel","title":"Reproduce.parallel_job_inner","text":"parallel_job_inner\n\nRun a parallel job over the arguments presented by argsiter. `argsiter` can be a enumeration OR ArgIterator. Each job will be dedicated to a specific task. The experiment must save its own data! As this is not handled by this function (although could be added in the future.)\n\n\n\n\n\n","category":"method"},{"location":"docs/search/#Search","page":"Search","title":"Search","text":"","category":"section"},{"location":"docs/search/","page":"Search","title":"Search","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/search/","page":"Search","title":"Search","text":"Modules = [Reproduce]\nPages   = [\"search.jl\"]","category":"page"},{"location":"docs/search/#Reproduce.Item","page":"Search","title":"Reproduce.Item","text":"Item\n\nAn Item in the experiment. Contains the parsed arguments.\n\n\n\n\n\n","category":"type"},{"location":"docs/search/#Reproduce.ItemCollection","page":"Search","title":"Reproduce.ItemCollection","text":"ItemCollection\n\nA collection of items. Mostly helpful, but not really used yet.\n\n\n\n\n\n","category":"type"},{"location":"docs/search/#Base.:--Union{Tuple{V}, Tuple{K}, Tuple{Dict{K, V}, Dict{K, V}}} where {K, V}","page":"Search","title":"Base.:-","text":"-(l::Dict{K,T}, r::Dict{K,T}) where {K, T}\n\nGet the difference between two dictionaries. Helper function for diff\n\n\n\n\n\n","category":"method"},{"location":"docs/search/#Base.diff-Tuple{Vector{Reproduce.Item}}","page":"Search","title":"Base.diff","text":"diff\n\nget difference of the list of items.\n\n\n\n\n\n","category":"method"},{"location":"docs/search/#Reproduce.details-Tuple{ItemCollection}","page":"Search","title":"Reproduce.details","text":"details\n\nget details of the pointed directory\n\n\n\n\n\n","category":"method"},{"location":"docs/search/#Reproduce.search-Tuple{ItemCollection, Any}","page":"Search","title":"Reproduce.search","text":"search\n\nSearch for specific entries, or a number of entries.\n\n\n\n\n\n","category":"method"},{"location":"docs/search/","page":"Search","title":"Search","text":"Reproduce.create_info!","category":"page"},{"location":"docs/search/#Reproduce.create_info!","page":"Search","title":"Reproduce.create_info!","text":"create_info!\n\n\n\n\n\n","category":"function"},{"location":"docs/misc/#Misc-Utilities","page":"Misc Utilities","title":"Misc Utilities","text":"","category":"section"},{"location":"docs/misc/","page":"Misc Utilities","title":"Misc Utilities","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/misc/","page":"Misc Utilities","title":"Misc Utilities","text":"_safe_fileop\n_safe_mkdir\n_safe_mkpath","category":"page"},{"location":"docs/misc/#Reproduce._safe_fileop","page":"Misc Utilities","title":"Reproduce._safe_fileop","text":"_safe_fileop\n\nNot entirely safe, but manages the interaction between whether a folder has already been created before another process. Kinda important for a multi-process workflow.\n\nCan't really control what the user will do...\n\n\n\n\n\n","category":"function"},{"location":"docs/misc/#Reproduce._safe_mkdir","page":"Misc Utilities","title":"Reproduce._safe_mkdir","text":"_safe_mkdir\n\nmkdir guarded by _safe_fileop.\n\n\n\n\n\n","category":"function"},{"location":"docs/misc/#Reproduce._safe_mkpath","page":"Misc Utilities","title":"Reproduce._safe_mkpath","text":"_safe_mkpath\n\nmkpath guarded by _safe_fileop.\n\n\n\n\n\n","category":"function"},{"location":"manual/experiment/#Building-and-Running-Experiments","page":"Developing an Experiment","title":"Building and Running Experiments","text":"","category":"section"},{"location":"manual/experiment/","page":"Developing an Experiment","title":"Developing an Experiment","text":"This page will be dedicated to introducing the user to building and running experiments using Reproduce. We will also go through some recommendations for what constitutes a new experiment (and a new data folder) and what we consider as an extension to an already existing experiment.","category":"page"},{"location":"manual/experiment/#Experiment-Struct","page":"Developing an Experiment","title":"Experiment Struct","text":"","category":"section"},{"location":"manual/experiment/#Argument-Iterators","page":"Developing an Experiment","title":"Argument Iterators","text":"","category":"section"},{"location":"manual/experiment/#Config-Files","page":"Developing an Experiment","title":"Config Files","text":"","category":"section"},{"location":"manual/experiment/#Running-experiments","page":"Developing an Experiment","title":"Running experiments","text":"","category":"section"},{"location":"#Reproduce.jl","page":"Home","title":"Reproduce.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for Reproduce.jl","category":"page"}]
}