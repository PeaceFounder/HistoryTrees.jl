module HistoryTrees

function power2div(x::Int)
    
    s = 1

    while 2*s <= x
        s *= 2
    end

    return s
end

function treehash(d::Vector{Int})
    
    n = length(d)

    if n == 1
        return d[1]
    end
    
    k = power2div(n-1)
    
    a = treehash(d[1:k])
    #println("a = $a")
    
    b = treehash(d[k+1:n])
    return (a, b)
end

"""
The shortest path from the leaf to the root to calculate the tree hash. 
"""
function inclusion_proof(d::Vector{Int}, m::Int) 
    
    n = length(d)
    
    p = []

    if n == 1 && m == 1
        return p
    end

    k = power2div(n-1)
    if m <= k
        append!(p, inclusion_proof(d[1:k], m))
        push!(p, treehash(d[k+1:n]))
    else
        append!(p, inclusion_proof(d[k+1:n], m - k))
        push!(p, treehash(d[1:k]))
    end
    
    return p
end


bit(x::UInt8, n) = x << (8 - n) >> 7
bit(x::UInt, n) = x << (64 - n) >> 63


function verify_inclusion(p::Vector, at, i, root, leaf)

    if i > at || (at > 0 && length(p) == 0)
        return false # note while testing 
    end

    i = i - 1
    at = at - 1

    h = leaf

    for (j, v) in enumerate(p)

         if (i % 2 == 0) && i != at
             h = h, v 
         else
             h = v, h
         end

        i ÷= 2
        at ÷= 2
    end

    return at == i && h == root
end



"""
A proof that subtree is part of the tree
"""
function consistency_proof(d::Vector{Int}, m::Int)

    @assert 1 <= m <= length(d)

    return subproof(m, d, true)
end

function subproof(m::Int, d::Vector{Int}, b::Bool)

    path = []
    n = length(d)
    
    if m == n
        if !b
            push!(path, treehash(d))
        else
            return path
        end
    end

    if m < n
        
        k = power2div(n-1)
        
        #if m <= k + 1
        if m <= k
            append!(path, subproof(m, d[1:k], b))
            push!(path, treehash(d[k+1:n]))
        else
            append!(path, subproof(m-k, d[k+1:n], false))
            push!(path, treehash(d[1:k]))
        end
    else
        return path
    end

end


ispoweroftwo(x::UInt) = (x != 0) && ((x & (x - 1)) == 0)
ispoweroftwo(x) = ispoweroftwo(UInt(x))


function verify_consistency(p, second, first, second_hash, first_hash)
    
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

            fr = (c, fr)
            sr = (c, sr)

            while fn % 2 == 0 && fn != 0
                fn >>= 1
                sn >>= 1
            end
        else
            
            sr = (sr, c)

        end

        fn >>= 1
        sn >>= 1
    end

    return fr == first_hash && sr == second_hash && sn == 0
end



end # module MerkleTrees
