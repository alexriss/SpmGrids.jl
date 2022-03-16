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

s = load_grid("Bias_spectrocopy.3ds")

```

## Related projects

- [SpmImageTycoon.jl](https://github.com/alexriss/SpmImageTycoon.jl): App to organize SPM images and spectra.
- [SpmImages.jl](https://github.com/alexriss/SpmImages.jl): Julia library to read and display SPM images.
- [SpmSpectroscopy.jl](https://github.com/alexriss/SpmSpectroscopy.jl): Julia library to analyze scanning tunneling and atomic force spectroscopy data.
- [imag*ex*](https://github.com/alexriss/imagex): Python scripts to analyze scanning probe images.
- [grid*ex*](https://github.com/alexriss/gridex): Python scripts to analyze 3D grid data.
