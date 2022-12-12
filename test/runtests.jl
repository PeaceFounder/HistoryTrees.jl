using Test

# Tested on tuples
module TestTuples
include("tuples.jl")
end

# Shows a real life use with hash function
module ExampleTest
include("example.jl")
end

# Test for Chain and combination with HistoryTree
module ChainTest
include("chaintree.jl")
end
