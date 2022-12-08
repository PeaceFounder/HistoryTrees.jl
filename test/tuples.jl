using Test

import HistoryTrees: treehash, inclusion_proof, verify_inclusion, consistency_proof, verify_consistency
import HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof, verify, root


@test treehash(collect(1:7); hash = tuple) == (((1, 2), (3, 4)), ((5, 6), 7))


function test_inclusion(m::Int, n::Int)

    x = collect(1:n)

    p = inclusion_proof(x, m; hash = tuple)
    root = treehash(x; hash = tuple)

    @test verify_inclusion(p, n, m, root, m; hash = tuple)
end


for i in 1:20
    for j in 1:i
        test_inclusion(j, i)
    end
end


function test_consistency(second, first)
    
    second_hash = treehash(collect(1:second); hash = tuple)

    first_hash = treehash(collect(1:first); hash = tuple)

    path = consistency_proof(collect(1:second), first; hash = tuple)

    @test verify_consistency(path, second, first, second_hash, first_hash; hash = tuple)
end


for m in 1:10
    for n in 1:m
        test_consistency(m, n)
    end
end

### For more detailed testing 

function assemble_inclusion_proof(m::Int, n::Int)
    
    x = collect(1:n)

    p = inclusion_proof(x, m; hash = tuple)
    root = treehash(x; hash = tuple)
    
    
    debug = Ref{NamedTuple}()
    verify_inclusion(p, n, m, root, m; debug, hash = tuple)

    return debug[]
end



@test assemble_inclusion_proof(3, 7).h == (((1, 2), (3, 4)), ((5, 6), 7))


function assemble_consistency_proof(m::Int, n::Int)
    
    x = collect(1:n)

    second_hash = treehash(x; hash = tuple)
    first_hash = treehash(x[1:m]; hash = tuple)

    p = consistency_proof(x, m; hash = tuple)


    debug = Ref{NamedTuple}()
    verify_consistency(p, n, m, second_hash, first_hash; debug, hash = tuple)
    
    return debug[]
end

(; fr, sr) = assemble_consistency_proof(3, 7)

@test fr == ((1, 2), 3)
@test sr == (((1, 2), (3, 4)), ((5, 6), 7))

### Testing functionality with a real hash

hashx(a, b) = hash((a, b))


let
    m = 3
    n = 7

    x = collect(1:n)

    p = inclusion_proof(x, m; hash = hashx)
    root = treehash(x; hash = hashx)

    @test verify_inclusion(p, n, m, root, m; hash = hashx)

end


let
    first = 3
    second = 7


    second_hash = treehash(collect(1:second); hash = hashx)

    first_hash = treehash(collect(1:first); hash = hashx)

    path = consistency_proof(collect(1:second), first; hash = hashx)

    @test verify_consistency(path, second, first, second_hash, first_hash; hash = hashx)

end


# Testing HistoryTree

tree = HistoryTree(Int, tuple)

for i in 1:7
    push!(tree, i)
end

# root and length is verifiaby communicated
_root = root(tree)
_length = length(tree)

# useful for giving assurances that the element is within a list whose treehash is root
proof = InclusionProof(tree, 3)
@test verify(proof, _root, _length; hash = tuple)

proof = ConsistencyProof(tree, 3)
@test verify(proof, _root, _length; hash = tuple)


