if Application.get_env(:interval, Interval.IntegerInterval, true) do
  defmodule Interval.IntegerInterval do
    @moduledoc false

    use Interval, type: Integer, discrete: true

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :int4range
    end

    @spec point_valid?(integer()) :: boolean()
    def point_valid?(a), do: is_integer(a)

    @spec point_compare(integer(), integer()) :: :lt | :eq | :gt
    def point_compare(a, a) when is_integer(a), do: :eq
    def point_compare(a, b) when is_integer(a) and is_integer(b) and a > b, do: :gt
    def point_compare(a, b) when is_integer(a) and is_integer(b) and a < b, do: :lt

    @spec point_step(integer(), integer()) :: integer()
    def point_step(a, n) when is_integer(a) and is_integer(n), do: a + n
  end
end
