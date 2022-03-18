```@meta
CurrentModule = SpmGrids
```

# SpmGrids

Documentation for [SpmGrids](https://github.com/alexriss/SpmGrids.jl).

## About

A julia library to analyze scanning tuprobe microscopy grid data. Currently, only [Nanonis](https://www.specs-group.com/nanonis/products/) files are supported.

## Usage

### Loading data and parameters

```@repl
using SpmGrids
grid = load_grid("Bias_spectroscopy.3ds");

grid.experiment_parameters  # available parameter names
grid.channel_names  # available channel names
grid.size, grid.size_unit, grid.center, grid.angle, grid.pixelsize  # grid parameters
grid.start_time, grid.end_time  # more parameters
grid.header  # even more parameters

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

### Plotting spectra

```@example
using SpmGrids
using CairoMakie

grid = load_grid("Bias_spectroscopy.3ds")

fig = Figure(resolution = (800, 400))
ax = Axis(fig[1, 1])

# line plot of `Current` vs `Bias` for all specified x and y indices
plot_spectrum(grid, "Bias", "Current", 10:12, 12, backend=CairoMakie)

fig
```

```@example
using SpmGrids
using GLMakie  # use any Makie backend you like

grid = load_grid("Bias_spectroscopy.3ds")

fig = Figure(resolution = (800, 400))
ax = Axis(fig[1, 1])

# x, y, as well as channel values can be indexed
plot_spectrum(grid, "Bias", "Frequency Shift", 8, 2:6, 20:120, backend=GLMakie)

# add legend
fig[1, 2] = Legend(fig, ax, "Legend", framevisible=false)

fig
```


## More information

A more detailed description can be found in the [Reference](@ref)
