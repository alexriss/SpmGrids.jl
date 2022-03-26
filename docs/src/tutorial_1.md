# [Tutorial 1: Loading and plotting](@id tutorial_start)

## Loading data and parameters

First, it is important to know that each grid has _channels_ and _parameters_. A channel is a 1D array of data over each point in the x,y grid. A parameter is one value for each point in the x,y grid.

In most cases, channels and parameters have different names, e.g. the channel "Current" and the parameter "Z offset", but in some cases the same names are used.

OK, let's look at some examples.

```@repl 1
using SpmGrids
grid = load_grid("Bias_spectroscopy.3ds")

parameter_names(grid)  # available parameter names
channel_names(grid)  # available channel names
grid.size, grid.size_unit, grid.center, grid.angle, grid.pixelsize  # grid parameters
grid.start_time, grid.end_time  # more parameters
grid.header  # even more parameters

has_channel(grid, "Current")  # true if the grid has a channel named "Current"
has_parameter(grid, "Z offset")  # true if the grid has a parameter named "Z offset"
```

Now let's access the actual data. Just use `get_channel` and `get_parameter`:

```@repl 1
x = get_channel(grid, "Current");  # `Current` channel for the whole grid
x = get_channel(grid, "Current", 5, 5);  # `Current` channel at point 5,5
x = get_channel(grid, "Current", :, 5);  # `Current` channel for 5th row
#  20th point of `Current` channel for 5th row
x = get_channel(grid, "Current", :, 5, 20);
x = get_channel(grid, grid.sweep_signal, 5, 6);  # sweep signal at point 5,6
p = get_parameter(grid, "Z offset", 3, 5);  # `Z offset` parameter at point 3,5

# get the first 50 points of the `Current` channel for 5th and 6th rows
x = get_channel(grid, "Current", :, 5:6, 1:50);
size(x) # 50 points of data for 20 columns and 2 rows
```

There is an even easier function `get_data` that returns a channel or parameter. Just be careful not to mix up channels and parameters.

```@repl 1
x = get_data(grid, "Current");  # `Current` channel
x = get_data(grid, "Sweep Start");  # `Sweep Start` parameter

# the following returns the `Z` channel
# there is also a `Z` parameter, but channels have precedence
x = get_data(grid, "Z");

# we can also access the `Z` parameter:
x = get_data(grid, par"Z");

# or, to make sure we can only get a channel
x = get_data(grid, ch"Z");
```


Backward channels can be accessed as follows:

```@repl 1
x = get_channel(grid, "Current [bwd]");
x = get_channel(grid, "Current", bwd=true);
x = get_channel(grid, bwd"Current");
x = get_data(grid, bwd"Z");
x = get_data(grid, ch"Z"bwd);
```

Not every grid has a backwards sweep, though. That is why the above expressions give error messages.
yes, that is actually on purpose. So that you can see what happens when you try to access channels that do no exist.

Also, parameters never have extra backward data.

Alright, shuffling data around is fun, but in many cases we want to create a plot. Luckily SpmGrids provides functions to do this fast and easy.

## Plotting spectra

First thing to know is that plotting needs a [Makie backend](https://makie.juliaplots.org/stable/documentation/backends/). CairoMakie can be used for static publication-quality images, while GLMakie and WGLMakie can be used as interactive backends.

Let's see how it works in detail. First, we plot a spectrum. A spectrum is a plot of one channel against another channel for each point in the grid.

```@example
using SpmGrids
using CairoMakie  # use any Makie backend you like

grid = load_grid("Bias_spectroscopy.3ds")

fig = Figure(resolution = (600, 300))
ax = Axis(fig[1, 1])

# line plot of `Current` vs `Bias` for all specified x and y indices
plot_spectrum(grid, "Bias", "Current", 10:12, 12, backend=CairoMakie)

fig
```

```@example
using SpmGrids
using CairoMakie

grid = load_grid("Bias_spectroscopy.3ds")

fig = Figure(resolution = (600, 300))
ax = Axis(fig[1, 1])

# x, y, as well as channel values can be indexed
plot_spectrum(grid, "Bias", "Frequency Shift", 8, 2:6, 20:120, backend=CairoMakie)

# add legend
fig[1, 2] = Legend(fig, ax, "Legend", framevisible=false)

fig
```

## Plotting lines

Line plots plot along lines in the three-dimensional grid that is spanned by the x,y plane, as well as the sweep channel.

We can do different types of lines. For instance - similar to spectra - we can plot a response channel vs the sweep channel for a specific point in the x,y plane.

But lines offer more choices: We can also plot a line of the response channel as a function of the x direction, as shown below.

```@example
using SpmGrids
using CairoMakie

grid = load_grid("Z_spectroscopy.3ds")

fig = Figure(resolution = (800, 800));
ax = Axis(fig[1, 1])
# plot the `Frequency Shift` for 120th point in the sweep for the second row
plot_line(grid, "Frequency Shift", :, 2, 120, backend=CairoMakie)
fig[1, 2] = Legend(fig, ax, "", framevisible=false, labelsize=10)

ax = Axis(fig[2, 1])
# plot the `Frequency Shift` at point (2,3) against the sweep signal
# keywords (e.g. `color`) with be passed to the plot function for forward channel
plot_line(grid, "Frequency Shift", 2, 3, :, color="#a0a0a0", backend=CairoMakie)
fig[2, 2] = Legend(fig, ax, "", framevisible=false, labelsize=10)

ax = Axis(fig[3, 1])
# plot the `Frequency Shift` at point (3,2) against `Current` channel
# keywords with suffix `_bwd` (e.g. `color_bwd`) will be passed
# to the plot function for backward channel
plot_line(grid, "Frequency Shift", 3,2, :, sweep_channel="Current", color_bwd="#a0a0a0", backend=CairoMakie)
fig[3, 2] = Legend(fig, ax, "", framevisible=false, labelsize=10)

fig
```

In all examples above, we use the indices for x, y, and the channel to select one-dimensional data.

## Plotting planes

To plot planes, we use indexing to select two-dimensional data. For instance, we can plot the "Frequency Shift" channel at a particular value of the sweep channel as a function of the x and y direction.

```@example plane
using SpmGrids
using CairoMakie

grid = load_grid("Bias_spectroscopy.3ds")

fig = Figure(resolution = (800, 400));
g1 = fig[1, 1] = GridLayout()
g2 = fig[1, 2] = GridLayout()

ax1 = Axis(g1[1, 1])

# plot the `Frequency Shift` for 120th point in the sweep
r1 = plot_plane(grid, "Frequency Shift", :, :, 120,
    ax=ax1, backend=CairoMakie)
ax1.title = r1.plot_label

# add colorbars
Colorbar(g1[1, 2], r1.plot, label=r1.data_label)

fig
```

```@example plane
# add second plot
ax2 = Axis(g2[1, 1])

# plot `Current` values of the bwd sweep
# for 10th to 100th point in the sweep for the 15th row
r2 = plot_plane(grid, "Current", :, 15, 1:100,
    ax=ax2, bwd=true, colormap=:imola, backend=CairoMakie)
ax2.title = r2.plot_label

Colorbar(g2[1, 2], r2.plot, label=r2.data_label)

# mark 15th row in the first plot
px, py = xyindex_to_point(grid, 1, 15)
hlines!(ax1, py * 1e9, color=:red)  # we need to convert to nm

fig
```

_(Still need to figure out why the colorbars are not aligned.)_

## Plotting cubes

And finally, we can plot three-dimensional data as cube plots.

```julia
using SpmGrids
using GLMakie

grid = load_grid("Bias_spectroscopy.3ds")

fig = Figure(resolution = (500, 400));
ax = Axis3(fig[1, 1], perspectiveness=0.5)

r = plot_cube(grid, "Current", :, :, :,
    colormap=:Spectral_11, backend=GLMakie)
Colorbar(fig[1,2], r.plot, label=r.data_label)

fig
```

![Cube plot](cube_plot.png)

All the plots can be interactive if you use the right [Makie backend](https://makie.juliaplots.org/stable/documentation/backends/).
