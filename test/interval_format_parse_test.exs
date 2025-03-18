defmodule IntervalFormatParseTest do
  use ExUnit.Case, async: true

  alias Interval.IntervalParseError
  alias Interval.IntegerInterval
  alias Interval.FloatInterval

  def inti(p), do: inti(p, p, "[]")
  def inti(left, right, bounds \\ "[)"), do: IntegerInterval.new(left, right, bounds)

  def floati(p), do: floati(p, p, "[]")
  def floati(left, right, bounds \\ "[)"), do: FloatInterval.new(left, right, bounds)

  test "format" do
    assert Interval.format(inti(1, 2, "[]")) === "[1,3)"
    assert Interval.format(inti(1, 2, "()")) === "empty"
    assert Interval.format(inti(1, 2, "[)")) === "[1,2)"
    assert Interval.format(inti(1, 2, "(]")) === "[2,3)"
    assert Interval.format(inti(nil, 2, "[)")) === ",2)"
    assert Interval.format(inti(1, nil, "[)")) === "[1,"

    assert Interval.format(floati(:empty)) === "empty"
    assert Interval.format(floati(1.0, 2.0, "[]")) === "[1.0,2.0]"
    assert Interval.format(floati(1.0, 2.0, "()")) === "(1.0,2.0)"
    assert Interval.format(floati(1.0, 2.0, "[)")) === "[1.0,2.0)"
    assert Interval.format(floati(1.0, 2.0, "(]")) === "(1.0,2.0]"
    assert Interval.format(floati(nil, 2.0, "[)")) === ",2.0)"
    assert Interval.format(floati(1.0, nil, "[)")) === "[1.0,"
  end

  test "parse" do
    assert Interval.parse("[1,2]", IntegerInterval) === {:ok, inti(1, 2, "[]")}
    assert Interval.parse("(1,2)", IntegerInterval) === {:ok, inti(1, 2, "()")}
    assert Interval.parse("[1,2)", IntegerInterval) === {:ok, inti(1, 2, "[)")}
    assert Interval.parse("(1,2]", IntegerInterval) === {:ok, inti(1, 2, "(]")}
    assert Interval.parse("empty", IntegerInterval) === {:ok, inti(:empty)}

    assert Interval.parse("[1,2]", FloatInterval) === {:ok, floati(1.0, 2.0, "[]")}
    assert Interval.parse("(1,2)", FloatInterval) === {:ok, floati(1.0, 2.0, "()")}
    assert Interval.parse("[1,2)", FloatInterval) === {:ok, floati(1.0, 2.0, "[)")}
    assert Interval.parse("(1,2]", FloatInterval) === {:ok, floati(1.0, 2.0, "(]")}
    assert Interval.parse("empty", FloatInterval) === {:ok, floati(:empty)}

    assert Interval.parse(",", FloatInterval) == {:ok, floati(nil, nil)}

    ##
    # errors
    ##
    # no comma
    assert {:error, :missing_comma} = Interval.parse("", FloatInterval)
    # no point between left/right bound and comma
    assert {:error, {:left, {:invalid_point, ""}}} = Interval.parse("[,1.0]", FloatInterval)
    assert {:error, {:right, {:invalid_point, ""}}} = Interval.parse("[1.0,]", FloatInterval)
    # no bound before/after point
    assert {:error, {:left, :missing_bound}} = Interval.parse("1.0,2.0]", FloatInterval)
    assert {:error, {:right, :missing_bound}} = Interval.parse("[1.0,2.0", FloatInterval)
    # point_parse not implemented
    assert {:error, {:not_implemented, {__MODULE__, :point_parse, 1}}} =
             Interval.parse("[1.0,2.0", __MODULE__)
  end

  test "parse!" do
    assert Interval.parse!("[1,2]", FloatInterval) === floati(1.0, 2.0, "[]")

    assert_raise IntervalParseError, fn ->
      Interval.parse!("(1,2", FloatInterval)
    end
  end

  defmodule MyInterval do
    use Interval, type: Integer

    defdelegate point_compare(a, b), to: IntegerInterval
    defdelegate point_normalize(a), to: IntegerInterval
  end

  test "MyInterval.format" do
    assert MyInterval.format(MyInterval.new(1, 2)) === "[1,2)"
    assert MyInterval.format(MyInterval.new(1, 2, "()")) === "(1,2)"
  end

  test "MyInterval.parse" do
    assert {:error, {:not_implemented, {MyInterval, :point_parse, 1}}} ===
             MyInterval.parse("[1,2)")
  end
end
