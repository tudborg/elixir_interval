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

    @impl true
    @spec point_format(DateTime.t()) :: String.t()
    def point_format(point) do
      DateTime.to_iso8601(point)
    end

    @impl true
    @spec point_parse(String.t()) :: {:ok, DateTime.t()} | :error
    def point_parse(str) do
      case DateTime.from_iso8601(str) do
        {:ok, dt, _offset} -> {:ok, dt}
        {:error, _} -> :error
      end
    end
  end
end
