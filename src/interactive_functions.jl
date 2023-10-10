"""
    line_plot_values(data::Array{Point2{Float64}}, data_bwd::Array{Point2{Float64}},
        i::Int)::String

Formats the values for the line plot label.
"""
function line_plot_values(data::Array{Point2{Float64}}, data_bwd::Array{Point2{Float64}},
    i::Int)::String

    if length(data_bwd) > 0
        return @sprintf("%0.2f   %0.2f", data[i][2], data_bwd[i][2])
    else
        return @sprintf("%0.2f", data[i][2])
    end
end


"""
    parameter_plane_values(data::Array{Float64,2}, x::Int, y::Int)::String

Formats the values for the parameter plane plot label.
"""
function parameter_plane_values(data::Array{Float64,2}, x::Int, y::Int)::String
    return @sprintf("%0.2f", data[x,y])
end


"""
    interactive_display(grid::SpmGrid, response_channel::String="", response_channel2::String="", parameter::String="";
        bwd::Bool=false, fig::Any=nothing, backend::Module=Main)::Any

Display the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments.
`response_channel` specifies the initial choice of the response channel,
`response_channel2` specifies the initial choice of the response channel for the second line plot,
`parameter` specifies the initial parameter to plot.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`)
should be imported and the figure can be set up and passed via the `fig` keyword argument.
"""
function interactive_display(grid::SpmGrid, response_channel::String="", response_channel2::String="", parameter::String="";
    bwd::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any

    if response_channel === ""
        if length(grid.channel_names) > 0
            response_channel = grid.channel_names[1]
        else
            response_channel = channel_names(grid)[1]
        end
    end
    if response_channel2 === ""
        if length(grid.channel_names) > 1
            response_channel2 = grid.channel_names[2]
        else
            response_channel2 = channel_names(grid)[2]
        end
    end
    if parameter === ""
        if length(grid.experiment_parameter_names) > 0
            parameter = grid.experiment_parameter_names[1]
        elseif length(grid.fixed_parameter_names) > 0
            parameter = grid.fixed_parameter_names[1]
        else
            parameter = parameter_names(grid)[1]
        end
    end

    if fig === nothing
        check_makie_loaded(backend, warn=false)
        if isdefined(backend, :activate!)  # WGLMakie does not have it
            backend.activate!(title="SpmGrids")
        end
        fontsize_theme = backend.Theme(fontsize = 10)
        backend.set_theme!(fontsize_theme)
        fig = backend.Figure(resolution = (1200, 1000))
    end

    all_channel_names = channel_names(grid)
    channel_names_units = map(all_channel_names) do c
        c * " ($(grid.channel_units[c]))"
    end

    all_parameter_names = parameter_names(grid)
    parameter_names_units = map(all_parameter_names) do p
        p * " ($(get_parameter_unit(grid, p)))"
    end

    if response_channel ∉ all_channel_names
        @warn "Channel name `$(response_channel)` not found."
        response_channel = all_channel_names[1]
    end
    if response_channel2 ∉ all_channel_names
        @warn "Channel name `$(response_channel2)` not found."
        response_channel2 = all_channel_names[2]
    end
    if parameter ∉ all_parameter_names
        @warn "Parameter name `$(parameter)` not found."
        parameter = all_parameter_names[1]
    end

    bwd_exists = length(all_channel_names) != length(channel_names(grid, skip_bwd=false))
    bwd_exists_for_all = length(all_channel_names) == length(channel_names(grid, skip_bwd=false)) ÷ 2

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
        bwd=bwd, observable=true)

    # widgets 

    menu_channel = backend.Menu(g12[1,1], options=zip(channel_names_units, all_channel_names),
        default=channel_names_units[findfirst(isequal(response_channel), all_channel_names)])
    
    menu_channel2 = backend.Menu(g32[1,1], options=zip(channel_names_units, all_channel_names),
    default=channel_names_units[findfirst(isequal(response_channel2), all_channel_names)])

    lsgrid = backend.SliderGrid(
        g12[2,1],
        (label="grid X", range=1:grid.pixelsize[1]),
        (label="grid Y", range=1:grid.pixelsize[2]),
        (label="grid Z", range=1:length(data_cube.z[])),
        tellheight = false)

    grid_x, grid_y, grid_z = [s.value for s in lsgrid.sliders]
    grid_z_start = grid_z[]

    if bwd_exists
        label_dir = backend.Label(g12[3,1][1,1], "backward", halign=:left, tellwidth=false)
        toggle_forward = backend.Toggle(g12[3,1][1,2], active=!bwd, halign=:left, tellwidth=false)
        label_dir2 = backend.Label(g12[3,1][1,3], "forward", halign=:left, tellwidth=false)
        forward = toggle_forward.active[]

        invisax = backend.Axis(g12[3,1][1,4])  # dummy axis
        backend.hidespines!(invisax)
        backend.hidedecorations!(invisax)

        label_dir3_str = bwd_exists_for_all ? "" : "(not available for all)"
        label_dir3 = backend.Label(g12[3,1][1,5], label_dir3_str, halign=:left, tellwidth=false, color="#a0a0a0")
        
        # todo: toggle backward/forward for spectra
        # label_dir_both = backend.Label(g12[3,1][1,5], "both in spectrum", halign=:right, tellwidth=false)
        # toggle_dir_both = backend.Toggle(g12[3,1][1,6], active=true, halign=:right, tellwidth=false)
    else
        forward = true
    end

    menu_parameter = backend.Menu(g31[1,1], options=zip(parameter_names_units, all_parameter_names),
        default=parameter_names_units[findfirst(isequal(parameter), all_parameter_names)])

    # plots
  
    ax_cube = backend.Axis3(g11[1, 1], zlabel=data_cube.z_label, perspectiveness=0.5, viewmode=:fit)
    plot_cube(data_cube, ax_cube, g11[1, 2], backend; kwargs...)

    data_plane = get_data_plane(grid, response_channel, :, :, grid_z[],
        bwd=!forward, backend=backend, observable=true)
    ax_plane_channel = backend.Axis(g21[1, 1], title=data_plane.plot_label, titlealign=:left)
    plot_plane(data_plane, ax_plane_channel, g21[1, 2], backend; kwargs...)

    data_parameter_plane = get_data_parameter_plane(grid, parameter, :, :,
        backend=backend, observable=true)
    ax_parameter_plane = backend.Axis(g41[1, 1], title=data_parameter_plane.plot_label, titlealign=:left)
    plot_plane(data_parameter_plane, ax_parameter_plane, g41[1, 2], backend; kwargs...)

    data_line_1 = get_data_line(grid, response_channel, grid_x[], grid_y[], :,
        observable=true)
    ax_line_1 = backend.Axis(g22[1, 1], title=data_line_1.plot_label, titlealign=:left,
        xlabel=data_line_1.x_label, ylabel=data_line_1.y_label)
    plot_line(data_line_1, ax_line_1, backend; kwargs...)

    data_line_2 = get_data_line(grid, response_channel2, grid_x[], grid_y[], :,
        observable=true)
    ax_line_2 = backend.Axis(g42[1, 1], title=data_line_2.plot_label, titlealign=:left,
        xlabel=data_line_2.x_label, ylabel=data_line_2.y_label)
    plot_line(data_line_2, ax_line_2, backend; kwargs...)

    # labels
    data_parameter_plane_topright = g41[1,1, backend.TopRight()]
    data_parameter_plane_label_text = map(
        (x,y,z) -> parameter_plane_values(data_parameter_plane.data[], x, y),
        grid_x, grid_y, grid_z
    )
    data_parameter_plane_label_x = backend.Label(data_parameter_plane_topright[1,1], data_parameter_plane_label_text,
        halign=:right, justification=:left, tellwidth=false, tellheight=false, color="#a0a0a0")
    data_line_1_topright = g22[1,1, backend.TopRight()]
    data_line_1_label_text = map(
        (x,y,z) -> line_plot_values(data_line_1.xy[], data_line_1.xy_bwd[], z),
        grid_x, grid_y, grid_z
    )
    data_line_1_label_x = backend.Label(data_line_1_topright[1,1], data_line_1_label_text,
        halign=:right, justification=:left, tellwidth=false, tellheight=false, color="#a0a0a0")
    data_line_2_topright = g42[1,1, backend.TopRight()]
    data_line_2_label_text = map(
        (x,y,z) -> line_plot_values(data_line_2.xy[], data_line_2.xy_bwd[], z),
        grid_x, grid_y, grid_z
    )
    data_line_2_label_x = backend.Label(data_line_2_topright[1,1], data_line_2_label_text,
        halign=:right, justification=:left, tellwidth=false, tellheight=false, color="#a0a0a0")
    
    # markers
    rect_3d = plot_rect_3d(data_cube, grid_z_start, ax_cube, backend)
    grid_x_pos = map(i -> data_cube.x[][i], grid_x)
    grid_y_pos = map(i -> data_cube.y[][i], grid_y)
    grid_z_pos = map(i -> data_cube.z[][i], grid_z)
    vline_1 = backend.vlines!(ax_line_1, grid_z_pos, color="#60100b60", linewidth=2, linestyle = :dash)
    vline_2 = backend.vlines!(ax_line_2, grid_z_pos, color="#60100b60", linewidth=2, linestyle = :dash)
    vline_parameter_plane = backend.vlines!(ax_parameter_plane, grid_x_pos, color="#0b106060", linewidth=2, linestyle = :dash)
    hline_parameter_plane = backend.hlines!(ax_parameter_plane, grid_y_pos, color="#0b106060", linewidth=2, linestyle = :dash)
    vline_plane = backend.vlines!(ax_plane_channel, grid_x_pos, color="#0b106060", linewidth=2, linestyle = :dash)
    hline_plane = backend.hlines!(ax_plane_channel, grid_y_pos, color="#0b106060", linewidth=2, linestyle = :dash)

    # events

    backend.on(menu_channel.selection) do s
        forward = !bwd_exists || toggle_forward.active[] ||
            !has_channel(grid, channel_name_bwd(s))
        data_new = get_data_cube(grid, s, :, :, :, bwd=!forward)
        set_observable_values!(data_cube, data_new)
        data_new = get_data_plane(grid, s, :, :, grid_z[], bwd=!forward)
        set_observable_values!(data_plane, data_new)
        data_new = get_data_line(grid, s, grid_x[], grid_y[], :)
        set_observable_values!(data_line_1, data_new)
        backend.autolimits!(ax_line_1)
        grid_x[] = grid_x[]  # trigger labels update
    end

    backend.on(menu_channel2.selection) do s
        data_new = get_data_line(grid, s, grid_x[], grid_y[], :)
        set_observable_values!(data_line_2, data_new)
        backend.autolimits!(ax_line_2)
        grid_x[] = grid_x[]  # trigger labels update
    end

    if bwd_exists
        backend.on(toggle_forward.active) do s
            response_channel = menu_channel.selection[]
            s = s || !bwd_exists || !has_channel(grid, channel_name_bwd(response_channel))
            data_new = get_data_cube(grid, response_channel, :, :, :, bwd=!s)
            set_observable_values!(data_cube, data_new)
            data_new = get_data_plane(grid, response_channel, :, :, grid_z[], bwd=!s)
            set_observable_values!(data_plane, data_new)
            grid_x[] = grid_x[]  # trigger labels update
        end
    end

    backend.on(menu_parameter.selection) do s
        data_new = get_data_parameter_plane(grid, s, :, :, backend=backend)
        set_observable_values!(data_parameter_plane, data_new)
        grid_x[] = grid_x[]  # trigger labels update
    end

    backend.on(grid_z) do z
        response_channel = menu_channel.selection[]
        forward = !bwd_exists || toggle_forward.active[] ||
            !has_channel(grid, channel_name_bwd(response_channel))
        data_new = get_data_plane(grid, response_channel, :, :, z, bwd=!forward)
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

    # mouse interaction
    for ax in (ax_plane_channel, ax_parameter_plane)
        on(backend.events(ax.scene).mousebutton) do mb
            if mb.button == backend.Mouse.left 
                pos = Float64.(collect(backend.mouseposition(ax.scene)))
                pos ./= (data_plane.x_factor[], data_plane.y_factor[])
                idx = point_to_xyindex(grid, pos)
                if all(idx .>= 1) && all(idx .<= grid.pixelsize)
                    backend.set_close_to!(lsgrid.sliders[1], idx[1])
                    backend.set_close_to!(lsgrid.sliders[2], idx[2])
                    return backend.Consume(true)
                end
            end
            return backend.Consume(false)
        end
    end

    for (ax, xy_data) in zip((ax_line_1, ax_line_2), (data_line_1.xy[], data_line_2.xy[]))
        on(backend.events(ax.scene).mousebutton) do mb
            if mb.button == backend.Mouse.left 
                plt, idx = backend.pick(ax.scene, backend.events(ax.scene).mouseposition[])
                # see also here: https://discourse.julialang.org/t/makie-mouse-event/74786
                # todo: right now, the first plot seems to always have preference.
                # e.g. if the second plot has a different range/zoom, the selection is based on the first plot
                isnothing(plt) && return backend.Consume(false)
                pos = Float64(backend.mouseposition(ax.scene)[1])
                idx = findmin(abs.(pos .- first.(xy_data)))[2]
                if idx .>= 1 && idx <= grid.points
                    backend.set_close_to!(lsgrid.sliders[3], idx)
                    return backend.Consume(true)
                end
            end
            return backend.Consume(false)
        end
    end

    return fig
end


"""
    interactive_display(fname::String, response_channel::String="", response_channel2::String="", parameter::String="";
        bwd::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any

Display the grid in an interactive GUI that can be used in Pluto, Jupyter, or other interactive environments.
`response_channel` specifies the initial choice of the response channel,
`response_channel2` specifies the initial choice of the response channel for the second line plot,
`parameter` specifies the initial parameter to plot.

Before using this function, a [Makie](https://makie.juliaplots.org/) backend (`GLMakie`, `CairoMakie` or `WGLMakie`)
should be imported and the figure can be set up and passed via the `fig` keyword argument.
"""
function interactive_display(fname::String, response_channel::String="", response_channel2::String="", parameter::String="";
    bwd::Bool=false, fig::Any=nothing, backend::Module=Main, kwargs...)::Any

    if !(isfile(fname))
        throw(ArgumentError("File $fname not found."))
    end
    grid = load_grid(fname)
    return interactive_display(grid, response_channel, response_channel2, parameter;
        bwd=bwd, fig=fig, backend=backend, kwargs...)
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
    set_observable_values!(nt::NamedTuple, nt_new::NamedTuple)::Nothing

Sets the Observables in `nt` to the values provided in `nt_new`.
"""
function set_observable_values!(nt::NamedTuple, nt_new::NamedTuple)::Nothing
    for k in keys(nt)
        setindex!(nt[k], nt_new[k])
    end
    return nothing
end


"""
    plot_line(data::NamedTuple, ax::Any, backend::Module; bwd::Bool=true, kwargs...)::Nothing

Plots a line from the NamedTuple `x` vs `y` and `x_bwd` vs `y_bwd` on Axis `ax`
"""
function plot_line(data::NamedTuple, ax::Any, backend::Module; bwd::Bool=true, kwargs...)::Nothing
    check_makie_loaded(backend, ax)
    ax = backend.current_axis()

    kwargs_fwd = get_kwargs(kwargs)
    kwargs_bwd = get_kwargs(kwargs, bwd=true)

    backend.scatterlines!(data.xy,
        linewidth=2, markersize=2, color=color_spectrum_fwd, label=data.plot_label;
        kwargs_fwd...)
    # always plot backwards - in case only some channels have backward data
    backend.scatterlines!(data.xy_bwd,
        linewidth=2, markersize=2, color=color_spectrum_bwd, label="$(data.plot_label) bwd";
        kwargs_bwd...)

    return nothing
end


"""
    plot_plane(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing

Plots a plane from the NamedTuple `data` on Axis `ax`. A colorbar is also plotted on `ax_cb`.
A Makie backend should be given and extra keyword arguments can be provided.
"""
function plot_plane(data::NamedTuple, ax::Any, ax_cb::Any, backend::Module; kwargs...)::Nothing
    check_makie_loaded(backend, ax)
    ax = backend.current_axis()

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
    check_makie_loaded(backend, ax, axis3=true)
    ax = backend.current_axis()

    ax.xlabel = data.x_label[]
    ax.ylabel = data.y_label[]
    # ax.zlabel = data.z_label[] # this can change, so we have to add it as a keyword parameter when creating the axis
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

