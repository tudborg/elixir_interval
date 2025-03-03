if Application.get_env(:interval, Interval.DecimalInterval, true) and Code.ensure_loaded?(Decimal) do
  defmodule Interval.DecimalInterval do
    @moduledoc false

    use Interval, type: Decimal, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :numrange
    end

    @spec point_valid?(Decimal.t()) :: boolean()
    def point_valid?(a), do: is_struct(a, Decimal)

    @spec point_compare(Decimal.t(), Decimal.t()) :: :lt | :eq | :gt
    def point_compare(a, b) when is_struct(a, Decimal) and is_struct(b, Decimal) do
      Decimal.compare(a, b)
    end

    @spec point_step(Decimal.t(), any()) :: nil
    def point_step(a, _n) when is_struct(a, Decimal), do: nil
  end
end
