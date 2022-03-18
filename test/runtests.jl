using Dates
using SpmGrids
using Test

@testset "loading" begin
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

    @test grid.fixed_parameters == ["Sweep Start", "Sweep End"]
    @test grid.experiment_parameters == ["X", "Y", "Z", "Z offset", "Settling time", "Integration time", "Z-Ctrl", "Final Z", "Scan:Current", "Scan:Applied Voltage measured", "Scan:Bias", "Scan:Z", "Scan:Phase", "Scan:Amplitude", "Scan:Frequency Shift", "Scan:Excitation"]
    @test grid.experiment_parameters_units == ["m", "m", "m", "m", "s", "s", "hold", "m", "A", "V", "V", "m", "deg", "m", "Hz", "V"]
    @test grid.fixed_parameters == ["Sweep Start", "Sweep End"]
    @test grid.channel_names == ["Current", "Applied Voltage measured", "Bias", "X", "Y", "Z", "Phase", "Amplitude", "Frequency Shift", "Excitation"]
    @test grid.channel_units == ["A", "V", "V", "m", "m", "m", "deg", "m", "Hz", "V"]

    @test grid.sweep_signal == "Bias"

    @test grid.header["Oscillation Control>PLL-Setup Demod. Bandwidth Amp (Hz)"] == "80E+0"
    @test grid.header["Z-Controller>Switch off delay (s)"] == "50E-3"
    @test grid.header["Comment"] == "KPFM"
    @test grid.header["Experiment"] == "Grid Spectroscopy"

    global grid = load_grid("Grid Spectroscopy002.3ds")

    @test length(grid.data) == 20 * 20 * (18 + 10 * 128)  # pixels * (parameters + channels * points)
    @test size(get_channel(grid, "Bias", 4:20, 5:5)) == (128,17,1)
    @test size(get_channel(grid, "Frequency Shift", 4:20, 5:7, 20:23)) == (4,17,3)
    @test get_channel(grid, "Bias", 20, 7, 20)[] ≈ 0.15511811f0
    @test all(get_parameter(grid, "Z offset", 3, :) .≈ 0.0)
    @test get_parameter(grid, "Z", 3, 5) ≈ -1.1132063f-8
    @test get_channel(grid, "Current", 20, 7, 20:24) ≈ Float32[1.3028699f-10, 1.2868269f-10, 1.2712124f-10, 1.2609777f-10, 1.2497206f-10]
end


@testset "plotting" begin
    # grid = load_grid("Grid Spectroscopy006.3ds") # contains bwd and fwd, also is stopped after a few lines

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
    @test x_factor ≈ 1.0f-3
    @test y_factor ≈ 1.0f0

    using CairoMakie  # should also work with WGLMakie and GLMakie
    fig = CairoMakie.Figure(resolution = (800, 400))
    ax = CairoMakie.Axis(fig[1, 1])
    plot_spectrum(grid, "Z", "Frequency Shift", 5, 1:10, backend=CairoMakie)
    plot_spectrum(grid, "Z", "Frequency Shift", 5:6, 1)
    plot_spectrum(grid, "Z", "Frequency Shift", :, 5:6, 100:120)
    plot_spectrum(grid, "Z", "Frequency Shift", 5:6, 1:10)

    @test ax.ylabel[] == "Frequency Shift / Hz"
    @test ax.xlabel[] == "Z / nm"

    fig = CairoMakie.Figure(resolution = (800, 400))
    ax = CairoMakie.Axis(fig[1, 1])
    plot_spectrum(grid, "Bias", "Current", 12, 12, ax=ax)
    @test ax.xlabel[] == "Bias / mV"
    @test ax.ylabel[] == "Current / pA"

    @test abs(ax.finallimits[].origin[1] / -115.00001f0 - 1.0) < 0.2
    @test abs(ax.finallimits[].origin[2] / -115.49187f0 - 1.0) < 0.2

    @test abs(ax.finallimits[].widths[1] / 330.0001f0 - 1.0) < 0.2
    @test abs(ax.finallimits[].widths[2] / 263.00067f0 - 1.0) < 0.2
end