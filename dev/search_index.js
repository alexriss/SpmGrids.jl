var documenterSearchIndex = {"docs":
[{"location":"tutorial_1/#tutorial_start","page":"Tutorial 1","title":"Tutorial 1: Loading and plotting","text":"","category":"section"},{"location":"tutorial_1/#Loading-data-and-parameters","page":"Tutorial 1","title":"Loading data and parameters","text":"","category":"section"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"First, it is important to know that each grid has channels and parameters. A channel is a 1D array of data over each point in the x,y grid. A parameter is one value for each point in the x,y grid.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"In most cases, channels and parameters have different names, e.g. the channel \"Current\" and the parameter \"Z offset\", but in some cases the same names are used.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"OK, let's look at some examples.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"using SpmGrids\ngrid = load_grid(\"Bias_spectroscopy.3ds\")\n\nparameter_names(grid)  # available parameter names\nchannel_names(grid)  # available channel names\ngrid.size, grid.size_unit, grid.center, grid.angle, grid.pixelsize  # grid parameters\ngrid.start_time, grid.end_time  # more parameters\ngrid.header  # even more parameters\n\nhas_channel(grid, \"Current\")  # true if the grid has a channel named \"Current\"\nhas_parameter(grid, \"Z offset\")  # true if the grid has a parameter named \"Z offset\"","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Now let's access the actual data. Just use get_channel and get_parameter:","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"x = get_channel(grid, \"Current\");  # `Current` channel for the whole grid\nx = get_channel(grid, \"Current\", 5, 5);  # `Current` channel at point 5,5\nx = get_channel(grid, \"Current\", :, 5);  # `Current` channel for 5th row\n#  20th point of `Current` channel for 5th row\nx = get_channel(grid, \"Current\", :, 5, 20);\nx = get_channel(grid, grid.sweep_signal, 5, 6);  # sweep signal at point 5,6\np = get_parameter(grid, \"Z offset\", 3, 5);  # `Z offset` parameter at point 3,5\n\n# get the first 50 points of the `Current` channel for 5th and 6th rows\nx = get_channel(grid, \"Current\", :, 5:6, 1:50);\nsize(x) # 50 points of data for 20 columns and 2 rows","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"There is an even easier function get_data that returns a channel or parameter. Just be careful not to mix up channels and parameters.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"x = get_data(grid, \"Current\");  # `Current` channel\nx = get_data(grid, \"Sweep Start\");  # `Sweep Start` parameter\n\n# the following returns the `Z` channel\n# there is also a `Z` parameter, but channels have precedence\nx = get_data(grid, \"Z\");\n\n# we can also access the `Z` parameter:\nx = get_data(grid, par\"Z\");\n\n# or, to make sure we can only get a channel\nx = get_data(grid, ch\"Z\");","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Backward channels can be accessed as follows:","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"x = get_channel(grid, \"Current [bwd]\");\nx = get_channel(grid, \"Current\", bwd=true);\nx = get_channel(grid, bwd\"Current\");\nx = get_data(grid, bwd\"Z\");\nx = get_data(grid, ch\"Z\"bwd);","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Not every grid has a backwards sweep, though. That is why the above expressions give error messages. yes, that is actually on purpose. So that you can see what happens when you try to access channels that do no exist.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Also, parameters never have extra backward data.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Alright, shuffling data around is fun, but in many cases we want to create a plot. Luckily SpmGrids provides functions to do this fast and easy.","category":"page"},{"location":"tutorial_1/#Plotting-spectra","page":"Tutorial 1","title":"Plotting spectra","text":"","category":"section"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"First thing to know is that plotting needs a Makie backend. CairoMakie can be used for static publication-quality images, while GLMakie and WGLMakie can be used as interactive backends.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Let's see how it works in detail. First, we plot a spectrum. A spectrum is a plot of one channel against another channel for each point in the grid.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"using SpmGrids\nusing CairoMakie  # use any Makie backend you like\n\ngrid = load_grid(\"Bias_spectroscopy.3ds\")\n\nfig = Figure(resolution = (600, 300))\nax = Axis(fig[1, 1])\n\n# line plot of `Current` vs `Bias` for all specified x and y indices\nplot_spectrum(grid, \"Bias\", \"Current\", 10:12, 12, backend=CairoMakie)\n\nfig","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"using SpmGrids\nusing CairoMakie\n\ngrid = load_grid(\"Bias_spectroscopy.3ds\")\n\nfig = Figure(resolution = (600, 300))\nax = Axis(fig[1, 1])\n\n# x, y, as well as channel values can be indexed\nplot_spectrum(grid, \"Bias\", \"Frequency Shift\", 8, 2:6, 20:120, backend=CairoMakie)\n\n# add legend\nfig[1, 2] = Legend(fig, ax, \"Legend\", framevisible=false)\n\nfig","category":"page"},{"location":"tutorial_1/#Plotting-lines","page":"Tutorial 1","title":"Plotting lines","text":"","category":"section"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"Line plots plot along lines in the three-dimensional grid that is spanned by the x,y plane, as well as the sweep channel.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"We can do different types of lines. For instance - similar to spectra - we can plot a response channel vs the sweep channel for a specific point in the x,y plane.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"But lines offer more choices: We can also plot a line of the response channel as a function of the x direction, as shown below.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"using SpmGrids\nusing CairoMakie\n\ngrid = load_grid(\"Z_spectroscopy.3ds\")\n\nfig = Figure(resolution = (800, 800));\nax = Axis(fig[1, 1])\n# plot the `Frequency Shift` for 120th point in the sweep for the second row\nplot_line(grid, \"Frequency Shift\", :, 2, 120, backend=CairoMakie)\nfig[1, 2] = Legend(fig, ax, \"\", framevisible=false, labelsize=10)\n\nax = Axis(fig[2, 1])\n# plot the `Frequency Shift` at point (2,3) against the sweep signal\n# keywords (e.g. `color`) with be passed to the plot function for forward channel\nplot_line(grid, \"Frequency Shift\", 2, 3, :, color=\"#a0a0a0\", backend=CairoMakie)\nfig[2, 2] = Legend(fig, ax, \"\", framevisible=false, labelsize=10)\n\nax = Axis(fig[3, 1])\n# plot the `Frequency Shift` at point (3,2) against `Current` channel\n# keywords with suffix `_bwd` (e.g. `color_bwd`) will be passed\n# to the plot function for backward channel\nplot_line(grid, \"Frequency Shift\", 3,2, :, sweep_channel=\"Current\", color_bwd=\"#a0a0a0\", backend=CairoMakie)\nfig[3, 2] = Legend(fig, ax, \"\", framevisible=false, labelsize=10)\n\nfig","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"In all examples above, we use the indices for x, y, and the channel to select one-dimensional data.","category":"page"},{"location":"tutorial_1/#Plotting-planes","page":"Tutorial 1","title":"Plotting planes","text":"","category":"section"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"To plot planes, we use indexing to select two-dimensional data. For instance, we can plot the \"Frequency Shift\" channel at a particular value of the sweep channel as a function of the x and y direction.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"using SpmGrids\nusing CairoMakie\n\ngrid = load_grid(\"Bias_spectroscopy.3ds\")\n\nfig = Figure(resolution = (800, 400));\ng1 = fig[1, 1] = GridLayout()\ng2 = fig[1, 2] = GridLayout()\n\nax1 = Axis(g1[1, 1])\n\n# plot the `Frequency Shift` for 120th point in the sweep\nr1 = plot_plane(grid, \"Frequency Shift\", :, :, 120,\n    ax=ax1, backend=CairoMakie)\nax1.title = r1.plot_label\n\n# add colorbars\nColorbar(g1[1, 2], r1.plot, label=r1.data_label)\n\nfig","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"# add second plot\nax2 = Axis(g2[1, 1])\n\n# plot `Current` values of the bwd sweep\n# for 10th to 100th point in the sweep for the 15th row\nr2 = plot_plane(grid, \"Current\", :, 15, 1:100,\n    ax=ax2, bwd=true, colormap=:imola, backend=CairoMakie)\nax2.title = r2.plot_label\n\nColorbar(g2[1, 2], r2.plot, label=r2.data_label)\n\n# mark 15th row in the first plot\npx, py = xyindex_to_point(grid, 1, 15)\nhlines!(ax1, py * r1.y_factor, color=:red)  # we need to convert to nm\n\nfig","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"(Still need to figure out why the colorbars are not aligned.)","category":"page"},{"location":"tutorial_1/#Plotting-cubes","page":"Tutorial 1","title":"Plotting cubes","text":"","category":"section"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"And finally, we can plot three-dimensional data as cube plots.","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"using SpmGrids\nusing GLMakie\n\ngrid = load_grid(\"Bias_spectroscopy.3ds\")\n\nfig = Figure(resolution = (500, 400));\nax = Axis3(fig[1, 1], perspectiveness=0.5)\n\nr = plot_cube(grid, \"Current\", :, :, :,\n    colormap=:Spectral_11, backend=GLMakie)\nColorbar(fig[1,2], r.plot, label=r.data_label)\n\nfig","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"(Image: Cube plot)","category":"page"},{"location":"tutorial_1/","page":"Tutorial 1","title":"Tutorial 1","text":"All the plots can be interactive if you use the right Makie backend.","category":"page"},{"location":"tutorial_2/#Tutorial-2:-Manipulating-grids","page":"Tutorial 2","title":"Tutorial 2: Manipulating grids","text":"","category":"section"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"Now that you are already familiar with the basic functionality of SpmGrids, let's dive deeper. Here we want to learn how to manipulate data.","category":"page"},{"location":"tutorial_2/#Adding-channels","page":"Tutorial 2","title":"Adding channels","text":"","category":"section"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"Let's manualla add a channel \"Z rel\" that is the relative Z position in the grid, i.e, the Z position with respect to the parameter \"Scan Start\". The new channel should have the unit of \"m\".","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"using SpmGrids\ngrid = load_grid(\"Z_spectroscopy.3ds\")\n\nz = get_channel(grid, \"Z\");\nsweep_start = get_parameter(grid, \"Sweep Start\");\n\nz_rel = z .- sweep_start;\nadd_channel!(grid, \"Z rel\", \"m\", z_rel)","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"Quite easy, isn't it?","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"However, notice that we didn't add the backward channel \"Z rel [bwd]\".","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"has_channel(grid, \"Z\")\nhas_channel(grid, bwd\"Z\")\nhas_channel(grid, \"Z rel\")\nhas_channel(grid, bwd\"Z rel\")","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"And we can do it manually, just as before. But a better way is the following. Again, we add a \"Z rel\" channel (in fact it will be overwritten). But this time we use the a function as the first argument in add_channel!. It takes two input parameters x and y and computes x .- y (i.e. the broadcasted subtraction).","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"The new channel name will be \"Z rel\", it's unit \"m\", and the input parameters for the function are \"Z\" and \"Sweep Start\".","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"add_channel!(\n    (x,y) -> x .- y,\n    grid, \"Z rel\", \"m\", \"Z\", \"Sweep Start\"\n)","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"We could also explicitely specify that \"Z\" is a channel and \"Sweep Start\" is a parameter by using ch\"Z\" and par\"Sweep Start\".","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"But the more important thing is that the function automatically handled the backward channels:","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"has_channel(grid, \"Z rel\")\nhas_channel(grid, bwd\"Z rel\")","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"One thing to keep in mind is that the channels can contain NaN values. This can happen when the grid was stopped prematurely or a sweep within a grid is stopped.","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"Thus to calculate a \"Z rel\" channel relative to the minimum value of all \"Z\" values, you need to do the following:","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"zmin = minimum(\n    SpmGrids.skipnan(get_channel(grid, \"Z\"))\n)\n\nadd_channel!(x -> x .- zmin, grid, \"Z rel\", \"m\", \"Z\")\n\nz_rel = get_channel(grid, \"Z rel\");\n\nz_rel[1,1,20]","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"The SpmGrids.skipnan function is a convenience function that skips all NaN values, it is just a shorthand for : filter(!isnan, x).","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"We could now even set the sweep_signal of the grid to the new \"Z rel\" channel:","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"grid.sweep_signal = \"Z rel\"","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"But be careful to know what you are doing when changing these values. The sweep signal has special requirements, for instance, its values should be unique.","category":"page"},{"location":"tutorial_2/#Adding-parameters","page":"Tutorial 2","title":"Adding parameters","text":"","category":"section"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"Similarly as adding channels, we can add parameters to our grid. For instance a parameter \"Sweep Span\":","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"add_parameter!(\n    (x,y) -> abs.(y .- x),\n    grid, \"Sweep Span\", \"m\", \"Sweep Start\", \"Sweep End\"\n)\n\np = get_parameter(grid, \"Sweep Span\");\n\nhas_parameter(grid, \"Sweep Span\")\n\nsize(p)\n\n# now all \"Z rel\" values are ≥ 0\nall(SpmGrids.skipnan(p) .≥ 0)","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"Also, all these new channels and parameters are available in the interactive widget. You can load it with:","category":"page"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"interactive_display(grid, colormap=:bluegreenyellow)","category":"page"},{"location":"tutorial_2/#More-information","page":"Tutorial 2","title":"More information","text":"","category":"section"},{"location":"tutorial_2/","page":"Tutorial 2","title":"Tutorial 2","text":"A more detailed description can be found in the Reference.","category":"page"},{"location":"reference/#Reference","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"Modules = [SpmGrids]\nPrivate = false","category":"page"},{"location":"reference/#SpmGrids.add_channel!-Tuple{Function, SpmGrids.SpmGrid, AbstractString, AbstractString, Vararg{Any}}","page":"Reference","title":"SpmGrids.add_channel!","text":"add_channel!(func::Function, grid::SpmGrid, name::AbstractString, unit::AbstractString,\n    args...; skip_bwd::Bool=false::Nothing\n\nAdds a generated channel with name, unit and data to the grid. The channel is generated by the function func that takes other channels/parameters specified by args... as input parameters. Any broadcasting functionality should be implemented in func. The name cannot be the same as names in the original channel names. If the name exists in the generated channel names, it will be overwritten. If skip_bwd is false (default), then bwd channels will be added if feasible.\n\nExamples\n\njulia> grid = load_grid(\"file.3ds\")\njulia> add_channel!(x -> abs(x), grid, \"CurrentAbs\", \"A\", \"Current\")\njulia> add_channel!((x,y) -> x + y, grid, \"\", \"A\", \"Current\", \"AbsCurrent\")\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.add_channel!-Tuple{SpmGrids.SpmGrid, AbstractString, AbstractString, AbstractArray{Float32}}","page":"Reference","title":"SpmGrids.add_channel!","text":"add_channel!(grid::SpmGrid, name::AbstractString, unit::AbstractString,\n    data::AbstractArray{Float32})::Nothing\n\nAdds a generated channel with name, unit and data to the grid. The data must be of the same size as channel data in the grid, i.e. grid.points x grid.pixelsize.... The name cannot be the same as names in the original channel names. If the name exists in the generated channel names, it will be overwritten.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.add_parameter!-Tuple{Function, SpmGrids.SpmGrid, AbstractString, AbstractString, Vararg{Any}}","page":"Reference","title":"SpmGrids.add_parameter!","text":"add_parameter!(func::Function, grid::SpmGrid, name::AbstractString, unit::AbstractString,\n    args...::AbstractString)::Nothing\n\nAdds a generated parameter with name, unit and data to the grid. The parameter is generated by the function func that takes other parameter/channels specified by args... as input parameters. Any broadcasting functionality should be implemented in func. The name cannot be the same as names in the original parameter names. If the name exists in the generated parameter names, it will be overwritten.\n\nExamples\n\njulia> grid = load_grid(\"file.3ds\")\njulia> add_parameter!(x -> abs(x), grid, \"Scan:ExcitationAbs\", \"V\", \"Scan:Excitation\")\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.add_parameter!-Tuple{SpmGrids.SpmGrid, AbstractString, AbstractString, AbstractArray{Float32}}","page":"Reference","title":"SpmGrids.add_parameter!","text":"add_parameter!(grid::SpmGrid, name::AbstractString, unit::AbstractString,\n    data::AbstractArray{Float32})::Nothing\n\nAdds a generated parameter with name, unit and data to the grid. The data must be of the same size as parameter data in the grid, i.e. grid.pixelsize. The name cannot be the same as names in the original parameter names. If the name exists in the generated parameter names, it will be overwritten.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.channel_names-Tuple{SpmGrids.SpmGrid}","page":"Reference","title":"SpmGrids.channel_names","text":"channel_names(grid::SpmGrid, skip_bwd=true)::Array{String}\n\nReturns all channel names in grid. If skip_bwd is true, then the channel names for the bwds direction are not returned.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.get_channel","page":"Reference","title":"SpmGrids.get_channel","text":"get_channel(grid::SpmGrid, name::AbstractString,\n    x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;\n    bwd::Bool=false)::SubArray{Float32}\n\nReturns the data for the channel name at the point(s) specified by x_index, y_index The channel data can be indexed by channel_index. If bwd is true, the bwd channel is returned if it exists. If view is true (default), then a view(@ref Base.view) is returned , otherwise a copy.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.get_data","page":"Reference","title":"SpmGrids.get_data","text":"get_data(grid::SpmGrid, name::AbstractString,\n    x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;\n    bwd::Bool=false)::SubArray{Float32}\n\nReturns the data for the channel or parameter name at the point(s) specified by x_index, y_index Channel data can also be indexed by channel_index. If bwd is true, the bwd channel is returned if it exists. If view is true (default), then a view(@ref Base.view) is returned , otherwise a copy.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.get_parameter","page":"Reference","title":"SpmGrids.get_parameter","text":"get_parameter(grid::SpmGrid, name::AbstractString,\n    x_index::GridRange=:, y_index::GridRange=:; view::Bool=true)::Union{Array{Float32},SubArray{Float32}}\n\nReturns the value for parameter name at the point(s)specified by x_index, y_index. If view is true (default), then a view(@ref Base.view) is returned , otherwise a copy.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.has_channel-Tuple{SpmGrids.SpmGrid, AbstractString}","page":"Reference","title":"SpmGrids.has_channel","text":"has_channel(grid::SpmGrid, name::AbstractString; bwd::Bool=false)::Bool\n\nReturns true if channel name is present in the grid. If bwd is true, the checks for the existance of the bwd channel.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.has_parameter-Tuple{SpmGrids.SpmGrid, AbstractString}","page":"Reference","title":"SpmGrids.has_parameter","text":"has_parameter(grid::SpmGrid, name::AbstractString)::Bool\n\nReturns true if parameter name is present in the grid.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.interactive_display","page":"Reference","title":"SpmGrids.interactive_display","text":"interactive_display(grid::SpmGrid, response_channel::String=\"\", response_channel2::String=\"\", parameter::String=\"\";\n    bwd::Bool=false, fig::Any=nothing, backend::Module=Main)::Any\n\nDisplay the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments. response_channel specifies the initial choice of the response channel, response_channel2 specifies the initial choice of the response channel for the second line plot, parameter specifies the initial parameter to plot.\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure can be set up and passed via the fig keyword argument.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.interactive_display-2","page":"Reference","title":"SpmGrids.interactive_display","text":"interactive_display(fname::String, response_channel::String=\"\", response_channel2::String=\"\", parameter::String=\"\";\n    bwd::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any\n\nDisplay the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments. response_channel specifies the initial choice of the response channel, response_channel2 specifies the initial choice of the response channel for the second line plot, parameter specifies the initial parameter to plot.\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure can be set up and passed via the fig keyword argument.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.load_grid-Tuple{AbstractString}","page":"Reference","title":"SpmGrids.load_grid","text":"load_grid(filename::AbstractString; header_only::Bool=false)\n\nLoads a grid from a binary file. If header_only is true, then only the header is loaded.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.parameter_names-Tuple{SpmGrids.SpmGrid}","page":"Reference","title":"SpmGrids.parameter_names","text":"parameter_names(grid::SpmGrid)::Array{String}\n\nReturns all parameter names in grid.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.plot_cube","page":"Reference","title":"SpmGrids.plot_cube","text":"plot_cube(grid::SpmGrid, response_channel::String,\n    x_index::GridRange, y_index::GridRange, channel_index::GridRange=nothing;\n    bwd::Bool=false, ax::Any=nothing, backend::Module=Main,\n    kwargs...)::NamedTuple\n\nPlots a cube of response_channel in the three-dimensional data spanned by the x,y plane and the sweep signal. Indexing is done through x_index, y_index and channel_index and should be done such that a three-dimensional array is obtained. If bwd is set to true, then data from the backward sweep is plotted if it exists.\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure or axis should be set up. A particular Axis can be specified via the ax keyword argument. By default, the Makie backend from the Main module is used; it can also be directly specified via the backend keyword argument.\n\nExtra keyword arguments can be specified and will be passed through to the plot function.\n\nReturns a NamedTuple containing the volume-plot, and a colorbar label.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.plot_cube-Tuple{NamedTuple, Any, Any, Module}","page":"Reference","title":"SpmGrids.plot_cube","text":"plot_cube(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing\n\nPlots a cube from the NamedTuple data on Axis ax. A colorbar is also plotted on ax_cb. A Makie backend should be given and extra keyword arguments can be provided.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.plot_line","page":"Reference","title":"SpmGrids.plot_line","text":"plot_line(grid::SpmGrid, response_channel::String,\n    x_index::GridRange, y_index::GridRange, channel_index::GridRange=nothing;\n    sweep_channel::String=\"\", bwd::Bool=true, ax::Any=nothing, backend::Module=Main,\n    kwargs...)::NamedTuple\n\nPlots the response_channel along a line in the three-dimensional data spanned by x,y plane and the spectroscopy data. Indexing is done through x_index, y_index and channel_index and should be done such that a one-dimensional array is obtained. It is also possible to plot response_channel vs sweep_channel (which defaults to the sweep signal if not specified) for one point in the grid If bwd is true (default), the plot will include data from backward sweep as well (if they exist).\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure or axis should be set up. A particular Axis can be specified via the ax keyword argument. By default, the Makie backend from the Main module is used; it can also be directly specified via the backend keyword argument.\n\nExtra keyword arguments can be specified and will be passed through to the plot function. Keyword arrguments with the suffix _bwd will be used for plotting of the backward scan.    \n\nReturns a NamedTuple.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.plot_line-Tuple{NamedTuple, Any, Module}","page":"Reference","title":"SpmGrids.plot_line","text":"plot_line(data::NamedTuple, ax::Any, backend::Module; bwd::Bool=true, kwargs...)::Nothing\n\nPlots a line from the NamedTuple x vs y and x_bwd vs y_bwd on Axis ax\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.plot_parameter_plane-Tuple{SpmGrids.SpmGrid, String, Union{Colon, UnitRange{Int64}, Int64}, Union{Colon, UnitRange{Int64}, Int64}}","page":"Reference","title":"SpmGrids.plot_parameter_plane","text":"plotparameterplane(grid::SpmGrid, parameter::String,         xindex::GridRange, yindex::GridRange;         ax::Any=nothing, backend::Module=Main,         kwargs...)::NamedTuple\n\nPlots values of parameters as a function of the x,y plane Indexing is done through x_index, y_index.\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure or axis should be set up. A particular Axis can be specified via the ax keyword argument. By default, the Makie backend from the Main module is used; it can also be directly specified via the backend keyword argument.\n\nExtra keyword arguments can be specified and will be passed through to the plot function.\n\nReturns a NamedTuple containing the heatmap, the colorbar label and the plot label.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.plot_plane","page":"Reference","title":"SpmGrids.plot_plane","text":"plot_plane(grid::SpmGrid, response_channel::String,\n    x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;\n    bwd::Bool=false, ax::Any=nothing, backend::Module=Main,\n    kwargs...)::NamedTuple\n\nPlots a plane of response_channel in the three-dimensional data spanned by x,y plane and the sweep signal. Indexing is done through x_index, y_index and channel_index and should be done such that a two-dimensional array is obtained. If bwd is set to true, then data from the backward sweep is plotted if it exists.\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure or axis should be set up. A particular Axis can be specified via the ax keyword argument. By default, the Makie backend from the Main module is used; it can also be directly specified via the backend keyword argument.\n\nExtra keyword arguments can be specified and will be passed through to the plot function.\n\nReturns a NamedTuple containing the heatmap, the colorbar label and the plot label.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.plot_plane-Tuple{NamedTuple, Any, Any, Module}","page":"Reference","title":"SpmGrids.plot_plane","text":"plot_plane(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing\n\nPlots a plane from the NamedTuple data on Axis ax. A colorbar is also plotted on ax_cb. A Makie backend should be given and extra keyword arguments can be provided.\n\n\n\n\n\n","category":"method"},{"location":"reference/#SpmGrids.plot_spectrum","page":"Reference","title":"SpmGrids.plot_spectrum","text":"plot_spectrum(grid::SpmGrid, sweep_channel::String, response_channel::String,\n    x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;\n    bwd::Bool=true, ax::Any=nothing, backend::Module=Main,\n    kwargs...)::NamedTuple\n\nPlots a line plot of response_channel vs sweep_channel on the given x_index and y_index. If sweep_channel is \"\", then the sweep signal will be used for sweep_channel. Additionally, the spectrum data can be indexed by channel_index. If bwd is true (default), the plot will include data from backward sweep as well (if they exist).\n\nBefore using this function, a Makie backend (GLMakie, CairoMakie or WGLMakie) should be imported and the figure or axis should be set up. A particular Axis can be specified via the ax keyword argument. By default, the Makie backend from the Main module is used; it can also be directly specified via the backend keyword argument.\n\nExtra keyword arguments can be specified and will be passed through to the plot function. Keyword arrguments with the suffix _bwd will be used for plotting of the backward scan.\n\nReturns a NamedTuple.\n\n\n\n\n\n","category":"function"},{"location":"reference/#SpmGrids.xyindex_to_point-Tuple{SpmGrids.SpmGrid, Int64, Int64}","page":"Reference","title":"SpmGrids.xyindex_to_point","text":"xyindex_to_point(grid::SpmGrid, index_x::Int, index_y)::Tuple{Float32,Float32}\n\nConverts index_x and index_y of grid to point coordinates in physical units.\n\n\n\n\n\n","category":"method"},{"location":"","page":"Introduction","title":"Introduction","text":"CurrentModule = SpmGrids","category":"page"},{"location":"#SpmGrids","page":"Introduction","title":"SpmGrids","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Documentation for SpmGrids.","category":"page"},{"location":"#About","page":"Introduction","title":"About","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"A julia library to analyze scanning tuprobe microscopy grid data. Currently, only Nanonis files are supported.","category":"page"},{"location":"#Installation","page":"Introduction","title":"Installation","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"SpmGrids can be installed from the Julia package registry via:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using Pkg\nPkg.add(\"SpmGrids\")","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Additionally, you need to install a Makie backend.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using Pkg\nPkg.add(\"GLMakie\")","category":"page"},{"location":"#interactive_widget","page":"Introduction","title":"Interactive widget","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Now the fun begins. The easiest way to analyze grids is the interactive widget.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using SpmGrids\nusing GLMakie  # you can also use the WGLMakie backend\n\ninteractive_display(\"Bias_spectroscopy.3ds\", colormap=:bluegreenyellow)","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"(Image: demo of interactive display)","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"You can also easily create and adapt these plots in julia, as described in the Tutorial.","category":"page"},{"location":"tutorial_3/#Tutorial-3:-Real-life-examples","page":"Tutorial 3","title":"Tutorial 3: Real life examples","text":"","category":"section"},{"location":"tutorial_3/#Example:-KPFM","page":"Tutorial 3","title":"Example: KPFM","text":"","category":"section"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"Let's look at a real world example: Kelvin Probe Force Microscopy (KPFM). The manual way to conduct such an experiment is to scan over a grid and sweep the bias at each point. The \"Frequency Shift\" vs. \"Bias\" can then be fitted to a parabola. We will denote the x and y positions of the maximum of this parabola as \"KPFM:Bias\" and \"KPFM:Frequency Shift\", respectively.","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"Let's see how to do this in SpmGrids.","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"using SpmGrids\ngrid = load_grid(\"Bias_spectroscopy.3ds\")\n\ndf = get_channel(grid, \"Frequency Shift\");\nV = get_channel(grid, \"Bias\");\n\n# dimensions of channels and paremeters, respectively\ndim_ch = size(df)\ndim_par = grid.pixelsize\n\n# pre-define arrays for the results\nkpfm_bias = Array{Float32}(undef, dim_par...)\nkpfm_df = Array{Float32}(undef, dim_par...)\nkpfm_fit = Array{Float32}(undef, dim_ch...)\nkpfm_res = Array{Float32}(undef, dim_ch...)\nkpfm_res_abs_sum = Array{Float32}(undef, dim_par...)\n\n# loop over all x,y pixels\nfor ix in 1:dim_ch[1], iy in 1:dim_ch[2]\n    # fit parabola to the data\n    x = V[ix, iy, :]\n    y = df[ix, iy, :]\n    X = [ones(dim_ch[3]) x x.^2]\n    coeffs = X \\ y\n\n    # coordinates of the maximum of the parabola\n    c, b, a = coeffs\n    kpfm_bias[ix, iy] = -b / (2 * a)\n    kpfm_df[ix, iy] = c - b^2 / (4 * a)\n\n    # fitted parabola\n    kpfm_fit[ix, iy, :] .= X * coeffs\n\n    # residuals\n    kpfm_res[ix, iy, :] .= y .- kpfm_fit[ix, iy, :]\n    kpfm_res_abs_sum[ix, iy] = sum(abs.(kpfm_res[ix, iy, :]))\nend\n\n# add all the data to the grid\n\nadd_parameter!(grid, \"KPFM:Bias\", \"V\", kpfm_bias)\nadd_parameter!(grid, \"KPFM:Frequency Shift\", \"Hz\", kpfm_df)\nadd_channel!(grid, \"KPFM:Fit\", \"Hz\", kpfm_fit)\nadd_channel!(grid, \"KPFM:Residuals\", \"Hz\", kpfm_res)\nadd_parameter!(grid, \"KPFM:Residuals AbsSum\", \"Hz\", kpfm_res_abs_sum)","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"And we would have to do the same for the backwards channel. But this file does not have a backwards channel. Also, there are no NaN values in this file. Otherwise, we would have to use a few skipnan functions in the code.","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"Now to look at the results, the easiest is to launch the interactive widget:","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"using GLMakie\ninteractive_display(grid, colormap=:bluegreenyellow)","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"(Image: screenshot of interactive display)","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"Of course all these plots can easily be generated with the plot functions. For instance:","category":"page"},{"location":"tutorial_3/","page":"Tutorial 3","title":"Tutorial 3","text":"using CairoMakie\n\nfig = Figure(resolution = (720, 600));\nax = Axis(fig[1,1])\nr = plot_line(grid, \"KPFM:Fit\", 5, 5, :, backend=CairoMakie, color=:red)\nr = plot_line(grid, \"Frequency Shift\", 5, 5, :, backend=CairoMakie, color=:black)\nvlines!(ax, kpfm_bias[5,5] * r.x_factor, color=:gray, linestyle=:dash)\n\nax = Axis(fig[2,1])\nr = plot_line(grid, \"KPFM:Residuals\", 5, 5, :, backend=CairoMakie, color=:gray)\n\nfig","category":"page"}]
}
