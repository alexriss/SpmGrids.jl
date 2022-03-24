var documenterSearchIndex = {"docs":
[{"location":"reference/#Reference","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"Modules = [SpmGrids]\nPrivate = false","category":"page"},{"location":"reference/#SpmGrids.get_channel","page":"Reference","title":"SpmGrids.get_channel","text":"get_channel(grid::SpmGrid, name::AbstractString, index_x::Any, index_y::Any, index_channel::Any=nothing)::Array{Float32}\n\nReturns the data for the channel name at the point(s) specified by index_x, index_y The channel data can be indexed by index_channel.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.get_parameter-Tuple{SpmGrids.SpmGrid, AbstractString, Any, Any}","page":"Reference","title":"SpmGrids.get_parameter","text":"get_parameter(grid::SpmGrid, name::AbstractString, index_x::Any, index_y::Any)::Union{Float32, Array{Float32}}\n\nReturns the value for parameter name at the point(s)specified by index_x, index_y.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.load_grid-Tuple{AbstractString}","page":"Reference","title":"SpmGrids.load_grid","text":"load_grid(filename::AbstractString; header_only::Bool=false)\n\nLoads a grid from a binary file. If header_only is true, then only the header is loaded.\n\n\n\n\n\n","category":"method"},{"location":"","page":"Introduction","title":"Introduction","text":"CurrentModule = SpmGrids","category":"page"},{"location":"#SpmGrids","page":"Introduction","title":"SpmGrids","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Documentation for SpmGrids.","category":"page"},{"location":"#About","page":"Introduction","title":"About","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"A julia library to analyze scanning tuprobe microscopy grid data. Currently, only Nanonis files are supported.","category":"page"},{"location":"#Usage","page":"Introduction","title":"Usage","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"using SpmGrids\n\ngrid = load_grid(\"Bias_spectrocopy.3ds\")\n\nc = get_channel(grid, \"Current\", 5, 5)  # get the current channel at point 5,5\nc = get_channel(grid, \"Current\", :, 5)  # get the current channel for fifth row\nc = get_channel(grid, \"Current\", :, 5, 20)  # get the 20th point of the current channel for fifth row\nc = get_channel(grid, \"Current\", :, 5:6, 1:50)  # get the first 50 points of the current channel for fifth and sixth rows, returns a 50x20x2 Array\n\nx = get_channel(grid, grid.sweep_signal, 5, 6)  # get the sweep signal at point 5,6\n\np = get_parameter(grid, \"Z offset\", 3, 5)  # get the `Z offset` parameter at point 3,5","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"A more detailed description can be found in the Reference","category":"page"}]
}