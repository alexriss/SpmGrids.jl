```@meta
CurrentModule = SpmGrids
```

# SpmGrids

Documentation for [SpmGrids](https://github.com/alexriss/SpmGrids.jl).

## About

A julia library to analyze scanning tuprobe microscopy grid data. Currently, only [Nanonis](https://www.specs-group.com/nanonis/products/) files are supported.

## Usage

```julia
using SpmGrids

grid = load_grid("Bias_spectrocopy.3ds")

c = get_channel(grid, "Current", 5, 5)  # get the current channel at point 5,5
c = get_channel(grid, "Current", :, 5)  # get the current channel for fifth row
c = get_channel(grid, "Current", :, 5, 20)  # get the 20th point of the current channel for fifth row
c = get_channel(grid, "Current", :, 5:6, 1:50)  # get the first 50 points of the current channel for fifth and sixth rows, returns a 50x20x2 Array

x = get_channel(grid, grid.sweep_signal, 5, 6)  # get the sweep signal at point 5,6

p = get_parameter(grid, "Z offset", 3, 5)  # get the `Z offset` parameter at point 3,5
```

A more detailed description can be found in the [Reference](@ref)
