# Tutorial 3: Real life examples

## Example: KPFM _(manual)_

Let's look at a real world example: [Kelvin Probe Force Microscopy (KPFM)](https://en.wikipedia.org/wiki/Kelvin_probe_force_microscope). The manual way to conduct such an experiment is to scan over a grid and sweep the bias at each point. The "Frequency Shift" vs. "Bias" can then be fitted to a parabola. We will denote the x and y positions of the maximum of this parabola as `"KPFM:Bias"` and `"KPFM:Frequency Shift"`, respectively.

Let's see how to do this in SpmGrids.

```@example kpfm
using SpmGrids
grid = load_grid("Bias_spectroscopy.3ds")

df = get_channel(grid, "Frequency Shift");
V = get_channel(grid, "Bias");

# dimensions of channels and paremeters, respectively
dim_ch = size(df)
dim_par = grid.pixelsize

# pre-define arrays for the results
kpfm_bias = Array{Float32}(undef, dim_par...)
kpfm_df = Array{Float32}(undef, dim_par...)
kpfm_fit = Array{Float32}(undef, dim_ch...)
kpfm_res = Array{Float32}(undef, dim_ch...)
kpfm_res_abs_sum = Array{Float32}(undef, dim_par...)

# loop over all x,y pixels
for ix in 1:dim_ch[1], iy in 1:dim_ch[2]
    # fit parabola to the data
    x = V[ix, iy, :]
    y = df[ix, iy, :]
    X = [ones(dim_ch[3]) x x.^2]
    coeffs = X \ y

    # coordinates of the maximum of the parabola
    c, b, a = coeffs
    kpfm_bias[ix, iy] = -b / (2 * a)
    kpfm_df[ix, iy] = c - b^2 / (4 * a)

    # fitted parabola
    kpfm_fit[ix, iy, :] .= X * coeffs

    # residuals
    kpfm_res[ix, iy, :] .= y .- kpfm_fit[ix, iy, :]
    kpfm_res_abs_sum[ix, iy] = sum(abs.(kpfm_res[ix, iy, :]))
end

# add all the data to the grid

add_parameter!(grid, "KPFM:Bias", "V", kpfm_bias)
add_parameter!(grid, "KPFM:Frequency Shift", "Hz", kpfm_df)
add_channel!(grid, "KPFM:Fit", "Hz", kpfm_fit)
add_channel!(grid, "KPFM:Residuals", "Hz", kpfm_res)
add_parameter!(grid, "KPFM:Residuals AbsSum", "Hz", kpfm_res_abs_sum)
```

And we would have to do the same for the backwards channel. But this file does not have a backwards channel. Also, there are no `NaN` values in this file. Otherwise, we would have to use a few `skipnan` functions in the code.

Now to look at the results, the easiest is to launch the [interactive widget](@ref interactive_widget):

```julia
using GLMakie
interactive_display(grid, colormap=:bluegreenyellow)
```

![screenshot of interactive display](demo_interactive_kpfm.png)

Of course all these plots can easily be generated with the plot functions. For instance:

```@example kpfm
using CairoMakie

fig = Figure(resolution = (720, 600));
ax = Axis(fig[1,1])
r = plot_line(grid, "KPFM:Fit", 5, 5, :, backend=CairoMakie, color=:red)
r = plot_line(grid, "Frequency Shift", 5, 5, :, backend=CairoMakie, color=:black)
vlines!(ax, kpfm_bias[5,5] * r.x_factor, color=:gray, linestyle=:dash)

ax = Axis(fig[2,1])
r = plot_line(grid, "KPFM:Residuals", 5, 5, :, backend=CairoMakie, color=:gray)

fig
```

## Example: KPFM _(auto)_

I can see that some might want this to be more convenient. This is why SpmGrids includes a function to do this automatically. You can do KPFM fits in just a few lines. Below is an example that
launches the [interactive display](@ref interactive_widget) at the end.

```julia
using SpmGrids
grid = load_grid("Bias_spectroscopy.3ds")
fit_KPFM!(grid, "Frequency Shift") 
interactive_display(grid, colormap=:bluegreenyellow)
```

We do not even need to specify the sweep channel. But we could - if needed. The function also handles the dreaded `NaN` values. And of course it does the fit also for backwards sweeps if they exist.

Let's look how to use it in practice and make a plot.

```@example kpfm_auto
using SpmGrids
using CairoMakie

grid = load_grid("Bias_spectroscopy.3ds")
fit_KPFM!(grid, "Frequency Shift") 

kpfm_bias = get_parameter(grid, "KPFM:Bias")

fig = Figure(resolution = (800, 330))

# plot the position of the KPFM fit for each grid point
ax1 = Axis(fig[1,1])
r1 = plot_parameter_plane(grid, "KPFM:Bias", backend=CairoMakie, colormap=:thermal)
Colorbar(fig[1, 2], r1.plot, label=r1.data_label)

# plot two selected spectra and their fits
ax2 = Axis(fig[1, 3])
points = [(2,2), (8, 17)]
colors = ["#213489", "#d96d69"]
markercolors = [:black, :white]

for (p,c, mc) in zip(points, colors, markercolors)
    # plot Frequency Shift and fit
    r2 = plot_line(grid, "KPFM:Fit", p[1], p[2], :, backend=CairoMakie, color=c)
    r2 = plot_line(grid, "Frequency Shift", p[1], p[2], :, backend=CairoMakie, color=c*"a0")

    # vertical line
    vlines!(ax2, kpfm_bias[p[1], p[2]] * r2.x_factor, color=c*"a0", linestyle=:dash)

    # mark points in the plane plot
    xycoords = xyindex_to_point(grid, p...) .* [r1.x_factor, r1.y_factor]
    scatter!(ax1, Point2(xycoords), marker=:cross, 
        color=mc, strokecolor=mc, 
        strokewidth=0.5, markersize=12)
end

fig 
```
