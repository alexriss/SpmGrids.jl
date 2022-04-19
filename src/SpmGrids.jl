module SpmGrids

# using DataFrames
using DataStructures: OrderedDict
using Dates
using GeometryBasics
using Observables
using Printf
using SpmSpectroscopy
using SpmImages
using TOML

export @bwd_str, @ch_str, @par_str
export load_grid, channel_names, parameter_names, has_channel, has_parameter
export get_data, get_channel, get_parameter, add_channel!, add_parameter!
export xyindex_to_point, point_to_xyindex
export plot_spectrum, plot_line, plot_plane, plot_cube, plot_parameter_plane
export interactive_display
export fit_KPFM!, deconvolve_force!

const VERSION = VersionNumber(TOML.parsefile(joinpath(@__DIR__, "../Project.toml"))["version"])

const PREFIX_channel = "[channel:]> "
const PREFIX_parameter = "[parameter:]> "

# valid range types for slicing the grid
const GridRange = Union{Int,UnitRange{Int},Colon}

mutable struct SpmGrid
    filename::String
    header::OrderedDict{String,String}

    channel_names::Vector{String}
    channel_units::Dict{String,String}
    fixed_parameter_names::Vector{String}
    experiment_parameter_names::Vector{String}
    parameter_units::Dict{String,String}

    sweep_signal::String  # unit is in dict `channel_units`
    points::Int
    data::Array{Float64}

    # generated data stored here
    generated_channels::OrderedDict{String,Array{Float64}}   # units in dict `channel_units`
    generated_parameters::OrderedDict{String,Array{Float64}}  # units in dict `parameter_units`

    size::Vector{Float64}
    size_unit::String
    center::Vector{Float64}
    angle::Float64
    pixelsize::Vector{Int}

    bias::Union{Missing,Float64}
    z_feedback::Union{Missing,Bool}
    
    start_time::DateTime
    end_time::DateTime
end
SpmGrid(filename::String) = SpmGrid(
        filename, OrderedDict{String,String}(),
        String[], Dict{String,String}(), String[], String[], Dict{String,String}(),
        "", 0, Float64[],
        OrderedDict{String,Vector{Float64}}(), OrderedDict{String,Vector{Float64}}(),
        Float64[], "", Float64[], 0., Int[],
        missing, missing,
        DateTime(-1), DateTime(-1)
    )


include("stack_functions.jl")
include("plot_functions.jl")
include("interactive_functions.jl")
include("domain_functions.jl")


function Base.show(io::IO, g::SpmGrid)
    if get(io, :compact, false)
        print(io, "SpmGrid(\"", g.filename, "\")")
    else
        print(io, "SpmGrid(\"", g.filename, "\", ",
        "sweep: \"", g.sweep_signal, "\", ",
        length(g.channel_names) + length(g.generated_channels), " channels, ",
        g.points, " points, ", g.pixelsize[1], "x", g.pixelsize[2], " pixels)")
    end
end


skipnan(x) = filter(!isnan, x)  # we can also do Iterators.skipnan - but this is better for now


macro bwd_str(str)
    channel_name_bwd(str)
end

macro ch_str(str, suffix="")
    if !startswith(str, PREFIX_channel)
        str = PREFIX_channel * str
    end
    if suffix == "bwd"
        str = channel_name_bwd(str)
    end
    return str
end

macro par_str(str, suffix="")
    if !startswith(str, PREFIX_parameter)
        str = PREFIX_parameter * str
    end
    if suffix == "bwd"
        str = channel_name_bwd(str)
    end
    return str
end


"""
    strip_prefix(str::AbstractString, prefix::String)::String
    
Strips `prefix` from `string`
"""
function strip_prefix(str::AbstractString, prefix::String)::String
    if startswith(str, prefix)
        return str[length(prefix) + 1:end]
    else
        return str
    end
end


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
            grid_settings = parse.(Float64, split(grid.header["Grid settings"], ";"))
            grid.center = [grid_settings[1], grid_settings[2]]
            grid.size = [grid_settings[3], grid_settings[4]]
            grid.size_unit = "m"
            grid.angle = grid_settings[5]
        else
            @warn "Grid settings are not specified in the file."
        end

        grid.fixed_parameter_names = split(grid.header["Fixed parameters"], ";")
        experiment_parameters_names_units = rsplit.(split(grid.header["Experiment parameters"], ";"), limit=2)
        grid.experiment_parameter_names = first.(experiment_parameters_names_units)
        parameters_units = strip.(last.(experiment_parameters_names_units), (['(', ')'], ))
        grid.parameter_units = Dict(zip(grid.experiment_parameter_names, parameters_units))

        channels= split(grid.header["Channels"], ";")
        channel_names_units = rsplit.(channels, limit=2)
        grid.channel_names = first.(channel_names_units)
        channel_units = strip.(last.(channel_names_units), (['(', ')'], ))
        grid.channel_units = Dict(zip(grid.channel_names, channel_units))

        sweep_signal_name_unit = rsplit(grid.header["Sweep Signal"], limit=2)
        grid.sweep_signal = sweep_signal_name_unit[1]
        sweep_signal_unit = strip(sweep_signal_name_unit[2], ['(', ')'])
        if sweep_signal_unit != grid.channel_units[grid.sweep_signal]
            @warn "Sweep signal unit ($sweep_signal_unit) does not match the unit for its channel ($(grid.sweep_signal): $(grid.channel_units[grid.sweep_signal]))."
        end

        num_parameters = parse(Int, grid.header["# Parameters (4 byte)"])

        grid.points = parse(Int, grid.header["Points"])

        grid.start_time = DateTime(grid.header["Start time"], dateformat"d.m.Y H:M:S")
        grid.end_time = DateTime(grid.header["End time"], dateformat"d.m.Y H:M:S")
    
        if haskey(grid.header, "Z-Controller>Controller status")
            grid.z_feedback = (grid.header["Z-Controller>Controller status"] == "ON") ? true : false
        end

        if haskey(grid.header, "Bias>Bias (V)")
            grid.bias = parse(Float64, grid.header["Bias>Bias (V)"])
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
    @assert num_parameters == length(grid.fixed_parameter_names) + length(grid.experiment_parameter_names)

    data = Array{Float32}(undef, num_parameters + grid.points * length(grid.channel_names), grid.pixelsize...)

    # some files end prematuyrely, so we create a buffer and fill the buffer with NaN32
    io = IOBuffer(UInt8[], read=true, write=true)
    write(io, (read(f, String)))
    diff = reduce(*, size(data)) * 4 - io.size
    nan_arr = fill(hton(NaN32), diff ÷ 4)
    write(io, nan_arr)

    seekstart(io)
    read!(io, data)
    data .= ntoh.(data)  # big-endian to host endian

    # permute dims, so that we have, x, y, channel
    grid.data = Float64.(permutedims(data, (2,3,1)))

    return nothing
end


"""
    channel_name_bwd(name::AbstractString)::AbstractString

Returns the name of the channel for the bwds direction.
"""
function channel_name_bwd(name::AbstractString)::AbstractString
    if !endswith(name, " [bwd]")
        name = name * " [bwd]"
    end
    return name
end


"""
    channel_names(grid::SpmGrid, skip_bwd=true)::Array{String}

Returns all channel names in `grid`.
If `skip_bwd` is `true`, then the channel names for the bwds direction are not returned.
"""
function channel_names(grid::SpmGrid; skip_bwd=true)::Array{String}
    all_channel_names = vcat(grid.channel_names, collect(keys(grid.generated_channels)))
    if skip_bwd
        filter!(!endswith(" [bwd]"), all_channel_names)
    end
    return all_channel_names
end


"""
    has_channel(grid::SpmGrid, name::AbstractString; bwd::Bool=false)::Bool

Returns `true` if channel `name` is present in the grid.
If `bwd` is `true`, the checks for the existance of the bwd channel.
"""
function has_channel(grid::SpmGrid, name::AbstractString; bwd::Bool=false)::Bool
    name = strip_prefix(name, PREFIX_channel)
    if bwd
        name = channel_name_bwd(name)
    end

    return name in channel_names(grid, skip_bwd=false)
end


"""
    get_channel_index(grid::SpmGrid, name::AbstractString)::UnitRange{Int}

For the channel data specified by `name`, the index range is returned.
This can directly be used to index the `data` field of the `SpmGrid`.
"""
function get_channel_index(grid::SpmGrid, name::AbstractString)::UnitRange{Int}
    i_channel = findfirst(isequal(name), grid.channel_names)
    n_parameters = length(grid.fixed_parameter_names) + length(grid.experiment_parameter_names)

    start = n_parameters + (i_channel - 1) * grid.points + 1
    stop = start + grid.points - 1 

    return start:stop
end


"""
    get_channel(grid::SpmGrid, name::AbstractString,
        x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
        bwd::Bool=false)::SubArray{Float64}

Returns the data for the channel `name` at the point(s) specified by `x_index`, `y_index`
The channel data can be indexed by `channel_index`.
If `bwd` is `true`, the bwd channel is returned if it exists.
If `view` is `true` (default), then a view(@ref Base.view) is returned , otherwise a copy.
"""
function get_channel(grid::SpmGrid, name::AbstractString,
    x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
    bwd::Bool=false, view::Bool=true)::Union{Float64,Array{Float64},SubArray{Float64}}

    name = strip_prefix(name, PREFIX_channel)

    if bwd
        if has_channel(grid, name, bwd=true)
            name = channel_name_bwd(name)
        else
            @warn """Backward channel for "$name" does not exist. Using forward channel."""
        end
    end

    if !has_channel(grid, name)
        all_channel_names = channel_names(grid)
        throw(ArgumentError("""Channel name "$(name)" not found in the SpmGrid. """ *
        """Available channel names are: $(join(all_channel_names, ", "))."""))
    end

    if haskey(grid.generated_channels, name)  # generated channels
        res =  @view grid.generated_channels[name][x_index, y_index, channel_index]
    else  # "original" channels
        idx = get_channel_index(grid, name)
        if channel_index !== Colon()
            idx = idx[channel_index]
        end
        res = @view grid.data[x_index, y_index, idx]
    end

    if view
        return res
    else
        return copy(res)
    end
end


"""
    add_channel!(grid::SpmGrid, name::AbstractString, unit::AbstractString,
        data::AbstractArray{Float64})::Nothing

Adds a generated channel with `name`, `unit` and `data` to the `grid`.
The `data` must be of the same size as channel data in the `grid`, i.e. `grid.points` x `grid.pixelsize...`.
The `name` cannot be the same as names in the original channel names.
If the `name` exists in the generated channel names, it will be overwritten.
"""
function add_channel!(grid::SpmGrid, name::AbstractString, unit::AbstractString,
    data::AbstractArray{Float64})::Nothing

    name = strip_prefix(name, PREFIX_channel)

    if size(data) != (grid.pixelsize..., grid.points)
        throw(ArgumentError("The data array needs to be of size $((grid.pixelsize[1], grid.pixelsize[2], grid.points)), but it has size $(size(data))."))
    end
    if name in grid.channel_names
        throw(ArgumentError("Channel name $(name) already exists in the original grid data. Please choose a different name."))
    end
    if length(name) === 0
        throw(ArgumentError("Please specify a channel name."))
    end

    grid.generated_channels[name] = data
    grid.channel_units[name] = unit

    return nothing
end


"""
    add_channel!(func::Function, grid::SpmGrid, name::AbstractString, unit::AbstractString,
        args...; skip_bwd::Bool=false::Nothing

Adds a generated channel with `name`, `unit` and `data` to the `grid`.
The channel is generated by the function `func` that
takes other channels/parameters specified by `args...` as input parameters.
Any broadcasting functionality should be implemented in `func`.
The `name` cannot be the same as names in the original channel names.
If the `name` exists in the generated channel names, it will be overwritten.
If `skip_bwd` is `false` (default), then bwd channels will be added if feasible.

# Examples
```julia
julia> grid = load_grid("file.3ds")
julia> add_channel!(x -> abs(x), grid, "CurrentAbs", "A", "Current")
julia> add_channel!((x,y) -> x + y, grid, "", "A", "Current", "AbsCurrent")
```
"""
function add_channel!(func::Function, grid::SpmGrid, name::AbstractString, unit::AbstractString,
    args...; skip_bwd::Bool=false)::Nothing

    name = strip_prefix(name, PREFIX_channel)

    channels = get_data.((grid, ), args)  # get_data automatically prefers channel names
    data = func(channels...)
    add_channel!(grid, name, unit, data)

    if !skip_bwd
        channels = get_data.((grid, ), args, bwd=true)
        data = func(channels...)
        add_channel!(grid, channel_name_bwd(name), unit, data)
    end

    return nothing
end


"""
    parameter_names(grid::SpmGrid)::Array{String}

Returns all parameter names in `grid`.
"""
function parameter_names(grid::SpmGrid)::Array{String}
    return vcat(grid.fixed_parameter_names, grid.experiment_parameter_names,
        collect(keys(grid.generated_parameters)))
end


"""
    has_parameter(grid::SpmGrid, name::AbstractString)::Bool

Returns `true` if parameter `name` is present in the grid.
"""
function has_parameter(grid::SpmGrid, name::AbstractString)::Bool
    name = strip_prefix(name, PREFIX_parameter)

    return name in parameter_names(grid)
end


"""
    get_parameter_index(grid::SpmGrid, name::AbstractString)::Int

Returns the index for the parameter specified by `name`. This can directly be used to index the `data` field of the `SpmGrid`.
"""
function get_parameter_index(grid::SpmGrid, name::AbstractString)::Int
    par_names = vcat(grid.fixed_parameter_names, grid.experiment_parameter_names)
    i_par = findfirst(isequal(name), par_names)
    return i_par
end


"""
    get_parameter_unit(grid::SpmGrid, name::AbstractString)::AbstractString
    
Returns the unit associated with the parameter `name`.
"""
function get_parameter_unit(grid::SpmGrid, name::AbstractString)::String
    name = strip_prefix(name, PREFIX_parameter)
    if name in grid.fixed_parameter_names
        return grid.channel_units[grid.sweep_signal]
    elseif haskey(grid.parameter_units, name)
        return grid.parameter_units[name]
    else
        return ""
    end
end


"""
    get_parameter(grid::SpmGrid, name::AbstractString,
        x_index::GridRange=:, y_index::GridRange=:; view::Bool=true)::Union{Array{Float64},SubArray{Float64}}

Returns the value for parameter `name` at the point(s)specified by `x_index`, `y_index`.
If `view` is `true` (default), then a view(@ref Base.view) is returned , otherwise a copy.
"""
function get_parameter(grid::SpmGrid, name::AbstractString,
    x_index::GridRange=:, y_index::GridRange=:; view::Bool=true)::Union{Float64,Array{Float64},SubArray{Float64}}
    
    name = strip_prefix(name, PREFIX_parameter)

    if !has_parameter(grid, name)
        par_names = parameter_names(grid)
        throw(ArgumentError("""Parameter name "$(name)" not found. Available parameter names are: $(join(par_names, ", "))."""))
    end
    
    if haskey(grid.generated_parameters, name)
        res = @view grid.generated_parameters[name][x_index, y_index]
    else
        idx = get_parameter_index(grid, name)
        res = @view grid.data[x_index, y_index, idx]
    end

    if view
        return res
    else
        return copy(res)
    end
end


"""
    add_parameter!(grid::SpmGrid, name::AbstractString, unit::AbstractString,
        data::AbstractArray{Float64})::Nothing

Adds a generated parameter with `name`, `unit` and `data` to the `grid`.
The `data` must be of the same size as parameter data in the `grid`, i.e. `grid.pixelsize`.
The `name` cannot be the same as names in the original parameter names.
If the `name` exists in the generated parameter names, it will be overwritten.
"""
function add_parameter!(grid::SpmGrid, name::AbstractString, unit::AbstractString,
    data::AbstractArray{Float64})::Nothing

    name = strip_prefix(name, PREFIX_parameter)

    if collect(size(data)) != grid.pixelsize
        throw(ArgumentError("The data array needs to be of size $(Tuple(grid.pixelsize)), but it has size $(size(data))."))
    end
    if name in grid.fixed_parameter_names || name in grid.experiment_parameter_names
        throw(ArgumentError("Parameter name $(name) already exists in the original grid data. Please choose a different name."))
    end
    if length(name) === 0
        throw(ArgumentError("Please specify a parameter name."))
    end

    grid.generated_parameters[name] = data
    grid.parameter_units[name] = unit

    return nothing
end


"""
    add_parameter!(func::Function, grid::SpmGrid, name::AbstractString, unit::AbstractString,
        args...::AbstractString)::Nothing

Adds a generated parameter with `name`, `unit` and `data` to the `grid`.
The parameter is generated by the function `func` that
takes other parameter/channels specified by `args...` as input parameters.
Any broadcasting functionality should be implemented in `func`.
The `name` cannot be the same as names in the original parameter names.
If the `name` exists in the generated parameter names, it will be overwritten.

# Examples
```julia
julia> grid = load_grid("file.3ds")
julia> add_parameter!(x -> abs(x), grid, "Scan:ExcitationAbs", "V", "Scan:Excitation")
```
"""
function add_parameter!(func::Function, grid::SpmGrid, name::AbstractString, unit::AbstractString,
    args...)::Nothing

    name = strip_prefix(name, PREFIX_parameter)

    p = map(args) do pname
        if has_parameter(grid, pname)  # prefer parameter names (get_data prefer channel names)
            return get_parameter(grid, pname)
        else
            return get_data(grid, pname)
        end
    end

    data = func(p...)
    add_parameter!(grid, name, unit, data)

    return nothing
end


"""
    get_data(grid::SpmGrid, name::AbstractString,
        x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
        bwd::Bool=false)::SubArray{Float64}

Returns the data for the channel or parameter `name` at the point(s) specified by `x_index`, `y_index`
Channel data can also be indexed by `channel_index`.
If `bwd` is `true`, the bwd channel is returned if it exists.
If `view` is `true` (default), then a view(@ref Base.view) is returned , otherwise a copy.
"""
function get_data(grid::SpmGrid, name::AbstractString,
    x_index::GridRange=:, y_index::GridRange=:, channel_index::GridRange=:;
    bwd::Bool=false, view::Bool=true)::Union{Float64,Array{Float64},SubArray{Float64}}

    if startswith(name, PREFIX_channel)
        return get_channel(grid, name, x_index, y_index, channel_index, bwd=bwd, view=view)
    elseif startswith(name, PREFIX_parameter)
        return get_parameter(grid, name, x_index, y_index, view=view)
    elseif has_channel(grid, name)
        return get_channel(grid, name, x_index, y_index, channel_index, bwd=bwd, view=view)
    elseif has_parameter(grid, name)
        return get_parameter(grid, name, x_index, y_index, view=view)
    else
        throw(ArgumentError("""No channel or parameter with name "$(name)" found.\n""" *
        """Available channel names are: $(join(channel_names(grid), ", ")).\n""" *
        """Available parameter names are: $(join(parameter_names(grid), ", "))."""
        ))
    end
end


"""
    xyindex_to_point(grid::SpmGrid, index_x::Int, index_y)::Tuple{Float64,Float64}

Converts `index_x` and `index_y` of `grid` to point coordinates in physical units.
"""
function xyindex_to_point(grid::SpmGrid, index_x::Int, index_y::Int)::Tuple{Float64,Float64}
    return Tuple(((index_x, index_y) .- 1) .* grid.size ./ (grid.pixelsize .- 1))

    # gridx_span = range(0, grid.size[1], length=grid.pixelsize[1])
    # gridy_span = range(0, grid.size[2], length=grid.pixelsize[2])
    # return gridx_span[index_x], gridy_span[index_y]
end


"""
    point_to_xyindex(grid::SpmGrid, point::Vector{Float64})::Tuple{Int,Int}

Converts `point` (in physical units) of `grid` to index_x and index_y
"""
function point_to_xyindex(grid::SpmGrid, point::Vector{Float64})::Tuple{Int,Int}
    return round.(Int, Tuple(1 .+ point .* (grid.pixelsize .- 1) ./ grid.size))
end


end # module
