using SpmGrids
using Documenter

DocMeta.setdocmeta!(SpmGrids, :DocTestSetup, :(using SpmGrids); recursive=true)

makedocs(;
    modules=[SpmGrids],
    authors="Alex Riss <00alexx@riss.at>",
    repo="https://github.com/alexriss/SpmGrids.jl/blob/{commit}{path}#{line}",
    sitename="SpmGrids.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://alexriss.github.io/SpmGrids.jl",
        assets=String[],
    ),
    pages=[
        "Introduction" => "index.md",
		"Reference" => "reference.md"
    ],
)

deploydocs(;
    repo="github.com/alexriss/SpmGrids.jl",
    devbranch="main",
)
