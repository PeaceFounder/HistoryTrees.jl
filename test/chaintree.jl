# In history trees inclusion proofs are limited to elements alone. Somtimes, however, it is necessary for the receiving party to be assured that a segment of the list retrived throuhg API is the true reality refelcting the immutable list. A possible fix is to use consistency proofs which should work excellent for the purpose.

# Another approach is to link leaves use HistoryTree for storing list of linked elements. Is it useful? Who knows. Let's keep this part as an experiment. 

# Note: this approach will likelly will become irrelevant as soon as a method to evaluate root hashes for history tree will become incremental.

using Test
import Nettle
import HistoryTrees: Chain, ChainHead, InclusionProof, ConsistencyProof, verify, root, chainhash, leaf, slice, HistoryTree
import HistoryTrees

# Testing of a Chain primitive

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

record!(chain::Chain, data) = push!(chain, digest(data))

chain = Chain(Digest, digest)

record!(chain, "Hello World")
@test root(chain) == root(chain, 1)

record!(chain, "Hello World 2")
@test root(chain) == root(chain, 2)

record!(chain, "Hello World 3")
@test root(chain) == root(chain, 3)

record!(chain, "Hello World 4")
@test chainhash(chain.ledger[3:4], root(chain, 2); hash = digest) == root(chain, 4)
@test chainhash(chain.ledger[2:3], root(chain, 1); hash = digest) == root(chain, 3)

leafs, head = slice(chain, 3:4)
@test verify(leafs, head, root(chain, 4); hash = digest)

leafs, head = slice(chain, 2:3)
@test verify(leafs, head, root(chain, 3); hash = digest)

leafs, head = slice(chain, 1:2)
@test verify(leafs, head, root(chain, 2); hash = digest)

leafs, head = slice(chain, 2:2)
@test verify(leafs, head, root(chain, 2); hash = digest)

leafs, head = slice(chain, 1:1)
@test verify(leafs, head, root(chain, 1); hash = digest)


# Implementation of a custom tree

struct ChainTree
    chain::Chain
    tree::HistoryTree
end

ChainTree(::Type{T}, hash) where T = ChainTree(Chain(T, hash), HistoryTree(T, hash))

Base.length(tree::ChainTree) = length(tree.chain)

leaf(chain::ChainTree, i::Int) = leaf(chain.chain, i)

root(chain::ChainTree) = root(chain.tree)
root(chain::ChainTree, i::Int) = root(chain.tree, i)


function Base.push!(chain::ChainTree, record)
    
    push!(chain.chain, record)
    push!(chain.tree, root(chain.chain))

    return
end

record!(tree::ChainTree, data) = push!(tree, digest(data))

ConsistencyProof(chain::ChainTree, index) = ConsistencyProof(chain.tree, index)

InclusionProof(chain::ChainTree, index) = InclusionProof(chain.tree, index)

struct ChainTreeSlice
    head::ChainHead
    tail::InclusionProof
end

function slice(tree::ChainTree, range)
    
    leafs, chain_slice = slice(tree.chain, range)
    proof = InclusionProof(tree, last(range))

    return leafs, ChainTreeSlice(chain_slice, proof)
end

function verify(leafs, proof::ChainTreeSlice, root, index; hash)

    if !verify(proof.tail, root, index; hash)
        return false
    end
    
    root1 = leaf(proof.tail)

    return verify(leafs, proof.head, root1; hash)
end


tree = ChainTree(Digest, digest)
record!(tree, "Hello World")

proof = InclusionProof(tree, 1)
@test verify(proof, root(tree), 1; hash = digest)

record!(tree, "Hello World 2")

leafs, proof = slice(tree, 1:2)
@test verify(leafs, proof, root(tree), 2; hash = digest)

record!(tree, "Hello World 3")

leafs, proof = slice(tree, 1:2)
verify(leafs, proof, root(tree), 3; hash = digest)

proof = ConsistencyProof(tree, 2)
@test verify(proof, root(tree), 3; hash = digest)

proof = InclusionProof(tree, 1)
@test verify(proof, root(tree), 3; hash = digest)

proof = InclusionProof(tree, 2)
@test verify(proof, root(tree), 3; hash = digest)
