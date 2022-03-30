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
