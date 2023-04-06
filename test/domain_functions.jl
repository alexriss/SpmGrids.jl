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

    # Z spectroscopy
    grid = load_grid("Grid Spectroscopy006.3ds")
    deconvolve_force!(grid, "Frequency Shift", bwd=false)

    @test has_channel(grid, "Force z")
    @test has_channel(grid, "Force x")
    @test has_channel(grid, "Force y")
    @test has_channel(grid, "Potential")
    @test !has_channel(grid, "Force z", bwd=true)
    @test !has_channel(grid, "Force x", bwd=true)
    @test !has_channel(grid, "Force y", bwd=true)
    @test !has_channel(grid, "Potential", bwd=true)

    grid = load_grid("Grid Spectroscopy006.3ds")
    deconvolve_force!(grid, "Frequency Shift")

    @test has_channel(grid, "Force z")
    @test has_channel(grid, "Force x")
    @test has_channel(grid, "Force y")
    @test has_channel(grid, "Potential")
    @test has_channel(grid, "Force z", bwd=true)
    @test has_channel(grid, "Force x", bwd=true)
    @test has_channel(grid, "Force y", bwd=true)
    @test has_channel(grid, "Potential", bwd=true)

    c = get_channel(grid, "Force z")
    @test c[6,2,10] ≈ -1.4573654967919203e-11
    @test c[12,3,10] ≈ -5.971859281705465e-12
    @test isnan(c[12,4,10])
    c = get_channel(grid, "Potential")
    @test c[12,1,10]≈ -0.0011771857638349808
    @test c[7,2,100] ≈ -0.18696641607427575
    @test isnan(c[12,4,10])
    c = get_channel(grid, "Force x")
    @test  c[12,3,100] ≈ 1.114412113440699e-11
    @test c[9,1,50] ≈ 1.3718976179363038e-12
    @test isnan(c[12,4,1])
    c = get_channel(grid, "Force y")
    @test c[11,2,35] ≈ 2.1034652984668115e-13
    @test c[1,2,98] ≈ -2.8012188662431884e-12
    @test isnan(c[11,4,35])

    c = get_channel(grid, bwd"Force z")
    @test c[6,2,10] ≈ -1.3280328215799362e-11
    @test c[12,3,10] ≈ -1.9820765373158113e-12
    @test isnan(c[12,4,1])
    c = get_channel(grid, bwd"Potential")
    @test c[12,1,10]≈ -0.0011360021159299938
    @test c[7,2,100] ≈ -0.18984193578405226
    @test isnan(c[12,4,10])
    c = get_channel(grid, bwd"Force x")
    @test  c[12,3,100] ≈ 9.464651478295935e-12
    @test c[9,1,50] ≈ -3.4812489338057054e-13
    @test isnan(c[12,4,1])
    c = get_channel(grid, bwd"Force y")
    @test c[11,2,35] ≈ -6.462421535974403e-13
    @test c[1,2,98] ≈ 1.1972075342766095e-12
    @test isnan(c[11,4,35])

end