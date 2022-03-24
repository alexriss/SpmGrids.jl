"""
    interactive_display(grid::SpmGrid, response_channel::String="", response_channel2::Stringg="", parameter::String="";
        backward::Bool=false, fig::Any=nothing, backend::Module=Main)::Any

Display the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments.
`response_channel` specifies the initial choice of the response channel,
`response_channel2` specifies the initial choice of the response channel for the second line plot,
`parameter` specifies the initial parameter to plot.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`)
should be imported and the figure can be set up and passed via the `fig` keyword argument.
"""
function interactive_display(grid::SpmGrid, response_channel::String="", response_channel2::String="", parameter::String="";
    backward::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any

    if response_channel === ""
        response_channel = grid.channel_names[1]
    end
    if response_channel2 === ""
        response_channel2 = grid.channel_names[2]
    end
    if parameter === ""
        parameter = grid.experiment_parameter_names[1]
    end

    if fig === nothing
        backend.set_window_config!(title="SpmGrids")
        fontsize_theme = backend.Theme(fontsize = 10)
        backend.set_theme!(fontsize_theme)
        fig = backend.Figure(resolution = (1200, 1000))
    end

    channel_names = filter(!endswith(" [bwd]"), vcat(grid.channel_names, grid.generated_channel_names))
    channel_names_units = map(channel_names) do c
        c * " ($(grid.channel_units[c]))"
    end

    parameter_names = vcat(grid.fixed_parameter_names, grid.experiment_parameter_names, grid.generated_parameter_names)
    parameter_names_units = map(parameter_names) do p
        p * " ($(get_parameter_unit(grid, p)))"
    end

    backward_exists = length(channel_names) != length(grid.channel_names)

    # layout

    g11 = fig[1, 1] = backend.GridLayout(valign=:top)
    g12 = fig[1, 2] = backend.GridLayout(valign=:top)
    g21 = fig[2, 1] = backend.GridLayout(valign=:top)
    g22 = fig[2, 2] = backend.GridLayout(valign=:top)
    g31 = fig[3, 1] = backend.GridLayout(valign=:bottom)
    g32 = fig[3, 2] = backend.GridLayout(valign=:bottom)
    g41 = fig[4, 1] = backend.GridLayout(valign=:top)
    g42 = fig[4, 2] = backend.GridLayout(valign=:top)

    backend.colsize!(fig.layout, 1, backend.Relative(0.4))
    backend.colsize!(fig.layout, 2, backend.Relative(0.6))
    backend.rowsize!(fig.layout, 1, backend.Relative(0.31))
    backend.rowsize!(fig.layout, 2, backend.Relative(0.31))
    backend.rowsize!(fig.layout, 3, backend.Relative(0.09))
    backend.rowsize!(fig.layout, 4, backend.Relative(0.31))

    # have to get this here because we need the data
    data_cube = get_data_cube(grid, response_channel, :, :, :,
        backward=backward, observable=true)

    # widgets 

    menu_channel = backend.Menu(g12[1,1], options=zip(channel_names_units, channel_names),
        i_selected=findfirst(isequal(response_channel), channel_names), selection=response_channel)
    
    menu_channel2 = backend.Menu(g32[1,1], options=zip(channel_names_units, channel_names),
        i_selected=findfirst(isequal(response_channel2), channel_names), selection=response_channel2)

    lsgrid = backend.labelslidergrid!(
        fig,
        ["grid X", "grid Y", "grid Z"],
        [1:grid.pixelsize[1], 1:grid.pixelsize[2], 1:length(data_cube.z[])];
        tellheight = false)
    g12[2,1] = lsgrid.layout
    grid_x, grid_y, grid_z = [s.value for s in lsgrid.sliders]
    grid_z_start = grid_z[]

    if backward_exists
        label_dir = backend.Label(g12[3,1][1,1], "backward", halign=:left, tellwidth=false)
        toggle_forward = backend.Toggle(g12[3,1][1,2], active=!backward, halign=:left, tellwidth=false)
        label_dir2 = backend.Label(g12[3,1][1,3], "forward", halign=:left, tellwidth=false)
        forward = toggle_forward.active[]

        invisax = backend.Axis(g12[3,1][1,4])  # dummy axis
        backend.hidespines!(invisax)
        backend.hidedecorations!(invisax)

        # todo: toggle backward/forward for spectra
        # label_dir_both = backend.Label(g12[3,1][1,5], "both in spectrum", halign=:right, tellwidth=false)
        # toggle_dir_both = backend.Toggle(g12[3,1][1,6], active=true, halign=:right, tellwidth=false)
    else
        forward = true
    end

    menu_parameter = backend.Menu(g31[1,1], options=zip(parameter_names_units, parameter_names),
        i_selected=findfirst(isequal(parameter), parameter_names), selection=parameter)

    # plots
  
    ax_cube = backend.Axis3(g11[1, 1], perspectiveness=0.5, viewmode=:fit)
    plot_cube(data_cube, ax_cube, g11[1, 2], backend; kwargs...)

    data_plane = get_data_plane(grid, response_channel, :, :, grid_z[],
        backward=!forward, backend=backend, observable=true)
    ax_plane_channel = backend.Axis(g21[1, 1], title=data_plane.plot_label)
    plot_plane(data_plane, ax_plane_channel, g21[1, 2], backend; kwargs...)

    data_parameter_plane = get_data_parameter_plane(grid, parameter, :, :,
        backend=backend, observable=true)
    ax_plane_parameter = backend.Axis(g41[1, 1], title=data_parameter_plane.plot_label)
    plot_plane(data_parameter_plane, ax_plane_parameter, g41[1, 2], backend; kwargs...)

    data_line_1 = get_data_line(grid, response_channel, grid_x[], grid_y[], :,
        observable=true)
    ax_line_1 = backend.Axis(g22[1, 1], title=data_line_1.plot_label, xlabel=data_line_1.x_label, ylabel=data_line_1.y_label)
    plot_line(data_line_1, ax_line_1, backend; kwargs...)

    data_line_2 = get_data_line(grid, response_channel2, grid_x[], grid_y[], :,
        observable=true)
    ax_line_2 = backend.Axis(g42[1, 1], title=data_line_2.plot_label, xlabel=data_line_2.x_label, ylabel=data_line_2.y_label)
    plot_line(data_line_2, ax_line_2, backend; kwargs...)

    # markers
    rect_3d = plot_rect_3d(data_cube, grid_z_start, ax_cube, backend)
    grid_x_pos = map(i -> data_cube.x[][i], grid_x)
    grid_y_pos = map(i -> data_cube.y[][i], grid_y)
    grid_z_pos = map(i -> data_cube.z[][i], grid_z)
    vline_1 = backend.vlines!(ax_line_1, grid_z_pos, color="#60100b60", linewidth=2, linestyle = :dash)
    vline_2 = backend.vlines!(ax_line_2, grid_z_pos, color="#60100b60", linewidth=2, linestyle = :dash)
    vline_plane = backend.vlines!(ax_plane_channel, grid_x_pos, color="#0b106060", linewidth=2, linestyle = :dash)
    hline_plane = backend.hlines!(ax_plane_channel, grid_y_pos, color="#0b106060", linewidth=2, linestyle = :dash)

    # events

    backend.on(menu_channel.selection) do s
        forward = !backward_exists || toggle_forward.active[]
        data_new = get_data_cube(grid, s, :, :, :, backward=!forward)
        set_observable_values!(data_cube, data_new)
        data_new = get_data_plane(grid, s, :, :, grid_z[], backward=!forward)
        set_observable_values!(data_plane, data_new)
        data_new = get_data_line(grid, s, grid_x[], grid_y[], :)
        set_observable_values!(data_line_1, data_new)
        backend.autolimits!(ax_line_1)
    end

    backend.on(menu_channel2.selection) do s
        data_new = get_data_line(grid, s, grid_x[], grid_y[], :)
        set_observable_values!(data_line_2, data_new)
        backend.autolimits!(ax_line_2)
    end

    if backward_exists
        backend.on(toggle_forward.active) do s
            response_channel = menu_channel.selection[]
            data_new = get_data_cube(grid, response_channel, :, :, :, backward=!s)
            set_observable_values!(data_cube, data_new)
            data_new = get_data_plane(grid, response_channel, :, :, grid_z[], backward=!s)
            set_observable_values!(data_plane, data_new)
        end
    end

    backend.on(menu_parameter.selection) do s
        data_new = get_data_parameter_plane(grid, s, :, :, backend=backend)
        set_observable_values!(data_parameter_plane, data_new)
    end

    backend.on(grid_z) do z
        forward = !backward_exists || toggle_forward.active[]
        response_channel = menu_channel.selection[]
        data_new = get_data_plane(grid, response_channel, :, :, z, backward=!forward)
        set_observable_values!(data_plane, data_new)
        backend.translate!(rect_3d, 0, 0, data_cube.z[][grid_z[]] - data_cube.z[][grid_z_start])
    end

    backend.on(grid_x) do x
        response_channel = menu_channel.selection[]
        data_new = get_data_line(grid, response_channel, x, grid_y[], :)
        set_observable_values!(data_line_1, data_new)
        backend.autolimits!(ax_line_1)
        response_channel2 = menu_channel2.selection[]
        data_new = get_data_line(grid, response_channel2, x, grid_y[], :)
        set_observable_values!(data_line_2, data_new)
        backend.autolimits!(ax_line_2)
    end

    backend.on(grid_y) do y
        response_channel = menu_channel.selection[]
        data_new = get_data_line(grid, response_channel, grid_x[], y, :)
        set_observable_values!(data_line_1, data_new)
        backend.autolimits!(ax_line_1)
        response_channel2 = menu_channel2.selection[]
        data_new = get_data_line(grid, response_channel2, grid_x[], y, :)
        set_observable_values!(data_line_2, data_new)
        backend.autolimits!(ax_line_2)
    end

    return fig
end


"""
    interactive_display(grid::SpmGrid, response_channel::String="";
        backward::Bool=false, fig::Any=nothing, backend::Module=Main)::Any

Display the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments.
`response_channel` specifies the initial choice of the response channel,

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`)
should be imported and the figure can be set up and passed via the `fig` keyword argument.
"""
function interactive_display(fname::String, response_channel::String="";
    backward::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any

    if !(isfile(fname))
        @error "File $fname not found."
    end
    grid = load_grid(fname)
    return interactive_display(grid, response_channel;
        backward=backward, fig=fig, backend=backend, kwargs...)
end


"""
    convert_to_observable!(nt::NamedTuple)::Nothing

Converts all values in the NamedTuple `nt` to Observables.
"""
function convert_to_observable!(nt::NamedTuple)::Nothing
    for (k,v) in zip(keys(nt), nt)
        nt[k] = Observable(v)
    end
    return nothing
end


"""
    set_observable_values!(nt::NamedTuple, nt_vals::NamedTuple)::Nothing

Sets the Observables in `nt` to the values provided in `nt_vals`.
"""
function set_observable_values!(nt::NamedTuple, nt_vals::NamedTuple)::Nothing
    for k in keys(nt)
        setindex!(nt[k], nt_vals[k])
    end
    return nothing
end


"""
    plot_line(data::NamedTuple, ax::Any, backend::Module; backward::Bool=true, kwargs...)::Nothing

Plots a line from the NamedTuple `x` vs `y` and `x_bwd` vs `y_bwd` on Axis `ax`
"""
function plot_line(data::NamedTuple, ax::Any, backend::Module; backward::Bool=true, kwargs...)::Nothing
    check_makie_loaded(backend)
    backend.current_axis!(ax)

    kwargs_fwd = get_kwargs(kwargs)
    kwargs_bwd = get_kwargs(kwargs, backward=true)

    backend.scatterlines!(data.x, data.y,
        linewidth=2, markersize=2, color=color_spectrum_fwd, label=data.plot_label;
        kwargs_fwd...)
    if backward && length(data.y_bwd[]) > 0
        backend.scatterlines!(data.x_bwd, data.y_bwd,
            linewidth=2, markersize=2, color=color_spectrum_bwd, label="$(data.plot_label) bwd";
            kwargs_bwd...)
    end

    return nothing
end


"""
    plot_plane(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing

Plots a plane from the NamedTuple `data` on Axis `ax`. A colorbar is also plotted on `ax_cb`.
A Makie backend should be given and extra keyword arguments can be provided.
"""
function plot_plane(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing
    check_makie_loaded(backend)
    backend.current_axis!(ax)

    ax.xlabel = data.x_label[]
    ax.ylabel = data.y_label[]
    ax.aspect = data.ax_aspect[]

    hm = backend.heatmap!(data.x, data.y, data.data,
        colorrange=data.colorrange, colormap=:grays, label=data.plot_label;
        kwargs...)

    cb  = backend.Colorbar(ax_cb, hm, label=data.data_label)
    cb.alignmode = backend.Mixed(right = 0)

    return nothing
end


"""
    plot_cube(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing

Plots a cube from the NamedTuple `data` on Axis `ax`. A colorbar is also plotted on `ax_cb`.
A Makie backend should be given and extra keyword arguments can be provided.
"""
function plot_cube(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing
    check_makie_loaded(backend)
    backend.current_axis!(ax)

    ax.xlabel = data.x_label[]
    ax.ylabel = data.y_label[]
    ax.zlabel = data.z_label[]
    ax.aspect = data.ax_aspect[]

    # we have to plot z_sorted and data_sorted, 
    # wrong plots are obntained if the axes indices are not sorted in ascending order
    # see https://github.com/JuliaPlots/Makie.jl/issues/1781
    vol = backend.volume!(data.x, data.y, data.z_sorted, data.data_sorted,
        colorrange=data.colorrange, transparency=true, colormap=:grays,
        nan_color=backend.RGBAf(0,0,0,0);
        kwargs...)

    cb = backend.Colorbar(ax_cb, vol, label=data.data_label)
    cb.alignmode = backend.Mixed(right = 0)

    return nothing
end


"""
    plot_rect_3d(data::NamedTuple, grid_z, ax::Any, backend::Module)::Any

Plots a rectangle around the cube plot (`cube_data`) in Axis `ax` at height corresponding to `grid_z`.
Returns the plot.
"""
function plot_rect_3d(data::NamedTuple, grid_z, ax::Any, backend::Module)::Any
    x_span = maximum(data.x[]) - minimum(data.x[])
    y_span = maximum(data.y[]) - minimum(data.y[])
    x_min = minimum(data.x[]) - 0.005 * x_span
    x_width = 1.01 * x_span
    y_min = minimum(data.y[]) - 0.005 * y_span
    y_width = 1.01 * y_span
    z_curr = data.z[][grid_z]

    rect_3d = backend.linesegments!(ax, backend.Rect(x_min, y_min, z_curr, x_width, y_width, 0),
        linewidth=2, color="#60100b")

    return rect_3d
end

