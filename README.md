# ![Interval](assets/banner.png "Interval")

[![CI](https://github.com/tbug/elixir_interval/actions/workflows/ci.yml/badge.svg)](https://github.com/tbug/elixir_interval/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/interval.svg)](https://hex.pm/packages/interval)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/interval/)

Datatype and operations for both discrete and continuous intervals,
Inspired by [PostgreSQL's range types](https://www.postgresql.org/docs/current/rangetypes.html).

Find the documentation at https://hexdocs.pm/interval/


## Installation

The package can be installed by adding `interval` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:interval, "~> 2.0.0"}
  ]
end
```

## Ecto & Postgres support

The builtin types (Like `Interval.DateTimeInterval`) can be used as an `Ecto.Type`
which will convert to Postgres' range types.

```elixir
# ...
  schema "reservations" do
    field :period, Interval.DateTimeInterval
    # ...
  end
# ...
```


## Built-in Interval Types

- `Interval.IntegerInterval` A discrete interval between two integers.
- `Interval.FloatInterval` A continuous interval between two floats.
- `Interval.DecimalInterval` A continuous interval between two `Decimal` structs.
- `Interval.DateInterval` A discrete interval between two `Date` structs.
- `Interval.DateTimeInterval` A continuous interval between two `DateTime` structs.
- `Interval.NaiveDateTimeInterval` A continuous interval between two `NaiveDateTime` structs.

See `Interval` for reference documentation on the available API functions.


Note though, that this feature only works with `Postgrex`, as the
intervals are converted to a `Postgrex.Range` struct which maps to the correct
range type in the database (like `tstzrange` etc.)

## Defining your own interval type

The library contains a `use` macro that does most of the work for you.

You must implement the `Interval.Behaviour`, which contains a handful of functions.

This is the full definition of the built-in `Interval.DecimalInterval`:

```elixir
defmodule Interval.DecimalInterval do
  use Interval, type: Decimal, discrete: false

  if Interval.Support.EctoType.supported?() do
    use Interval.Support.EctoType, ecto_type: :numrange
  end

  @impl true
  @spec point_normalize(any()) :: {:ok, Decimal.t()} | :error
  def point_normalize(a) when is_struct(a, Decimal), do: {:ok, a}
  def point_normalize(_), do: :error

  @impl true
  @spec point_compare(Decimal.t(), Decimal.t()) :: :lt | :eq | :gt
  def point_compare(a, b) when is_struct(a, Decimal) and is_struct(b, Decimal) do
    Decimal.compare(a, b)
  end
end
```

## More Examples

### Integer intervals

Integer intervals are discrete intervals (just like the `int4range` in Postgres).

```elixir
alias Interval.IntegerInterval
# ...
a = IntegerInterval.new(1, 4, "[]")
# [1, 5)
b = IntegerInterval.new(2, 5, "[]")
# [2, 6)

assert IntegerInterval.contains?(a, b)
assert IntegerInterval.overlaps?(a, b)

c = IntegerInterval.intersection(a, b) # [2, 5)
d = IntegerInterval.union(a, b) # [1, 6)
e = IntegerInterval.difference(a, b) # [1, 2)
```

Discrete intervals are always normalized to the bound form `[)` (just like in Postgres).


### DateTime intervals

DateTime intervals are continuous intervals (just like `tstzrange` in Postgres).

```elixir
alias Interval.DateTimeInterval
# ...
# default bound is  "[)"
a = DateTimeInterval.new(~U[2022-01-01 00:00:00Z], ~U[2023-01-01 00:00:00Z])
b = DateTimeInterval.new(~U[2018-07-01 00:00:00Z], ~U[2022-03-01 00:00:00Z])

DateTimeInterval.intersection(a, b)

# %DateTimeInterval{
#   left: {:inclusive, ~U[2022-01-01 00:00:00Z]},
#   right: {:exclusive, ~U[2022-03-01 00:00:00Z]}
# }
```

