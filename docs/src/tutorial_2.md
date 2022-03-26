# Tutorial 2: Manipulating grids

Now that you are already familiar with the basic functionality of SpmGrids, let's dive deeper.
Here we want to learn how to manipulate data.

## Adding channels

Let's manualla add a channel "Z rel" that is the relative Z position in the grid, i.e, the Z position with respect to the parameter "Scan Start". The new channel should have the unit of "m".

```@repl 2
using SpmGrids
grid = load_grid("Z_spectroscopy.3ds")

z = get_channel(grid, "Z");
sweep_start = get_parameter(grid, "Sweep Start");

z_rel = z .- sweep_start;
add_channel!(grid, "Z rel", "m", z_rel)
```

Quite easy, isn't it?

However, notice that we didn't add the backward channel "Z rel [bwd]".

```@repl 2
has_channel(grid, "Z")
has_channel(grid, bwd"Z")
has_channel(grid, "Z rel")
has_channel(grid, bwd"Z rel")
```

And we can do it manually, just as before. But a better way is the following. Again, we add a "Z rel" channel (in fact it will be overwritten). But this time we use the a function as the first argument
in `add_channel!`. It takes two input parameters `x` and `y` and computes `x .- y` (i.e. the broadcasted subtraction).

The new channel name will be `"Z rel"`, it's unit `"m"`, and the input parameters for the function are `"Z"` and `"Sweep Start"`.

```@repl 2
add_channel!(
    (x,y) -> x .- y,
    grid, "Z rel", "m", "Z", "Sweep Start"
)
```

We could also explicitely specify that `"Z"` is a channel and `"Sweep Start"` is a parameter by using `ch"Z"` and `par"Sweep Start"`.

But the more important thing is that the function automatically handled the backward channels:

```@repl 2
has_channel(grid, "Z rel")
has_channel(grid, bwd"Z rel")
```

One thing to keep in mind is that the channels can contain `NaN` values.
This can happen when the grid was stopped prematurely or a sweep within a grid is stopped.

Thus to calculate a "Z rel" channel relative to the minimum value of all "Z" values,
you need to do the following:

```@repl 2
zmin = minimum(
    SpmGrids.skipnan(get_channel(grid, "Z"))
)

add_channel!(x -> x .- zmin, grid, "Z rel", "m", "Z")

z_rel = get_channel(grid, "Z rel");

z_rel[1,1,20]
```

The `SpmGrids.skipnan` function is a convenience function that skips all `NaN` values,
it is just a shorthand for : `filter(!isnan, x)`.

We could now even set the `sweep_signal` of the grid to the new `"Z rel"` channel:

```@repl 2
grid.sweep_signal = "Z rel"
```

But be careful to know what you are doing when changing these values. The sweep signal has special requirements, for instance, its values should be unique.

## Adding parameters

Similarly as adding channels, we can add parameters to our grid. For instance a parameter "Sweep Span":

```@repl 2
add_parameter!(
    (x,y) -> abs.(y .- x),
    grid, "Sweep Span", "m", "Sweep Start", "Sweep End"
)

p = get_parameter(grid, "Sweep Span");

has_parameter(grid, "Sweep Span")

size(p)

# now all "Z rel" values are ≥ 0
all(SpmGrids.skipnan(p) .≥ 0)
```

Also, all these new channels and parameters are available in the [interactive widget](@ref interactive_widget). You can load it with:

```julia
interactive_display(grid, colormap=:bluegreenyellow)
```

## More information

A more detailed description can be found in the [Reference](@ref).
