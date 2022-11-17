if Application.get_env(:interval, Interval.DateTime, true) do
  defmodule Interval.DateTime do
    @moduledoc false

    use Interval, type: DateTime, discrete: false

    if Code.ensure_loaded?(Interval.Support.Ecto) do
      use Interval.Support.Ecto, ecto_type: :tstzrange
    end

    def size(%__MODULE__{right: :unbounded}), do: nil
    def size(%__MODULE__{left: :unbounded}), do: nil
    def size(%__MODULE__{left: :empty, right: :empty}), do: 0.0
    def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: DateTime.diff(b, a)

    def point_valid?(a), do: is_struct(a, DateTime)

    defdelegate point_compare(a, b), to: DateTime, as: :compare

    def point_step(%DateTime{}, _n), do: nil
  end
end
