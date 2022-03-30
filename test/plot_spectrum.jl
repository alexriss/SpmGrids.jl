using CairoMakie


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