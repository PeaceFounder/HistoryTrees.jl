module HistoryTrees


mutable struct HistoryTree
    d::Vector{<:Any}
    hash
    root
end

leaf(tree::HistoryTree, N::Int) = tree.d[N]

root(tree::HistoryTree) = tree.root
root(tree::HistoryTree, N::Int) = treehash(view(tree.d, 1:N); hash = tree.hash)

HistoryTree(d::Vector{<:Any}, hash) = HistoryTree(d, hash, treehash(d; hash))

HistoryTree(::Type{T}, hash) where T = HistoryTree(T[], hash, nothing)


Base.length(tree::HistoryTree) = length(tree.d)

function Base.push!(tree::HistoryTree, di) 
    
    push!(tree.d, di)
    tree.root = treehash(tree.d; hash = tree.hash)
    
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

    root = treehash(d[1:index]; hash)

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

function treehash(d::Vector{<:Any}; hash) 
    
    n = length(d)

    if n == 1
        return d[1]
    end
    
    k = power2div(n-1)
    
    a = treehash(d[1:k]; hash)
    #println("a = $a")
    
    b = treehash(d[k+1:n]; hash)
    return hash(a, b)
end

"""
The shortest path from the leaf to the root to calculate the tree hash. 
"""
function inclusion_proof(d::Vector{<:Any}, m::Int; hash) 
    
    n = length(d)
    
    p = []

    if n == 1 && m == 1
        return p
    end

    k = power2div(n-1)
    if m <= k
        append!(p, inclusion_proof(d[1:k], m; hash))
        push!(p, treehash(d[k+1:n]; hash))
    else
        append!(p, inclusion_proof(d[k+1:n], m - k; hash))
        push!(p, treehash(d[1:k]; hash))
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
function consistency_proof(d::Vector{<:Any}, m::Int; hash)

    @assert 1 <= m <= length(d)

    return subproof(m, d, true; hash)
end

function subproof(m::Int, d::Vector{<:Any}, b::Bool; hash)

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
        
        #if m <= k + 1
        if m <= k
            append!(path, subproof(m, d[1:k], b; hash))
            push!(path, treehash(d[k+1:n]; hash))
        else
            append!(path, subproof(m-k, d[k+1:n], false; hash))
            push!(path, treehash(d[1:k]; hash))
        end
    else
        return path
    end

end


ispoweroftwo(x::UInt) = (x != 0) && ((x & (x - 1)) == 0)
ispoweroftwo(x) = ispoweroftwo(UInt(x))


function verify_consistency(p, second, first, second_hash, first_hash; debug::Union{Ref, Nothing} = nothing, hash)
    
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


end # module MerkleTrees
