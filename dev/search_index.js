var documenterSearchIndex = {"docs":
[{"location":"docs/experiment/#Experiment.jl-1","page":"Experiment","title":"Experiment.jl","text":"","category":"section"},{"location":"docs/experiment/#","page":"Experiment","title":"Experiment","text":"CurrentModule = Reproduce","category":"page"},{"location":"docs/experiment/#","page":"Experiment","title":"Experiment","text":"Modules = [Reproduce]\nPages   = [\"experiment.jl\"]","category":"page"},{"location":"docs/experiment/#Reproduce.Experiment","page":"Experiment","title":"Reproduce.Experiment","text":"Experiment(dir, file, module_name, func_name, args_iter, config=nothing; modify_save_path=true)\n\nThis is a struct which encapsulates the idea of an experiment.\n\nArguments\n\ndir: The directory associated w/ this experiment\nfile: The path to the file containing the experiment module\nmodule_name: The module encapsulating your experiment (either a string or symbol)\nfunc_name: The function inside the module which runs your experiment\nargs_iter: The settings your want to iterate over. This can be any iterator which returns (job_id, params)\nconfig: [Optional] The path of the config file your experiment was built from. See Experiment(config_path, save_path=\"\")\nmodify_save_path: If true and you are using ArgIterator or ArgLooper the argiter added to the experiment will have a new staticarg \"save_dir\" added.\n\n\n\n\n\n","category":"type"},{"location":"docs/experiment/#Reproduce.Experiment","page":"Experiment","title":"Reproduce.Experiment","text":"Experiment(config_path, save_path=\"\")\n\nBuild and experiment from either a toml file or a json.\n\n\n\n\n\n","category":"type"},{"location":"docs/experiment/#Reproduce.add_experiment","page":"Experiment","title":"Reproduce.add_experiment","text":"add_experiment(exp_dir, experiment_file, exp_module_name, exp_func_name, args_iter, hash, config)\nadd_experiment(exp::Experiment)\n\nSet up details of experiment in exp_dir. This includes saving settings and config files, etc... It is recommended to use pre_experiment(exp::Experiment; kwargs...).\n\n\n\n\n\n","category":"function"},{"location":"docs/experiment/#Reproduce.create_experiment_dir-Tuple{Any}","page":"Experiment","title":"Reproduce.create_experiment_dir","text":"create_experiment_dir(exp_dir; org_file=false, replace=false, tldr=\"\")\ncreate_experiment_dir(exp::Experiment; kwargs...)\n\nThis creates an experiment directory and sets up a notes file (if orgfile is true). It is recommended to use [`preexperiment(exp::Experiment; kwargs...)`](@ref).\n\nArguments\n\norg_file=false: Indicator on whether to create an org file w/ notes on the job (experimental).\nreplace=false: If true the directory will be deleted. This is not recommended when calling createexperimentdir from multiple jobs.\ntldr=\"\": A TLDR which will be put into the org file.\n\n\n\n\n\n","category":"method"},{"location":"docs/experiment/#Reproduce.pre_experiment-Tuple{Experiment}","page":"Experiment","title":"Reproduce.pre_experiment","text":"pre_experiment(exp::Experiment; kwargs...)\n\nExperiment setup phase. This helps deal with all the setup that needs to occur to setup an experiment folder.\n\n\n\n\n\n","category":"method"},{"location":"manual/experiment/#Building-and-Running-Experiments-1","page":"Experiment","title":"Building and Running Experiments","text":"","category":"section"},{"location":"manual/experiment/#","page":"Experiment","title":"Experiment","text":"This page will be dedicated to introducing the user to building and running experiments using Reproduce. We will also go through some recommendations for what constitutes a new experiment (and a new data folder) and what we consider as an extension to an already existing experiment.","category":"page"},{"location":"manual/experiment/#Experiment-Struct-1","page":"Experiment","title":"Experiment Struct","text":"","category":"section"},{"location":"manual/experiment/#Argument-Iterators-1","page":"Experiment","title":"Argument Iterators","text":"","category":"section"},{"location":"manual/experiment/#ArgIter-1","page":"Experiment","title":"ArgIter","text":"","category":"section"},{"location":"manual/experiment/#ArgLooper-1","page":"Experiment","title":"ArgLooper","text":"","category":"section"},{"location":"manual/experiment/#Config-Files-1","page":"Experiment","title":"Config Files","text":"","category":"section"},{"location":"manual/experiment/#Running-experiments-1","page":"Experiment","title":"Running experiments","text":"","category":"section"},{"location":"manual/experiment/#Config.jl-1","page":"Experiment","title":"Config.jl","text":"","category":"section"},{"location":"#Reproduce.jl-1","page":"Home","title":"Reproduce.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Documentation for Reproduce.jl","category":"page"}]
}
