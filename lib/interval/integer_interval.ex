if Application.get_env(:interval, Interval.IntegerInterval, true) do
  defmodule Interval.IntegerInterval do
    @moduledoc false

    use Interval, type: Integer, discrete: true

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :int4range
    end

    @impl true
    @spec point_normalize(any()) :: {:ok, integer()} | :error
    def point_normalize(a) when is_integer(a), do: {:ok, a}
    def point_normalize(_), do: :error

    @impl true
    @spec point_compare(integer(), integer()) :: :lt | :eq | :gt
    def point_compare(a, a) when is_integer(a), do: :eq
    def point_compare(a, b) when is_integer(a) and is_integer(b) and a > b, do: :gt
    def point_compare(a, b) when is_integer(a) and is_integer(b) and a < b, do: :lt

    @impl true
    @spec point_step(integer(), integer()) :: integer()
    def point_step(a, n) when is_integer(a) and is_integer(n), do: a + n
  end
end
