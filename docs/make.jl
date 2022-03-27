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
        "Tutorial 1: Basics" => "tutorial_1.md",
        "Tutorial 2: Data manipulation" => "tutorial_2.md",
        "Tutorial 3: Real life" => "tutorial_3.md",
		"Reference" => "reference.md"
    ],
)

deploydocs(;
    repo="github.com/alexriss/SpmGrids.jl",
    devbranch="main",
)
