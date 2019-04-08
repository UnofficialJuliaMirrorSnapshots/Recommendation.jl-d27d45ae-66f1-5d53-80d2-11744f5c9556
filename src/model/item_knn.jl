export ItemKNN

struct ItemKNN <: Recommender
    da::DataAccessor
    hyperparams::Parameters
    sim::AbstractMatrix
    states::States
end

"""
    ItemKNN(
        da::DataAccessor,
        hyperparams::Parameters=Parameters(:k => 5)
    )

[Item-based CF](https://dl.acm.org/citation.cfm?id=963776) that provides a way to model item-item concepts by utilizing the similarities of items in the CF paradigm. `k` represents number of neighbors.

Item properties are relatively stable compared to the users' tastes, and the number of items is generally smaller than the number of users. Hence, while user-based CF successfully captures the similarities of users' complex tastes, modeling item-item concepts could be much more promising in terms of both scalability and overall accuracy.

Item-based CF defines a similarity between an item ``i`` and ``j`` as:

```math
s_{i,j} = \\frac{ \\sum_{u \\in \\mathcal{U}_{i \\cap j}}  (r_{u, i} - \\overline{r}_i) (r_{u, j} - \\overline{r}_j)}
{ \\sqrt{\\sum_{u \\in \\mathcal{U}_{i \\cap j}} (r_{u,i} - \\overline{r}_i)^2} \\sqrt{\\sum_{u \\in \\mathcal{U}_{i \\cap j}} (r_{u, j} - \\overline{r}_j)^2} },
```

where ``\\mathcal{U}_{i \\cap j}`` is a set of users that both of ``r_{u,i}`` and ``r_{u, j}`` are not missing, and ``\\overline{r}_i, \\overline{r}_j`` are mean values of ``i``-th and ``j``-th column in ``R``. Similarly to the user-based algorithm, for the ``t``-th nearest-neighborhood item ``\\tau(t)``, prediction can be done by top-``k`` weighted sum of target user's feedbacks:

```math
r_{u,i} = \\frac{\\sum^k_{t=1} s_{i,\\tau(t)} \\cdot r_{u,\\tau(t)} }{ \\sum^k_{t=1} s_{i,\\tau(t)} }.
```

In case that the number of items is smaller than users, item-based CF could be a more reasonable choice than the user-based approach.
"""
ItemKNN(da::DataAccessor,
        hyperparams::Parameters=Parameters(:k => 5)) = begin
    n_item = size(da.R, 2)
    ItemKNN(da, hyperparams, zeros(n_item, n_item), States(:is_built => false))
end

function build(rec::ItemKNN; is_adjusted_cosine::Bool=false)
    # cosine similarity

    R = copy(rec.da.R)
    n_row, n_col = size(R)

    if is_adjusted_cosine
        # subtract mean
        for ri in 1:n_row
            indices = broadcast(!isnan, R[ri, :])
            vmean = mean(R[ri, indices])
            R[ri, indices] .-= vmean
        end
    end

    # unlike pearson correlation, matrix can be filled by zeros for cosine similarity
    R[isnan.(R)] .= 0

    # compute L2 nrom of each column
    norms = sqrt.(sum(R.^2, dims=1))

    for ci in 1:n_col
        for cj in ci:n_col
            numer = dot(R[:, ci], R[:, cj])
            denom = norms[ci] * norms[cj]
            s = numer / denom

            rec.sim[ci, cj] = s
            if (ci != cj); rec.sim[cj, ci] = s; end
        end
    end

    # NaN similarities are converted into zeros
    rec.sim[isnan.(rec.sim)] .= 0

    rec.states[:is_built] = true
end

function predict(rec::ItemKNN, u::Int, i::Int)
    check_build_status(rec)

    numer = denom = 0

    # negative similarities are filtered
    pairs = collect(zip(1:size(rec.da.R)[2], max.(rec.sim[i, :], 0)))
    ordered_pairs = sort(pairs, by=tuple->last(tuple), rev=true)[1:rec.hyperparams[:k]]

    for (j, s) in ordered_pairs
        r = rec.da.R[u, j]
        if isnan(r); continue; end

        numer += s * r
        denom += s
    end

    (denom == 0) ? 0 : numer / denom
end
