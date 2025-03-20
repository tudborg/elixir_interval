defmodule Helper do
  @moduledoc """
  Generators for property testing
  """

  alias Interval.FloatInterval
  alias Interval.DecimalInterval
  alias Interval.IntegerInterval

  import ExUnitProperties

  def bounds() do
    StreamData.one_of(
      ["[]", "[)", "(]", "()"]
      |> Enum.map(&StreamData.constant/1)
    )
  end

  def bounded_interval(module, left_generator, offset_generator) do
    gen all(
          left <- left_generator,
          offset <- offset_generator,
          bounds <- bounds()
        ) do
      # to avoid producing empty intervals,
      # we check that the bounds and ensure that we cannot produce
      # an interval that would normalize to empty
      if module.discrete?() do
        offset =
          case bounds do
            # both inclusive, we are OK with offset being 0
            "[]" -> module.point_step(offset, -1)
            # if either bound is inclusive,
            "(]" -> offset
            # the default of offset `[1,` is OK
            "[)" -> offset
            # both exclusive, so offset must be at least 2 to not produce empty
            "()" -> module.point_step(offset, +1)
          end

        Interval.new(
          module: module,
          left: left,
          right: add_offset(left, offset),
          bounds: bounds
        )
      else
        Interval.new(
          module: module,
          left: left,
          right: add_offset(left, offset),
          bounds: bounds
        )
      end
    end
  end

  def unbounded_interval(module, point_generator) do
    gen all(
          point <- point_generator,
          point_is_left <- StreamData.boolean(),
          bounds <- bounds()
        ) do
      opts =
        if point_is_left do
          [module: module, left: point, right: nil, bounds: bounds]
        else
          [module: module, left: nil, right: point, bounds: bounds]
        end

      Interval.new(opts)
    end
  end

  defp add_offset(value, offset) when is_integer(value), do: value + offset
  defp add_offset(value, offset) when is_float(value), do: value + offset

  defp add_offset(value, offset) when is_struct(value, Decimal) do
    Decimal.add(value, offset)
    |> Decimal.normalize()
  end

  def empty_interval(module) do
    StreamData.constant(module.new(left: :empty, right: :empty))
  end

  def interval(module, opts \\ []) do
    case module do
      IntegerInterval -> integer_interval(opts)
      FloatInterval -> float_interval(opts)
      DecimalInterval -> decimal_interval(opts)
    end
  end

  def integer_interval(opts \\ []) do
    opts = Keyword.merge([unbounded: true, bounded: true, empty: true], opts)
    i = StreamData.integer()
    pi = StreamData.positive_integer()

    StreamData.one_of(
      [
        if(Keyword.get(opts, :bounded), do: bounded_interval(IntegerInterval, i, pi)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(IntegerInterval, i)),
        if(Keyword.get(opts, :empty), do: empty_interval(IntegerInterval))
      ]
      |> Enum.reject(&is_nil/1)
    )
  end

  def float_interval(opts \\ []) do
    opts = Keyword.merge([unbounded: true, bounded: true, empty: true], opts)
    f = StreamData.float()
    pf = StreamData.float(min: 0.1)

    StreamData.one_of(
      [
        if(Keyword.get(opts, :bounded), do: bounded_interval(FloatInterval, f, pf)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(FloatInterval, f)),
        if(Keyword.get(opts, :empty), do: empty_interval(FloatInterval))
      ]
      |> Enum.reject(&is_nil/1)
    )
  end

  def decimal_interval(opts \\ []) do
    opts = Keyword.merge([unbounded: true, bounded: true, empty: true], opts)
    zero = Decimal.new(0)

    f =
      StreamData.float()
      |> StreamData.map(&Decimal.from_float/1)
      |> StreamData.map(&Decimal.normalize/1)
      |> StreamData.map(fn value ->
        # When -0 is generated, 0 and -0 isn't the same
        # term, and the test assertions get's annoying to do.
        # Instead, just prevent -0 from being generated.
        case Decimal.compare(value, zero) do
          :eq -> zero
          _ -> value
        end
      end)

    pf =
      StreamData.float(min: 0.1)
      |> StreamData.map(&Decimal.from_float/1)
      |> StreamData.map(&Decimal.normalize/1)

    StreamData.one_of(
      [
        if(Keyword.get(opts, :bounded), do: bounded_interval(DecimalInterval, f, pf)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(DecimalInterval, f)),
        if(Keyword.get(opts, :empty), do: empty_interval(DecimalInterval))
      ]
      |> Enum.reject(&is_nil/1)
    )
  end
end
