using GLMakie


@testset "interactive" begin
    logs, value = Test.collect_test_logs() do
        f = interactive_display("Grid Spectroscopy002.3ds", "chname", "chname2", "parname", backend=GLMakie, colormap=:lajolla)
    end
    @test occursin("chname", logs[1].message)
    @test occursin("not found", logs[1].message)
    @test occursin("chname2", logs[2].message)
    @test occursin("not found", logs[2].message)
    @test occursin("parname", logs[3].message)
    @test occursin("not found", logs[3].message)
    @test content(f[1,2][1,1]).selection[] == "Current"  # menu channel
    @test content(f[3,2][1,1]).selection[] == "Applied Voltage measured"  # menu channel2
    @test content(f[3,1][1,1]).selection[] == "Sweep Start"  # menu parameter

    f = interactive_display("Grid Spectroscopy002.3ds", backend=GLMakie, colormap=:lajolla)
    @test content(f[1,1][1,1]).xlabel[] == "grid x / nm"  # cube
    @test content(f[1,1][1,1]).ylabel[] == "grid y / nm"
    @test content(f[1,1][1,1]).zlabel[] == "Bias / mV"
    @test approx(content(f[1,1][1,2]).limits[], (-160.23476, 196.02937))  # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Current / pA"

    @test content(f[2,1][1,1]).xlabel[] == "grid x / nm"  #  plane
    @test content(f[2,1][1,1]).ylabel[] == "grid y / nm"
    @test approx(content(f[2,1][1,2]).limits[], (50.462166, 196.02937))  # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Current / pA"

    @test content(f[4,1][1,1]).xlabel[] == "grid x / nm"  #  par plane
    @test content(f[4,1][1,1]).ylabel[] == "grid y / nm"
    @test approx(content(f[4,1][1,2]).limits[], (103.536995, 117.787))  # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "X / nm"

    @test content(f[2,2][1,1]).xlabel[] == "Bias / mV"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Current / pA"
    @test content(f[2,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[4,2][1,1]).xlabel[] == "Bias / mV"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Applied Voltage measured / mV"
    @test content(f[4,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[1,2][1,1]).selection[] == "Current"  # menu channel1, selection observable
    @test content(f[1,2][2,1]).sliders[1].value[] == 1  # grid x
    @test content(f[1,2][2,1]).sliders[2].value[] == 1  # grid y
    @test content(f[1,2][2,1]).sliders[3].value[] == 1  # grid z
    
    @test content(f[3,1][1,1]).selection[] == "X"  # menu parameter, selection observable
    
    @test content(f[3,2][1,1]).selection[] == "Applied Voltage measured"  # menu channel2, selection observable
    
    # change values
    content(f[1,2][1,1]).selection[] = "Frequency Shift"
    content(f[1,2][2,1]).sliders[1].value[] = 6
    content(f[1,2][2,1]).sliders[2].value[] = 2
    content(f[1,2][2,1]).sliders[3].value[] = 69
    content(f[3,1][1,1]).selection[] = "Sweep Start"
    content(f[3,2][1,1]).selection[] = "Phase"

    @test approx(content(f[1,1][1,2]).limits[], (-7.0765924, -5.8998227))  # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Frequency Shift / Hz"
    @test approx(content(f[2,1][1,2]).limits[], (-6.503672, -6.044674))  # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Frequency Shift / Hz"
    @test approx(content(f[4,1][1,2]).limits[], (198.0, 202.0))  # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "Sweep Start / mV"
    @test content(f[2,2][1,1]).xlabel[] == "Bias / mV"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Frequency Shift / Hz"
    @test content(f[2,2][1,1]).title[] == "grid x=3.95 nm, grid y=789.47 pm"
    @test content(f[4,2][1,1]).xlabel[] == "Bias / mV"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Phase / mdeg"
    @test content(f[4,2][1,1]).title[] == "grid x=3.95 nm, grid y=789.47 pm"

    # labels
    @test content(f[4,1][1,1, TopRight()][1,1]).text[] == "200.00"
    @test content(f[2,2][1,1, TopRight()][1,1]).text[] == "-6.14"
    @test content(f[4,2][1,1, TopRight()][1,1]).text[] == "-7.41"

    grid = load_grid("Grid Spectroscopy006.3ds")
    add_channel!(x -> abs.(x), grid, "AbsCurrent", "A", "Current", skip_bwd=true)
    add_channel!(x -> abs.(x), grid, "AbsBias", "V", "Bias")
    add_parameter!(x -> abs.(x), grid, "AbsExcitation", "V", "Scan:Excitation")

    f = interactive_display(grid, "Frequency Shift", "Current", "Sweep Start",
        bwd=true, backend=GLMakie, colormap=:lajolla)

    @test content(f[1,1][1,1]).xlabel[] == "grid x / nm"  # cube
    @test content(f[1,1][1,1]).ylabel[] == "grid y / nm"
    @test content(f[1,1][1,1]).zlabel[] == "Z [bwd] / nm"
    @test approx(content(f[1,1][1,2]).limits[], (-27.851484, -1.9089116)) # cube colorbar
    @test content(f[1,1][1,2]).label[] == "Frequency Shift [bwd] / Hz"

    @test content(f[2,1][1,1]).xlabel[] == "grid x / nm"  #  plane
    @test content(f[2,1][1,1]).ylabel[] == "grid y / nm"
    @test approx(content(f[2,1][1,2]).limits[], (-2.4514494, -1.9089116))  # plane colorbar
    @test content(f[2,1][1,2]).label[] == "Frequency Shift [bwd] / Hz"

    @test content(f[4,1][1,1]).xlabel[] == "grid x / nm"  #  par plane
    @test content(f[4,1][1,1]).ylabel[] == "grid y / nm"
    @test approx(content(f[4,1][1,2]).limits[], (197.99998, 201.99998))  # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "Sweep Start / pm"

    @test content(f[2,2][1,1]).xlabel[] == "Z / nm"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "Frequency Shift / Hz"
    @test content(f[2,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[4,2][1,1]).xlabel[] == "Z / nm"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "Current / pA"
    @test content(f[4,2][1,1]).title[] == "grid x=0 m, grid y=0 m"

    @test content(f[1,2][1,1]).selection[] == "Frequency Shift"  # menu channel1, selection observable
    @test content(f[1,2][2,1]).sliders[1].value[] == 1  # grid x
    @test content(f[1,2][2,1]).sliders[2].value[] == 1  # grid y
    @test content(f[1,2][2,1]).sliders[3].value[] == 1  # grid z
    @test content(f[1,2][3,1][1,2]).active[] == false  # backward/forward
    
    @test content(f[3,1][1,1]).selection[] == "Sweep Start"  # menu parameter, selection observable\
    
    @test content(f[3,2][1,1]).selection[] == "Current"  # menu channel2, selection observable

    @test content(f[4,1][1,1, TopRight()][1,1]).text[] == "200.00"
    @test content(f[2,2][1,1, TopRight()][1,1]).text[] == "-2.13   -2.05"
    @test content(f[4,2][1,1, TopRight()][1,1]).text[] == "-0.02   -0.01"
    
    # change values, mostly NaN values to be plotted
    content(f[1,2][1,1]).selection[] = "Bias"
    content(f[1,2][2,1]).sliders[1].value[] = 9
    content(f[1,2][2,1]).sliders[2].value[] = 6
    content(f[1,2][2,1]).sliders[3].value[] = 96
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
    @test approx(content(f[4,1][1,2]).limits[], (0.026592601, 47.17634)) # par plane colorbar
    @test content(f[4,1][1,2]).label[] == "AbsExcitation / mV"
    @test content(f[2,2][1,1]).xlabel[] == "Z / m"  #  plot 1
    @test content(f[2,2][1,1]).ylabel[] == "AbsBias / V"
    @test content(f[4,2][1,1]).xlabel[] == "Z / m"  #  plot 2
    @test content(f[4,2][1,1]).ylabel[] == "AbsCurrent / A"

    # labels
    @test content(f[4,1][1,1, TopRight()][1,1]).text[] == "NaN"
    @test content(f[2,2][1,1, TopRight()][1,1]).text[] == "NaN   NaN"
    @test content(f[4,2][1,1, TopRight()][1,1]).text[] == "NaN"
end