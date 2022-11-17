if Code.ensure_loaded?(Postgrex) do
  defmodule Interval.Support.Postgrex do
    @moduledoc """
    Conversion helpers for converting `t:Postgrex.Range.t/0` to and from
    an `t:Interval.t/0`

    ## Example

        interval = Interval.Support.Postgrex.from_range(my_int4range, Interval.Integer)
    """

    alias Postgrex.Range

    @doc """
    Convert a `Postgrex.Range` to a struct of type `module`
    """
    def from_range(%Range{} = range, module) do
      bounds =
        [
          if(range.lower_inclusive, do: "[", else: "("),
          if(range.upper_inclusive, do: "]", else: ")")
        ]
        |> Enum.join()

      module.new(left: range.lower, right: range.upper, bounds: bounds)
    end

    @doc """
    Convert an `Interval` struct to a `Postgrex.Range`.
    """
    def to_range(interval, module \\ nil)

    def to_range(%module{left: left, right: right}, module) do
      {lower, lower_inclusive} = to_point(left)
      {upper, upper_inclusive} = to_point(right)

      %Range{
        lower: lower,
        upper: upper,
        lower_inclusive: lower_inclusive,
        upper_inclusive: upper_inclusive
      }
    end

    def to_range(%module{} = struct, nil) do
      to_range(struct, module)
    end

    defp to_point(:unbounded), do: {:unbound, false}
    defp to_point(:empty), do: {:empty, false}
    defp to_point({:inclusive, point}), do: {point, true}
    defp to_point({:exclusive, point}), do: {point, false}
  end
end
