defprotocol Interval.Intervalable do
  @moduledoc """
  Implementing this protocol allows `Interval` to infer the implementation
  to use for a value, which allows you to pass the values to `Interval.new/1`
  without specifying a `module` option:

      iex> Interval.new(left: 1, right: 2)

  Instead of

      iex> Interval.new(module: Interval.Integer, left: 1, right: 2)
      # or equivalent
      iex> Interval.Integer.new(left: 1, right: 2)

  This functionality is purely for ergonomic reasons,
  and is not required to be able to define custom intervals, or to use
  the builtin ones.

  Explicitly calling `Interval.Integer.new/1` could be preferred in certain
  situations because you know exactly what implementation you are getting.
  """

  @doc "Return the Interval.Behaviour implementation to use for this value type"
  def infer_implementation(value)
end

if Application.get_env(:interval, Interval.Integer, true) do
  defimpl Interval.Intervalable, for: Integer do
    def infer_implementation(value) when is_integer(value), do: Interval.Integer
  end
end

if Application.get_env(:interval, Interval.Float, true) do
  defimpl Interval.Intervalable, for: Float do
    def infer_implementation(value) when is_float(value), do: Interval.Float
  end
end

if Application.get_env(:interval, Interval.Date, true) do
  defimpl Interval.Intervalable, for: Date do
    def infer_implementation(value) when is_struct(value, Date), do: Interval.Date
  end
end

if Application.get_env(:interval, Interval.DateTime, true) do
  defimpl Interval.Intervalable, for: DateTime do
    def infer_implementation(value) when is_struct(value, DateTime), do: Interval.DateTime
  end
end

if Application.get_env(:interval, Interval.NaiveDateTime, true) do
  defimpl Interval.Intervalable, for: NaiveDateTime do
    def infer_implementation(value) when is_struct(value, NaiveDateTime),
      do: Interval.NaiveDateTime
  end
end

if Application.get_env(:interval, Interval.Decimal, true) do
  defimpl Interval.Intervalable, for: Decimal do
    def infer_implementation(value) when is_struct(value, Decimal), do: Interval.Decimal
  end
end
