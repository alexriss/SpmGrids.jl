using Dates
using SpmGrids
using Test

@testset "loading" begin
    grid = load_grid("Grid Spectroscopy002.3ds", header_only=true)

    @test grid.pixelsize == [20,20]
    @test grid.angle ≈ 0.
    @test grid.center ≈ [1.106620E-7, 2.331660E-7]
    @test grid.size ≈ [1.5e-8, 1.5e-8]

    @test grid.points == 128

    @test grid.bias ≈ 0.2
    @test grid.z_feedback == false

    @test grid.start_time == DateTime(2017,03,09,21,19,38)
    @test grid.end_time == DateTime(2017,03,10,8,21,16)

    @test length(grid.data) == 0  # 0 because `header_only` is true
    @test length(grid.data_parameters) == 0  # 0 because `header_only` is true

    @test grid.fixed_parameters == ["Sweep Start", "Sweep End"]
    @test grid.experiment_parameters == ["X (m)", "Y (m)", "Z (m)", "Z offset (m)", "Settling time (s)", "Integration time (s)", "Z-Ctrl hold", "Final Z (m)", "Scan:Current (A)", "Scan:Applied Voltage measured (V)", "Scan:Bias (V)", "Scan:Z (m)", "Scan:Phase (deg)", "Scan:Amplitude (m)", "Scan:Frequency Shift (Hz)", "Scan:Excitation (V)"]
    @test grid.channel_names == ["Current", "Applied Voltage measured", "Bias", "X", "Y", "Z", "Phase", "Amplitude", "Frequency Shift", "Excitation"]
    @test grid.channel_units == ["A", "V", "V", "m", "m", "m", "deg", "m", "Hz", "V"]

    @test grid.sweep_signal == "Bias"

    @test grid.header["Oscillation Control>PLL-Setup Demod. Bandwidth Amp (Hz)"] == "80E+0"
    @test grid.header["Z-Controller>Switch off delay (s)"] == "50E-3"
    @test grid.header["Comment"] == "KPFM"
    @test grid.header["Experiment"] == "Grid Spectroscopy"

    grid = load_grid("Grid Spectroscopy002.3ds")

    @test length(grid.data) == 20 * 20 * (18 + 10 * 128)  # pixels * (parameters + channels * points)
end

