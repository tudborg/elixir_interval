if Application.get_env(:interval, Interval.DateTimeInterval, true) do
  defmodule Interval.DateTimeInterval do
    @moduledoc false

    use Interval, type: DateTime, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :tstzrange
    end

    @impl true
    @spec point_normalize(any()) :: {:ok, DateTime.t()} | :error
    def point_normalize(a) when is_struct(a, DateTime), do: {:ok, a}
    def point_normalize(_), do: :error

    @impl true
    @spec point_compare(DateTime.t(), DateTime.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: DateTime, as: :compare
  end
end
