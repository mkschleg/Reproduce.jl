module ClusterManagers

using Distributed
using Sockets

export launch, manage, kill, init_worker, connect
import Distributed: launch, manage, kill, init_worker, connect

worker_arg() = `--worker=$(Distributed.init_multi(); cluster_cookie())`


export SlurmManager, addprocs_slurm

import Logging.@warn

struct SlurmManager <: ClusterManager
    np::Integer
end

function launch(manager::SlurmManager, params::Dict, instances_arr::Array,
                c::Condition)
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        stdkeys = keys(Distributed.default_addprocs_params())

        p = filter(x->(!(x[1] in stdkeys) && x[1] != :job_file_loc), params)

        srunargs = []
        for k in keys(p)
            if length(string(k)) == 1
                push!(srunargs, "-$k")
                val = p[k]
                if length(val) > 0
                    push!(srunargs, "$(p[k])")
                end
            else
                k2 = replace(string(k), "_"=>"-")
                val = p[k]
                if length(val) > 0
                    push!(srunargs, "--$(k2)=$(p[k])")
                else
                    push!(srunargs, "--$(k2)")
                end
            end
        end

        # Get job file location from parameter dictionary.
        job_file_loc = joinpath(exehome, get(params, :job_file_loc, "."))

        # Make directory if not already made.
        if !isdir(job_file_loc)
            mkdir(job_file_loc)
        end

        # cleanup old files
	map(f->rm(joinpath(job_file_loc, f)), filter(t -> occursin(r"job(.*?).out", t), readdir(job_file_loc)))

        job_output_name = "job"
        make_job_output_path(task_num) = joinpath(job_file_loc, "$(job_output_name)-$(task_num).out")
        job_output_template = make_job_output_path("%4t")

        np = manager.np
        jobname = "julia-$(getpid())"
        srun_cmd = `srun --exclusive --no-kill -J $jobname -n $np -o "$(job_output_template)" -D $exehome $(srunargs) $exename $exeflags $(worker_arg())`
        srun_proc = open(srun_cmd)

        slurm_spec_regex = r"([\w]+):([\d]+)#(\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3})"
        
        for i = 0:np - 1
            println("connecting to worker $(i + 1) out of $np")
            slurm_spec_match = nothing
            fn = make_job_output_path(lpad(i, 4, "0"))
            t0 = time()
            while true
                # Wait for output log to be created and populated, then parse
                if isfile(fn) && filesize(fn) > 0
                    slurm_spec_match = open(fn) do f
                        # Due to error and warning messages, the specification
                        # may not appear on the file's first line
                        for line in eachline(f)
                            re_match = match(slurm_spec_regex, line)
                            if re_match !== nothing
                                return re_match    # only returns from do-block
                            end
                        end
                    end
                    if slurm_spec_match !== nothing
                        break   # break if specification found
                    end
                end
            end
            config = WorkerConfig()
            config.port = parse(Int, slurm_spec_match[2])
            config.host = strip(slurm_spec_match[3])
            # Keep a reference to the proc, so it's properly closed once
            # the last worker exits.
            config.userdata = srun_proc
            push!(instances_arr, config)
            notify(c)
        end
    catch e
        println("Error launching Slurm job:")
        rethrow(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig,
                op::Symbol)
    # This function needs to exist, but so far we don't do anything
end

addprocs_slurm(np::Integer; kwargs...) = addprocs(SlurmManager(np); kwargs...)

end
