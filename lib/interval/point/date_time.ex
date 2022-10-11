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

    @doc """
        iex> next(~U[2022-01-01 00:00:00Z])
        ~U[2022-01-01 00:00:00Z]
    """
    def next(%DateTime{} = a), do: a

    @doc """
        iex> previous(~U[2022-01-01 00:00:00Z])
        ~U[2022-01-01 00:00:00Z]
    """
    def previous(%DateTime{} = a), do: a

    @doc """
        iex> Interval.Point.DateTime.min(~U[2022-01-01 00:00:00Z], ~U[2022-01-02 00:00:00Z])
        ~U[2022-01-01 00:00:00Z]

        iex> Interval.Point.DateTime.min(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 00:00:00Z])
        ~U[2022-01-01 00:00:00Z]
        
        iex> Interval.Point.DateTime.min(~U[2022-01-02 00:00:00Z], ~U[2022-01-01 00:00:00Z])
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

        iex> Interval.Point.DateTime.max(~U[2022-01-02 00:00:00Z], ~U[2022-01-02 00:00:00Z])
        ~U[2022-01-02 00:00:00Z]
        
        iex> Interval.Point.DateTime.max(~U[2022-01-02 00:00:00Z], ~U[2022-01-01 00:00:00Z])
        ~U[2022-01-02 00:00:00Z]
    """
    def max(a, b) do
      case DateTime.compare(a, b) do
        :lt -> b
        :eq -> a
        :gt -> a
      end
    end

    @doc """
        iex> subtract(~U[2022-01-02 00:00:00Z], ~U[2022-01-01 00:00:00Z])
        86400
    """
    def subtract(a, b, unit \\ :second) do
      DateTime.diff(a, b, unit)
    end

    @doc """
        iex> add(~U[2022-01-01 00:00:00Z], 86400)
        ~U[2022-01-02 00:00:00Z]
    """
    def add(a, value_to_add, unit \\ :second) do
      DateTime.add(a, value_to_add, unit)
    end
  end
end
