if Application.get_env(:interval, Interval.Float, true) do
  defmodule Interval.Float do
    @moduledoc false

    use Interval, type: Float, discrete: false

    if Code.ensure_loaded?(Interval.Support.Ecto) do
      use Interval.Support.Ecto, ecto_type: :floatrange
    end

    @spec size(t()) :: float() | nil
    def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: b - a
    def size(%__MODULE__{left: :empty, right: :empty}), do: 0.0
    def size(%__MODULE__{left: :unbounded}), do: nil
    def size(%__MODULE__{right: :unbounded}), do: nil

    @spec point_valid?(float()) :: boolean()
    def point_valid?(a), do: is_float(a)

    @spec point_compare(float(), float()) :: :lt | :eq | :gt
    def point_compare(a, a) when is_float(a), do: :eq
    def point_compare(a, b) when is_float(a) and is_float(b) and a > b, do: :gt
    def point_compare(a, b) when is_float(a) and is_float(b) and a < b, do: :lt

    @spec point_step(float(), any()) :: nil
    def point_step(a, _n) when is_float(a), do: nil
  end
end
