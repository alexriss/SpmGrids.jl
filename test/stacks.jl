@testset "image stacks" begin
    stacks = readdir("stacks", join=true)

    err = nothing
    try
        load_grid(stacks[1:1])
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "Please provide at least")

    images = load_image.(stacks[1:5], output_info=0)
    images[3].angle = -12.0
    err = nothing
    try
        load_grid(images)
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "rotation")
    @test contains(sprint(showerror, err), "same")

    err = nothing
    try
        load_grid([stacks[1], stacks[1], stacks[1]])
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "no variation")

    images = load_image.(stacks[2:5], output_info=0)
    logs, value = Test.collect_test_logs() do
        grid = load_grid(stacks[2:5], im -> im.z, "Z", "m_")
    end
    @test occursin("already exists", logs[1].message)

    @test grid.bias ≈ -0.00115
    @test grid.z_feedback == false
    @test grid.sweep_signal == "Z"
    @test grid.start_time == images[1].start_time
    @test grid.end_time == unix2datetime(datetime2unix(images[end].start_time) + images[end].acquisition_time)
    @test grid.fixed_parameter_names == ["Sweep Start", "Sweep End"]
    @test grid.channel_units["Z"] == "m_"
    @test grid.channel_names == ["Z", "Applied Voltage measured", "Bias", "Current", "Phase",
        "Amplitude", "Frequency Shift", "Excitation",
        "Z [bwd]", "Applied Voltage measured [bwd]", "Bias [bwd]", "Current [bwd]", "Phase [bwd]",
        "Amplitude [bwd]", "Frequency Shift [bwd]", "Excitation [bwd]"]
    @test grid.channel_units["Phase"] == "deg"
    @test grid.channel_units["Frequency Shift [bwd]"] == "Hz"
    @test grid.channel_units["Current [bwd]"] == "A"
    @test grid.channel_units["Current"] == "A"
    @test size(grid.data) == (48,48,66)
    @test approx(get_channel(grid, "Z", 15, 1, 3), SpmImages.get_channel(images[3], "Z").data[15,1])
    @test approx(get_channel(grid, "Z", 1, 48, 2), images[2].z)
    # images are sorted
    @test approx(get_channel(grid, "Phase", 48, 3, 1), SpmImages.get_channel(images[4], "Phase").data[48,3])
    @test approx(get_parameter(grid, "Sweep Start", 3, 48), images[4].z)

    images = load_image.(stacks[1:5], output_info=0)
    images[4].z_feedback = true
    images[5].bias = 1.
    grid = load_grid(images, im -> im.bias, "Bias_", "V", header_only=true)
    @test ismissing(grid.bias)
    @test ismissing(grid.z_feedback)
    @test grid.sweep_signal == "Bias_"
    @test grid.start_time == images[1].start_time
    @test grid.end_time == unix2datetime(datetime2unix(images[end].start_time) + images[end].acquisition_time)
    @test grid.fixed_parameter_names == ["Sweep Start", "Sweep End"]
    @test grid.channel_units["Bias_"] == "V"
    @test length(grid.data) == 0

    @test approx(grid.center, images[1].center * 1e-9)
    @test grid.angle ≈ -41.
    @test approx(grid.size, images[1].scansize * 1e-9)

    im = images[1]
    im2 = images[2]
    offset = [0.2, 0.3]
    im.center .+= offset
    sort!(images, by=im -> (im.bias, im.start_time))
    grid = load_grid(images, im -> im.bias, "Bias_", "V")
    @test approx(grid.center * 1e9, im2.center .+ offset ./ 2)
    @test approx(grid.size * 1e9, im2.scansize .+ offset)
    @test size(grid.data) == (58, 62, 92)
    @test approx(get_channel(grid, "Bias_", 15, 1, 3), SpmImages.get_channel(images[3], "Bias_").data[15,1])
    @test isnan(get_channel(grid, "Frequency Shift", 5, 3, 4)[])
    @test get_channel(grid, "Frequency Shift", 25, 23, 4)[] ≈ -25.57718276977539
    @test approx(get_channel(grid, "Bias_", 15, 1, 3), SpmImages.get_channel(images[3], "Bias_").data[15,1])

    grid = load_grid(images, im -> im.bias, "Bias_", "V", only_overlap=true)
    @test approx(grid.center * 1e9, im2.center .+ offset ./ 2)
    @test approx(grid.size * 1e9, im2.scansize .- offset)
    @test size(grid.data) == (38, 34, 92)
    @test approx(get_channel(grid, "Bias_", 15, 1, 3), SpmImages.get_channel(images[3], "Bias_").data[15,1])
    @test get_channel(grid, "Frequency Shift", 5, 3, 4)[] ≈ -25.569202423095703
    @test get_channel(grid, "Frequency Shift", 25, 23, 4)[] ≈ -25.272993087768555
    @test approx(get_channel(grid, "Bias_", 15, 1, 3), SpmImages.get_channel(images[3], "Bias_").data[15,1])

    im.center .-= offset .* 2
    grid = load_grid(images, im -> im.z, "Z_", "m")
    @test approx(grid.center * 1e9, im2.center .- offset ./ 2)
    @test approx(grid.size * 1e9, im2.scansize .+ offset)
    @test size(grid.data) == (58, 62, 92)
    @test isnan(get_channel(grid, "Phase", 15, 1, 3)[])
    @test isnan(get_channel(grid, "Frequency Shift", 50, 3, 4)[])
    @test get_channel(grid, "Frequency Shift", 25, 23, 4)[] ≈ -25.272993087768555
    @test get_channel(grid, "Phase", 15, 23, 3)[] ≈ 0.4804893732070923

    grid = load_grid(images, im -> im.z, "Z_", "m", only_overlap=true)
    @test approx(grid.center * 1e9, im2.center .- offset ./ 2)
    @test approx(grid.size * 1e9, im2.scansize .- offset)
    @test size(grid.data) == (38, 34, 92)
    @test get_channel(grid, "Phase", 15, 1, 3)[] ≈ 0.3382571041584015
    @test get_channel(grid, "Frequency Shift", 25, 23, 4)[] ≈ -25.695274353027344
    @test get_channel(grid, "Excitation", 15, 23, 3)[] ≈ 0.04180599004030228

    images[4].center .+= 100.
    err = nothing
    try
        load_grid(images)
    catch err
    end
    @test isnothing(err)
    try
        load_grid(images, only_overlap=true)
    catch err
    end
    @test err isa Exception
    @test contains(sprint(showerror, err), "overlap")
end
