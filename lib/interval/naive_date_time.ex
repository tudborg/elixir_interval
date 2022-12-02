if Application.get_env(:interval, Interval.NaiveDateTime, true) do
  defmodule Interval.NaiveDateTime do
    @moduledoc false

    use Interval, type: NaiveDateTime, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :tstzrange
    end

    @spec size(t()) :: integer() | nil
    def size(%__MODULE__{right: :unbounded}), do: nil
    def size(%__MODULE__{left: :unbounded}), do: nil
    def size(%__MODULE__{left: :empty, right: :empty}), do: 0.0
    def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: NaiveDateTime.diff(b, a)

    @spec point_valid?(NaiveDateTime.t()) :: boolean()
    def point_valid?(a), do: is_struct(a, NaiveDateTime)

    @spec point_compare(NaiveDateTime.t(), NaiveDateTime.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: NaiveDateTime, as: :compare

    @spec point_step(NaiveDateTime.t(), any()) :: nil
    def point_step(%NaiveDateTime{}, _n), do: nil
  end
end
