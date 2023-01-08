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
    @test all(xyindex_to_point(grid, 1, 1) .≈ (0.0, 0.0))
    @test all(xyindex_to_point(grid, grid.pixelsize...) .≈ Tuple(grid.size))
    @test point_to_xyindex(grid, [0.0, 7.105263157894736e-9]) == (1, 10)
    @test point_to_xyindex(grid, [0.0, 0.0]) == (1, 1)
    @test point_to_xyindex(grid, grid.size) == Tuple(grid.pixelsize)

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

@testset "resize" begin
    grid = load_grid("Grid Spectroscopy006.3ds")

    err = nothing
    try
        resize!(grid, 12)
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "at least two dimensions")

    err = nothing
    try
        resize!(grid)
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "at least two dimensions")

    logs, value = Test.collect_test_logs() do
        resize!(grid, 12, 12, 12, 12)
    end
    @test occursin("too many", logs[1].message)

    logs, value = Test.collect_test_logs() do
        resize!(grid, (12, 12, 12, 12))
    end
    @test occursin("too many", logs[1].message)

    logs, value = Test.collect_test_logs() do
        resize!(grid, ratio=(12, 12, 12, 12))
    end
    @test occursin("too many", logs[1].message)

    pixelsize_old = grid.pixelsize
    points_old = grid.points

    add_parameter!((x,y) -> y-x, grid, "Sweep Diff before", "", "Sweep Start", "Sweep End")

    resize!(grid, ratio=0.5)
    @test grid.pixelsize == ceil.(Int, pixelsize_old * 0.5)
    @test grid.points == ceil.(Int, points_old * 0.5)
    z = get_channel(grid, "Z")
    @test size(z)[1:2] == Tuple(ceil.(Int, pixelsize_old * 0.5))
    @test size(z)[3] == ceil.(Int, points_old * 0.5)
    @test size(get_parameter(grid, "Sweep Start")) == Tuple(ceil.(Int, pixelsize_old * 0.5))
    @test size(get_parameter(grid, "Z offset")) == Tuple(ceil.(Int, pixelsize_old * 0.5))

    add_parameter!((x,y) -> y-x, grid, "Sweep Diff", "", "Sweep Start", "Sweep End")
    @test size(get_parameter(grid, "Sweep Diff")) == Tuple(ceil.(Int, pixelsize_old * 0.5))
    @test size(get_parameter(grid, "Sweep Diff before")) == Tuple(ceil.(Int, pixelsize_old * 0.5))

    grid = load_grid("Grid Spectroscopy006.3ds")
    pixelsize_old = grid.pixelsize
    points_old = grid.points
    
    resize!(grid, (12, 12, 12))
    @test grid.pixelsize == [12,12]
    @test grid.points == 12
    z = get_channel(grid, "Z")
    @test size(z)[1:2] == (12,12)
    @test size(z)[3] == 12
    @test size(get_parameter(grid, "Sweep Start")) == (12, 12)
    @test size(get_parameter(grid, "Z offset")) == (12, 12)

    grid = load_grid("Grid Spectroscopy006.3ds")
    pixelsize_old = grid.pixelsize
    points_old = grid.points
    resize!(grid, (12, 12))
    @test grid.pixelsize == [12,12]
    @test grid.points == points_old
    z = get_channel(grid, "Z")
    @test size(z)[1:2] == (12,12)
    @test size(z)[3] == points_old
    @test size(get_parameter(grid, "Sweep Start")) == (12, 12)
    @test size(get_parameter(grid, "Z offset")) == (12, 12)

    grid = load_grid("Grid Spectroscopy006.3ds")
    pixelsize_old = grid.pixelsize
    points_old = grid.points
    resize!(grid, 12, 12)
    @test grid.pixelsize == [12,12]
    @test grid.points == points_old
    z = get_channel(grid, "Z")
    @test size(z)[1:2] == (12,12)
    @test size(z)[3] == points_old
    @test size(get_parameter(grid, "Sweep Start")) == (12, 12)
    @test size(get_parameter(grid, "Z offset")) == (12, 12)

    grid = load_grid("Grid Spectroscopy006.3ds")
    pixelsize_old = grid.pixelsize
    points_old = grid.points
    resize!(grid, ratio=(0.5, 0.5))
    @test grid.pixelsize == ceil.(Int, pixelsize_old * 0.5)
    @test grid.points == points_old
    z = get_channel(grid, "Z")
    @test size(z)[1:2] == Tuple(ceil.(Int, pixelsize_old * 0.5))
    @test size(z)[3] == points_old
    @test size(get_parameter(grid, "Sweep Start")) == Tuple(ceil.(Int, pixelsize_old * 0.5))
    @test size(get_parameter(grid, "Z offset")) == Tuple(ceil.(Int, pixelsize_old * 0.5))
end
