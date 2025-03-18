if Application.get_env(:interval, Interval.FloatInterval, true) do
  defmodule Interval.FloatInterval do
    @moduledoc false

    use Interval, type: Float, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :floatrange
    end

    @impl true
    @spec point_normalize(any()) :: {:ok, float()} | :error
    def point_normalize(-0.0), do: {:ok, +0.0}
    def point_normalize(a) when is_float(a), do: {:ok, a}
    def point_normalize(_), do: :error

    @impl true
    @spec point_compare(float(), float()) :: :lt | :eq | :gt
    def point_compare(a, a) when is_float(a), do: :eq
    def point_compare(a, b) when is_float(a) and is_float(b) and a > b, do: :gt
    def point_compare(a, b) when is_float(a) and is_float(b) and a < b, do: :lt

    @impl true
    @spec point_format(float()) :: String.t()
    def point_format(point) do
      Float.to_string(point)
    end

    @impl true
    @spec point_parse(String.t()) :: {:ok, float()} | :error
    def point_parse(str) do
      case Float.parse(str) do
        {num, ""} -> {:ok, num}
        {_num, _} -> :error
        :error -> :error
      end
    end
  end
end
