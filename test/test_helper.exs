ExUnit.start()

defmodule Helper do
  @moduledoc """
  Generators for property testing
  """

  import ExUnitProperties
  alias Interval
  alias Interval.Point

  def bounds() do
    StreamData.one_of(
      ["[]", "[)", "(]", "()"]
      |> Enum.map(&StreamData.constant/1)
    )
  end

  def bounded_interval(left_generator, offset_generator) do
    gen all(
          left <- left_generator,
          offset <- offset_generator,
          bounds <- bounds()
        ) do
      # to avoid producing empty intervals,
      # we check that the bounds and ensure that we cannot produce
      # an interval that would normalize to empty
      case Point.type(left) do
        :discrete ->
          offset =
            case bounds do
              # both inclusive, we are OK with offset being 0
              "[]" -> Point.previous(offset)
              # if either bound is inclusive,
              "(]" -> offset
              # the default of offset `[1,` is OK
              "[)" -> offset
              # both exclusive, so offset must be at least 2 to not produce empty
              "()" -> Point.next(offset)
            end

          Interval.new(left: left, right: left + offset, bounds: bounds)

        :continuous ->
          Interval.new(left: left, right: left + offset, bounds: bounds)
      end

      Interval.new(left: left, right: left + offset, bounds: bounds)
    end
  end

  def unbounded_interval(point_generator) do
    gen all(
          point <- point_generator,
          point_is_left <- StreamData.boolean(),
          bounds <- bounds()
        ) do
      opts =
        if point_is_left do
          [left: point, right: nil, bounds: bounds]
        else
          [left: nil, right: point, bounds: bounds]
        end

      Interval.new(opts)
    end
  end

  def empty_interval() do
    StreamData.constant(Interval.empty())
  end

  def integer_interval(opts \\ []) do
    opts = Keyword.merge([unbounded: true, bounded: true, empty: true], opts)
    i = StreamData.integer()
    pi = StreamData.positive_integer()

    StreamData.one_of(
      [
        if(Keyword.get(opts, :bounded), do: bounded_interval(i, pi)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(i)),
        if(Keyword.get(opts, :empty), do: empty_interval())
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
        if(Keyword.get(opts, :bounded), do: bounded_interval(f, pf)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(f)),
        if(Keyword.get(opts, :empty), do: empty_interval())
      ]
      |> Enum.reject(&is_nil/1)
    )
  end
end
