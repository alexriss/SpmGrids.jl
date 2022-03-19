<img width="100" height="100" src="docs/src/assets/logo.svg?raw=true" />

# SpmGrids.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://alexriss.github.io/SpmGrids.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://alexriss.github.io/SpmGrids.jl/dev)
[![Build Status](https://github.com/alexriss/SpmGrids.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alexriss/SpmGrids.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/alexriss/SpmGrids.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alexriss/SpmGrids.jl)

A julia library to analyze scanning probe microscopy grid data. Currently, only [Nanonis](https://www.specs-group.com/nanonis/products/) files are supported.

## Usage

### Loading data and parameters

```julia
using SpmGrids

grid = load_grid("Bias_spectrocopy.3ds")

c = get_channel(grid, "Current", 5, 5)  # get the current channel at point 5,5
c = get_channel(grid, "Current", :, 5)  # get the current channel for fifth row
c = get_channel(grid, "Current", :, 5, 20)  # 
# get the first 50 points of the current channel for fifth and sixth rows
# returns a 50x20x2 Arrayget the 20th point of the current channel for fifth row
c = get_channel(grid, "Current", :, 5:6, 1:50)

x = get_channel(grid, grid.sweep_signal, 5, 6)  # get the sweep signal at point 5,6

p = get_parameter(grid, "Z offset", 3, 5)  # get the `Z offset` parameter at point 3,5
```

### Plot setup

```julia
using WGLMakie  # use any Makie backend you like

fig = Figure(resolution = (800, 400))
ax = Axis(fig[1, 1])
```

### Plot spectra

```julia

# line plot of `Current` vs `Bias` for all specified x and y indices
plot_spectrum(grid, "Bias", "Current", 12:10, 12)

# you index x, y, as well as channel values
plot_spectrum(grid, "Bias", "Current", 12:10, 12, 100:120)


# add legend
fig[1, 2] = Legend(fig, ax, "Legend", framevisible=false)
fig
```

### Plot lines

```julia
# plot the `Frequency Shift` for 120th point in the sweep for the second row
plot_line(grid, "Frequency Shift", :, 2, 120, backend=CairoMakie)
fig
```

### Plot planes

```julia
# plot the `Frequency Shift` for 120th point in the sweep
hm1, cb_label1, label1 = plot_plane(grid, "Frequency Shift", :, :, 120,
    ax=ax1, backend=GLMakie)
ax1.title = label1

# add colorbars
Colorbar(g1[1, 2], hm1, label=cb_label1)

fig
```

### Plot cubes

```julia
# we need a 3d axis
fig = Figure(resolution = (500, 400));
ax = Axis3(fig[1, 1], perspectiveness=0.5)

vol, cb_label = plot_cube(grid, "Current", :, :, :, colormap=:Spectral_11)

# and the colorbar...
Colorbar(fig[1,2], vol, label=cb_label)

fig
```

## Related projects

- [SpmImageTycoon.jl](https://github.com/alexriss/SpmImageTycoon.jl): App to organize SPM images and spectra.
- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [SpmSpectroscopy.jl](https://github.com/alexriss/SpmSpectroscopy.jl): Julia library to analyze scanning tunneling and atomic force spectroscopy data.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
