if Application.get_env(:interval, Interval.NaiveDateTimeInterval, true) do
  defmodule Interval.NaiveDateTimeInterval do
    @moduledoc false

    use Interval, type: NaiveDateTime, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :tstzrange
    end

    @spec point_valid?(NaiveDateTime.t()) :: boolean()
    def point_valid?(a), do: is_struct(a, NaiveDateTime)

    @spec point_compare(NaiveDateTime.t(), NaiveDateTime.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: NaiveDateTime, as: :compare

    @spec point_step(NaiveDateTime.t(), any()) :: nil
    def point_step(%NaiveDateTime{}, _n), do: nil
  end
end
