# Get the value of a single fact

Get the value of a single fact

## Usage

``` r
fact(
  name,
  cloud = getOption("fax.cloud", FALSE),
  refresh = FALSE,
  strict = getOption("fax.strict", FALSE)
)
```

## Arguments

- name:

  A fact name, e.g. `"cpu.effective"`.

- cloud:

  Allow network requests to the cloud instance metadata service.
  Defaults to the `fax.cloud` option, else `FALSE`.

- refresh:

  If `TRUE`, ignore cached values and resolve facts again.

- strict:

  If `TRUE`, re-raise errors from resolvers instead of recording them as
  `status = "error"`. Defaults to the `fax.strict` option, else `FALSE`.

## Value

The fact's value, or `NA` if it could not be determined.

## See also

[`facts()`](https://pedrobtz.github.io/fax/reference/facts.md) for a
lazy snapshot of many facts.

## Examples

``` r
try(fact("cpu.effective"))
#> Error in startsWith(known_facts(), paste0(name, ".")) : 
#>   non-character object(s)
```
