# HistoryTrees.jl

There are multiple ways to construct an immutable record of history. The simplest way is to interleave each new element with what we shall call a root. Like if one has seven elements `[1, 2, 3, 4, 5, 6, 7]`, then every element can be protected by publishing tree hash calculated on tuples like `root = ((((((1, 2), 3), 4), 5), 6), 7)`. This is great as long as one does not need to prove the inclusion of an element. For instance, proof that the 3rd element has been included is (root, 7, 6, 5, 4, 3) and grows linearly with the size of the list. 

An alternative is to hash list as a Merkle tree. For a list of four elements `[1, 2, 3, 4]`, the root hash would be `root = ((1, 2), (3, 4)]`, which allows constructing a proof of inclusion for 3rd element as [root, 4, (1, 2)] which grows logarithmically with the size of the list. However, an issue with this approach is that the list needs to be of size 2^N. One could use padding to overcome that, but that requires large recomputations when new elements are added to the list. 

A better approach is to use history trees which place leaves directly under the incomplete node. For seven elements that reduce root hash to `root = (((1, 2), (3, 4)), ((5, 6), 7))` and is more satisfying than padding and provides logarithmically sized proofs for inclusion of element and consistency of the tree. 

To use a history tree first, one is constructed as
```julia
tree = HistoryTree(Int, tuple)

for i in 1:7
    push!(tree, i)
end
```
where the first element is input element hashes and the second element is a callable for a hash function for two elements. We can use a tuple and interchange it with a real hash function importing it from `Nettle.jl` for demonstrative purposes. 

The most important quantities of the tree are the root and its length, which we can access:
```
_root = root(tree)
_length = length(tree)
```
which can be signed by the main server and distributed to clients.

The clients then can ask for proof that a particular element is included in the list, to which the server replies with
```
proof = InclusionProof(tree, 3)
```
as an example for the third element. This proof client quickly verifies:
```
verify(proof, _root, _length; hash = tuple)
```

Another possibility is for the client to verify if the server has only added elements to sync the last synchronisation. To do so client asks for consistency proof constructed as follows:
```
proof = ConsistencyProof(tree, 3)
```
which the client verifies as:
```
verify(proof, _root, _length; hash = tuple)
```

A scenario where they are combined is when a client sends an element for inclusion in the list for which it receives a signed (root1, length1) and inclusion proof. Later on, the client wants to check that the element is still within the list. Instead of again asking for an inclusion proof server sends back a consistency proof for (root1, length1) at the current state (root2, length2), which is signed. That way, a client also enforces that other clients' messages have not been modified. 

**Note:** ~~a whole tree hash is currently recomputed for every new element added; thus, performance is not so great.~~  **Currently, multiple tree hashes are computed to construct proofs like `InclusionProof` and `ConsistencyProof`. A further improvement would be to store a complete subtree hash and retrieve them in the calculation. Prepending bytes with a leaf or node byte may be necessary for security.**

## References

- Crosby, Scott A. and Dan S. Wallach. *Efficient Data Structures For Tamper-Evident Logging.* USENIX Security Symposium (2009).
- RFC6962 and RFC9162
- Farhan Aly. *Don't trust your logs! Implementing a Merkle tree for an Immutable Verifiable Log (in Go)* (2022)
