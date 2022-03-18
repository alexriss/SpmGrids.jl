const unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "µ", "n", "p", "f", "a"]
const unit_factors = [1.0f18, 1.0f15, 1.0f12, 1.0f9, 1.0f6, 1.0f3, 1.0, 1.0f-3, 1.0f-6, 1.0f-9, 1.0f-12, 1.0f-15, 1.0f-18]

const color_spectrum_fwd = "#241571"
const color_spectrum_bwd = "#B80F0A"
const color_spectrum_light_fwd = "#9495f1"
const color_spectrum_light_bwd = "#F89F9A"


skipnan(x) = filter(!isnan, x)


"""
    get_kwargs(kwargs::Base.Pairs; backward::Bool=false)::Dict{Symbol,Any}

Extracts the keyword arguments for forward and backward plots. The arguments for backward
plot are suffixed by `_bwd`.
"""
function get_kwargs(kwargs::Base.Pairs; backward::Bool=false)::Dict{Symbol,Any}
    res = Dict{Symbol,Any}()
    for (k,v) in kwargs
        kstr = string(k)
        if backward
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
    get_factor_prefix(number::Float32)::Tuple{Float32, String}

Determines the best SI unit prefix for the given `number`.
Returns a tuple of the factor and the prefix.
"""
function get_factor_prefix(number::Float32)::Tuple{Float32, String}
    # The format function of the Formatting library supports some of the SI prefixes, but
    # 1. only down to pico, and 2. it will not convert 0.05 as 50.0m (instead as 0.0)

    unit_prefix = unit_prefixes[end]
    unit_factor = unit_factors[end]

    number_abs = abs(number)
    for (i, factor) in enumerate(unit_factors)
        if number_abs >= factor
            unit_prefix = unit_prefixes[i]
            unit_factor = factor
            break
        end
    end
    return unit_factor, unit_prefix
end


"""
    format_with_prefix(number::Float32; delimiter::String="")::String

formats a number to a notation that uses SI prefixes.
"""
function format_with_prefix(number::Float32; delimiter::String=" ")::String
    if number === 0f0
        return "0$delimiter"
    end
    unit_factor, unit_prefix = get_factor_prefix(number)
    number = number / unit_factor
    return @sprintf("%0.2f", number) * "$delimiter$unit_prefix"
end


"""
    function get_factor_prefix(numbers::Array{Float32})::Tuple{Float32, String}

Determines the best SI unit prefix for a given array `numbers`.
Returns a tuple of the factor and the prefix.
"""
function get_factor_prefix(numbers::AbstractArray{<:Float32})::Tuple{Float32, String}
    abs_numbers = abs.(skipnan(numbers))
    if length(abs_numbers) === 0
        return 1f0, ""
    end
    return get_factor_prefix(maximum(abs_numbers))
end


"""
    axis_label(name::String, unit::String="",  prefix::String="")::String

Formats axis label in the form of `name / prefix unit`.
"""
function axis_label(name::String, unit::String="",  prefix::String="")::String
    return "$name / $(prefix)$(unit)"
end


"""
    axis_label(grid::SpmGrid, name::String, prefix::String="")::String

Formats axis label in the form of `name / prefix unit`.
`unit` is ommited if a corresponding `unit` can not be found to the given `name`.
"""
function axis_label(grid::SpmGrid, name::String, prefix::String="")::String
    names = vcat(grid.channel_names, grid.experiment_parameters)
    units = vcat(grid.channel_units, grid.experiment_parameters_units)

    idx = findfirst(isequal(name), names)
    if idx === nothing
        unit = ""
    else
        unit = units[idx]
    end

    return axis_label(name, unit, prefix)
end


"""
    check_makie_loaded()::Nothing

Checks if a [Makie](https://makie.juliaplots.org/) backend is loaded. Throws an error if none is loaded.
"""
function check_makie_loaded(backend::Module)::Nothing
    if !isdefined(backend, :GLMakie) && !isdefined(backend, :CairoMakie) && !isdefined(backend, :WGLMakie)
        error("No Makie backend loaded. Please load either the GL, Cairo or WGL backends. See https://makie.juliaplots.org/ for more information.")
    end

    return nothing
end


"""
    plot_spectrum(grid::SpmGrid, channel_x::String, channel_y::String,
        index_x::GridRange, index_y::GridRange, index_channel::GridRange=:;
        backward::Bool=true, ax::Any=nothing, backend::Module=Main,
        kwargs...)::Nothing)

Plots a scatter plot of `channel_y` vs `channel_x` on the given `index_x` and `y_index`.
If `channel_x` is `""`, then the sweep signal will be used for `channel_x`.
Additionally, the spectrum data can be indexed by `index_channel`.
If `include_backward` is `true`` (default), the plot will include data from backward sweep as well (if they exist).

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.
Keyword arrguments with the suffix `_bwd` will be used for plotting of the backward scan.
"""
function plot_spectrum(grid::SpmGrid, channel_x::String, channel_y::String,
    index_x::GridRange, index_y::GridRange, index_channel::GridRange=:;
    backward::Bool=true, ax::Any=nothing, backend::Module=Main,
    kwargs...)::Nothing

    check_makie_loaded(backend)

    if ax === nothing
        ax = backend.current_axis()
    end

    if channel_x === ""
        channel_x = grid.sweep_signal
    end

    index_x = convert_to_range(index_x)
    index_y = convert_to_range(index_y)
    index_channel = convert_to_range(index_channel)

    x = get_channel(grid, channel_x, index_x, index_y, index_channel)
    y = get_channel(grid, channel_y, index_x, index_y, index_channel)

    @assert size(x) == size(y)

    if "$channel_x [bwd]" in grid.channel_names &&  "$channel_y [bwd]" in grid.channel_names
        x_bwd = get_channel(grid, "$channel_x [bwd]", index_x, index_y, index_channel)
        y_bwd = get_channel(grid, "$channel_y [bwd]", index_x, index_y, index_channel)

        @assert size(x) == size(x_bwd) == size(y_bwd)
    else
        x_bwd = Float32[]
        y_bwd = Float32[]
    end

    x_all = vcat(vec(x), vec(x_bwd))
    y_all = vcat(vec(y), vec(y_bwd))
    x_factor, x_prefix = get_factor_prefix(x_all)
    y_factor, y_prefix = get_factor_prefix(y_all)

    x_label = SpmGrids.axis_label(grid, channel_x, x_prefix)
    y_label = SpmGrids.axis_label(grid, channel_y, y_prefix)
    ax.xlabel = x_label
    ax.ylabel = y_label

    if index_x === Colon()
        index_x = 1:size(x, 2)
    end
    if index_y === Colon()
        index_y = 1:size(x, 3)
    end

    kwargs_fwd = get_kwargs(kwargs)
    kwargs_bwd = get_kwargs(kwargs, backward=true)

    n = max(2, length(index_x) * length(index_y)) # should be at least 2 to create the cgrad in the next line
    colors_fwd = backend.cgrad([color_spectrum_fwd, color_spectrum_light_fwd], n)
    colors_bwd = backend.cgrad([color_spectrum_bwd, color_spectrum_light_bwd], n)
    i = 1
    for (i_x,idx_x) in enumerate(index_x), (i_y,idx_y) in enumerate(index_y)
        x_plot = @view x[:, i_x, i_y]
        y_plot = @view y[:, i_x, i_y]
        if length(x_bwd) > 0
            x_plot_bwd = @view x_bwd[:, i_x, i_y]
            y_plot_bwd = @view y_bwd[:, i_x, i_y]
        end

        backend.scatterlines!(x_plot ./ x_factor, y_plot ./ y_factor,
            linewidth=2, markersize=2, color=colors_fwd[i], label="$(idx_x), $(idx_y)";
            kwargs_fwd...)
        if backward && length(x_bwd) > 0
            backend.scatterlines!(x_plot_bwd ./ x_factor, y_plot_bwd ./ y_factor,
                linewidth=2, markersize=2, color=colors_bwd[i], label="$(idx_x), $(idx_y) bwd";
                kwargs_bwd...)
        end

        i+=1
    end

    return nothing
end


"""
    plot_line(grid::SpmGrid, channel_y::String,
        index_x::GridRange, index_y::GridRange, index_channel::GridRange=nothing;
        channel_x::String="", backward::Bool=true, ax::Any=nothing, backend::Module=Main,
        kwargs...)::Nothing)

Plots a line in the three-dimensional data spanned by xy plane and the spectroscopy data `channel_y`.
Indexing is done through `index_x`, `index_y` and `index_channel` and should be done such that a
one-dimensional array is obtained.
It is also possible to plot `channel_y` vs `channel_x`
(which defaults ot the sweep signal if not specified) for one point in the grid
If `include_backward` is `true`` (default), the plot will include data from backward sweep as well (if they exist).

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up.
A particular Axis can be specified via the `ax` keyword argument.
By default, the Makie backend from the `Main` module is used;
it can also be directly specified via the `backend` keyword argument.

Extra keyword arguments can be specified and will be passed through to the plot function.
Keyword arrguments with the suffix `_bwd` will be used for plotting of the backward scan.    
"""
function plot_line(grid::SpmGrid, channel_y::String,
    index_x::GridRange, index_y::GridRange, index_channel::GridRange=nothing;
    channel_x::String="", backward::Bool=true, ax::Any=nothing, backend::Module=Main,
    kwargs...)::Nothing

    check_makie_loaded(backend)

    if ax === nothing
        ax = backend.current_axis()
    end

    index_x = convert_to_range(index_x)
    index_y = convert_to_range(index_y)
    index_channel = convert_to_range(index_channel)

    y = get_channel(grid, channel_y, index_x, index_y, index_channel)

    if count(isequal(1), size(y)) < 2 && all(size(y) .> 0)
        @error "Use indexes to obtain a one-dimensional array (e.g. of size 128,1,1). Currently, the array size is $(size(l))."
    end

    if "$channel_y [bwd]" in grid.channel_names
        y_bwd = get_channel(grid, "$channel_y [bwd]", index_x, index_y, index_channel)
        @assert size(y_bwd) == size(y)
    else
        y_bwd = Float32[]
    end

    nc, nx, ny = size(y)
    gridx_span = range(0, grid.size[1], length=grid.pixelsize[1])
    gridy_span = range(0, grid.size[2], length=grid.pixelsize[2])
    sweep_span = get_channel(grid, grid.sweep_signal, 1, 1, :)
    if nx != 1
        x = gridx_span[index_x]
        x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid x", grid.size_unit, x_prefix)
        point1 = format_with_prefix(gridy_span[index_y[]]) * grid.size_unit
        point2 = format_with_prefix(sweep_span[index_channel[]]) * grid.sweep_signal_unit
        label = "grid y=$point1, $(grid.sweep_signal)=$point2"
        y = @view y[1,:,1]  # all other dimensions are of length 1
        if length(y_bwd) > 0
            y_bwd = @view y_bwd[1,:,1]
        end
    elseif ny != 1
        x = gridy_span[index_y]
        x_factor, x_prefix = get_factor_prefix(collect(x))
        x_label = axis_label("grid y", grid.size_unit, x_prefix)
        point1 = format_with_prefix(gridx_span[index_x[]]) * grid.size_unit
        point2 = format_with_prefix(sweep_span[index_channel[]]) * grid.sweep_signal_unit
        label = "grid x=$point1, $(grid.sweep_signal)=$point2"
        y = @view y[1,1,:]  # all other dimensions are of length 1
        if length(y_bwd) > 0
            y_bwd = @view y_bwd[1,1,:]
        end
    else
        if channel_x === ""
            channel_x = grid.sweep_signal
        end
        x = get_channel(grid, channel_x, index_x[], index_y[], index_channel)
        x_factor, x_prefix = get_factor_prefix(x)
        x_label = axis_label(grid, channel_x, x_prefix)
        point1 = format_with_prefix(gridx_span[index_x[]]) * grid.size_unit
        point2 = format_with_prefix(gridy_span[index_y[]]) * grid.size_unit
        label= "grid x=$point1, grid y=$point2"
        y = @view y[:,1,1]  # all other dimensions are of length 1
        if length(y_bwd) > 0
            y_bwd = @view y_bwd[:,1,1]
        end
    end

    y_factor, y_prefix = get_factor_prefix(y)
    y_label = axis_label(grid, channel_y, y_prefix)
    ax.xlabel = x_label
    ax.ylabel = y_label

    kwargs_fwd = get_kwargs(kwargs)
    kwargs_bwd = get_kwargs(kwargs, backward=true)

    backend.scatterlines!(x ./ x_factor, y ./ y_factor,
        linewidth=2, markersize=2, color=color_spectrum_fwd, label=label;
        kwargs_fwd...)
    if backward && length(y_bwd) > 0
        backend.scatterlines!(x ./ x_factor, y_bwd ./ y_factor,
            linewidth=2, markersize=2, color=color_spectrum_bwd, label="$(label) bwd";
            kwargs_bwd...)
    end

    return nothing
end
