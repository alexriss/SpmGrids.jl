"""
    interactive_display(grid::SpmGrid, response_channel::String="", parameter::String="";
        backward::Bool=false, fig::Any=nothing, backend::Module=Main)::Any

Display the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments.
`response_channel` specifies the initial choice of the response channel,
`parameter` specifies the initial [arameter to plot.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`)
should be imported and the figure can be set up and passed via the `fig` keyword argument.
"""
function interactive_display(grid::SpmGrid, response_channel::String="", parameter::String="";
    backward::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any

    if response_channel === ""
        response_channel = grid.channel_names[1]
    end
    if parameter === ""
        parameter = grid.experiment_parameter_names[1]
    end

    if fig === nothing
        backend.set_window_config!(title="SpmGrids")
        fontsize_theme = backend.Theme(fontsize = 8)
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

    g11 = fig[1, 1] = backend.GridLayout(valign=:top)
    g12 = fig[1, 2] = backend.GridLayout(valign=:top)
    g21 = fig[2, 1] = backend.GridLayout(valign=:top)
    g22 = fig[2, 2] = backend.GridLayout(valign=:top)
    g31 = fig[3, 1] = backend.GridLayout(valign=:top)
    g41 = fig[4, 1] = backend.GridLayout(valign=:top)
    g42 = fig[4, 2] = backend.GridLayout(valign=:top)

    backend.colsize!(fig.layout, 1, backend.Relative(0.4))
    backend.colsize!(fig.layout, 2, backend.Relative(0.6))
    backend.rowsize!(fig.layout, 1, backend.Relative(0.31))
    backend.rowsize!(fig.layout, 2, backend.Relative(0.31))
    backend.rowsize!(fig.layout, 3, backend.Relative(0.09))
    backend.rowsize!(fig.layout, 4, backend.Relative(0.31))

    menu_channel = backend.Menu(g12[1,1], options=zip(channel_names_units, channel_names),
        i_selected=findfirst(isequal(response_channel), channel_names), selection=response_channel)
    
    lsgrid = backend.labelslidergrid!(
        fig,
        ["grid X", "grid Y", "grid Z"],
        [1:grid.pixelsize[1], 1:grid.pixelsize[2], 1:grid.points];
        tellheight = false)
    g12[2,1] = lsgrid.layout
    grid_x, grid_y, grid_z = [s.value for s in lsgrid.sliders]

    if backward_exists
        label_dir = backend.Label(g12[3,1][1,1], "backward / forward", halign=:left, tellwidth=false)
        toggle_forward = backend.Toggle(g12[3,1][1,2], active=!backward, halign=:left, tellwidth=false)
        invisax = backend.Axis(g12[3,1][1,3])  # dummy axis
        backend.hidespines!(invisax)
        backend.hidedecorations!(invisax)
        forward = toggle_forward.active[]
    else
        forward = true
    end

    menu_parameter = backend.Menu(g31[1,1], options=zip(parameter_names_units, parameter_names),
        i_selected=findfirst(isequal(parameter), parameter_names), selection=parameter)
  
    data_cube = get_data_cube(grid, response_channel, :, :, :,
        backward=!forward, observable=true)
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

    backend.on(menu_channel.selection) do s
        forward = !backward_exists || toggle_forward.active[]
        data_new = get_data_cube(grid, s, :, :, :, backward=!forward)
        set_observable_values!(data_cube, data_new)
        data_new = get_data_plane(grid, s, :, :, grid_z[], backward=!forward)
        set_observable_values!(data_plane, data_new)
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

    backend.Colorbar(ax_cb, hm, label=data.data_label)

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

    vol = backend.volume!(data.x, data.y, data.z, data.data,
        colorrange=data.colorrange, transparency=true, colormap=:grays;
        kwargs...)

    backend.Colorbar(ax_cb, vol, label=data.data_label)

    return nothing
end

