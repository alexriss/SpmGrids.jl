
using CairoMakie


@testset "plot cube" begin
    grid = load_grid("Grid Spectroscopy006.3ds") # contains bwd and fwd, also is stopped after a few lines
    
    fig = CairoMakie.Figure(resolution = (800, 400));
    ax = CairoMakie.Axis(fig[1, 1])
    logs, value = Test.collect_test_logs() do
        r = plot_cube(grid, "Amplitude", :, :, :,
            bwd=true, colormap=:Spectral_11, backend=CairoMakie)
    end
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
    ax = CairoMakie.Axis(fig[1, 1])
    logs, value = Test.collect_test_logs() do
        plot_cube(grid, "Bias", backend=CairoMakie)
    end
    @test occursin("is not a 3D axis", logs[1].message)
    @test occursin("Please", logs[1].message)
end