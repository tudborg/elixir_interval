if Application.get_env(:interval, Interval.NaiveDateTimeInterval, true) do
  defmodule Interval.NaiveDateTimeInterval do
    @moduledoc false

    use Interval, type: NaiveDateTime, discrete: false

    if Interval.Support.EctoType.supported?() do
      use Interval.Support.EctoType, ecto_type: :tstzrange
    end

    if Interval.Support.Jason.supported?() do
      use Interval.Support.Jason
    end

    @impl true
    @spec point_normalize(NaiveDateTime.t()) :: {:ok, NaiveDateTime.t()} | :error
    def point_normalize(a) when is_struct(a, NaiveDateTime), do: {:ok, a}
    def point_normalize(_), do: :error

    @impl true
    @spec point_compare(NaiveDateTime.t(), NaiveDateTime.t()) :: :lt | :eq | :gt
    defdelegate point_compare(a, b), to: NaiveDateTime, as: :compare

    @impl true
    @spec point_step(NaiveDateTime.t(), any()) :: nil
    def point_step(%NaiveDateTime{}, _n), do: nil

    @impl true
    @spec point_format(NaiveDateTime.t()) :: String.t()
    def point_format(point) do
      NaiveDateTime.to_iso8601(point)
    end

    @impl true
    @spec point_parse(String.t()) :: {:ok, NaiveDateTime.t()} | :error
    def point_parse(str) do
      case NaiveDateTime.from_iso8601(str) do
        {:ok, dt} -> {:ok, dt}
        {:error, _} -> :error
      end
    end
  end
end
