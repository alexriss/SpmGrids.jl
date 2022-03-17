const unit_prefixes = ["E", "P", "T", "G", "M", "k", "", "m", "µ", "n", "p", "f", "a"]
const unit_factors = [1.0f18, 1.0f15, 1.0f12, 1.0f9, 1.0f6, 1.0f3, 1.0, 1.0f-3, 1.0f-6, 1.0f-9, 1.0f-12, 1.0f-15, 1.0f-18]

const color_spectrum_fwd = "#241571"
const color_spectrum_bwd = "#B80F0A"


skipnan(x) = filter(!isnan, x)


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
    function get_factor_prefix(numbers::Array{Float32})::Tuple{Float32, String}

Determines the best SI unit prefix for a given array `numbers`.
Returns a tuple of the factor and the prefix.
"""
function get_factor_prefix(numbers::Array{Float32})::Tuple{Float32, String}
    return get_factor_prefix(maximum(abs.(skipnan(numbers))))
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
        return "$name / $(prefix)"
    else
        return "$name / $(prefix)$(units[idx])"
    end
end


"""
    check_makie_loaded()::Nothing

Checks if a [Makie](https://makie.juliaplots.org/) backend is loaded. Throws an error if none is loaded.
"""
function check_makie_loaded()::Nothing
    if !isdefined(@__MODULE__, :GLMakie) && isdefined(@__MODULE__, :CairoMakie) && !isdefined(@__MODULE__, :WGLMakie)
        error("No Makie backend loaded. Please load either the GL, Cairo or WGL backends. See https://makie.juliaplots.org/ for more information.")
    end

    return nothing
end


"""
    plot_channel(grid::SpmGrid, channel_x::String, channel_y::String, index_x::Any, y_index::Any;
        backward::Bool=true)::Nothing

Plots a scatter plot of `channel_y` vs `channel_x` on the given `index_x` and `y_index`.
If `include_backward` is `true`` (default), the plot will include data from backward sweep as well (if they exist).

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`) should be imported
and the figure or axis should be set up. A particular Axis can be specified via the `ax` keyword argument.
"""
function plot_channel(grid::SpmGrid, channel_x::String, channel_y::String, index_x::Any, index_y::Any;
    ax::Any=nothing, backward::Bool=true)::Nothing

    check_makie_loaded()

    if ax === nothing
        ax = Main.current_axis()
    end

    x = get_channel(grid, channel_x, index_x, index_y)
    y = get_channel(grid, channel_y, index_x, index_y)

    if "$channel_x [bwd]" in grid.channel_names &&  "$channel_y [bwd]" in grid.channel_names
        x_bwd = get_channel(grid, "$channel_x [bwd]", index_x, index_y)
        y_bwd = get_channel(grid, "$channel_y [bwd]", index_x, index_y)
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

    for i_x in 1:length(index_x), i_y in 1:length(index_y)
        if length(index_x) > 1 && length(index_y) > 1
            x_plot = @view x[:, i_x, i_y]
            y_plot = @view y[:, i_x, i_y]
            if length(x_bwd) > 0
                x_plot_bwd = @view x_bwd[:, i_x, i_y]
                y_plot_bwd = @view y_bwd[:, i_x, i_y]
            end
        elseif length(index_x) > 1
            x_plot = @view x[:, i_x]
            y_plot = @view y[:, i_x]
            if length(x_bwd) > 0
                x_plot_bwd = @view x_bwd[:, i_x]
                y_plot_bwd = @view y_bwd[:, i_x]
            end
        elseif length(index_y) > 1
            x_plot = @view x[:, i_y]
            y_plot = @view y[:, i_y]
            if length(x_bwd) > 0
                x_plot_bwd = @view x_bwd[:, i_y]
                y_plot_bwd = @view y_bwd[:, i_y]
            end
        else
            x_plot = x
            y_plot = y
            if length(x_bwd) > 0
                x_plot_bwd = x_bwd
                y_plot_bwd = y_bwd
            end
        end

        if backward && length(x_bwd) > 0
            Main.scatterlines!(x_plot_bwd ./ x_factor, y_plot_bwd ./ y_factor, linewidth=2, markersize=2, color=color_spectrum_bwd)
        end
        Main.scatterlines!(x_plot ./ x_factor, y_plot ./ y_factor, linewidth=2, markersize=2, color=color_spectrum_fwd)
    end

    return nothing
end
