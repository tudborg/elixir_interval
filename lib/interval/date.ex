if Application.get_env(:interval, Interval.Date, true) do
  defmodule Interval.Date do
    @moduledoc false

    use Interval, type: Date, discrete: true

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :daterange
    end

    @spec size(t()) :: integer() | nil
    def size(%__MODULE__{right: :unbounded}), do: nil
    def size(%__MODULE__{left: :unbounded}), do: nil
    def size(%__MODULE__{left: :empty, right: :empty}), do: 0
    def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: Date.diff(b, a)

    @spec point_valid?(Date.t()) :: boolean()
    def point_valid?(a), do: is_struct(a, Date)

    @spec point_compare(Date.t(), Date.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: Date, as: :compare

    @spec point_step(Date.t(), integer()) :: Date.t()
    def point_step(%Date{} = date, n) when is_integer(n), do: Date.add(date, n)
  end
end
