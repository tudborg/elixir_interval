if Application.get_env(:interval, Integer, true) do
  defimpl Interval.Point, for: Integer do
    @doc """
        iex> compare(1, 1)
        :eq
        
        iex> compare(1, 2)
        :lt

        iex> compare(2, 1)
        :gt
    """
    def compare(a, a) when is_integer(a), do: :eq
    def compare(a, b) when is_integer(a) and is_integer(b) and a > b, do: :gt
    def compare(a, b) when is_integer(a) and is_integer(b) and a < b, do: :lt

    @doc """
        iex> type(1)
        :discrete
    """
    def type(a) when is_integer(a), do: :discrete

    @doc """
        iex> 1 |> next() |> next()
        3
    """
    def next(a) when is_integer(a), do: a + 1

    @doc """
        iex> 3 |> previous() |> previous()
        1
    """
    def previous(a) when is_integer(a), do: a - 1

    @doc """
        iex> Interval.Point.Integer.min(1, 2)
        1
    """
    defdelegate min(a, b), to: Kernel

    @doc """
        iex> Interval.Point.Integer.max(1, 2)
        2
    """
    defdelegate max(a, b), to: Kernel

    @doc """
        iex> subtract(3, 1)
        2
    """
    def subtract(a, b, _unit \\ nil) do
      a - b
    end

    @doc """
        iex> add(1, 2)
        3
    """
    def add(a, value, _unit \\ nil) do
      a + value
    end

    def zero(_), do: 0
  end
end
