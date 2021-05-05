var documenterSearchIndex = {"docs":
[{"location":"docs/experiment/#Experiment.jl","page":"Experiment","title":"Experiment.jl","text":"","category":"section"},{"location":"docs/experiment/","page":"Experiment","title":"Experiment","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/experiment/","page":"Experiment","title":"Experiment","text":"Modules = [Reproduce]\nPages   = [\"experiment.jl\"]","category":"page"},{"location":"docs/experiment/#Reproduce.Experiment","page":"Experiment","title":"Reproduce.Experiment","text":"Experiment(dir, file, module_name, func_name, args_iter, config=nothing; modify_save_path=true)\n\nThis is a struct which encapsulates the idea of an experiment.\n\nArguments\n\ndir: The directory associated w/ this experiment\nfile: The path to the file containing the experiment module\nmodule_name: The module encapsulating your experiment (either a string or symbol)\nfunc_name: The function inside the module which runs your experiment\nargs_iter: The settings your want to iterate over. This can be any iterator which returns (job_id, params)\nconfig: [Optional] The path of the config file your experiment was built from. See Experiment(config_path, save_path=\"\")\nmodify_save_path: If true and you are using ArgIterator or ArgLooper the argiter added to the experiment will have a new staticarg \"save_dir\" added.\n\n\n\n\n\n","category":"type"},{"location":"docs/experiment/#Reproduce.Experiment-2","page":"Experiment","title":"Reproduce.Experiment","text":"Experiment(config_path, save_path=\"\")\n\nBuild and experiment from either a toml file or a json.\n\n\n\n\n\n","category":"type"},{"location":"docs/experiment/#Reproduce.add_experiment","page":"Experiment","title":"Reproduce.add_experiment","text":"add_experiment(exp_dir, experiment_file, exp_module_name, exp_func_name, args_iter, hash, config)\nadd_experiment(exp::Experiment)\n\nSet up details of experiment in exp_dir. This includes saving settings and config files, etc... It is recommended to use pre_experiment(exp::Experiment; kwargs...).\n\n\n\n\n\n","category":"function"},{"location":"docs/experiment/#Reproduce.append_experiment_notes_file-NTuple{8,Any}","page":"Experiment","title":"Reproduce.append_experiment_notes_file","text":"append_experiment_notes_file(exp_dir, experiment_file, exp_module_name, exp_func_name, settings_file, config_file, args_iter, config)\n\nWrite into an org file which contains the notes for the run experiments\n\n\n\n\n\n","category":"method"},{"location":"docs/experiment/#Reproduce.create_experiment_dir-Tuple{Any}","page":"Experiment","title":"Reproduce.create_experiment_dir","text":"create_experiment_dir(exp_dir; org_file=false, replace=false, tldr=\"\")\ncreate_experiment_dir(exp::Experiment; kwargs...)\n\nThis creates an experiment directory and sets up a notes file (if orgfile is true). It is recommended to use [`preexperiment(exp::Experiment; kwargs...)`](@ref).\n\nArguments\n\norg_file=false: Indicator on whether to create an org file w/ notes on the job (experimental).\nreplace=false: If true the directory will be deleted. This is not recommended when calling createexperimentdir from multiple jobs.\ntldr=\"\": A TLDR which will be put into the org file.\n\n\n\n\n\n","category":"method"},{"location":"docs/experiment/#Reproduce.pre_experiment-Tuple{Experiment}","page":"Experiment","title":"Reproduce.pre_experiment","text":"pre_experiment(exp::Experiment; kwargs...)\n\nExperiment setup phase. This helps deal with all the setup that needs to occur to setup an experiment folder.\n\n\n\n\n\n","category":"method"},{"location":"manual/parallel/#Running-a-parallel-job","page":"Parallel Jobs","title":"Running a parallel job","text":"","category":"section"},{"location":"docs/parse/#parse.jl","page":"Data Structure","title":"parse.jl","text":"","category":"section"},{"location":"docs/parse/","page":"Data Structure","title":"Data Structure","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/parse/","page":"Data Structure","title":"Data Structure","text":"Modules = [Reproduce]\nPages   = [\"parse.jl\"]","category":"page"},{"location":"docs/parse/#Reproduce.create_info!-Tuple{Dict,String}","page":"Data Structure","title":"Reproduce.create_info!","text":"create_info!\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#parallel.jl","page":"Parallel","title":"parallel.jl","text":"","category":"section"},{"location":"docs/parallel/","page":"Parallel","title":"Parallel","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/parallel/","page":"Parallel","title":"Parallel","text":"Modules = [Reproduce]\nPages   = [\"parallel.jl\"]","category":"page"},{"location":"docs/parallel/#Reproduce.job-Tuple{Experiment}","page":"Parallel","title":"Reproduce.job","text":"job(experiment::Experiment; kwargs...)\njob(experiment_file, exp_dir, args_iter; kwargs...)\njob(experiment::Experiment, job_id; kwargs...)\njob(experiment_file, exp_dir, args_iter, job_id; kwargs...)\n\nRun a job specified by the experiment.\n\n\n\n\n\n","category":"method"},{"location":"docs/parallel/#Reproduce.parallel_job-Tuple{AbstractString,AbstractString,Any}","page":"Parallel","title":"Reproduce.parallel_job","text":"parallel_job\n\nRun a parallel job over the arguments presented by argsiter. `argsiter` can be a enumeration OR ArgIterator. Each job will be dedicated to a specific task. The experiment must save its own data! As this is not handled by this function (although could be added in the future.)\n\n\n\n\n\n","category":"method"},{"location":"manual/experiment/#Building-and-Running-Experiments","page":"Developing an Experiment","title":"Building and Running Experiments","text":"","category":"section"},{"location":"manual/experiment/","page":"Developing an Experiment","title":"Developing an Experiment","text":"This page will be dedicated to introducing the user to building and running experiments using Reproduce. We will also go through some recommendations for what constitutes a new experiment (and a new data folder) and what we consider as an extension to an already existing experiment.","category":"page"},{"location":"manual/experiment/#Experiment-Struct","page":"Developing an Experiment","title":"Experiment Struct","text":"","category":"section"},{"location":"manual/experiment/#Argument-Iterators","page":"Developing an Experiment","title":"Argument Iterators","text":"","category":"section"},{"location":"manual/experiment/#ArgIter","page":"Developing an Experiment","title":"ArgIter","text":"","category":"section"},{"location":"manual/experiment/#ArgLooper","page":"Developing an Experiment","title":"ArgLooper","text":"","category":"section"},{"location":"manual/experiment/#Config-Files","page":"Developing an Experiment","title":"Config Files","text":"","category":"section"},{"location":"manual/experiment/#Running-experiments","page":"Developing an Experiment","title":"Running experiments","text":"","category":"section"},{"location":"manual/experiment/#Config.jl","page":"Developing an Experiment","title":"Config.jl","text":"","category":"section"},{"location":"#Reproduce.jl","page":"Home","title":"Reproduce.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for Reproduce.jl","category":"page"}]
}
