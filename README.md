[![Coverage Status](https://coveralls.io/repos/matthieugomez/FixedEffectModels.jl/badge.svg?branch=master)](https://coveralls.io/r/matthieugomez/FixedEffectModels.jl?branch=master)
[![Build Status](https://travis-ci.org/matthieugomez/FixedEffectModels.jl.svg?branch=master)](https://travis-ci.org/matthieugomez/FixedEffectModels.jl)



The function `reg` estimates linear models with 
  - high dimensional categorical variable (intercept or interacted with continuous variables)
  - instrumental variables (via 2SLS)
  - robust standard errors (White or clustered) 



`reg` returns a very light object. This allows to estimate multiple models on the same DataFrame without ever worrying about RAM. It is simply composed of 
 
  - the vector of coefficients, 
  - the covariance matrix, 
  - a set of scalars (number of observations, the degree of freedoms, r2, etc)
  - a boolean vector reporting rows used in the estimation

Methods such as `predict`, `residuals` are still defined but require to specify a dataframe as a second argument.  The huge size of `lm` and `glm` models in R (and for now in Julia) is discussed [here](http://www.r-bloggers.com/trimming-the-fat-from-glm-models-in-r/), [here](https://blogs.oracle.com/R/entry/is_the_size_of_your), [here](http://stackoverflow.com/questions/21896265/how-to-minimize-size-of-object-of-class-lm-without-compromising-it-being-passe) [here](http://stackoverflow.com/questions/15260429/is-there-a-way-to-compress-an-lm-class-for-later-prediction) (and for absurd consequences, [here](http://stackoverflow.com/questions/26010742/using-stargazer-with-memory-greedy-glm-objects) and [there](http://stackoverflow.com/questions/22577161/not-enough-ram-to-run-stargazer-the-normal-way)).


`reg` is fast:
![benchmark](https://cdn.rawgit.com/matthieugomez/FixedEffectModels.jl/master/benchmark/result3.svg)
The code used for this graph can be found [here](https://github.com/matthieugomez/FixedEffectModels.jl/blob/master/benchmark/benchmark.md).

To install the package, 

```julia
Pkg.add("FixedEffectModels")
```
## Syntax

The general syntax is

```julia
reg(depvar ~ exogenousvars + (endogeneousvars = instrumentvars) |> absorbvars, df)
```

```julia
using  RDatasets, DataFrames, FixedEffectModels
df = dataset("plm", "Cigar")
df[:pState] =  pool(df[:State])
reg(Sales ~ NDI |> pState, df)
#>                          Fixed Effect Model                         
#> =====================================================================
#> Dependent variable          Sales   Number of obs                1380
#> Degree of freedom              47   R2                          0.207
#> R2 Adjusted                 0.179   F Statistics:             7.40264
#> =====================================================================
#>         Estimate  Std.Error  t value Pr(>|t|)   Lower 95%   Upper 95%
#> ---------------------------------------------------------------------
#> NDI  -0.00170468 9.13903e-5 -18.6527    0.000 -0.00188396 -0.00152539
#> =====================================================================
```


### Fixed effects


- Specify multiple high dimensional fixed effects.

  ```julia
  df[:pYear] =  pool(df[:Year])
  reg(Sales ~ NDI |> pState + pYear, df)
  ```
- Interact fixed effects with continuous variables using `&`

  ```julia
  reg(Sales ~ NDI |> pState + pState&Year, df)
  ```

- Categorical variables must be of type PooledDataArray. Use the function `pool` to transform one column into a `PooledDataArray` and  `group` to combine multiple columns into a `PooledDataArray`.


### Weights

 Weights are supported with the option `weight`. They correspond to R weights and analytical weights in Stata.

```julia
reg(Sales ~ NDI |> pState, df, weight = :Pop)
```

### Subset

You can estimate a model on a subset of your data with the option `subset` 

```julia
reg(Sales ~ NDI |> pState, weight = :Pop, subset = df[:pState] .< 30)
```

## Errors
Compute robust standard errors by constructing an object of type `AbstractVcov`. For now, `VcovSimple()` (default), `VcovWhite()` and `VcovCluster(cols)` are implemented.

```julia
reg(Sales ~ NDI, df, VcovWhite())
reg(Sales ~ NDI, df, VcovCluster([:State]))
reg(Sales ~ NDI, df, VcovCluster([:State, :Year]))
```


You can easily define your own type: after declaring it as a child of `AbstractVcov`, define a `allvars` and a `vcov!` methods for it. For instance,  White errors are implemented with the following code:

```julia
immutable type VcovWhite <: AbstractVcov 
end

function vcov!(x::AbstractVcovData, t::VcovWhite) 
	Xu = broadcast!(*,  regressormatrix(x), residuals(X))
	S = At_mul_B(Xu, Xu)
	scale!(S, nobs(X)/df_residual(X))
	sandwich(x, S) 
end
```


## Partial out

`partial_out` returns the residuals of a set of variables after regressing them on a set of regressors. The syntax is similar to `reg` - just with multiple `lhs`. It returns  a dataframe with as many columns as there are dependent variables and as many rows as the original dataframe.
The regression model is estimated on only the rows where *none* of the dependent variables is missing. With the option `add_mean = true`, the mean of the initial variable is added to the residuals.



```julia
using  RDatasets, DataFrames, FixedEffectModels
df = dataset("plm", "Cigar")
df[:pState] =  pool(df[:State])
df[:pYear] =  pool(df[:Year])
result = partial_out(Sales + Price ~ 1|> pYear + pState, df, add_mean = true)
#> 1380x2 DataFrame
#> | Row  | Sales   | Price   |
#> |------|---------|---------|
#> | 1    | 107.029 | 69.7684 |
#> | 2    | 112.099 | 70.1641 |
#> | 3    | 113.325 | 69.9445 |
#> | 4    | 110.523 | 70.1401 |
#> | 5    | 109.501 | 69.5184 |
#> | 6    | 104.332 | 71.451  |
#> | 7    | 107.266 | 71.3488 |
#> | 8    | 109.769 | 71.2836 |
#> ⋮
#> | 1372 | 117.975 | 64.5648 |
#> | 1373 | 116.216 | 64.8778 |
#> | 1374 | 117.605 | 68.7996 |
#> | 1375 | 106.281 | 67.0257 |
#> | 1376 | 113.707 | 68.3996 |
#> | 1377 | 115.144 | 63.4974 |
#> | 1378 | 105.099 | 61.1083 |
#> | 1379 | 119.936 | 49.9365 |
#> | 1380 | 122.503 | 57.7017 |
```

This allows to examine graphically the relation between two variables after partialing out the variation due to control variables. For instance, the relationship between SepalLength seems to be decreasing in SepalWidth in the `iris` dataset
```julia
using  RDatasets, DataFrames, Gadfly, FixedEffectModels
df = dataset("datasets", "iris")
plot(
   layer(df, x="SepalWidth", y="SepalLength", Stat.binmean(n=10), Geom.point),
   layer(df, x="SepalWidth", y="SepalLength", Geom.smooth(method=:lm))
)
```
![binscatter](http://cdn.rawgit.com/matthieugomez/FixedEffectModels.jl/master/benchmark/first.svg)

But the relationship is actually increasing within species.
```
plot(
   layer(df, x="SepalWidth", y="SepalLength", color = "Species", Stat.binmean(n=10), Geom.point),
   layer(df, x="SepalWidth", y="SepalLength", color = "Species", Geom.smooth(method=:lm))
)
```
![binscatter](https://cdn.rawgit.com/matthieugomez/FixedEffectModels.jl/9a12681d81f9d713cec3b88b1abf362cdddb9a14/benchmark/second.svg)


If there is large number of groups, a better way to visualize this fact is to plot the variables after partialing them out:
```
result = partial_out(SepalWidth + SepalLength ~ 1|> Species, df, add_mean = true)
using Gadfly
plot(
   layer(result, x="SepalWidth", y="SepalLength", Stat.binmean(n=10), Geom.point),
   layer(result, x="SepalWidth", y="SepalLength", Geom.smooth(method=:lm))
)
```
![binscatter](https://cdn.rawgit.com/matthieugomez/FixedEffectModels.jl/9a12681d81f9d713cec3b88b1abf362cdddb9a14/benchmark/third.svg)

The combination of `partial_out` and Gadfly `Stat.binmean` is very similar to the the Stata program [binscatter](https://michaelstepner.com/binscatter/).




