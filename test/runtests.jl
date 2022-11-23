using Test

import HistoryTrees: treehash, inclusion_proof, verify_inclusion, consistency_proof, verify_consistency


@test treehash(collect(1:7)) == (((1, 2), (3, 4)), ((5, 6), 7))


function test_inclusion(m::Int, n::Int)

    x = collect(1:n)

    p = inclusion_proof(x, m)
    root = treehash(x)

    @test verify_inclusion(p, n, m, root, m)
end


for i in 2:20
    for j in 1:i
        test_inclusion(j, i)
    end
end


function test_consistency(second, first)
    
    second_hash = treehash(collect(1:second))

    first_hash = treehash(collect(1:first))

    path = consistency_proof(collect(1:second), first)

    @test verify_consistency(path, second, first, second_hash, first_hash)
end


for m in 2:10
    for n in 1:m
        test_consistency(m, n)
    end
end
