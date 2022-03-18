module SpmGrids

# using DataFrames
using DataStructures: OrderedDict
using Dates
using Printf
using TOML

export load_grid, get_channel, get_parameter
export plot_spectrum, plot_line

const VERSION = VersionNumber(TOML.parsefile(joinpath(@__DIR__, "../Project.toml"))["version"])

# valid range types for slicing the grid
const GridRange = Union{Int,UnitRange{Int},Colon}

mutable struct SpmGrid
    filename::String
    header::OrderedDict{String,String}
    channel_names::Vector{String}
    channel_units::Vector{String}

    fixed_parameters::Vector{String}
    experiment_parameters::Vector{String}
    experiment_parameters_units::Vector{String}
    points::Int

    data::Array{Float32}

    sweep_signal::String
    sweep_signal_unit::String

    size::Vector{Float32}
    size_unit::String
    center::Vector{Float32}
    angle::Float32
    pixelsize::Vector{Int}

    bias::Union{Missing,Float32}
    z_feedback::Union{Missing,Bool}
    
    start_time::DateTime
    end_time::DateTime
end
SpmGrid(filename::String) = SpmGrid(
        filename, OrderedDict(), String[], String[],
        String[], String[], String[], 0,
        Float32[],
        "", "",
        Float32[], "", Float32[], 0., Int[],
        missing, missing,
        DateTime(-1), DateTime(-1)
    )


include("plot_functions.jl")


"""
    load_grid(filename::AbstractString; header_only::Bool=false)

Loads a grid from a binary file. If `header_only` is `true`, then only the header is loaded.
"""
function load_grid(filename::AbstractString; header_only::Bool=false)::SpmGrid

    ext = rsplit(filename, "."; limit=2)[end]
    if ext != "3ds"
        throw(ArgumentError("Unknown file type \"$ext\""))
    end

    grid = SpmGrid(filename)
    num_parameters = 0

    open(filename) do f
        for line in eachline(f)
            if line == ":HEADER_END:"  # end of header
                break
            elseif occursin("=", line)
                key, value = split(line, "="; limit=2)
                value = strip(value, '"')  # often the values are in quotes
                grid.header[key] = value
            end
        end

        if haskey(grid.header, "Grid dim")
            grid.pixelsize = parse.(Int, split(grid.header["Grid dim"], " x "))
        else
            @warn "Grid dimensions are not specified in the file."
        end

        if haskey(grid.header, "Grid settings")
            grid_settings = parse.(Float32, split(grid.header["Grid settings"], ";"))
            grid.center = [grid_settings[1], grid_settings[2]]
            grid.size = [grid_settings[3], grid_settings[4]]
            grid.size_unit = "m"
            grid.angle = grid_settings[5]
        else
            @warn "Grid settings are not specified in the file."
        end

        grid.fixed_parameters = split(grid.header["Fixed parameters"], ";")
        experiment_parameters_names_units = rsplit.(split(grid.header["Experiment parameters"], ";"), limit=2)
        grid.experiment_parameters = first.(experiment_parameters_names_units)
        grid.experiment_parameters_units = strip.(last.(experiment_parameters_names_units), (['(', ')'], ))

        channels= split(grid.header["Channels"], ";")
        channel_names_units = rsplit.(channels, limit=2)
        grid.channel_names = first.(channel_names_units)
        grid.channel_units = strip.(last.(channel_names_units), (['(', ')'], ))

        sweep_signal_name_unit = rsplit(grid.header["Sweep Signal"], limit=2)
        grid.sweep_signal = sweep_signal_name_unit[1]
        grid.sweep_signal_unit = strip(sweep_signal_name_unit[2], ['(', ')'])

        num_parameters = parse(Int, grid.header["# Parameters (4 byte)"])

        grid.points = parse(Int, grid.header["Points"])

        grid.start_time = DateTime(grid.header["Start time"], dateformat"d.m.Y H:M:S")
        grid.end_time = DateTime(grid.header["End time"], dateformat"d.m.Y H:M:S")
    
        if haskey(grid.header, "Z-Controller>Controller status")
            grid.z_feedback = (grid.header["Z-Controller>Controller status"] == "ON") ? true : false
        end

        if haskey(grid.header, "Bias>Bias (V)")
            grid.bias = parse(Float32, grid.header["Bias>Bias (V)"])
        end

        # read binary data
        if !header_only
            read_binary_data!(grid, f, num_parameters)
        end
    end


    return grid
end


"""
    read_binary_data!(grid::SpmGrid, f::IOStream, num_parameters::Int)

Reads binary data from 3ds file. The file pointer should be set to the start of the binary data.
"""
function read_binary_data!(grid::SpmGrid, f::IOStream, num_parameters::Int)::Nothing
    @assert num_parameters == length(grid.fixed_parameters) + length(grid.experiment_parameters)

    data = Array{Float32}(undef, num_parameters + grid.points * length(grid.channel_names), grid.pixelsize...)

    # some files end prematuyrely, so we create a buffer and fill the buffer with NaN32
    io = IOBuffer(UInt8[], read=true, write=true)
    write(io, (read(f, String)))
    diff = reduce(*, size(data)) * 4 - io.size
    nan_arr = fill(hton(NaN32), diff ÷ 4)
    write(io, nan_arr)

    seekstart(io)
    read!(io, data)
    grid.data = ntoh.(data)  # big-endian to host endian

    return nothing
end


"""
    get_channel_index(grid::SpmGrid, name::AbstractString)::UnitRange{Int}

For the channel data specified by `name`, the index range is returned. This can directly be used to index the `data` field of the `SpmGrid`.
"""
function get_channel_index(grid::SpmGrid, name::AbstractString)::UnitRange{Int}
    i_channel = findfirst(isequal(name), grid.channel_names)
    if i_channel === nothing
        throw(ArgumentError("""Channel name "$(name)" not found in the SpmGrid. Available channel names are $(join(grid.channel_names, ", "))."""))
    end

    n_parameters = length(grid.fixed_parameters) + length(grid.experiment_parameters)

    start = n_parameters + (i_channel - 1) * grid.points + 1
    stop = start + grid.points - 1 

    return start:stop
end


"""
    get_channel(grid::SpmGrid, name::AbstractString,
        index_x::GridRange, index_y::GridRange, index_channel::GridRange=:)::Array{Float32}

Returns the data for the channel `name` at the point(s) specified by `index_x`, `index_y`
The channel data can be indexed by `index_channel`.
"""
function get_channel(grid::SpmGrid, name::AbstractString,
    index_x::GridRange, index_y::GridRange, index_channel::GridRange=:)::SubArray{Float32}

    idx = get_channel_index(grid, name)
    if index_channel !== Colon()
        idx = idx[index_channel]
    end
    return @view grid.data[idx, index_x, index_y]
end


"""
    get_parameter_index(grid::SpmGrid, name::AbstractString)::Int

Returns the index for the parameter specified by `name`. This can directly be used to index the `data` field of the `SpmGrid`.
"""
function get_parameter_index(grid::SpmGrid, name::AbstractString)::Int
    par_names = vcat(grid.fixed_parameters, grid.experiment_parameters)
    i_par = findfirst(isequal(name), par_names)
    if i_par === nothing
        throw(ArgumentError("""Parameter name "$(name)" not found in the SpmGrid. Available parameter names are $(join(par_names, ", "))."""))
    end

    return i_par
end


"""
    get_parameter(grid::SpmGrid, name::AbstractString,
        index_x::GridRange, index_y::GridRange)::Union{Float32, Array{Float32}}

Returns the value for parameter `name` at the point(s)specified by `index_x`, `index_y`.
"""
function get_parameter(grid::SpmGrid, name::AbstractString,
    index_x::GridRange, index_y::GridRange)::Union{Float32, Array{Float32}}
    
    idx = get_parameter_index(grid, name)
    return grid.data[idx, index_x, index_y]
end


end # module
