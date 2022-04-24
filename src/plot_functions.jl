const unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "µ", "n", "p", "f", "a"]
const unit_factors = [1.0e18, 1.0e15, 1.0e12, 1.0e9, 1.0e6, 1.0e3, 1.0, 1.0e-3, 1.0e-6, 1.0e-9, 1.0e-12, 1.0e-15, 1.0e-18]
# to avoid problems with float precisions, we define those here
const unit_factors_inv = [1.0e-18, 1.0e-15, 1.0e-12, 1.0e-9, 1.0e-6, 1.0e-3, 1.0, 1.0e3, 1.0e6, 1.0e9, 1.0e12, 1.0e15, 1.0e18]

const color_spectrum_fwd = "#241571"
const color_spectrum_bwd = "#B80F0A"
const color_spectrum_light_fwd = "#9495f1"
const color_spectrum_light_bwd = "#F89F9A"


"""
    get_kwargs(kwargs::Base.Pairs; bwd::Bool=false)::Dict{Symbol,Any}

Extracts the keyword arguments for forward and backward plots. The arguments for backward
plot are suffixed by `_bwd`.
"""
function get_kwargs(kwargs::Base.Pairs; bwd::Bool=false)::Dict{Symbol,Any}
    res = Dict{Symbol,Any}()
    for (k,v) in kwargs
        kstr = string(k)
        if bwd
            if endswith(kstr, "_bwd")
                res[Symbol(kstr[1:end-4])] = v
            end
        else
            if !endswith(kstr, "_bwd")
                res[Symbol(kstr)] = v
            end
        end
    end
    return res
end


"""
    combined_sort!(arr1::Vector{Float64}, arr2::Vector{Float64})::Nothing

Sorts the values in two arrays by the values in the first one.
"""
function combined_sort!(arr1::Vector{Float64}, arr2::Vector{Float64})::Nothing
    p = sortperm(arr1)
    arr1 .= arr1[p]
    arr2 .= arr2[p]
    return nothing
end


"""
    convert_to_range(r::GridRange)::GridRange

If the GridRange is an Int-type index, then it is converted to a UnitRange.
UnitRange and Colon types are left as is.
"""
function convert_to_range(r::GridRange)::GridRange
    if typeof(r) == Int
        return r:r
    else
        return r
    end
end


"""
    get_factor_prefix(number::Float64)::Tuple{Float64, String}

Determines the best SI unit prefix for the given `number`.
Returns a tuple of the factor and the prefix.
"""
function get_factor_prefix(number::Float64)::Tuple{Float64, String}
    # The format function of the Formatting library supports some of the SI prefixes, but
    # 1. only down to pico, and 2. it will not convert 0.05 as 50.0m (instead as 0.0)

    if number == 0.  # use `==` because 0. !== -0.
        return 1., ""
    end

    unit_prefix = unit_prefixes[end]
    unit_factor_inv = unit_factors_inv[end]

    number_abs = abs(number)
    for (i, factor) in enumerate(unit_factors)
        if number_abs >= factor
            unit_prefix = unit_prefixes[i]
            unit_factor_inv = unit_factors_inv[i]
            break
        end
    end
    return unit_factor_inv, unit_prefix
end


"""
    function get_factor_prefix(numbers::Array{Float64})::Tuple{Float64, String}

Determines the best SI unit prefix for a given array `numbers`.
Returns a tuple of the factor and the prefix.
"""
function get_factor_prefix(numbers::AbstractArray{<:Float64})::Tuple{Float64, String}
    abs_numbers = abs.(skipnan(numbers))
    if length(abs_numbers) === 0
        return 1.0, ""
    end
    return get_factor_prefix(maximum(abs_numbers))
end


"""
    format_with_prefix(number::Float64; delimiter::String="")::String

formats a number to a notation that uses SI prefixes.
"""
function format_with_prefix(number::Float64; delimiter::String=" ")::String
    if number === 0.
        return "0$delimiter"
    end
    if number === NaN
        return "$delimiter"
    end
    unit_factor, unit_prefix = get_factor_prefix(number)
    number = number * unit_factor
    return @sprintf("%0.2f", number) * "$delimiter$unit_prefix"
end


"""
    get_sweep_span(data::Array{Float64,3})::Vector{Float64}

Extracts the maximum valid range of the sweep signal (first dimension in `data`),
i.e. it picks the values along this axis that are not NaNs.
It also checks if all values are equal across the other dimensions.
"""
function get_sweep_span(data::AbstractArray{Float64,3})::Vector{Float64}
    res = data[1, 1, :]
    for i in 1:length(res)
        dataf = filter(!isnan, @view data[:, :, i])
        if length(dataf) == 0
            res[i] = NaN
        else
            res[i] = dataf[1]
            if !all(dataf .== dataf[1])
                @warn "Sweep signal is not constant across x,y dimensions."
            end
        end
    end
    return res
end


"""
    get_range(data::Array{Float64})::Tuple{Float64,Float64}

Calculates range (i.e. min and max) of data. If all data is the same, the range is expanded.
"""
function get_range(data::Array{Float64})::Tuple{Float64,Float64}
    data = skipnan(data)
    if length(data) === 0
        data = [0.]
    end
    data_min = minimum(data)
    data_max = maximum(data)
    if data_min == data_max  # makie seems to have problems with the colorbars if min=max
        delta = max(1e-2, abs(data_min) * 1e-2)  # since the data is always normalized, we can do this
        data_min -= delta
        data_max += delta
    end
    return (data_min, data_max)
end


"""
    axis_label(name::String, unit::String="",  prefix::String="")::String

Formats axis label in the form of `name / prefix unit`.
"""
function axis_label(name::String, unit::String="", prefix::String="")::String
    return "$name / $(prefix)$(unit)"
end


"""
    axis_label(grid::SpmGrid, name::String, prefix::String="")::String

Formats axis label in the form of `name / prefix unit`.
`unit` is ommited if a corresponding `unit` can not be found to the given `name` of a channel.
"""
function axis_label(grid::SpmGrid, name::String, prefix::String="")::String
    if haskey(grid.channel_units, name)
        unit = grid.channel_units[name]
    else
        unit = ""
    end
    
    return axis_label(name, unit, prefix)
end


"""
    axis_parameter_label(grid::SpmGrid, name::String, prefix::String="")::String

Formats axis label in the form of `name / prefix unit`.
`unit` is ommited if a corresponding `unit` can not be found to the given `name` of a parameter.
"""
function axis_parameter_label(grid::SpmGrid, name::String, prefix::String="")::String
    unit = get_parameter_unit(grid, name)
    return axis_label(name, unit, prefix)
end


"""
    check_makie_loaded(backend::Module, ax::Any=nothing; axis3::Bool=false)::Nothing

Checks if a [Makie](https://makie.juliaplots.org/) backend is loaded. Throws an error if none is loaded.
Sets the `current_axis` to `ax`. Also sets up a figure and axis if necessary.
If `axis3` is `true` then it sets up a 3D axis.
"""
function check_makie_loaded(backend::Module, ax::Any=nothing; axis3::Bool=false)::Nothing
    if !isdefined(backend, :GLMakie) && !isdefined(backend, :CairoMakie) && !isdefined(backend, :WGLMakie)
        error("No Makie backend loaded. Please load either the GL, Cairo or WGL backends. See https://makie.juliaplots.org/ for more information.")
    end

    if backend.current_figure() === nothing
        backend.Figure()
    end

    if backend.current_axis() === nothing && ax === nothing
        if axis3
            backend.Axis3(backend.current_figure()[1,1], perspectiveness=0.5)
        else
            backend.Axis(backend.current_figure()[1,1])
        end
    elseif ax === nothing
        ax = backend.current_axis()
    else
        backend.current_axis!(ax)
    end

    if axis3 && typeof(backend.current_axis()) != backend.Axis3
        @warn "The current axis is not a 3D axis. Please use a 3D axis for 3D plots. Generating a 3D axis at [1,1]."
        backend.Axis3(backend.current_figure()[1,1], perspectiveness=0.5)
    elseif !axis3 && typeof(backend.current_axis()) != backend.Axis
        @warn "The current axis is not a 2D axis. Please use a 2D axis for 2D plots. Generating a 2D axis at [1,1]."
        backend.Axis(backend.current_figure()[1,1])
    end

    return nothing
end


"""
    plot_spectrum(grid::SpmGrid, sweep_channel::String, response_channel::String,
        x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;
        bwd::Bool=true, ax::Any=nothing, backend::Module=Main,
        kwargs...)::NamedTuple

Plots a line plot of `response_channel` vs `sweep_channel` on the given `x_index` and `y_index`.
If `sweep_channel` is `""`, then the sweep signal will be used for `sweep_channel`.
Additionally, the spectrum data can be indexed by `channel_index`.
If `bwd` is `true` (default), the plot will include data from backward sweep as well (if they exist).

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.
Keyword arrguments with the suffix `_bwd` will be used for plotting of the backward scan.

Returns a NamedTuple.
"""
function plot_spectrum(grid::SpmGrid, sweep_channel::String, response_channel::String,
    x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;
    bwd::Bool=true, ax::Any=nothing, backend::Module=Main,
    kwargs...)::NamedTuple

    check_makie_loaded(backend, ax)
    ax = backend.current_axis()

    if sweep_channel === ""
        sweep_channel = grid.sweep_signal
    end

    x_index = convert_to_range(x_index)
    y_index = convert_to_range(y_index)
    channel_index = convert_to_range(channel_index)

    x = get_channel(grid, sweep_channel, x_index, y_index, channel_index)
    y = get_channel(grid, response_channel, x_index, y_index, channel_index)

    @assert size(x) == size(y)

    if has_channel(grid, sweep_channel, bwd=true) && has_channel(grid, response_channel, bwd=true)
        x_bwd = get_channel(grid, channel_name_bwd(sweep_channel), x_index, y_index, channel_index)
        y_bwd = get_channel(grid, channel_name_bwd(response_channel), x_index, y_index, channel_index)
        @assert size(x) == size(x_bwd) == size(y_bwd)
    else
        x_bwd = Float64[]
        y_bwd = Float64[]
    end

    x_all = vcat(vec(x), vec(x_bwd))
    y_all = vcat(vec(y), vec(y_bwd))
    x_factor, x_prefix = get_factor_prefix(x_all)
    y_factor, y_prefix = get_factor_prefix(y_all)

    x_label = SpmGrids.axis_label(grid, sweep_channel, x_prefix)
    y_label = SpmGrids.axis_label(grid, response_channel, y_prefix)
    ax.xlabel = x_label
    ax.ylabel = y_label

    if x_index === Colon()
        x_index = 1:size(x, 2)
    end
    if y_index === Colon()
        y_index = 1:size(x, 3)
    end

    kwargs_fwd = get_kwargs(kwargs)
    kwargs_bwd = get_kwargs(kwargs, bwd=true)

    n = max(2, length(x_index) * length(y_index)) # should be at least 2 to create the cgrad in the next line
    colors_fwd = backend.cgrad([color_spectrum_fwd, color_spectrum_light_fwd], n)
    colors_bwd = backend.cgrad([color_spectrum_bwd, color_spectrum_light_bwd], n)
    i = 1
    for (i_x,idx_x) in enumerate(x_index), (i_y,idx_y) in enumerate(y_index)
        x_plot = @view x[i_x, i_y, :]
        y_plot = @view y[i_x, i_y, :]
        if bwd && length(x_bwd) > 0
            x_plot_bwd = @view x_bwd[i_x, i_y, :]
            y_plot_bwd = @view y_bwd[i_x, i_y, :]
        end

        x_plot = x_plot .* x_factor
        y_plot = y_plot .* y_factor
        # sort x axis if necessary
        if !issorted(x_plot) && !issorted(x_plot, rev=true)
            combined_sort!(x_plot, y_plot)
        end
        if bwd && length(x_bwd) > 0
            x_plot_bwd = x_plot_bwd .* x_factor
            y_plot_bwd = y_plot_bwd .* y_factor
            if !issorted(x_plot_bwd) && !issorted(x_plot_bwd, rev=true)
                combined_sort!(x_plot_bwd, y_plot_bwd)
            end
        end

        label = "$(idx_x), $(idx_y)"
        backend.scatterlines!(ax, x_plot, y_plot,
            linewidth=2, markersize=2, color=colors_fwd[i], label=label;
            kwargs_fwd...)
        if bwd && length(x_bwd) > 0
            backend.scatterlines!(x_plot_bwd, y_plot_bwd,
                linewidth=2, markersize=2, color=colors_bwd[i], label="$label bwd";
                kwargs_bwd...)
        end

        i+=1
    end

    return (x_factor=x_factor, y_factor=y_factor)
end


"""
    get_data_line(grid::SpmGrid, response_channel::String,
        x_index::GridRange, y_index::GridRange, channel_index::GridRange=nothing;
        sweep_channel::String="", bwd::Bool=true, observable::Bool=false)

Returns the data used for a line plot of `response_channel` along a line in the three-dimensional data spanned by x,y plane and the spectroscopy data.
Indexing is done through `x_index`, `y_index` and `channel_index` and should be done such that a
one-dimensional array is obtained.
It is also possible to plot `response_channel` vs `sweep_channel`
(which defaults to the sweep signal if not specified) for one point in the grid
If `bwd` is `true` (default), the plot will include data from backward sweep as well (if they exist).
If `observable` is set to `true`, then observables are returned.

Returns a NamedTuple.
"""
function get_data_line(grid::SpmGrid, response_channel::String,
    x_index::GridRange, y_index::GridRange, channel_index::GridRange=nothing;
    sweep_channel::String="", bwd::Bool=true, observable::Bool=false)
    x_index = convert_to_range(x_index)
    y_index = convert_to_range(y_index)
    channel_index = convert_to_range(channel_index)

    y = get_channel(grid, response_channel, x_index, y_index, channel_index)

    if count(isequal(1), size(y)) < 2 || !all(size(y) .> 0)
        throw(ArgumentError("Use indexes to obtain a one-dimensional array (e.g. of size 128,1,1). Currently, the array size is $(size(y))."))
    end

    if has_channel(grid, response_channel, bwd=true)
        y_bwd = get_channel(grid, channel_name_bwd(response_channel), x_index, y_index, channel_index)
        @assert size(y_bwd) == size(y)
    else
        x_bwd = Float64[]
        y_bwd = Float64[]
    end

    nx, ny, nc = size(y)
    gridx_span = range(0, grid.size[1], length=grid.pixelsize[1])
    gridy_span = range(0, grid.size[2], length=grid.pixelsize[2])
    sweep_span = get_channel(grid, grid.sweep_signal, 1, 1, :)
    if nx != 1
        x = gridx_span[x_index]
        x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid x", grid.size_unit, x_prefix)
        point1 = format_with_prefix(gridy_span[y_index[]]) * grid.size_unit
        point2 = format_with_prefix(sweep_span[channel_index[]]) * grid.channel_units[grid.sweep_signal]
        label = "grid y=$point1, $(grid.sweep_signal)=$point2"
        y = @view y[:, 1, 1]  # all other dimensions are of length 1
        if length(y_bwd) > 0
            x_bwd = x
            y_bwd = @view y_bwd[:, 1, 1]
        end
    elseif ny != 1
        x = gridy_span[y_index]
        x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid y", grid.size_unit, x_prefix)
        point1 = format_with_prefix(gridx_span[x_index[]]) * grid.size_unit
        point2 = format_with_prefix(sweep_span[channel_index[]]) * grid.channel_units[grid.sweep_signal]
        label = "grid x=$point1, $(grid.sweep_signal)=$point2"
        y = @view y[1, :, 1]  # all other dimensions are of length 1
        if length(y_bwd) > 0
            x_bwd = x
            y_bwd = @view y_bwd[1, :, 1]
        end
    else
        if sweep_channel === ""
            sweep_channel = grid.sweep_signal
        end
        x = get_channel(grid, sweep_channel, x_index[], y_index[], channel_index)
        if length(y_bwd) > 0
            sweep_channel_bwd = channel_name_bwd(sweep_channel)
            if sweep_channel in grid.channel_names
                x_bwd = get_channel(grid, sweep_channel_bwd, x_index[], y_index[], channel_index)
            else
                x_bwd = x
            end
            y_bwd = @view y_bwd[1, 1, :]
        end
        x_factor, x_prefix = get_factor_prefix(vcat(x, x_bwd))
        x_label = axis_label(grid, sweep_channel, x_prefix)
        point1 = format_with_prefix(gridx_span[x_index[]]) * grid.size_unit
        point2 = format_with_prefix(gridy_span[y_index[]]) * grid.size_unit
        label= "grid x=$point1, grid y=$point2"
        y = @view y[1, 1, :]  # all other dimensions are of length 1
    end
    y_factor, y_prefix = get_factor_prefix(vcat(y, y_bwd))
    y_label = axis_label(grid, response_channel, y_prefix)

    x = x .* x_factor
    y = y .* y_factor

    # sort x axis if necessary
    if !issorted(skipnan(x)) && !issorted(skipnan(x), rev=true)
        @show "unsorted", x
        combined_sort!(x, y)
    end
    if bwd && length(y_bwd) > 0
        x_bwd = x_bwd .* x_factor
        y_bwd = y_bwd .* y_factor
        if !issorted(skipnan(x_bwd)) && !issorted(skipnan(x_bwd), rev=true)
            combined_sort!(x_bwd, y_bwd)
        end
    end

    xy = Point2.(x, y)
    xy_bwd = Point2.(x_bwd, y_bwd)

    if observable
        return (xy=Observable(xy), xy_bwd=Observable(xy_bwd),
            x_factor=Observable(x_factor), x_prefix=Observable(x_prefix), x_label=Observable(x_label),
            y_factor=Observable(y_factor), y_prefix=Observable(y_prefix), y_label=Observable(y_label),
            plot_label=Observable(label))
    else
        return (xy=xy, xy_bwd=xy_bwd,
            x_factor=x_factor, x_prefix=x_prefix, x_label=x_label,
            y_factor=y_factor, y_prefix=y_prefix, y_label=y_label,
            plot_label=label)
    end
end


"""
    plot_line(grid::SpmGrid, response_channel::String,
        x_index::GridRange, y_index::GridRange, channel_index::GridRange=nothing;
        sweep_channel::String="", bwd::Bool=true, ax::Any=nothing, backend::Module=Main,
        kwargs...)::NamedTuple

Plots the `response_channel` along a line in the three-dimensional data spanned by x,y plane and the spectroscopy data.
Indexing is done through `x_index`, `y_index` and `channel_index` and should be done such that a
one-dimensional array is obtained.
It is also possible to plot `response_channel` vs `sweep_channel`
(which defaults to the sweep signal if not specified) for one point in the grid
If `bwd` is `true` (default), the plot will include data from backward sweep as well (if they exist).

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.
Keyword arrguments with the suffix `_bwd` will be used for plotting of the backward scan.    

Returns a NamedTuple.
"""
function plot_line(grid::SpmGrid, response_channel::String,
    x_index::GridRange, y_index::GridRange, channel_index::GridRange=nothing;
    sweep_channel::String="", bwd::Bool=true, ax::Any=nothing, backend::Module=Main,
    kwargs...)::NamedTuple

    check_makie_loaded(backend, ax)
    ax = backend.current_axis()

    data = get_data_line(grid, response_channel, x_index, y_index, channel_index,
        sweep_channel=sweep_channel, bwd=bwd)

    ax.xlabel = data.x_label
    ax.ylabel = data.y_label
    
    kwargs_fwd = get_kwargs(kwargs)
    kwargs_bwd = get_kwargs(kwargs, bwd=true)

    backend.scatterlines!(data.xy,
        linewidth=2, markersize=2, color=color_spectrum_fwd, label=data.plot_label;
        kwargs_fwd...)
    if bwd && length(data.xy_bwd) > 0
        backend.scatterlines!(data.xy_bwd,
            linewidth=2, markersize=2, color=color_spectrum_bwd, label="$(data.plot_label) bwd";
            kwargs_bwd...)
    end

    return (x_factor=data.x_factor, y_factor=data.y_factor, plot_label=data.plot_label)
end


"""
    get_data_parameter_plane(grid::SpmGrid, parameter::String,
        x_index=:::GridRange, y_index=:::GridRange;
        backend::Module=Main, observable::Bool=false)::NamedTuple


Returns the data used for a plane plot of `parameter` in the three-dimensional data
spanned by x,y plane and the parameter. Indexing is done through `x_index`, `y_index`
and should be done such that a two-dimensional array is obtained.
If `observable` is set to `true`, then observables are returned.
A Makie backend should be given, too.

Returns a NamedTuple.
"""
function get_data_parameter_plane(grid::SpmGrid, parameter::String,
    x_index::GridRange=:, y_index::GridRange=:;
    backend::Module=Main, observable::Bool=false)::NamedTuple

    x_index = convert_to_range(x_index)
    y_index = convert_to_range(y_index)

    z = get_parameter(grid, parameter, x_index, y_index)

    if !all(size(z) .> 0)
        throw(ArgumentError("Use indexes to obtain a two-dimensional array (e.g. of size 128,128). Currently, the array size is $(size(z))."))
    end

    gridx_span = range(0, grid.size[1], length=grid.pixelsize[1])
    gridy_span = range(0, grid.size[2], length=grid.pixelsize[2])
    x = gridx_span[x_index]
    y = gridy_span[y_index]

    # common scale for both x and y
    xy_prefix, xy_factor = get_factor_prefix(collect(vcat(x, y)))
    x_factor, x_prefix = xy_prefix, xy_factor
    y_factor, y_prefix = xy_prefix, xy_factor
    x_label = axis_label("grid x", grid.size_unit, x_prefix)
    y_label = axis_label("grid y", grid.size_unit, y_prefix)

    label = parameter
    ax_aspect = backend.DataAspect()

    z_factor, z_prefix = get_factor_prefix(z)
    z_label = axis_parameter_label(grid, parameter, z_prefix)

    x = collect(x) .* x_factor
    y = collect(y) .* y_factor
    z = collect(z) .* z_factor

    if observable
        return (x=Observable(x), y=Observable(y), data=Observable(z),
            colorrange=Observable(get_range(z)),
            x_factor=Observable(x_factor), x_prefix=Observable(x_prefix), x_label=Observable(x_label),
            y_factor=Observable(y_factor), y_prefix=Observable(y_prefix), y_label=Observable(y_label),
            data_factor=Observable(z_factor), data_prefix=Observable(z_prefix), data_label=Observable(z_label),
            plot_label=Observable(label), ax_aspect=Observable(ax_aspect))
    else
        return (x=x, y=y, data=z,
            colorrange=get_range(z),
            x_factor=x_factor, x_prefix=x_prefix, x_label=x_label,
            y_factor=y_factor, y_prefix=y_prefix, y_label=y_label,
            data_factor=z_factor, data_prefix=z_prefix, data_label=z_label,
            plot_label=label, ax_aspect=ax_aspect)
    end
end


"""
plot_parameter_plane(grid::SpmGrid, parameter::String,
        x_index::GridRange=:, y_index::GridRange=:;
        ax::Any=nothing, backend::Module=Main,
        kwargs...)::NamedTuple

Plots values of `parameters` as a function of the x,y plane
Indexing is done through `x_index`, `y_index`.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.

Returns a NamedTuple containing the heatmap, the colorbar label and the plot label.
"""
function plot_parameter_plane(grid::SpmGrid, parameter::String,
    x_index::GridRange=:, y_index::GridRange=:;
    ax::Any=nothing, backend::Module=Main,
    kwargs...)::NamedTuple

    check_makie_loaded(backend, ax)
    ax = backend.current_axis()

    data = get_data_parameter_plane(grid, parameter, x_index, y_index, backend=backend)

    ax.aspect = data.ax_aspect
    ax.xlabel = data.x_label
    ax.ylabel = data.y_label
    
    hm = backend.heatmap!(data.x, data.y, data.data,
        colormap=:grays, colorrange=data.colorrange, label=data.plot_label; kwargs...)

    return (
        x_factor=data.x_factor, y_factor=data.y_factor, data_factor=data.data_factor,
        plot=hm, data_label=data.data_label, plot_label=data.plot_label
    )
end


"""
    get_data_plane(grid::SpmGrid, response_channel::String,
        x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;
        bwd::Bool=false, backend::Module=Main, observable::Bool=false)::NamedTuple


Returns the data used for a plane plot of `response_channel` in the three-dimensional data
spanned by x,y plane and the sweep signal. Indexing is done through `x_index`, `y_index`
and `channel_index` and should be done such that a two-dimensional array is obtained.
If `bwd` is set to `true`, then data from the backward sweep is plotted if it exists.
If `observable` is set to `true`, then observables are returned.
A Makie backend should be given, too.
    
Returns a NamedTuple.
"""
function get_data_plane(grid::SpmGrid, response_channel::String,
    x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;
    bwd::Bool=false, backend::Module=Main, observable::Bool=false)::NamedTuple

    # for now, the sweep_channel is always the sweep signal
    # it is the only one that has the same values for all points
    sweep_channel = grid.sweep_signal

    x_index = convert_to_range(x_index)
    y_index = convert_to_range(y_index)
    channel_index = convert_to_range(channel_index)

    if bwd
        if has_channel(grid, response_channel, bwd=true)
            response_channel = channel_name_bwd(response_channel)
        else
            @warn """No backward sweep data for channel "$response_channel"."""
        end
        if has_channel(grid, sweep_channel, bwd=true)
            sweep_channel = channel_name_bwd(sweep_channel)
        else
            @warn """No backward sweep data for channel "$sweep_channel"."""
        end
    end

    z = get_channel(grid, response_channel, x_index, y_index, channel_index)

    if count(isequal(1), size(z)) < 1 || !all(size(z) .> 0)
        throw(ArgumentError("Use indexes to obtain a two-dimensional array (e.g. of size 128,1,5). Currently, the array size is $(size(z))."))
    end

    nx, ny, nc = size(z)
    gridx_span = range(0, grid.size[1], length=grid.pixelsize[1])
    gridy_span = range(0, grid.size[2], length=grid.pixelsize[2])
    sweep_span = get_sweep_span(get_channel(grid, grid.sweep_signal, x_index, y_index, :))
    if nx != 1 && nc != 1
        x = gridy_span[x_index]
        y = sweep_span[channel_index]
        
        x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid x", grid.size_unit, x_prefix)
        y_factor, y_prefix = get_factor_prefix(y)
        y_label = axis_label(grid, sweep_channel, y_prefix)
        
        point = format_with_prefix(gridy_span[y_index[]]) * grid.size_unit
        label = "grid y=$point"

        ax_aspect = 1
        z = @views z[:, 1, :]  # y dimension is 1
    elseif ny != 1 && nc != 1
        x = gridx_span[y_index]
        y = sweep_span[channel_index]
        
        x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid y", grid.size_unit, x_prefix)
        y_factor, y_prefix = get_factor_prefix(y)
        y_label = axis_label(grid, sweep_channel, y_prefix)
        
        point = format_with_prefix(gridx_span[x_index[]]) * grid.size_unit
        label = "grid x=$point"

        ax_aspect = 1
        z = @views z[1, :, :] # x dimension is 1
    else
        x = gridx_span[x_index]
        y = gridy_span[y_index]

        # we need a common factor and prefix
        xy_prefix, xy_factor = get_factor_prefix(collect(vcat(x, y)))
        x_factor, x_prefix = xy_prefix, xy_factor
        y_factor, y_prefix = xy_prefix, xy_factor
        # x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid x", grid.size_unit, x_prefix)
        # y_factor, y_prefix = get_factor_prefix(collect(y))
        y_label = axis_label("grid y", grid.size_unit, y_prefix)

        c = sweep_span[channel_index][]
        point = format_with_prefix(c) * grid.channel_units[grid.sweep_signal]
        label = "$(grid.sweep_signal)=$point"

        ax_aspect = backend.DataAspect()
        z = @view z[:, :, 1]  # channel dimension is 1
    end

    z_factor, z_prefix = get_factor_prefix(z)
    z_label = axis_label(grid, response_channel, z_prefix)

    x = collect(x) .* x_factor
    y = collect(y) .* y_factor
    z = collect(z) .* z_factor

    if observable
        return (x=Observable(x), y=Observable(y), data=Observable(z),
            colorrange=Observable(get_range(z)),
            x_factor=Observable(x_factor), x_prefix=Observable(x_prefix), x_label=Observable(x_label),
            y_factor=Observable(y_factor), y_prefix=Observable(y_prefix), y_label=Observable(y_label),
            data_factor=Observable(z_factor), data_prefix=Observable(z_prefix), data_label=Observable(z_label),
            plot_label=Observable(label), ax_aspect=Observable(ax_aspect))
    else
        return (x=x, y=y, data=z,
            colorrange=get_range(z),
            x_factor=x_factor, x_prefix=x_prefix, x_label=x_label,
            y_factor=y_factor, y_prefix=y_prefix, y_label=y_label,
            data_factor=z_factor, data_prefix=z_prefix, data_label=z_label,
            plot_label=label, ax_aspect=ax_aspect)
    end

end



"""
    plot_plane(grid::SpmGrid, response_channel::String,
        x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;
        bwd::Bool=false, ax::Any=nothing, backend::Module=Main,
        kwargs...)::NamedTuple

Plots a plane of `response_channel` in the three-dimensional data spanned by x,y plane and the sweep signal.
Indexing is done through `x_index`, `y_index` and `channel_index` and should be done such that a
two-dimensional array is obtained.
If `bwd` is set to `true`, then data from the backward sweep is plotted if it exists.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.

Returns a NamedTuple containing the heatmap, the colorbar label and the plot label.
"""
function plot_plane(grid::SpmGrid, response_channel::String,
    x_index::GridRange, y_index::GridRange, channel_index::GridRange=:;
    bwd::Bool=false, ax::Any=nothing, backend::Module=Main,
    kwargs...)::NamedTuple

    check_makie_loaded(backend, ax)
    ax = backend.current_axis()

    data = get_data_plane(grid, response_channel, x_index, y_index, channel_index,
        bwd=bwd, backend=backend)

    ax.aspect = data.ax_aspect
    ax.xlabel = data.x_label
    ax.ylabel = data.y_label
    
    hm = backend.heatmap!(data.x, data.y, data.data,
        colormap=:grays, colorrange=data.colorrange, label=data.plot_label; kwargs...)

    return (
        x_factor=data.x_factor, y_factor=data.y_factor, data_factor=data.data_factor,
        plot=hm, data_label=data.data_label, plot_label=data.plot_label
    )
end


"""
    get_data_cube(grid::SpmGrid, response_channel::String,
        x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
        bwd::Bool=false)::NamedTuple

Returns the data used for a cube plot of `response_channel` in the three-dimensional data spanned
by the x,y plane and the sweep signal. Indexing is done through `x_index`, `y_index` and
`channel_index` and should be done such that a three-dimensional array is obtained.
If `bwd` is set to `true`, then data from the backward sweep is plotted if it exists.
If `observable` is set to `true`, then observables are returned.

Returns a NamedTuple.
"""
function get_data_cube(grid::SpmGrid, response_channel::String,
    x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
    bwd::Bool=false, observable::Bool=false)::NamedTuple

    # for now, the sweep_channel is always the sweep signal
    # it is the only one that has the same values for all points
    sweep_channel = grid.sweep_signal

    x_index = convert_to_range(x_index)
    y_index = convert_to_range(y_index)
    channel_index = convert_to_range(channel_index)

    if bwd
        if has_channel(grid, response_channel, bwd=true)
            response_channel = channel_name_bwd(response_channel)
        else
            @warn """No bwd sweep data for channel "$response_channel"."""
        end
        if has_channel(grid, sweep_channel, bwd=true)
            sweep_channel = channel_name_bwd(sweep_channel)
        else
            @warn """No backward sweep data for channel "$sweep_channel"."""
        end
    end

    data = get_channel(grid, response_channel, x_index, y_index, channel_index)

    if !all(size(data) .> 0)
        throw(ArgumentError("Use indexes to obtain a three-dimensional array (e.g. of size 128,5,5). Currently, the array size is $(size(data))."))
    end

    gridx_span = range(0, grid.size[1], length=grid.pixelsize[1])
    gridy_span = range(0, grid.size[2], length=grid.pixelsize[2])
    sweep_span = get_sweep_span(get_channel(grid, grid.sweep_signal, x_index, y_index, :))
    x = gridx_span[x_index]
    y = gridy_span[y_index]
    z = sweep_span[channel_index]

    x_factor, x_prefix = get_factor_prefix(collect(x))
    x_label = axis_label("grid x", grid.size_unit, x_prefix)
    y_factor, y_prefix = get_factor_prefix(collect(y))
    y_label = axis_label("grid y", grid.size_unit, y_prefix)
    z_factor, z_prefix = get_factor_prefix(collect(z))
    z_label = axis_label(grid, sweep_channel, z_prefix)
    
    aspect_x = abs(x[end] - x[begin])
    aspect_y = abs(y[end] - y[begin])
    aspect_z = max(aspect_x, aspect_y)
    ax_aspect = (aspect_x, aspect_y, aspect_z)

    data_factor, data_prefix = get_factor_prefix(data)
    data_label = axis_label(grid, response_channel, data_prefix)
    data_plot = data .* data_factor

    # get rid of NaN values in the sweep signal
    sel = findall(!isnan, z)
    z = (z .* z_factor)[sel]
    data_plot = data_plot[:, :, sel]
    x = collect(x .* x_factor)
    y = collect(y .* y_factor)

    # we have to sort the z values, because toehrwise there is a bug in the volume plot
    # see https://github.com/JuliaPlots/ Makie.jl/issues/1781
    if !issorted(z)
        p = sortperm(z)
        z_sorted = z[p]
        data_plot_sorted = data_plot[:, :, p]
    else
        z_sorted = z
        data_plot_sorted = data_plot
    end

    colorrange = get_range(data_plot)
    
    if observable
        return (x=Observable(x), y=Observable(y), z=Observable(z), data=Observable(data_plot),
            z_sorted=Observable(z_sorted), data_sorted=Observable(data_plot_sorted),
            colorrange=Observable(colorrange),
            x_factor=Observable(x_factor), x_prefix=Observable(x_prefix), x_label=Observable(x_label),
            y_factor=Observable(y_factor), y_prefix=Observable(y_prefix), y_label=Observable(y_label),
            z_factor=Observable(z_factor), z_prefix=Observable(z_prefix), z_label=Observable(z_label),
            data_factor=Observable(data_factor), data_prefix=Observable(data_prefix), data_label=Observable(data_label),
            ax_aspect=Observable(ax_aspect))
    else
        return (x=x, y=y, z=z, data=data_plot,
            z_sorted=z_sorted, data_sorted=data_plot_sorted,
            colorrange=colorrange,
            x_factor=x_factor, x_prefix=x_prefix, x_label=x_label,
            y_factor=y_factor, y_prefix=y_prefix, y_label=y_label,
            z_factor=z_factor, z_prefix=z_prefix, z_label=z_label,
            data_factor=data_factor, data_prefix=data_prefix, data_label=data_label,
            ax_aspect=ax_aspect)
    end
end


"""
    plot_cube(grid::SpmGrid, response_channel::String,
        x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
        bwd::Bool=false, ax::Any=nothing, backend::Module=Main,
        kwargs...)::NamedTuple


Plots a cube of `response_channel` in the three-dimensional data spanned by the x,y plane and the sweep signal.
Indexing is done through `x_index`, `y_index` and `channel_index` and should be done such that a
three-dimensional array is obtained.
If `bwd` is set to `true`, then data from the backward sweep is plotted if it exists.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.

Returns a NamedTuple containing the volume-plot, and a colorbar label.
"""
function plot_cube(grid::SpmGrid, response_channel::String,
    x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
    bwd::Bool=false, ax::Any=nothing, backend::Module=Main,
    kwargs...)::NamedTuple

    check_makie_loaded(backend, ax, axis3=true)
    ax = backend.current_axis()

    data = get_data_cube(grid, response_channel, x_index, y_index, channel_index,
        bwd=bwd)

    ax.xlabel = data.x_label
    ax.ylabel = data.y_label
    ax.zlabel = data.z_label
    ax.aspect = data.ax_aspect

    # we have to plot z_sorted and data_sorted, 
    # wrong plots are obntained if the axes indices are not sorted in ascending order
    # see https://github.com/JuliaPlots/Makie.jl/issues/1781
    if length(data.z_sorted) === 0
        vol = nothing
    else
        vol = backend.volume!(data.x, data.y, data.z_sorted,
            data.data_sorted, colorrange=data.colorrange,
            transparency=true, colormap=:grays;
            kwargs...)
    end

    return (
        x_factor=data.x_factor, y_factor=data.y_factor, z_factor=data.z_factor,
        data_factor=data.data_factor,
        plot=vol, data_label=data.data_label
    )
end
