# Interval

docs: <https://hexdocs.pm/interval>

inspired by [PostgreSQL's range types](https://www.postgresql.org/docs/current/rangetypes.html)

## Installation

The package can be installed by adding `interval` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:interval, "~> 0.1.0"}
  ]
end
```

## Concept

### Interval

### Empty

### Bounds


## Examples


#### Integer intervals

```elixir
a = Interval.new(left: 1, right: 4, bounds: "[]")
b = Interval.new(left: 2, right: 5, bounds: "[]")

assert Interval.contains?(a, b)
assert Interval.overlaps?(a, b)

c = Interval.intersection(a, b) # [2, 4]
d = Interval.union(a, b) # [1, 5]
```

#### DateTime intervals

```elixir
# default bound is  "[)"
y2022 = Interval.new(left: ~U[2022-01-01 00:00:00Z], right: ~U[2023-01-01 00:00:00Z])
x = Interval.new(left: ~U[2018-07-01 00:00:00Z], right: ~U[2022-03-01 00:00:00Z])

Interval.intersection(y2022, x)

# %Interval{
#   left: %Interval.Endpoint{inclusive: true, point: ~U[2022-01-01 00:00:00Z]},
#   right: %Interval.Endpoint{inclusive: false, point: ~U[2022-03-01 00:00:00Z]}
# }
```
