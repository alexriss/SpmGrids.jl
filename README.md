<img width="100" height="100" src="docs/src/assets/logo.svg?raw=true" />

# SpmGrids.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://alexriss.github.io/SpmGrids.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://alexriss.github.io/SpmGrids.jl/dev)
[![Build Status](https://github.com/alexriss/SpmGrids.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alexriss/SpmGrids.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/alexriss/SpmGrids.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alexriss/SpmGrids.jl)

A julia library to analyze scanning probe microscopy grid data. Currently, only [Nanonis](https://www.specs-group.com/nanonis/products/) files are supported.

## Usage

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

using WGLMakie  # use any Makie backend you like
fig = Figure(resolution = (800, 400))
ax = Axis(fig[1, 1])
# line plot of `Current` vs `Bias` for all specified x and y indices
plot_spectrum(grid, "Bias", "Current", 12:10, 12)
plot_spectrum(grid, "Bias", "Current", 12:10, 12, 100:120)  # index x, y, as well as channel values

# add legend
fig[1, 2] = Legend(fig, ax, "Legend", framevisible=false)
```

## Related projects

- [SpmImageTycoon.jl](https://github.com/alexriss/SpmImageTycoon.jl): App to organize SPM images and spectra.
- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [SpmSpectroscopy.jl](https://github.com/alexriss/SpmSpectroscopy.jl): Julia library to analyze scanning tunneling and atomic force spectroscopy data.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
