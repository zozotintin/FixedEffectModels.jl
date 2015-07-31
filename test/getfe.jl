
using RDatasets, DataFrames, FixedEffectModels, Base.Test

df = dataset("plm", "Cigar")
df[:pState] = pool(df[:State])
df[:pYear] = pool(df[:Year])

result = reg(Sales ~ Price |> pYear, df, save = true)
@test_approx_eq  result.augmentdf[1, :pYear] 164.77833189721005

result = reg(Sales ~ Price |> pYear + pState, df, save = true)
@test_approx_eq_eps  result.augmentdf[1, :pYear] + result.augmentdf[1, :pState]  140.6852 1e-3

result = reg(Sales ~ Price |> Year&pState, df, save = true)
@test_approx_eq_eps result.augmentdf[1, :YearxpState]  1.742779  1e-3

#result = reg(Sales ~ Price |> pState + Year&pState, df, save = true)
#@test_approx_eq_eps  result.augmentdf[1, :pState] + df[1, :Year] * result.augmentdf[1, :(YearxpState)]   100.26845979175184  1e-2


result = reg(Sales ~ Price |> pState, df, save = true, subset = (df[:State] .<= 30))

@test isna(result.augmentdf[1380,:pState])

