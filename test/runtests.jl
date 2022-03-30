using CairoMakie
using Dates
using GLMakie
using SpmGrids
using Test


skipnan = SpmGrids.skipnan

"""
Compares two Arrays/Tuples, each element should not deviate by more than `thresh` (relative to b).
"""
function similar(a, b, thresh=1e-3)::Bool
    if length(a) != length(b)
        return false
    end
    if any(abs.(a .- b) ./ b .> thresh)
        return false
    end
    return true
end


@testset "load data" begin
    grid = load_grid("Grid Spectroscopy002.3ds", header_only=true)

    @test grid.pixelsize == [20,20]
    @test grid.angle ≈ 0.
    @test grid.center ≈ [1.106620E-7, 2.331660E-7]
    @test grid.size ≈ [1.5e-8, 1.5e-8]
    @test grid.size_unit == "m"

    @test grid.points == 128

    @test grid.bias ≈ 0.2
    @test grid.z_feedback == false

    @test grid.start_time == DateTime(2017,03,09,21,19,38)
    @test grid.end_time == DateTime(2017,03,10,8,21,16)

    @test length(grid.data) == 0  # 0 because `header_only` is true

    @test grid.fixed_parameter_names == ["Sweep Start", "Sweep End"]
    @test grid.experiment_parameter_names == ["X", "Y", "Z", "Z offset", "Settling time", "Integration time",
        "Z-Ctrl", "Final Z", "Scan:Current", "Scan:Applied Voltage measured", "Scan:Bias", "Scan:Z",
        "Scan:Phase", "Scan:Amplitude", "Scan:Frequency Shift", "Scan:Excitation"]
    @test getindex.((grid.parameter_units, ), grid.experiment_parameter_names) ==
        ["m", "m", "m", "m", "s", "s", "hold", "m", "A", "V", "V", "m", "deg", "m", "Hz", "V"]
    @test grid.fixed_parameter_names == ["Sweep Start", "Sweep End"]
    @test grid.channel_names == ["Current", "Applied Voltage measured", "Bias", "X", "Y", "Z", "Phase",
        "Amplitude", "Frequency Shift", "Excitation"]
    @test getindex.((grid.channel_units, ), grid.channel_names) ==
        ["A", "V", "V", "m", "m", "m", "deg", "m", "Hz", "V"]

    @test grid.sweep_signal == "Bias"

    @test grid.header["Oscillation Control>PLL-Setup Demod. Bandwidth Amp (Hz)"] == "80E+0"
    @test grid.header["Z-Controller>Switch off delay (s)"] == "50E-3"
    @test grid.header["Comment"] == "KPFM"
    @test grid.header["Experiment"] == "Grid Spectroscopy"

    # Base.show with header_only=true
    io = IOBuffer()
    print(IOContext(io, :compact => false), grid)
    @test String(take!(io)) == """SpmGrid("Grid Spectroscopy002.3ds", sweep: "Bias", 10 channels, 128 points, 20x20 pixels)"""
    print(IOContext(io, :compact => true), grid)
    @test String(take!(io)) == """SpmGrid("Grid Spectroscopy002.3ds")"""
    
    grid = load_grid("Grid Spectroscopy002.3ds")

    # Base.show with header_only=false
    print(IOContext(io, :compact => false), grid)
    @test String(take!(io)) == """SpmGrid("Grid Spectroscopy002.3ds", sweep: "Bias", 10 channels, 128 points, 20x20 pixels)"""
    print(IOContext(io, :compact => true), grid)
    @test String(take!(io)) == """SpmGrid("Grid Spectroscopy002.3ds")"""

    @test length(grid.data) == 20 * 20 * (18 + 10 * 128)  # pixels * (parameters + channels * points)
    @test size(get_channel(grid, "Bias", 4:20, 5:5)) == (17,1,128)
    @test size(get_channel(grid, "Frequency Shift", 4:20, 5:7, 20:23)) == (17,3, 4)
    @test get_channel(grid, "Bias", 20, 7, 20)[] ≈ 0.15511811
    @test all(get_parameter(grid, "Z offset", 3, :) .≈ 0.0)
    @test get_parameter(grid, "Z", 3, 5)[] ≈ -1.1132063271190873e-8
    @test get_channel(grid, "Current", 20, 7, 20:24) ≈ [1.3028698953032603e-10, 1.2868268950416706e-10, 1.2712124408675862e-10, 1.2609777111372011e-10, 1.2497206047790144e-10]

    @test has_parameter(grid, "Z offset")
    @test has_parameter(grid, "Sweep End")
    @test has_parameter(grid, "Sweep En") == false
    @test has_channel(grid, "Current")
    @test has_channel(grid, "Z")
    @test has_channel(grid, "Current", bwd=true) == false
    @test has_channel(grid, "Curren", bwd=true) == false
    @test has_channel(grid, "Curren") == false
    @test has_channel(grid, "Current [bwd]") == false

    logs, value = Test.collect_test_logs() do
        get_channel(grid, "Bias", bwd=true)
    end
    @test occursin("Using forward", logs[1].message)

    @test all(xyindex_to_point(grid, 1, 10) .≈ (0.0, 7.105263157894736e-9))

    grid = load_grid("Grid Spectroscopy006.3ds")
    @test has_parameter(grid, "Z offset")
    @test has_parameter(grid, "Sweep End")
    @test has_parameter(grid, "Sweep En") == false
    @test has_channel(grid, "Current")
    @test has_channel(grid, "Z")
    @test has_channel(grid, "Current", bwd=true)
    @test has_channel(grid, "Curren", bwd=true) == false
    @test has_channel(grid, "Current [bwd]")
    @test has_channel(grid, "Current [bwd]", bwd=true)

    err = nothing
    try
        get_channel(grid, "Bias2")
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "not found")

    err = nothing
    try
        get_parameter(grid, "Bias2")
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "not found")

    @test all(skipnan(get_data(grid, ch"Current"bwd)) .== skipnan(get_channel(grid, "Current", bwd=true)))
    @test all(skipnan(get_data(grid, ch"Current")) .== skipnan(get_channel(grid, "Current")))
    @test all(skipnan(get_data(grid, "Current")) .== skipnan(get_channel(grid, "Current")))
    @test all(skipnan(get_data(grid, "Current")) .== skipnan(get_channel(grid, ch"Current")))
    @test all(skipnan(get_data(grid, "Scan:Excitation")) .== skipnan(get_parameter(grid, "Scan:Excitation")))
    @test all(skipnan(get_data(grid, par"Scan:Excitation")) .== skipnan(get_parameter(grid, "Scan:Excitation")))
    @test all(skipnan(get_data(grid, par"Scan:Excitation")) .== skipnan(get_parameter(grid, par"Scan:Excitation")))
    @test typeof(get_data(grid, ch"Current")) <: SubArray
    @test typeof(get_data(grid, ch"Current", :, 1, 1)) <: SubArray
    @test typeof(get_data(grid, ch"Current", 1, 1, 1)) <: SubArray
    @test typeof(get_data(grid, par"Scan:Excitation")) <: SubArray
    @test typeof(get_data(grid, par"Scan:Excitation", :, 2)) <: SubArray
    @test typeof(get_data(grid, par"Scan:Excitation", 2, 2)) <: SubArray

    @test typeof(get_data(grid, ch"Current", view=false)) <: Array
    @test typeof(get_data(grid, ch"Current", view=false, :, 1, 1)) <: Array
    @test typeof(get_data(grid, ch"Current", view=false, 1, 1, 1)) <: Array
    @test typeof(get_data(grid, par"Scan:Excitation", view=false)) <: Array
    @test typeof(get_data(grid, par"Scan:Excitation", view=false, :, 2)) <: Array
    @test typeof(get_data(grid, par"Scan:Excitation", view=false, 2, 2)) <: Array

    err = nothing
    try
        get_data(grid, "doesnotexist")
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "Available channel names")
    @test contains(sprint(showerror, err), "Available parameter names")
end


@testset "add data" begin
    grid = load_grid("Grid Spectroscopy006.3ds")

    err = nothing
    try
        add_channel!(grid, "Bias2", "", Float64[])
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "needs to be of size")

    err = nothing
    try
        add_channel!(grid, "Bias", "", get_channel(grid, "Bias"))
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "already exists")
    @test contains(sprint(showerror, err), "Please")  # be polite

    err = nothing
    try
        add_channel!(grid, "", "", get_channel(grid, "Bias"))
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "specify a channel name")
    @test contains(sprint(showerror, err), "Please")  # be polite

    add_channel!(x -> abs.(x), grid, "CurrentAbs", "A", "Current", skip_bwd=true)
    add_channel!(x -> abs.(x), grid, "CurrentAbs", "A", "Current", skip_bwd=true)  # this overwrites the previous
    add_channel!((x,y) -> x + y, grid, "CurrentSum", "A", "Current", "CurrentAbs", skip_bwd=true)

    @test length(grid.generated_channels) == 2
    @test all(skipnan(get_channel(grid, "CurrentAbs")) .== skipnan(abs.(get_channel(grid, "Current"))))
    @test get_channel(grid, "CurrentSum", 1, 2, 20) ≈
        get_channel(grid, "CurrentAbs", 1, 2, 20) + get_channel(grid, "Current", 1, 2, 20)
    @test all(skipnan(get_channel(grid, "CurrentSum", 1:10, 2, 20)) .== 
        skipnan((get_channel(grid, "CurrentAbs", 1:10, 2, 20) + get_channel(grid, "Current", 1:10, 2, 20))))
    @test all(skipnan(get_channel(grid, "CurrentSum", 1:10, :, 1:20)) .==
        skipnan(get_channel(grid, "CurrentAbs", 1:10, :, 1:20) + get_channel(grid, "Current", 1:10, :, 1:20)))


    # should do backward channels too
    add_channel!(x -> abs.(x), grid, "CurrentAbs", "A", "Current")
    add_channel!(x -> abs.(x), grid, "CurrentAbs", "A", "Current")  # this overwrites the previous
    add_channel!((x,y) -> x + y, grid, "CurrentSum", "A", "Current", "CurrentAbs")
    @test length(grid.generated_channels) == 4
    @test all(skipnan(get_channel(grid, "CurrentAbs")) .== skipnan(abs.(get_channel(grid, "Current"))))
    @test get_channel(grid, "CurrentSum", 1, 2, 20) ≈
        get_channel(grid, "CurrentAbs", 1, 2, 20) + get_channel(grid, "Current", 1, 2, 20)
    @test all(get_channel(grid, "CurrentSum", 1:10, 2, 20) .== 
        get_channel(grid, "CurrentAbs", 1:10, 2, 20) + get_channel(grid, "Current", 1:10, 2, 20))
    @test all(skipnan(get_channel(grid, "CurrentSum", 1:10, :, 1:20)) .==
        skipnan(get_channel(grid, "CurrentAbs", 1:10, :, 1:20) + get_channel(grid, "Current", 1:10, :, 1:20)))
    @test all(skipnan(get_channel(grid, "CurrentAbs [bwd]")) .== skipnan(abs.(get_channel(grid, "Current [bwd]"))))
    @test get_channel(grid, "CurrentSum [bwd]", 1, 2, 20) ≈
        get_channel(grid, "CurrentAbs [bwd]", 1, 2, 20) + get_channel(grid, "Current [bwd]", 1, 2, 20)
    @test all(skipnan(get_channel(grid, "CurrentSum", 1:10, 2, 20)) .== 
        skipnan(get_channel(grid, "CurrentAbs [bwd]", 1:10, 2, 20) + get_channel(grid, "Current [bwd]", 1:10, 2, 20)))
    @test all(skipnan(get_channel(grid, "CurrentSum [bwd]", 1:10, :, 1:20)).==
        skipnan(get_channel(grid, "CurrentAbs [bwd]", 1:10, :, 1:20) + get_channel(grid, "Current [bwd]", 1:10, :, 1:20)))
    
        
    err = nothing
    try
        add_parameter!(grid, "Bias2", "", Float64[])
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "needs to be of size")

    err = nothing
    try
        add_parameter!(grid, "Sweep Start", "", get_parameter(grid, "Sweep Start"))
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "already exists")
    @test contains(sprint(showerror, err), "Please")  # be polite

    err = nothing
    try
        add_parameter!(grid, "", "", get_parameter(grid, "Sweep Start"))
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "specify a parameter name")
    @test contains(sprint(showerror, err), "Please")  # be polite

    add_parameter!((x,y) -> y-x, grid, "Sweep Diff", "", "Sweep Start", "Sweep End")
    add_parameter!((x,y) -> y-x, grid, "Sweep Diff", "", "Sweep Start", "Sweep End")  # this overwrites the previous
    add_parameter!((x,y) -> x+y, grid, "WeirdOne", "", "Sweep Diff", "Scan:Excitation")

    @test length(grid.generated_parameters) == 2
    @test get_parameter(grid, "Sweep Diff", 1, 2) ≈
        get_parameter(grid, "Sweep End", 1, 2) - get_parameter(grid, "Sweep Start", 1, 2)
    @test all(skipnan(get_parameter(grid, "Sweep Diff")) .==
        skipnan(get_parameter(grid, "Sweep End") - get_parameter(grid, "Sweep Start")))
    @test all(skipnan(get_parameter(grid, "WeirdOne")) .==
        skipnan(get_parameter(grid, "Sweep Diff") + get_parameter(grid, "Scan:Excitation")))

    add_channel!((x,y) -> x .- y, grid, "Z rel", "m", "Z", "Sweep Start")
    z = get_channel(grid, "Z")
    @test all(skipnan(get_data(grid, ch"Z rel")) .== skipnan(z .- get_parameter(grid, "Sweep Start")))
    z = get_channel(grid, bwd"Z")
    @test all(skipnan(get_data(grid, ch"Z rel"bwd)) .== skipnan(z .- get_parameter(grid, "Sweep Start")))
end


@testset "plot spectrum" begin
    grid = load_grid("Grid Spectroscopy002.3ds")

    x_name = grid.sweep_signal
    y_name = "Frequency Shift"
    y = get_channel(grid, y_name, 6, 6)
    x = get_channel(grid, x_name, 5, 6)

    y_factor, y_prefix = SpmGrids.get_factor_prefix(y)
    x_factor, x_prefix = SpmGrids.get_factor_prefix(x)
    x_label = SpmGrids.axis_label(grid, x_name, x_prefix)
    y_label = SpmGrids.axis_label(grid, y_name, y_prefix)

    @test x_label == "Bias / mV"
    @test y_label == "Frequency Shift / Hz"
    @test x_factor ≈ 1.0e3
    @test y_factor ≈ 1.

    # fig = CairoMakie.Figure(resolution = (800, 400))
    # ax = CairoMakie.Axis(fig[1, 1])
    # should set up automatically
    plot_spectrum(grid, "Z", "Frequency Shift", 5, 1:10, backend=CairoMakie)
    plot_spectrum(grid, "Z", "Frequency Shift", 5:6, 1)
    plot_spectrum(grid, "Z", "Frequency Shift", :, 5:6, 100:120)
    plot_spectrum(grid, "Z", "Frequency Shift", 5:6, 1:10)

    ax = current_axis()
    @test ax.ylabel[] == "Frequency Shift / Hz"
    @test ax.xlabel[] == "Z / nm"

    fig = CairoMakie.Figure(resolution = (800, 400))
    ax = CairoMakie.Axis(fig[1, 1])
    plot_spectrum(grid, "Bias", "Current", 12, 12, ax=ax)
    @test ax.xlabel[] == "Bias / mV"
    @test ax.ylabel[] == "Current / pA"

    @test abs(ax.finallimits[].origin[1] / -115.00001 - 1.0) < 0.2
    @test abs(ax.finallimits[].origin[2] / -115.49187 - 1.0) < 0.2

    @test abs(ax.finallimits[].widths[1] / 330.0001 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[2] / 263.00067 - 1.0) < 0.2

    grid = load_grid("Grid Spectroscopy006.3ds") # contains bwd and fwd, also is stopped after a few lines

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_spectrum(grid, "", "Frequency Shift", :, 5, color_bwd="#e0e0e0")  # only NaNs in 5th row
    @test ax.xlabel[] == "Z / m"
    @test ax.ylabel[] == "Frequency Shift / Hz"

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_spectrum(grid, "", "Current", :, 2, color_bwd="#e0e0e0")  # only NaNs in 5th row
    @test ax.xlabel[] == "Z / nm"
    @test ax.ylabel[] == "Current / pA"

    # x channel shoudl be sorted
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_spectrum(grid, "Frequency Shift", "Current", :, 2, color_bwd="#e0e0e0")  # only NaNs in 5th row
    @test ax.xlabel[] == "Frequency Shift / Hz"
    @test ax.ylabel[] == "Current / pA"
end


@testset "plot line" begin
    grid = load_grid("Grid Spectroscopy006.3ds") # contains bwd and fwd, also is stopped after a few lines

    # fig = CairoMakie.Figure(resolution = (800, 400));
    # ax = CairoMakie.Axis(fig[1, 1])
    # this should also work withiout the fig and ax setup
    plot_line(grid, "Frequency Shift", :, 5, 10, color_bwd="#e0e0e0")  # only NaNs in 5th row
    ax = current_axis()
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "Frequency Shift / Hz"

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_line(grid, "Frequency Shift", 5:10, 1, 10, color_bwd="#e0e0e0")  
    @test ax.xlabel[] == "grid x / pm"
    @test ax.ylabel[] == "Frequency Shift / Hz"
    @test abs(ax.finallimits[].origin[1] / 362.90323 - 1.0) < 0.2
    @test abs(ax.finallimits[].origin[2] / -2.4572 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[1] / 532.25806 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[2] / 0.2953453 - 1.0) < 0.2

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_line(grid, "Current", 5, :, 10, color_bwd="#e0e0e0")  
    @test ax.xlabel[] == "grid y / nm"
    @test ax.ylabel[] == "Current / fA"
    @test abs(ax.finallimits[].origin[1] / -0.00967742 - 1.0) < 0.2
    @test abs(ax.finallimits[].origin[2] / -34.985077 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[1] / 0.21290325 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[2] / 22.791697 - 1.0) < 0.2

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_line(grid, "Frequency Shift", 5, 2, 1:120, color_bwd="#e0e0e0")  
    @test ax.xlabel[] == "Z / nm"
    @test ax.ylabel[] == "Frequency Shift / Hz"
    @test abs(ax.finallimits[].origin[1] / -4.942342 - 1.0) < 0.2
    @test abs(ax.finallimits[].origin[2] / -7.784694 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[1] / 0.5133338 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[2] / 6.1346087 - 1.0) < 0.2

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_line(grid, "Frequency Shift", 5, 2, 1:120, color_bwd="#e0e0e0",
        sweep_channel="Z")
    @test ax.xlabel[] == "Z / nm"
    @test ax.ylabel[] == "Frequency Shift / Hz"
    @test abs(ax.finallimits[].origin[1] / -4.942342 - 1.0) < 0.2
    @test abs(ax.finallimits[].origin[2] / -7.784694 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[1] / 0.5133338 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[2] / 6.1346087 - 1.0) < 0.2

    # x channel should be sorted
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    plot_line(grid, "Frequency Shift", 5, 2, 1:120, color_bwd="#e0e0e0",
        sweep_channel="Current")
    @test ax.xlabel[] == "Current / pA"
    @test ax.ylabel[] == "Frequency Shift / Hz"
end

@testset "plot plane" begin
    grid = load_grid("Grid Spectroscopy006.3ds") # contains bwd and fwd, also is stopped after a few lines

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_plane(grid, "Frequency Shift", 5, :, 1:120, color_bwd="#e0e0e0")
    @test ax.xlabel[] == "grid y / nm"
    @test ax.ylabel[] == "Z / nm"
    @test r.data_label == "Frequency Shift / Hz"
    @test r.plot_label == "grid x=387.10 pm"

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_plane(grid, "Amplitude", :, 1, 1:120, bwd=true)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "Z [bwd] / nm"
    @test r.data_label == "Amplitude [bwd] / pm"
    @test r.plot_label == "grid y=0 m"

    grid = load_grid("Grid Spectroscopy002.3ds")
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])

    # this should give out two warnings, because there are no backward channels
    logs, value = Test.collect_test_logs() do
        r = plot_plane(grid, "Amplitude", :, :, 20, bwd=true)
    end
    @test occursin("No backward sweep data", logs[1].message)
    @test occursin("No backward sweep data", logs[2].message)

    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Amplitude / pm"  # there is no bwd channel here
    @test r.plot_label == "Bias=155.12 mV"

    # check some data
    d = SpmGrids.get_data_plane(grid, "Frequency Shift", :, :, 120)
    @test d.x[20] ≈ 15.0
    @test d.x[2] ≈ 0.7894736842105262
    @test d.y[6] ≈ 3.9473684
    @test d.data[2,17] ≈ -6.689748764038086
    d = SpmGrids.get_data_plane(grid, "Frequency Shift", 20, :, :)
    @test d.x[20] ≈ 15.0
    @test d.x[2] ≈ 0.7894736842105262
    @test d.y[6] ≈ 188.18898499011993
    @test d.data[2,17] ≈ -6.0430384
    d = SpmGrids.get_data_plane(grid, "Frequency Shift", 5:15, 3, :)
    @test d.x[2] ≈ 3.9473684
    @test d.x[11] ≈ 11.052631578947368
    @test d.y[6] ≈ 188.18898499011993
    @test d.data[2,17] ≈ -6.0026183

    grid = load_grid("Grid Spectroscopy006.3ds")
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_plane(grid, "Z", :, :, 21, bwd=true)  # Z is constant

    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Z [bwd] / nm"  # there is no bwd channel here
    @test r.plot_label == "Z=-4.53 nm"

    # only NaN data
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_plane(grid, "Z", :, 5:32, 21)  # Z is constant
    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Z / m"
    @test r.plot_label == "Z= m"
end

@testset "plot par plane" begin
    grid = load_grid("Grid Spectroscopy006.3ds")
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_parameter_plane(grid, "Z offset", :, :)
    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Z offset / pm"
    @test r.plot_label == "Z offset"

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_parameter_plane(grid, "Sweep End", :, :)
    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Sweep End / pm"
    @test r.plot_label == "Sweep End"


    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_parameter_plane(grid, "Scan:Amplitude", :, :)
    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Scan:Amplitude / pm"
    @test r.plot_label == "Scan:Amplitude"

    # only NaN data
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    r = plot_parameter_plane(grid, "Scan:Excitation", :, 5:32)
    ax.title = r.plot_label
    Colorbar(fig[1, 2], r.plot, label=r.data_label)
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test r.data_label == "Scan:Excitation / V"
    @test r.plot_label == "Scan:Excitation"

    # wrong type of axis, should give a warning
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis3(fig[1, 1], perspectiveness=0.5)
    logs, value = Test.collect_test_logs() do
        r = plot_parameter_plane(grid, "Scan:Excitation")
    end
    @test occursin("is not a 2D axis", logs[1].message)
    @test occursin("Please", logs[1].message)
end

@testset "plot cube" begin
    grid = load_grid("Grid Spectroscopy006.3ds") # contains bwd and fwd, also is stopped after a few lines
    
    # fig = CairoMakie.Figure(resolution = (800, 400));
    # ax = CairoMakie.Axis3(fig[1, 1], perspectiveness=0.5)
    # should auto-setup an Axis3
    logs, value = Test.collect_test_logs() do
        r = plot_cube(grid, "Amplitude", :, :, :,
            bwd=true, colormap=:Spectral_11, backend=CairoMakie)
    end
    # it uses the previous Axis, so there will be a warning
    @test occursin("is not a 3D axis", logs[1].message)
    @test occursin("Please", logs[1].message)

    fig = current_figure()
    ax = current_axis()
    Colorbar(fig[1, 2], r.plot, label=r.data_label)

    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test ax.zlabel[] == "Z [bwd] / nm"
    @test r.data_label == "Amplitude [bwd] / pm"

    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis3(fig[1, 1], perspectiveness=0.5)

    # Bias is constant, let's see if the plot and Colorbar work
    r = plot_cube(grid, "Bias", :, :, :,
        colormap=:Spectral_11, backend=CairoMakie)
    Colorbar(fig[1, 2], r.plot, label=r.data_label)        

    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test ax.zlabel[] == "Z / nm"
    @test r.data_label == "Bias / V"

    # Only NaNs
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis3(fig[1, 1], perspectiveness=0.5)
    r = plot_cube(grid, "Bias", :, 5:32, :,
        colormap=:Spectral_11, backend=CairoMakie)

    @test r.plot === nothing  # nothing to plot, so no 3d plot is made, and no colorbar can be made
    @test ax.xlabel[] == "grid x / nm"
    @test ax.ylabel[] == "grid y / nm"
    @test ax.zlabel[] == "Z / m"
    @test r.data_label == "Bias / V"

    # wrong type of axis, should give a warning
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1], perspectiveness=0.5)
    logs, value = Test.collect_test_logs() do
        plot_cube(grid, "Bias", backend=CairoMakie)
    end
    @test occursin("is not a 3D axis", logs[1].message)
    @test occursin("Please", logs[1].message)
end

@testset "interactive" begin
    f = interactive_display("Grid Spectroscopy002.3ds", backend=GLMakie, colormap=:lajolla)

    @test content(f[1,1][1,1]).xlabel[] == "grid x / nm"  # cube
    @test content(f[1,1][1,1]).ylabel[] == "grid y / nm"
    @test content(f[1,1][1,1]).zlabel[] == "Bias / mV"
    @test similar(content(f[1,1][1,2]).limits[], (-160.23476, 196.02937))  # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Current / pA"

    @test content(f[2,1][1,1]).xlabel[] == "grid x / nm"  #  plane
    @test content(f[2,1][1,1]).ylabel[] == "grid y / nm"
    @test similar(content(f[2,1][1,2]).limits[], (50.462166, 196.02937))  # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Current / pA"

    @test content(f[4,1][1,1]).xlabel[] == "grid x / nm"  #  par plane
    @test content(f[4,1][1,1]).ylabel[] == "grid y / nm"
    @test similar(content(f[4,1][1,2]).limits[], (103.536995, 117.787))  # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "X / nm"

    @test content(f[2,2][1,1]).xlabel[] == "Bias / mV"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Current / pA"
    @test content(f[2,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[4,2][1,1]).xlabel[] == "Bias / mV"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Applied Voltage measured / mV"
    @test content(f[4,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[1,2][1,1]).selection[] == "Current"  # menu channel1, selection observable
    @test content(f[1,2][2,1][1,2]).value[] == 1  # grid x
    @test content(f[1,2][2,1][2,2]).value[] == 1  # grid y
    @test content(f[1,2][2,1][3,2]).value[] == 1  # grid z
    
    @test content(f[3,1][1,1]).selection[] == "X"  # menu parameter, selection observable\
    
    @test content(f[3,2][1,1]).selection[] == "Applied Voltage measured"  # menu channel2, selection observable
    
    # change values
    content(f[1,2][1,1]).selection[] = "Frequency Shift"
    content(f[1,2][2,1][1,2]).value[] = 6
    content(f[1,2][2,1][2,2]).value[] = 2
    content(f[1,2][2,1][3,2]).value[] = 69
    content(f[3,1][1,1]).selection[] = "Sweep Start"
    content(f[3,2][1,1]).selection[] = "Phase"

    @test similar(content(f[1,1][1,2]).limits[], (-7.0765924, -5.8998227))  # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Frequency Shift / Hz"
    @test similar(content(f[2,1][1,2]).limits[], (-6.503672, -6.044674))  # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Frequency Shift / Hz"
    @test similar(content(f[4,1][1,2]).limits[], (198.0, 202.0))  # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "Sweep Start / mV"
    @test content(f[2,2][1,1]).xlabel[] == "Bias / mV"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Frequency Shift / Hz"
    @test content(f[2,2][1,1]).title[] == "grid x=3.95 nm, grid y=789.47 pm"
    @test content(f[4,2][1,1]).xlabel[] == "Bias / mV"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Phase / mdeg"
    @test content(f[4,2][1,1]).title[] == "grid x=3.95 nm, grid y=789.47 pm"

    grid = load_grid("Grid Spectroscopy006.3ds")
    add_channel!(x -> abs.(x), grid, "AbsCurrent", "A", "Current", skip_bwd=true)
    add_channel!(x -> abs.(x), grid, "AbsBias", "V", "Bias")
    add_parameter!(x -> abs.(x), grid, "AbsExcitation", "V", "Scan:Excitation")

    f = interactive_display(grid, "Frequency Shift", "Current", "Sweep Start",
        bwd=true, backend=GLMakie, colormap=:lajolla)

    @test content(f[1,1][1,1]).xlabel[] == "grid x / nm"  # cube
    @test content(f[1,1][1,1]).ylabel[] == "grid y / nm"
    @test content(f[1,1][1,1]).zlabel[] == "Z [bwd] / nm"
    @test similar(content(f[1,1][1,2]).limits[], (-27.851484, -1.9089116)) # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Frequency Shift [bwd] / Hz"

    @test content(f[2,1][1,1]).xlabel[] == "grid x / nm"  #  plane
    @test content(f[2,1][1,1]).ylabel[] == "grid y / nm"
    @test similar(content(f[2,1][1,2]).limits[], (-2.4514494, -1.9089116))  # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Frequency Shift [bwd] / Hz"

    @test content(f[4,1][1,1]).xlabel[] == "grid x / nm"  #  par plane
    @test content(f[4,1][1,1]).ylabel[] == "grid y / nm"
    @test similar(content(f[4,1][1,2]).limits[], (197.99998, 201.99998))  # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "Sweep Start / pm"

    @test content(f[2,2][1,1]).xlabel[] == "Z / nm"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Frequency Shift / Hz"
    @test content(f[2,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[4,2][1,1]).xlabel[] == "Z / nm"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Current / pA"
    @test content(f[4,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[1,2][1,1]).selection[] == "Frequency Shift"  # menu channel1, selection observable
    @test content(f[1,2][2,1][1,2]).value[] == 1  # grid x
    @test content(f[1,2][2,1][2,2]).value[] == 1  # grid y
    @test content(f[1,2][2,1][3,2]).value[] == 1  # grid z
    @test content(f[1,2][3,1][1,2]).active[] == false  # backward/forward
    
    @test content(f[3,1][1,1]).selection[] == "Sweep Start"  # menu parameter, selection observable\
    
    @test content(f[3,2][1,1]).selection[] == "Current"  # menu channel2, selection observable
    
    # change values, mostly NaN values to be plotted
    content(f[1,2][1,1]).selection[] = "Bias"
    content(f[1,2][2,1][1,2]).value[] = 9
    content(f[1,2][2,1][2,2]).value[] = 6
    content(f[1,2][2,1][3,2]).value[] = 96
    content(f[1,2][3,1][1,2]).active = true
    content(f[3,1][1,1]).selection[] = "Scan:Bias"
    content(f[3,2][1,1]).selection[] = "Excitation"

    @test content(f[1,1][1,1]).zlabel[] == "Z / nm"
    @test content(f[1,1][1,2]).limits[] == (-0.01, 0.01)  # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Bias / V"
    @test content(f[2,1][1,1]).title[] == "Z=-4.82 nm"
    @test content(f[2,1][1,2]).limits[] == (-0.01, 0.01)   # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Bias / V"
    @test content(f[4,1][1,2]).limits[] == (-0.01, 0.01) # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "Scan:Bias / V"
    @test content(f[2,2][1,1]).xlabel[] == "Z / m"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Bias / V"
    @test content(f[2,2][1,1]).title[] == "grid x=774.19 pm, grid y=483.87 pm"
    @test content(f[4,2][1,1]).xlabel[] == "Z / m"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Excitation / V"
    @test content(f[4,2][1,1]).title[] == "grid x=774.19 pm, grid y=483.87 pm"

    # check generated channels and parameters
    @test occursin("not available for all", content(f[1,2][3,1][1,5]).text[])  # some generated channels dont have backwards data
    content(f[1,2][1,1]).selection[] = "AbsBias"
    content(f[1,2][3,1][1,2]).active = false
    content(f[3,2][1,1]).selection[] = "AbsCurrent"
    content(f[3,1][1,1]).selection[] = "AbsExcitation"
    content(f[3,2][1,1]).selection[] = "AbsCurrent"  # changes length of xy_bwd values

    @test content(f[1,1][1,1]).zlabel[] == "Z [bwd] / nm"
    @test content(f[1,1][1,2]).limits[] == (-0.01, 0.01)  # cube colorbar
    @test content(f[1,1][1,2]).label[] == "AbsBias [bwd] / V"
    @test content(f[2,1][1,1]).title[] == "Z=-4.82 nm"
    @test content(f[2,1][1,2]).limits[] == (-0.01, 0.01)   # plane colorbar
    @test content(f[2,1][1,2]).label[] == "AbsBias [bwd] / V"
    @test similar(content(f[4,1][1,2]).limits[], (0.026592601, 47.17634)) # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "AbsExcitation / mV"
    @test content(f[2,2][1,1]).xlabel[] == "Z / m"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "AbsBias / V"
    @test content(f[4,2][1,1]).xlabel[] == "Z / m"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "AbsCurrent / A"
end

@testset "domain functions" begin
    grid = load_grid("Grid Spectroscopy002.3ds")
    
    # KPFM

    # manually create backwards channels
    add_channel!(grid, bwd"Frequency Shift", "Hz", get_channel(grid, "Frequency Shift"))
    add_channel!(grid, bwd"Bias", "V", get_channel(grid, "Bias"))

    fit_KPFM!(grid, "Frequency Shift")

    d = get_data(grid, "KPFM:Bias")
    @test d[2,12] ≈ 0.14959989639861593
    @test d[7,16] ≈ 0.13154882380114918

    d = get_data(grid, "KPFM:Frequency Shift")
    @test d[9, 2] ≈ -5.9851432718361455
    @test d[12, 8] ≈ -6.070098

    d = get_data(grid, "KPFM:Fit")
    @test d[1,6,123] ≈ -6.576270333507708
    @test d[3,9,12] ≈ -6.0692973
    d = get_data(grid, bwd"KPFM:Fit")
    @test d[1,6,123] ≈ -6.576270333507708
    @test d[3,9,12] ≈ -6.0692973

    d = get_data(grid, "KPFM:Residuals")
    @test d[1,2,98] ≈ 0.02949972226111086
    @test  d[7,3,2] ≈ -0.04449738294511185
    d = get_data(grid, bwd"KPFM:Residuals")
    @test d[1,2,98] ≈ 0.02949972226111086
    @test  d[7,3,2] ≈ -0.04449738294511185

    d = get_data(grid, "KPFM:Residuals AbsSum")
    @test d[5,1] ≈ 1.6319225859795568
    @test d[12,6] ≈ 1.9877788006380177


    # force deconvolution

    # check error messages
    delete!(grid.header, "Oscillation Control>Amplitude Setpoint (m)")
    err = nothing
    try
        deconvolve_force!(grid, "Frequency Shift")
    catch err
    end
    @test contains(sprint(showerror, err), "oscillation amplitude")
    @test contains(sprint(showerror, err), "not saved in the header")
    @test contains(sprint(showerror, err), "Please specify")

    delete!(grid.header, "Oscillation Control>Center Frequency (Hz)")
    err = nothing
    try
        deconvolve_force!(grid, "Frequency Shift")
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "resonance frequency")
    @test contains(sprint(showerror, err), "not saved in the header")
    @test contains(sprint(showerror, err), "Please specify")

    grid = load_grid("Grid Spectroscopy006.3ds")
    logs, value = Test.collect_test_logs() do
        force_deconvolve!(grid, "Frequency Shift")
    end
    @test occursin("not sorted", logs[1].message)
    @test occursin("you sure", logs[1].message)

end