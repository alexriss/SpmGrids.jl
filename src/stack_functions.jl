"""
    load_grid(filenames::Vector{<:AbstractString}, by::Function=im->im.z,
        name::AbstractString="Z_", unit::AbstractString="m";
        only_overlap::Bool=false, header_only::Bool=false)::SpmGrid

Loads a grid from a stack of image files. The sweep signal is specified with the `by` argument,
as well as `name` and `unit`.
The first image determines the pixel density, as well as the channels that will be available.
Here, the backward channels will be associated with the backward scan direciton in the images.
Ideally, all images should have the same pixel density and recorded channels.
if `only_overlap` is true, then data is returned only for the pixels that are overlapping in all images.
If `header_only` is `true`, then only the header is created.
"""
function load_grid(filenames::Vector{<:AbstractString}, by::Function=im->im.z,
    name::AbstractString="Z_", unit::AbstractString="m";
    only_overlap::Bool=false, header_only::Bool=false)::SpmGrid

    images = load_image.(filenames, header_only=header_only, output_info=0)
    return load_grid(images, by, name, unit, only_overlap=only_overlap, header_only=header_only)
end


"""
    load_grid(images::Vector{<:SpmImage}, by::Function=im -> im.z
    name::AbstractString="Z", unit::AbstractString="m";
    only_overlap::Bool=false, header_only::Bool=false)::SpmGrid

Loads a grid from a stack of images. The sweep signal is specified with the `by` argument,
as well as `name` and `unit`.
The first image determines the pixel density, as well as the channels that will be available.
Here, the backward channels will be associated with the backward scan direciton in the images.
Ideally, all images should have the same pixel density and recorded channels.
if `only_overlap` is true, then data is returned only for the pixels that are overlapping in all images.
If `header_only` is `true`, then only the header is created.
"""
function load_grid(images::Vector{<:SpmImage}, by::Function=im->im.z,
    name::AbstractString="Z_", unit::AbstractString="m";
    only_overlap::Bool=false, header_only::Bool=false)::SpmGrid

    if length(images) <=1
        throw(ArgumentError("Please provide at least two images."))
    end

    lower_left_outside = images[1].center .- images[1].scansize / 2
    upper_right_outside = images[1].center .+ images[1].scansize / 2
    lower_left_inside = copy(lower_left_outside)
    upper_right_inside = copy(upper_right_outside)
    sweep_min = by(images[1])
    sweep_max = by(images[1])

    start_time = images[1].start_time
    end_time = images[1].start_time
    bias = images[1].bias
    z_feedback = images[1].z_feedback
    for im in images
        if im.angle != images[1].angle
            throw(ArgumentError("The rotation of all images must be the same." *
            "Image $(im.filename) has a different angle than $(images[1].filename): " *
            "$(im.angle) vs. $(images[1].angle)"))
        end

        lower_left = im.center .- im.scansize / 2
        upper_right = im.center .+ im.scansize / 2
        lower_left_inside .= max.(lower_left_inside, lower_left)
        upper_right_inside .= min.(upper_right_inside, upper_right)
        lower_left_outside .= min.(lower_left_outside, lower_left)
        upper_right_outside .= max.(upper_right_outside, upper_right)

        sweep_pos = by(im)
        sweep_min = min(sweep_min, sweep_pos)
        sweep_max = max(sweep_max, sweep_pos)

        ts = im.start_time
        te = unix2datetime(datetime2unix(im.start_time) + im.acquisition_time)
        start_time = min(start_time, ts)
        end_time = max(end_time, te)

        if !(im.bias ≈ images[1].bias)
            bias = missing
        end
        if im.z_feedback != images[1].z_feedback
            z_feedback = missing
        end
    end

    if sweep_max == sweep_min
        throw(ArgumentError("There is no variation in the sweep signal."))
    end

    filename = "$(length(images))-stack from: " * images[1].filename
    grid = SpmGrid(filename)
    grid.points = length(images)

    lower_left = (only_overlap) ? lower_left_inside : lower_left_outside
    upper_right = (only_overlap) ? upper_right_inside : upper_right_outside

    if any(lower_left .> upper_right)
        throw(ArgumentError("Not all images overlap. Try setting the argument `only_overlap` to `false`."))
    end

    pixelsize = (upper_right .- lower_left) ./ images[1].scansize .* images[1].pixelsize
    grid.pixelsize = round.(Int, pixelsize)

    grid.center = (lower_left .+ upper_right) ./ 2 * 1e-9  # convert from nm to m
    grid.size = (upper_right .- lower_left) * 1e-9  # convert from nm to m
    grid.size_unit = "m"
    grid.angle = images[1].angle

    grid.start_time = start_time
    grid.end_time = end_time

    grid.bias = bias
    grid.z_feedback = z_feedback

    grid.fixed_parameter_names = ["Sweep Start", "Sweep End"]

    grid.channel_names = vcat(images[1].channel_names, channel_name_bwd.(images[1].channel_names))
    grid.channel_units = Dict(zip(grid.channel_names, vcat(images[1].channel_units, images[1].channel_units)))

    if name in grid.channel_names
        @warn """Channel "$name" already exists in the images. It will be overwritten."""
    else
        push!(grid.channel_names, name)
        push!(grid.channel_names, channel_name_bwd(name))
    end
    grid.sweep_signal = name
    grid.channel_units[name] = unit
    grid.channel_units[channel_name_bwd(name)] = unit

    if !header_only
        images = sort(images, by=im -> (by(im), im.start_time))
        read_data!(grid, images, sweep_min, sweep_max)
    end

    return grid
end


"""
    read_data!(grid::SpmGrid, images::Vector{<:SpmImage})::Nothing

Reads the data from the images into the grid. The "Sweep Start" and "Sweep End" parameters are
populated with `sweep_min` and `sweep_max`, respectively.
"""
function read_data!(grid::SpmGrid, images::Vector{<:SpmImage},
    sweep_min::Float64, sweep_max::Float64)::Nothing

    @assert length(grid.experiment_parameter_names) == 0
    num_parameters = length(grid.fixed_parameter_names)

    grid.data = fill(NaN, grid.pixelsize..., num_parameters + grid.points * length(grid.channel_names))

    idx = get_parameter_index(grid, "Sweep Start")
    grid.data[:, :, idx] .= sweep_min
    idx = get_parameter_index(grid, "Sweep End")
    grid.data[:, :, idx] .= sweep_max

    for (i_im, im) in enumerate(images)
        stack_image!(grid, im, i_im)
    end

    return nothing
end


"""
    stack_image!(grid::SpmGrid, image::SpmImage, slice::int)

Insert `image` data into the `grid` at certain `slice`.
"""
function stack_image!(grid::SpmGrid, image::SpmImage, slice::Int)
    im = image

    grid_lower_left = grid.center .- grid.size ./ 2
    grid_upper_right = grid.center .+ grid.size ./ 2

    im_lower_left = (im.center .- im.scansize ./ 2) * 1e-9  # convert from nm to m
    im_upper_right = (im.center .+ im.scansize ./ 2) * 1e-9  # convert from nm to m

    lower_left = max.(grid_lower_left, im_lower_left)
    upper_right = min.(grid_upper_right, im_upper_right)

    grid_lower_left_idx = collect(point_to_xyindex(grid, lower_left .- grid_lower_left))
    grid_upper_right_idx = collect(point_to_xyindex(grid, upper_right .- grid_lower_left))
    im_lower_left_idx = round.(Int, SpmImages.nm_to_pixels(im, (lower_left .- im_lower_left) * 1e9))
    im_upper_right_idx = round.(Int, SpmImages.nm_to_pixels(im, (upper_right .- im_lower_left) * 1e9))

    # @show grid_lower_left_idx, grid_upper_right_idx, im_lower_left_idx, im_upper_right_idx
   
    # limit values
    for i in 1:2
        # same scale
        if grid_upper_right[i] - grid_lower_left_idx[i] < im_upper_right_idx[i] - im_lower_left_idx[i]
            im_upper_right_idx[i] = im_lower_left_idx[i] + grid_upper_right_idx[i] - grid_lower_left_idx[i]
        elseif grid_upper_right[i] - grid_lower_left_idx[i] > im_upper_right_idx[i] - im_lower_left_idx[i]
            grid_upper_right_idx[i] = grid_lower_left_idx[i] + im_upper_right_idx[i] - im_lower_left_idx[i]
        end
        # within maximum size of image and grid, respectively
        if grid_lower_left_idx[i] < 1
            im_lower_left_idx[i] -= (grid_lower_left_idx[i] + 1)
            grid_lower_left_idx[i] = 1
        end
        if grid_upper_right_idx[i] > grid.pixelsize[i]
            im_upper_right_idx[i] -= (grid_upper_right_idx[i] - grid.pixelsize[i])
            grid_upper_right_idx[i] = grid.pixelsize[i]
        end
        if im_lower_left_idx[i] < 1
            grid_lower_left_idx[i] -= (im_lower_left_idx[i] + 1)
            im_lower_left_idx[i] = 1
        end
        if im_upper_right_idx[i] > im.pixelsize[i]
            grid_upper_right_idx[i] -= (im_upper_right_idx[i] - im.pixelsize[i])
            im_upper_right_idx[i] = im.pixelsize[i]
        end
    end
    # @show grid_lower_left_idx, grid_upper_right_idx, im_lower_left_idx, im_upper_right_idx

    for name in grid.channel_names
        idx_ch = get_channel_index(grid, name)[slice]
        # todo take into account possible shifts of images
        if endswith(name, " [bwd]")
            name = name[1:end-6] * " bwd"
        end
        grid.data[
            grid_lower_left_idx[1]:grid_upper_right_idx[1],
            grid_lower_left_idx[2]:grid_upper_right_idx[2],
            idx_ch
        ] .= @views SpmImages.get_channel(im, name).data[
            im_lower_left_idx[2]:im_upper_right_idx[2],
            im_lower_left_idx[1]:im_upper_right_idx[1]
        ]'
    end

end
