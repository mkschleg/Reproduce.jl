using Documenter
using Reproduce

makedocs(
    sitename = "Reproduce",
    format = Documenter.HTML(),
    modules = [Reproduce],
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Developing an Experiment"=>"manual/experiment.md"
            "Parallel Jobs"=>"manual/parallel.md"
        ],
        "Documentation" => [
            "Parser"=>"docs/parse.md",
            "Iterators"=>"docs/iterators.md",
            "Experiment"=>"docs/experiment.md",
            "Parallel"=>"docs/parallel.md",
            "Experiment Utilities"=>"docs/exp_utils.md",
            "Misc Utilities"=>"docs/misc.md"

        ]
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#

deploydocs(
    repo = "github.com/mkschleg/Reproduce.jl.git",
    devbranch = "main",
    versions = ["stable" => "v^"]
)
