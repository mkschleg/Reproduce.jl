using Pkg
Pkg.activate(".")

using Reproduce
using Reproduce.Config


function main()

    arg_settings = ArgParseSettings()
    @add_arg_table arg_settings begin
        "config_file"
        arg_type=String
        "runs"
        arg_type=Int64
        "save_loc"
        arg_type=String
        "--numworkers"
        arg_type=Int64
        default=2
    end
    parsed = parse_args(arg_settings)

    save_loc = parsed["save_loc"]

    # cfg = ConfigManager(parsed["config_file"], save_loc)
    create_experiment_dir(save_loc; org_file=false)
    config_job(parsed["config_file"],
               save_loc,
               parsed["runs"];
               num_workers=parsed["numworkers"],
               extra_args=[save_loc])
end

main()
