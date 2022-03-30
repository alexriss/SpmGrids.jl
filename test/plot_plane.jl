using CairoMakie


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
