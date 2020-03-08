using Documenter
using Reproduce

makedocs(
    sitename = "Reproduce",
    format = Documenter.HTML(),
    modules = [Reproduce],
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Experiment"=>"manual/experiment.md"
            # "Data Analysis"=>"manual/data_analysis.md"
        ],
        "Documentation" => [
            "Experiment"=>"docs/experiment.md",
            # "Search"=>"docs/search.md"
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
    devbranch = "master",
    versions = ["stable" => "v^"]
)
