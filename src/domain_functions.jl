const elementary_charge = 1.602176634e-19  # Coulombs


"""
    fit_KPFM!(grid::SpmGrid, response_channel::String;
        sweep_channel::String="", bwd::Bool=true)::Nothing

Fits KPFM data. This is done by fitting a parabola to the graoh of
`response_channel` vs `sweep_channel` on the grid. If not explicitely specified,
`sweep_channel` defaults to the sweep signal of the grid.

For KPFM, the response channel should be the "Frequency Shift" channel and
the sweep channel is the "Bias".

Adds the parameters `"KPFM:Bias"`, `"KPFM:Frequency Shift"`, `"KPFM:Residuals AbsSum"` and
the channels `"KPFM:Fit"`, `"KPFM:Residuals"` to the SpmGrid `grid`.

If `bwd` is `true` (default), the plot will include data from backward sweep as well (if they exist).
"""
function fit_KPFM!(grid::SpmGrid, response_channel::String;
    sweep_channel::String="", bwd::Bool=true)::Nothing

    if sweep_channel === ""
        sweep_channel = grid.sweep_signal
    end

    df = get_channel(grid, response_channel)
    V = get_channel(grid, sweep_channel)

    # dimensions of channels and paremeters, respectively
    dim_ch = size(df)
    dim_par = grid.pixelsize
    
    # pre-define arrays for the results
    kpfm_bias = Array{Float64}(undef, dim_par...)
    kpfm_df = Array{Float64}(undef, dim_par...)
    kpfm_fit = Array{Float64}(undef, dim_ch...)
    kpfm_res = Array{Float64}(undef, dim_ch...)
    kpfm_res_abs_sum = Array{Float64}(undef, dim_par...)
    
    # loop over all x,y pixels
    for ix in 1:dim_ch[1], iy in 1:dim_ch[2]
        # fit parabola to the data
        x = @view V[ix, iy, :]
        y = @view df[ix, iy, :]

        sel = findall(!isnan, x)
        x = @view x[sel]
        y = @view y[sel]

        X = [ones(dim_ch[3]) x x.^2]
        coeffs = X \ y
    
        # coordinates of the maximum of the parabola
        c, b, a = coeffs
        kpfm_bias[ix, iy] = -b / (2 * a)
        kpfm_df[ix, iy] = c - b^2 / (4 * a)
    
        # fitted parabola
        kpfm_fit[ix, iy, :] .= X * coeffs
    
        # residuals
        kpfm_res[ix, iy, :] .= y .- kpfm_fit[ix, iy, :]
        kpfm_res_abs_sum[ix, iy] = sum(abs.(kpfm_res[ix, iy, :]))
    end
    
    # for backward sweep, we use backward names for the channels
    if response_channel == channel_name_bwd(response_channel)
        name = x -> channel_name_bwd(x)
    else
        name = x -> x
    end

    # add all the data to the grid
    add_parameter!(grid, name("KPFM:Bias"), "V", kpfm_bias)
    add_parameter!(grid, name("KPFM:Frequency Shift"), "Hz", kpfm_df)
    add_channel!(grid, name("KPFM:Fit"), "Hz", kpfm_fit)
    add_channel!(grid, name("KPFM:Residuals"), "Hz", kpfm_res)
    add_parameter!(grid, name("KPFM:Residuals AbsSum"), "Hz", kpfm_res_abs_sum)

    # backward sweeps
    if bwd &&
        has_channel(grid, response_channel, bwd=true) &&
        has_channel(grid, sweep_channel, bwd=true) &&
        response_channel != channel_name_bwd(response_channel)

            fit_KPFM!(grid, channel_name_bwd(response_channel),
                sweep_channel=channel_name_bwd(sweep_channel), bwd=false)
    end

    return nothing
end


"""
    trapz(x::Vector{Float64}, y::Vector{Float64}, val::Float64=0.)::Vector{Float64}

Performs a trapezoidal integration of `x` vs. y` with the boundary condition that
the last element of the integrated function will have a value of `val`.
The resulting array will be of the same length
as the input arrays, but will contain an extra `val` value at the end (because the x-values for 
the integrated function are between the x-values for the function `y`).
"""
function trapz(x::Vector{Float64}, y::Vector{Float64}, val::Float64=0.)::Vector{Float64}
    N = length(y)
    res = Array{Float64}(undef, N)
    res[N] = val
    for i = N-1:-1:1  # we start at the furthest distance
        prev = (i == N - 1 || isnan(res[i+1])) ? val : res[i+1]
        res[i] = prev + (x[i+1] - x[i]) * (y[i] + y[i+1]) * 0.5
    end
    return res
end


"""
    deconvolve_force!(grid::SpmGrid, response_channel::String,
        f₀::Float64=0., A::Float64=0., k::Float64=1800.;
        sweep_channel::String="", bwd::Bool=true)::Nothing

Applies the [Sadar Jarvis force deconvolution algorithm](https://aip.scitation.org/doi/10.1063/1.1667267)
as implemented in the [SpmSpectroscopy](https://github.com/alexriss/SpmSpectroscopy.jl) package
to each point in the `grid`.
`response_channel` should refer to the "Frequency Shift" channel and
`sweep_channel` (which defaults to the sweep signal of the grid) should be tip height "Z".

In addition, the along the experimental parameters `f₀` (resonance frequency),
`A` (oscillation amplitude), and `k` (cantilever stiffness) can be specified.
For `k` the default values is 1800 N/m, which is a typical value for
[qPlus sensors](https://doi.org/10.1063/1.5052264). If the values for `f₀` and `A` are left
at their default values of `0.`, the values will be extracted from the header data.

Adds the channels `"Force z"` and `"Potential"` to the SpmGrid `grid`. Additionally,
the channels `"Force x"` and `"Force y"` will be calculated by differentiation of the 
Potential in x and y direction, respectively. The x and y force components will not be
calculated if the `sweep_channel` is not sorted.

If `bwd` is `true` (default), the plot will include data from backward sweep as well (if they exist).
"""
function deconvolve_force!(grid::SpmGrid, response_channel::String,
    f₀::Float64=0., A::Float64=0., k::Float64=1800.;
    sweep_channel::String="", bwd::Bool=true)::Nothing

    if f₀ ≈ 0.
        if haskey(grid.header, "Oscillation Control>Center Frequency (Hz)")
            f₀ = parse(Float64, grid.header["Oscillation Control>Center Frequency (Hz)"])
        else
            throw(ArgumentError("The resonance frequency f₀ is not saved in the header of the grid. Please specify the value manually."))
        end
    end

    if A ≈ 0.
        if haskey(grid.header, "Oscillation Control>Amplitude Setpoint (m)")
            f₀ = parse(Float64, grid.header["Oscillation Control>Amplitude Setpoint (m)"])
        else
            throw(ArgumentError("The oscillation amplitude A is not saved in the header of the grid. Please specify the value manually."))
        end
    end

    if sweep_channel === ""
        sweep_channel = grid.sweep_signal
    end

    grid_df = get_channel(grid, response_channel)
    grid_z = get_channel(grid, sweep_channel)

    sweep_channel_unit = grid.channel_units[sweep_channel] 
    if sweep_channel_unit != "m"
        @warn """The sweep channel unit is "$(sweep_channel_unit)". Expected "m". """ *
        """Are you sure this is the right type of experiment?"""
    end

    zmin, zmax = extrema(skipnan(grid_z))
    if zmin ≈ zmax
        throw(error("There is no variation in the sweep channel. " *
        "This is very likely the wrong type of grid experiment for a force deconvolution."))
    end

    dim_ch = size(grid_df)
    
    # pre-define arrays for the results
    grid_Fz = Array{Float64}(undef, dim_ch)
    grid_E = Array{Float64}(undef, dim_ch)
    grid_Fx = Array{Float64}(undef, dim_ch)
    grid_Fy = Array{Float64}(undef, dim_ch)
    
    # loop over all x,y pixels
    calc_xy_derivs = true
    for ix in 1:dim_ch[1], iy in 1:dim_ch[2]
        # fit parabola to the data
        z = @view grid_z[ix, iy, :]
        df = @view grid_df[ix, iy, :]

        sel_notnan = findall(!isnan, z)
        sel_nan = findall(isnan, z)
        z = @view z[sel_notnan]
        df = @view df[sel_notnan]

        # Z values need to be sorted in ascending order
        if issorted(z)
            sort_order = :asc
        elseif issorted(z, rev=true)
            sort_order = :desc
            z = reverse(z)
            df = reverse(df)
        else  # z values not sorted, we will try to sort them, but this should probably not happen
            sort_order = :unsorted
            sort_perm = sortperm(z)
            z = z[sort_perm]
            df = df[sort_perm]

            calc_xy_derivs = false
        end

        # force deconvolution
        if length(z) >= 5
            z_, F = SpmSpectroscopy.deconvolve_sader_jarvis(z, df, f₀, A, k, pad=true, val=NaN)
            # integrate to E
            E = trapz(z_, F)
        else
            F = fill(NaN, size(z))
            E = fill(NaN, size(z))
        end

        # revert to original order
        if sort_order === :desc
            reverse!(F)
            reverse!(E)
        elseif sort_order === :unsorted
            F = F[sortperm(sort_perm)]
            E = E[sortperm(sort_perm)]
        end

        grid_Fz[ix, iy, sel_notnan] .= F
        grid_Fz[ix, iy, sel_nan] .= NaN
        grid_E[ix, iy, sel_notnan] .= E
        grid_E[ix, iy, sel_nan] .= NaN
    end

    nx, ny, nc = dim_ch
    if calc_xy_derivs
        # differentiate in x and y direction
        grid_Fx = cat(diff(grid_E, dims=1), fill(NaN, 1, ny, nc), dims=1)
        grid_Fx = cat(diff(grid_E, dims=2), fill(NaN, nx, 1, nc), dims=2)
    else
        @warn "The sweep channel is not sorted, the x and y force components will not be calculated." *
        "Are you sure this is the correct type of experiment for a force deconvolution?"
    end

    # for backward sweep, we use backward names for the channels
    if response_channel == channel_name_bwd(response_channel)
        name = x -> channel_name_bwd(x)
    else
        name = x -> x
    end

    # add all the data to the grid
    add_channel!(grid, name("Force z"), "N", grid_Fz)
    add_channel!(grid, name("Potential"), "eV", grid_E ./ elementary_charge)

    if calc_xy_derivs
        add_channel!(grid, name("Force x"), "N", grid_Fx)
        add_channel!(grid, name("Force y"), "N", grid_Fy)
    end

    # backward sweeps
    if bwd &&
        has_channel(grid, response_channel, bwd=true) &&
        has_channel(grid, sweep_channel, bwd=true) &&
        response_channel != channel_name_bwd(response_channel)

        deconvolve_force!(grid, channel_name_bwd(response_channel),
                f₀, A, k,
                sweep_channel=channel_name_bwd(sweep_channel), bwd=false)
    end

    return nothing
end