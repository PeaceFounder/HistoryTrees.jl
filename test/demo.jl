# A simple performance charetaristics for inclusion and consistency proof sizes.

using UnicodePlots

import HistoryTrees: inclusion_proof, consistency_proof

function max_inclusion_proof_length(n::Int) 

    s = 0

    for i in 1:n
        p = inclusion_proof(collect(1:n), i)
        if length(p) > s
            s = length(p)
        end
    end
    
    return s
end


function max_consistency_proof_length(n::Int) 

    s = 0

    for i in 1:n
        p = consistency_proof(collect(1:n), i)
        if length(p) > s
            s = length(p)
        end
    end
    
    return s
end


x = 1:100

plt = lineplot(x, max_inclusion_proof_length.(x), name = "inclusion")
lineplot!(plt, x, max_consistency_proof_length.(x), name = "consistency")



