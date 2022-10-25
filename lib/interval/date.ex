defmodule Interval.Date do
  @moduledoc false

  use Interval, type: Date, discrete: true

  def size(%__MODULE__{right: :unbounded}), do: nil
  def size(%__MODULE__{left: :unbounded}), do: nil
  def size(%__MODULE__{left: :empty, right: :empty}), do: 0
  def size(%__MODULE__{left: {_, a}, right: {_, b}}), do: Date.diff(b, a)

  def point_valid?(a), do: is_struct(a, Date)

  @doc """
      iex> point_compare(~D[2022-01-01], ~D[2022-01-01])
      :eq
      
      iex> point_compare(~D[2022-01-01], ~D[2022-01-02])
      :lt

      iex> point_compare(~D[2022-01-02], ~D[2022-01-01])
      :gt
  """
  defdelegate point_compare(a, b), to: Date, as: :compare

  @doc """
      iex> point_step(~D[2022-01-01], 1)
      ~D[2022-01-02]
  """
  def point_step(%Date{} = date, n) when is_integer(n), do: Date.add(date, n)
end
