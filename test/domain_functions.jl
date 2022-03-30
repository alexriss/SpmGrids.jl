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

    # not a Z-Spectroscopy experiment, so it should give a warning
    grid = load_grid("Grid Spectroscopy002.3ds")
    err = nothing
    try
        deconvolve_force!(grid, "Frequency Shift", sweep_channel="Z")
    catch err
    end
    @test contains(sprint(showerror, err), "no variation")
    @test contains(sprint(showerror, err), "wrong type of grid experiment")

    z = get_channel(grid, "Z")
    z[1,1,1:3] .= [-3., -2., -1.]  # manually set, so that there is some variation
    logs, value = Test.collect_test_logs() do
        deconvolve_force!(grid, "Frequency Shift")
    end
    @test occursin("sweep channel unit is", logs[1].message)
    @test occursin("you sure", logs[1].message)

    z[1,1,1:3] .= [1.,0.,2.]  # manually set, so that there is some variation
    logs, value = Test.collect_test_logs() do
        deconvolve_force!(grid, "Frequency Shift", sweep_channel="Z")
    end
    @test occursin("not sorted", logs[1].message)
    @test occursin("you sure", logs[1].message)

end