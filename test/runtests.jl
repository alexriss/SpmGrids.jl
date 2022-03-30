using Dates
using SpmGrids
using Test


skipnan = SpmGrids.skipnan

"""
Compares two Arrays/Tuples, each element should not deviate by more than `thresh` (relative to b).
"""
function similar(a, b, thresh=1e-3)::Bool
    if length(a) != length(b)
        return false
    end
    if any(abs.(a .- b) ./ b .> thresh)
        return false
    end
    return true
end


# usage:
# Pkg.test("SpmGrids", test_args=["interactive", "plot_cube"])
# from: https://github.com/JuliaArrays/StaticArrays.jl/blob/master/test/runtests.jl
enabled_tests = lowercase.(ARGS)
function addtests(fname)
    key = lowercase(splitext(fname)[1])
    if isempty(enabled_tests) || key in enabled_tests
        include(fname)
    end
end

addtests("load_add_data.jl")
addtests("plot_spectrum.jl")
addtests("plot_line.jl")
addtests("plot_plane.jl")
addtests("plot_cube.jl")
addtests("interactive.jl")
addtests("domain_functions.jl")
