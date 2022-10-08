if Application.get_env(:interval, DateTime, true) do
  defimpl Interval.Point, for: DateTime do
    @doc """
      iex> compare(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 00:00:00Z])
      :eq
      
      iex> compare(~U[2022-01-01 00:00:00Z], ~U[2022-01-02 00:00:00Z])
      :lt

      iex> compare(~U[2022-01-02 00:00:00Z], ~U[2022-01-01 00:00:00Z])
      :gt
    """
    defdelegate compare(a, b), to: DateTime

    @doc """
      iex> type(~U[2022-01-01 00:00:00Z])
      :continuous
    """
    def type(%DateTime{}), do: :continuous
    def type(_), do: :invalid

    @doc """
      iex> next(~U[2022-01-01 00:00:00Z])
      ** (RuntimeError) DateTime is not a discrete Interval.Point type
    """
    def next(%DateTime{}), do: raise("DateTime is not a discrete Interval.Point type")

    @doc """
      iex> previous(~U[2022-01-01 00:00:00Z])
      ** (RuntimeError) DateTime is not a discrete Interval.Point type
    """
    def previous(%DateTime{}), do: raise("DateTime is not a discrete Interval.Point type")

    @doc """
      iex> Interval.Point.DateTime.min(~U[2022-01-01 00:00:00Z], ~U[2022-01-02 00:00:00Z])
      ~U[2022-01-01 00:00:00Z]
    """
    def min(a, b) do
      case DateTime.compare(a, b) do
        :lt -> a
        :eq -> a
        :gt -> b
      end
    end

    @doc """
      iex> Interval.Point.DateTime.max(~U[2022-01-01 00:00:00Z], ~U[2022-01-02 00:00:00Z])
      ~U[2022-01-02 00:00:00Z]
    """
    def max(a, b) do
      case DateTime.compare(a, b) do
        :lt -> b
        :eq -> a
        :gt -> a
      end
    end
  end
end
