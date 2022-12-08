using Test
import Nettle
import HistoryTrees: HistoryTree, InclusionProof, verify, root

struct Digest
    data::Vector{UInt8}
end

Base.:(==)(x::Digest, y::Digest) = x.data == y.data


function digest(data::Vector{UInt8})
    return Digest(Nettle.digest("SHA3_256", data))
end

function digest(data::String)
    bytes = Vector{UInt8}(data)
    return digest(bytes)
end

function digest(x::Digest, y::Digest)
    return digest(UInt8[x.data..., y.data...])
end


record!(tree::HistoryTree, data) = push!(tree, digest(data))
    

tree = HistoryTree(Digest, digest)
record!(tree, "Hello World")

proof = InclusionProof(tree, 1)
@test verify(proof, root(tree), 1; hash = digest)

record!(tree, "Hello World 2")

proof = InclusionProof(tree, 1)
@test verify(proof, root(tree), 2; hash = digest)

proof = InclusionProof(tree, 2)
@test verify(proof, root(tree), 2; hash = digest)
