# Facts with their status and source

Returns one row per fact, with the metadata recorded while resolving it.

## Usage

``` r
facts_df(x = facts(), namespaces = NULL)
```

## Arguments

- x:

  A `fax` object from
  [`facts()`](https://pedrobtz.github.io/fax/reference/facts.md).

- namespaces:

  Namespaces to include. With `NULL`, all default namespaces plus any
  opt-in namespace already resolved in `x`.

## Value

A data frame with columns:

- `fact`: the fact name.

- `value`: a list-column of values (`NA` when not available).

- `status`: `"ok"`, `"not_applicable"`, `"unavailable"` or `"error"`.

- `source`: the files, commands, environment variables or URLs used.

- `resolver`: the id of the resolver that produced the value.

- `elapsed`: resolution time in seconds.

- `message`: why the status is not `"ok"`.

## Examples

``` r
facts_df(facts())
#> [1] fact     value    status   source   resolver elapsed  message 
#> <0 rows> (or 0-length row.names)
```
