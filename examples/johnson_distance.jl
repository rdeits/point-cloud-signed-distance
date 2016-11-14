module jd

using StaticArrays
import GeometryTypes
const gt = GeometryTypes

@generated function projection_weights!{M, N, T}(simplex::SVector{M, SVector{N, T}}, deltas, viable)
    projection_weights_impl!(simplex, deltas, viable)
end

function projection_weights_impl!{M, N, T}(::Type{SVector{M, SVector{N, T}}}, deltas)
    num_subsets = 2^M - 1
    complements = falses(M, num_subsets)
    subsets = falses(M, num_subsets)
    for i in 1:num_subsets
        for j in 1:M
            subsets[j, i] = (i >> (j - 1)) & 1
            complements[j, i] = !subsets[j, i]
        end
    end

    expr = quote
#         deltas = zeros(MMatrix{$M, $num_subsets, $T})
#         viable = ones(MVector{$num_subsets, Bool})
    end

    for i in 1:M
        push!(expr.args, quote
            deltas[$(2^(i - 1))][$i] = 1
        end)
    end

    for s in 1:(num_subsets - 1)
        k = first((1:M)[subsets[:,s]])
        for j in (1:M)[complements[:,s]]
            s2 = s + (1 << (j - 1))
            push!(expr.args, quote
                @inbounds for i in $((1:M)[subsets[:,s]])
                    deltas[$s2][$j] += deltas[$s][i] *
                    (dot(simplex[i], simplex[$k]) - dot(simplex[i], simplex[$j]))
                end
            end)
            push!(expr.args, quote
                if deltas[$s2][$j] > 0
                    viable[$s] = false
                elseif deltas[$s2][$j] < 0
                    viable[$s2] = false
                end
            end)
        end
        push!(expr.args, quote
            if viable[$s]
                return deltas[$s] ./ sum(deltas[$s])
#                 return deltas[$s]
            end
        end)
    end
    push!(expr.args, quote
        return deltas[$num_subsets] ./ sum(deltas[$num_subsets])
#         return deltas[end]
    end)
    return expr
end

function projection_weights_old{M, N, T}(simplex::SVector{M, SVector{N, T}})
    num_subsets = 2^M - 1
    complements = falses(M, num_subsets)
    subsets = falses(M, num_subsets)
    for i in 1:num_subsets
        for j in 1:M
            subsets[j, i] = (i >> (j - 1)) & 1
            complements[j, i] = !subsets[j, i]
        end
    end

    deltas = zeros(MMatrix{M, num_subsets, T})
    viable = ones(MVector{num_subsets, Bool})

    for i in 1:M
        deltas[i, 2^(i - 1)] = 1
    end

    for s in 1:(num_subsets - 1)
        k = first((1:M)[subsets[:,s]])
        for j in (1:M)[complements[:,s]]
            s2 = s + (1 << (j - 1))
            delta_j_s2 = 0
            for i in (1:M)[subsets[:,s]]
                delta_j_s2 += deltas[i, s] * (dot(simplex[i], simplex[k]) - dot(simplex[i], simplex[j]))
            end
            if delta_j_s2 > 0
                viable[s] = false
            elseif delta_j_s2 < 0
                viable[s2] = false
            end
            deltas[j, s2] = delta_j_s2
        end
        if viable[s]
            return deltas[:,s] ./ sum(deltas[:,s])
        end
    end
    return deltas[:,end] ./ sum(deltas[:,end])
end

end