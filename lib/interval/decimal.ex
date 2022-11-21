if Application.get_env(:interval, Interval.Decimal, true) and Code.ensure_loaded?(Decimal) do
  defmodule Interval.Decimal do
    @moduledoc false

    use Interval, type: Decimal, discrete: false

    if Code.ensure_loaded?(Interval.Support.Ecto) do
      use Interval.Support.Ecto, ecto_type: :numrange
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
end
