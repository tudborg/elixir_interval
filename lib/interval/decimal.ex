if Application.get_env(:interval, Interval.Decimal, true) and Code.ensure_loaded?(Decimal) do
  defmodule Interval.Decimal do
    @moduledoc false

    use Interval, type: Decimal, discrete: false

    if Code.ensure_loaded?(Interval.Support.Ecto) do
      use Interval.Support.Ecto, ecto_type: :numrange
    end

    def point_valid?(a), do: is_struct(a, Decimal)

    def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: Decimal.sub(b, a)
    def size(%__MODULE__{left: :empty, right: :empty}), do: Decimal.new(0)
    def size(%__MODULE__{left: :unbounded}), do: nil
    def size(%__MODULE__{right: :unbounded}), do: nil

    def point_compare(a, b) when is_struct(a, Decimal) and is_struct(b, Decimal) do
      Decimal.compare(a, b)
    end

    def point_step(a, _n) when is_struct(a, Decimal), do: nil
  end
end
