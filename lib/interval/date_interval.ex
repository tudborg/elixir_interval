if Application.get_env(:interval, Interval.DateInterval, true) do
  defmodule Interval.DateInterval do
    @moduledoc false

    use Interval, type: Date, discrete: true

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :daterange
    end

    @spec point_valid?(Date.t()) :: boolean()
    def point_valid?(a), do: is_struct(a, Date)

    @spec point_compare(Date.t(), Date.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: Date, as: :compare

    @spec point_step(Date.t(), integer()) :: Date.t()
    def point_step(%Date{} = date, n) when is_integer(n), do: Date.add(date, n)
  end
end
