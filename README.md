# Interval

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
    {:interval, "~> 0.3.3"}
  ]
end
```

## Built-in Interval Types

- `Interval.Integer` A discrete interval between two integers.
- `Interval.Float` A continuous interval between two floats.
- `Interval.Decimal` A continuous interval between two `Decimal` structs.
- `Interval.Date` A discrete interval between two `Date` structs.
- `Interval.DateTime` A continuous interval between two `DateTime` structs.
- `Interval.NaiveDateTime` A continuous interval between two `NaiveDateTime` structs.

## Ecto & Postgres `range` types

The builtin types (Like `Interval.DateTime`) can be used as an `Ecto.Type` out
of the box:

```elixir
# ...
  schema "reservations" do
    field :period, Interval.DateTime
    # ...
  end
# ...
```

Note though, that this feature only works with `Postgrex`, as the
intervals are converted to a `Postgrex.Range` struct which maps to the correct
range type in the database (like `tstzrange` etc.)

## Defining your own interval type

The library contains a `use` macro that does most of the work for you.

You must implement the `Interval.Behaviour`, which contains a handful of functions.

This is the full definition of the built-in `Interval.Decimal`:

```elixir
defmodule Interval.Decimal do
  use Interval, type: Decimal, discrete: false

  if Interval.Support.EctoType.supported?() do
    use Interval.Support.EctoType, ecto_type: :numrange
  end

  @spec size(t()) :: Decimal.t() | nil
  def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: Decimal.sub(b, a)
  def size(%__MODULE__{left: :empty, right: :empty}), do: Decimal.new(0)
  def size(%__MODULE__{left: :unbounded}), do: nil
  def size(%__MODULE__{right: :unbounded}), do: nil

  @spec point_valid?(Decimal.t()) :: boolean()
  def point_valid?(a), do: is_struct(a, Decimal)

  @spec point_compare(Decimal.t(), Decimal.t()) :: :lt | :eq | :gt
  def point_compare(a, b) when is_struct(a, Decimal) and is_struct(b, Decimal) do
    Decimal.compare(a, b)
  end

  @spec point_step(Decimal.t(), any()) :: nil
  def point_step(a, _n) when is_struct(a, Decimal), do: nil
end
```

As you can see, defining your own interval types is pretty easy.

## More Examples

### Integer intervals

Integer intervals are discrete intervals (just like the `int4range` in postgres).

```elixir
a = Interval.Integer.new(left: 1, right: 4, bounds: "[]")
b = Interval.Integer.new(left: 2, right: 5, bounds: "[]")

assert Interval.contains?(a, b)
assert Interval.overlaps?(a, b)

c = Interval.intersection(a, b) # [2, 4]
d = Interval.union(a, b) # [1, 5]
```

Discrete intervals are always normalized to the bound form `[)` (just like in postgres).


### DateTime intervals

DateTime intervals are continuous intervals (just like `tstzrange` in postgrex).

```elixir
# default bound is  "[)"
y2022 = Interval.DateTime.new(left: ~U[2022-01-01 00:00:00Z], right: ~U[2023-01-01 00:00:00Z])
x = Interval.DateTime.new(left: ~U[2018-07-01 00:00:00Z], right: ~U[2022-03-01 00:00:00Z])

Interval.intersection(y2022, x)

# %Interval.DateTime{
#   left: {:inclusive, ~U[2022-01-01 00:00:00Z]},
#   right: {:exclusive, ~U[2022-03-01 00:00:00Z]}
# }
```

