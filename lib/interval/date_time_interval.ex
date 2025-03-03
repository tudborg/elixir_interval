if Application.get_env(:interval, Interval.DateTimeInterval, true) do
  defmodule Interval.DateTimeInterval do
    @moduledoc false

    use Interval, type: DateTime, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :tstzrange
    end

    @spec point_valid?(DateTime.t()) :: boolean()
    def point_valid?(a), do: is_struct(a, DateTime)

    @spec point_compare(DateTime.t(), DateTime.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: DateTime, as: :compare

    @spec point_step(DateTime.t(), any()) :: nil
    def point_step(%DateTime{}, _n), do: nil
  end
end
