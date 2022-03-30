using CairoMakie


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