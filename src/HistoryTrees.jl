module HistoryTrees

# Legacy chain type 
# In some situations is combined with Merkle trees

mutable struct Chain
    ledger::Vector{<:Any}
    hash
    root
end

Chain(::Type{T}, hash) where T = Chain(T[], hash, nothing)

Base.length(chain::Chain) = length(chain.ledger)

leaf(chain::Chain, i::Int) = chain.ledger[i]

root(chain::Chain) = chain.root

function chainhash(ledger::AbstractVector{<:Any}, root0; hash)

    rooti = root0

    for record in ledger
        rooti = hash(rooti, record)
    end

    return rooti
end

function root(chain::Chain, i::Int)

    if i == 0
        return nothing
    end

    if i == 1
        return leaf(chain, 1)
    end

    root0 = leaf(chain, 1)

    return chainhash(view(chain.ledger, 2:i), root0; hash = chain.hash)
end


function Base.push!(chain::Chain, record)

    if length(chain) == 0
        chain.root = record
        push!(chain.ledger, record)
        return
    end
    
    chain.root = chain.hash(chain.root, record)
    push!(chain.ledger, record)
    return
end

verify_segment(ledger::AbstractVector{<:Any}, root0, root1; hash) = chainhash(ledger, root0; hash) == root1

verify_segment(ledger::AbstractVector{<:Any}, root1; hash) = chainhash(view(ledger, 2:lastindex(ledger)), first(ledger); hash) == root1

struct ChainHead
    root
end

ChainHead(chain::Chain, n::Int) = ChainHead(root(chain, n))

verify(leafs::AbstractVector{<:Any}, segment::ChainHead, root1; hash) = isnothing(segment.root) ? verify_segment(leafs, root1; hash) : verify_segment(leafs, segment.root, root1; hash)

verify(leaf, head::ChainHead, root1; hash) = isnothing(head.root) ? leaf == root1 : hash(head.root, leaf) == root1


function slice(chain::Chain, range)
    
    leafs = chain.ledger[range]
    proof = ChainHead(root(chain, first(range) - 1))

    return leafs, proof
end

# Implemetation of HistoryTree

mutable struct HistoryTree
    d::Vector{<:Any}
    stack::Vector{<:Any}
    hash
    root
end

leaf(tree::HistoryTree, N::Int) = tree.d[N]

root(tree::HistoryTree) = tree.root
root(tree::HistoryTree, N::Int) = treehash(view(tree.d, 1:N); hash = tree.hash)


HistoryTree(::Type{T}, hash) where T = HistoryTree(T[], T[], hash, nothing)

# Cold start with already present data; 
# TODO: rewrite with a while loop.
function stack!(s::Vector, d::AbstractVector{<:Any}; hash)

    n = power2div(length(d))
    m = length(d) - n 

    push!(s, treehash(view(d, 1:n); hash))

    if m == 0
        return s
    else
        return stack!(s, view(d, (n+1):lastindex(d)); hash)
    end
end

stack(d::AbstractVector{T}; hash) where T = stack!(T[], d; hash)

HistoryTree(d::Vector{<:Any}, hash) = HistoryTree(d, stack(d; hash), hash, treehash(d; hash))


Base.length(tree::HistoryTree) = length(tree.d)


log2int(x) = Int(log2(x))

function collapse_length(n::Int)

    if ispoweroftwo(n)
        return log2int(n)        
    else
        collapse_length(n - power2div(n))
    end
end

# index is the element which is going to be computed
function treehash!(stack::Vector{<:Any}, index::Int, value; hash)

    y = value

    for _ in 1:collapse_length(index)

        q = pop!(stack)
        y = hash(q, y)

    end

    x = y

    for si in reverse(stack)
        x = hash(si, x)
    end

    push!(stack, y)

    return x
end



function Base.push!(tree::HistoryTree, di) 
    
    push!(tree.d, di)
    #tree.root = treehash(tree.d; hash = tree.hash)
    tree.root = treehash!(tree.stack, length(tree), di; hash = tree.hash)
    return
end


struct InclusionProof
    path::Vector{<:Any}
    index::Int
    leaf
end

function InclusionProof(tree::HistoryTree, index::Int)
    
    (; d, hash) = tree

    path = inclusion_proof(d, index; hash)

    leaf = d[index]

    return InclusionProof(path, index, leaf)
end

leaf(proof::InclusionProof) = proof.leaf

function verify(proof::InclusionProof, root, length; hash)
    return verify_inclusion(proof.path, length, proof.index, root, proof.leaf; hash)
end


struct ConsistencyProof
    path::Vector{<:Any}
    index::Int
    root # Internal
end



function ConsistencyProof(tree::HistoryTree, index::Int)
    
    (; d, hash) = tree

    path = consistency_proof(d, index; hash)

    root = treehash(view(d, 1:index); hash)

    return ConsistencyProof(path, index, root)
end

root(proof::ConsistencyProof) = proof.root

function verify(proof::ConsistencyProof, root, length; hash)
    return verify_consistency(proof.path, length, proof.index, root, proof.root; hash)
end

function power2div(x::Int)
    
    s = 1

    while 2*s <= x
        s *= 2
    end

    return s
end

function treehash(d::AbstractVector{<:Any}; hash) 
    
    n = length(d)

    if n == 1
        return d[1]
    end
    
    k = power2div(n-1)
    
    a = treehash(view(d, 1:k); hash)
    
    b = treehash(view(d, k+1:n); hash)
    return hash(a, b)
end

"""
The shortest path from the leaf to the root to calculate the tree hash. 
"""
function inclusion_proof(d::AbstractVector{<:Any}, m::Int; hash) 
    
    n = length(d)
    
    p = []

    if n == 1 && m == 1
        return p
    end

    k = power2div(n-1)
    if m <= k
        append!(p, inclusion_proof(view(d, 1:k), m; hash))
        push!(p, treehash(view(d, k+1:n); hash))
    else
        append!(p, inclusion_proof(view(d, k+1:n), m - k; hash))
        push!(p, treehash(view(d, 1:k); hash))
    end
    
    return p
end


bit(x::UInt8, n) = x << (8 - n) >> 7
bit(x::UInt, n) = x << (64 - n) >> 63


function verify_inclusion(p::Vector{<:Any}, at, i, root, leaf; debug::Union{Ref, Nothing} = nothing, hash)

    if i == at == 1
        return leaf == root
    end

    if i > at || (at > 0 && length(p) == 0)
        return false # note while testing 
    end

    i = i - 1
    at = at - 1

    h = leaf

    for (j, v) in enumerate(p)

         if (i % 2 == 0) && i != at
             h = hash(h, v)
         else
             h = hash(v, h)
         end

        i ÷= 2
        at ÷= 2
    end

    if !isnothing(debug)
        debug[] = (; i, h)
    end


    return at == i && h == root
end



"""
A proof that subtree is part of the tree
"""
function consistency_proof(d::AbstractVector{<:Any}, m::Int; hash)

    @assert 1 <= m <= length(d)

    return subproof(m, d, true; hash)
end

function subproof(m::Int, d::AbstractVector{<:Any}, b::Bool; hash)

    path = []
    n = length(d)
    
    if m == n
        if !b
            push!(path, treehash(d; hash))
        else
            return path
        end
    end

    if m < n
        
        k = power2div(n-1)
        
        if m <= k
            append!(path, subproof(m, view(d, 1:k), b; hash))
            push!(path, treehash(view(d, k+1:n); hash))
        else
            append!(path, subproof(m-k, view(d, k+1:n), false; hash))
            push!(path, treehash(view(d, 1:k); hash))
        end
    else
        return path
    end

end


ispoweroftwo(x::UInt) = (x != 0) && ((x & (x - 1)) == 0)
ispoweroftwo(x) = ispoweroftwo(UInt(x))


function verify_consistency(p::Vector{<:Any}, second, first, second_hash, first_hash; debug::Union{Ref, Nothing} = nothing, hash)
    
    l = length(p)
    
    if first == second && first_hash == second_hash && l == 0
        return true
    end

    if !(first < second) || l == 0
        return false
    end


    if ispoweroftwo(first)
        pp = [first_hash, p...]
    else
        pp = p
    end
    
    fn = first - 1 # 1 based indexing
    sn = second - 1
    
    while fn%2 == 1
        fn >>= 1
        sn >>= 1
    end

    fr, sr = pp[1], pp[1]
    

    for (step, c) in enumerate(pp)

        if step == 1
            continue
        end
                
        if sn == 0 # mysterius condition
            return false
        end

        if fn % 2 == 1 || fn == sn

            fr = hash(c, fr)
            sr = hash(c, sr)

            while fn % 2 == 0 && fn != 0
                fn >>= 1
                sn >>= 1
            end
        else
            
            sr = hash(sr, c)

        end

        fn >>= 1
        sn >>= 1
    end

    if !isnothing(debug)
        debug[] = (; fr, sr, sn)
    end

    return fr == first_hash && sr == second_hash && sn == 0
end


struct TreeSlice
    stack::Vector{<:Any}
    proof::ConsistencyProof
end


function TreeSlice(tree::HistoryTree, range)

    (; d, hash) = tree

    if first(range) == 1
        stack0 = []
    else
        stack0 = stack(view(d, 1:(first(range)-1)); hash)
    end

    proof = ConsistencyProof(tree, last(range))

    return TreeSlice(stack0, proof)
end


function slice(tree::HistoryTree, range)

    leafs = tree.d[range]
    proof = TreeSlice(tree, range)

    return (leafs, proof)
end

# it should be possible to evaluete root more efficiently rather than steping increments

function verify(leafs::AbstractVector{<:Any}, proof::TreeSlice, root, index; hash)

    verify(proof.proof, root, index; hash) || return false

    stack = copy(proof.stack)
    index = proof.proof.index - length(leafs)

    local rooti

    for i in leafs
        index += 1
        rooti = treehash!(stack, index, i; hash)
    end

    return rooti == proof.proof.root
end

verify(leaf, proof::TreeSlice, root, index; hash) = verify([leaf], proof, root, index; hash)

end
