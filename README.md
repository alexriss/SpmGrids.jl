﻿<img width="100" height="100" src="docs/src/assets/logo.svg?raw=true" />

# SpmGrids.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://alexriss.github.io/SpmGrids.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://alexriss.github.io/SpmGrids.jl/dev)
[![Build Status](https://github.com/alexriss/SpmGrids.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alexriss/SpmGrids.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/alexriss/SpmGrids.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alexriss/SpmGrids.jl)
<a href="https://twitter.com/00alexx"><img src="https://img.shields.io/twitter/follow/00alexx?style=social" alt="Twitter"></a>


A julia library to analyze scanning probe microscopy grid data. Currently, only [Nanonis](https://www.specs-group.com/nanonis/products/) files are supported.

## Disclaimer

Everything is experimental.

## Quick usage

```julia
using SpmGrids
using GLMakie  # you can also use the WGLMakie backend

interactive_display("Bias_spectroscopy.3ds", colormap=:bluegreenyellow)
```

![demo of interactive display](docs/src/demo_interactive.gif)

## Dive deeper

Yes, there is more. For an explanation on how to load and manipulate data and how to create plots, see the [Documentation](https://alexriss.github.io/SpmGrids.jl/stable).

## Known issues

The 3D plot sometimes does not correctly display the data. This is due to [Makie](https://makie.juliaplots.org/) issues and hopefully will be solved soon.

## Get in touch

Please post issues, suggestions, and pull requests on github. <a href="https://twitter.com/00alexx">Follow me on twitter</a> for updates and more information about this project: 
<a href="https://twitter.com/00alexx"><img src="https://img.shields.io/twitter/follow/00alexx?style=social" alt="Twitter"></a>

## Related projects

- [SpmImageTycoon.jl](https://github.com/alexriss/SpmImageTycoon.jl): App to organize SPM images and spectra.
- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [SpmSpectroscopy.jl](https://github.com/alexriss/SpmSpectroscopy.jl): Julia library to analyze scanning tunneling and atomic force spectroscopy data.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
