if Application.get_env(:interval, Date, true) do
  defimpl Interval.Point, for: Date do
    @doc """
      iex> compare(~D[2022-01-01], ~D[2022-01-01])
      :eq
      
      iex> compare(~D[2022-01-01], ~D[2022-01-02])
      :lt

      iex> compare(~D[2022-01-02], ~D[2022-01-01])
      :gt
    """
    defdelegate compare(a, b), to: Date

    @doc """
      iex> type(~D[2022-01-01])
      :discrete
    """
    def type(%Date{}), do: :discrete
    def type(_), do: :invalid

    @doc """
      iex> next(~D[2022-01-01])
      ~D[2022-01-02]
    """
    def next(%Date{} = date), do: Date.add(date, 1)

    @doc """
      iex> previous(~D[2022-01-01])
      ~D[2021-12-31]
    """
    def previous(%Date{} = date), do: Date.add(date, -1)

    @doc """
      iex> Interval.Point.Date.min(~D[2022-01-01], ~D[2022-01-02])
      ~D[2022-01-01]
    """
    def min(a, b) do
      case Date.compare(a, b) do
        :lt -> a
        :eq -> a
        :gt -> b
      end
    end

    @doc """
      iex> Interval.Point.Date.max(~D[2022-01-01], ~D[2022-01-02])
      ~D[2022-01-02]
    """
    def max(a, b) do
      case Date.compare(a, b) do
        :lt -> b
        :eq -> a
        :gt -> a
      end
    end
  end
end
