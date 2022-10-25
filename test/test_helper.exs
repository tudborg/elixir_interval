ExUnit.start()

defmodule Helper do
  @moduledoc """
  Generators for property testing
  """

  import ExUnitProperties
  alias Interval

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
      case module.discrete?() do
        true ->
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

          Interval.new(module: module, left: left, right: left + offset, bounds: bounds)

        false ->
          Interval.new(module: module, left: left, right: left + offset, bounds: bounds)
      end

      Interval.new(module: module, left: left, right: left + offset, bounds: bounds)
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

  def empty_interval(module) do
    StreamData.constant(module.new(left: :empty, right: :empty))
  end

  def integer_interval(opts \\ []) do
    opts = Keyword.merge([unbounded: true, bounded: true, empty: true], opts)
    i = StreamData.integer()
    pi = StreamData.positive_integer()

    StreamData.one_of(
      [
        if(Keyword.get(opts, :bounded), do: bounded_interval(Interval.Integer, i, pi)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(Interval.Integer, i)),
        if(Keyword.get(opts, :empty), do: empty_interval(Interval.Integer))
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
        if(Keyword.get(opts, :bounded), do: bounded_interval(Interval.Float, f, pf)),
        if(Keyword.get(opts, :unbounded), do: unbounded_interval(Interval.Float, f)),
        if(Keyword.get(opts, :empty), do: empty_interval(Interval.Float))
      ]
      |> Enum.reject(&is_nil/1)
    )
  end
end
