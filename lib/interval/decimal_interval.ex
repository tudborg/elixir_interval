if Application.get_env(:interval, Interval.DecimalInterval, true) and Code.ensure_loaded?(Decimal) do
  defmodule Interval.DecimalInterval do
    @moduledoc false

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

    @impl true
    @spec point_format(Decimal.t()) :: String.t()
    def point_format(point) do
      Decimal.to_string(point)
    end

    @impl true
    @spec point_parse(String.t()) :: {:ok, Decimal.t()} | :error
    def point_parse(str) do
      case Decimal.parse(str) do
        {num, ""} -> {:ok, num}
        {_num, _} -> :error
        :error -> :error
      end
    end
  end
end
