export ThresholdPercentage

struct ThresholdPercentage <: Recommender
    da::DataAccessor
    hyperparams::Parameters
    scores::AbstractVector
    states::States
end

"""

    ThresholdPercentage(
        da::DataAccessor,
        hyperparams::Parameters=Parameters(:th => 2.5)
    )

Recommend based on percentage of ratings which are greater than a certain threshold value `th`.
"""
ThresholdPercentage(da::DataAccessor,
                    hyperparams::Parameters=Parameters(:th => 2.5)) = begin
    n_item = size(da.R, 2)
    ThresholdPercentage(da, hyperparams, zeros(n_item), States(:is_built => false))
end

function build(rec::ThresholdPercentage)
    n_item = size(rec.da.R, 2)

    for i in 1:n_item
        v = rec.da.R[:, i]
        rec.scores[i] = length(v[v .>= rec.hyperparams[:th]]) / count(!iszero, v) * 100.0
    end

    rec.states[:is_built] = true
end

function ranking(rec::ThresholdPercentage, u::Int, i::Int)
    check_build_status(rec)
    rec.scores[i]
end
