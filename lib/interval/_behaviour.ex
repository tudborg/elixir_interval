defmodule Interval.Behaviour do
  @moduledoc """

  """

  @type t() :: any()

  @doc """
  Is the interval empty?

  An empty interval is an interval that represents zero points.
  Any interval containing zero points is considered empty.
  """
  @callback empty?(a :: t()) :: boolean()

  @doc """
  Is the interval left-unbounded?
  Meaning, is all points left of the right bound included in this interval?

  ## Examples

      a: ---)
      r: true

      a: [---)
      r: false

      a: [---
      r: false
  """
  @callback left_unbounded?(a :: t()) :: boolean()

  @doc """
  Is the interval right-unbounded?
  Meaning, is all points right of the left bound included in this interval?

  ## Examples

      a: [---
      r: true

      a: [---)
      r: false

      a: ---)
      r: false

  """
  @callback right_unbounded?(a :: t()) :: boolean()

  @doc """
  Is the interval left-inclusive?
  Meaning is the left endpoint included in the range?

  NOTE: Discrete intervals (like integers and dates) are always normalized
  to be left-inclusive right-exclusive (`[)`) which this function reflects.

  ## Examples

      a: [---)
      r: true

      a: (---]
      r: false
  """
  @callback left_inclusive?(a :: t()) :: boolean()

  @doc """
  Is the interval right-inclusive?
  Meaning is the right endpoint included in the range?

  NOTE: Discrete intervals (like integers and dates) are always normalized
  to be left-inclusive right-exclusive (`[)`) which this function reflects.

  ## Examples

      a: (---]
      r: true

      a: [---)
      r: false

  """
  @callback right_inclusive?(a :: t()) :: boolean()

  @doc """
  Is the interval `a` strictly left of the interval `b`?

  Meaning is all points in `a` to the left of `b`.

  ## Examples

      a: [---)
      b:     [---)
      r: true

      a: [---)
      b:        [---)
      r: true

      a: [---)
      b:    [---)
      r: false (overlaps)

  """
  @callback strictly_left_of?(a :: t(), b :: t()) :: boolean()

  @doc """
  Is the interval `a` strictly right of the interval `b`?

  Meaning is all points in `a` to the right of `b`.

  ## Examples

      a:     [---)
      b: [---)
      r: true

      a:        [---)
      b: [---)
      r: true

      a:    [---)
      b: [---)
      r: false (overlaps)

  """
  @callback strictly_right_of?(a :: t(), b :: t()) :: boolean()

  @doc """
  Is the interval `a` adjacent to `b`, to the left of `b`.

  `a` is adjacent to `b` left of `b`, if `a` and `b` do _not_ overlap,
  and there are no points between `a.right` and `b.left`.

  ## Examples

      a: [---)
      b:     [---)
      r: true

      a: [---]
      b:     [---]
      r: false (overlaps)

      a: (---)
      b:        (---)
      r: false (points exist between a.right and b.left)

  """
  @callback adjacent_left_of?(a :: t(), b :: t()) :: boolean()

  @doc """
  Is the interval `a` adjacent to `b`, to the right of `b`.

  `a` is adjacent to `b` right of `b`, if `a` and `b` do _not_ overlap,
  and there are no points between `a.left` and `b.right`.

  ## Examples

      a:     [---)
      b: [---)
      r: true

      a:     [---)
      b: [---]
      r: false (overlaps)

      a:        (---)
      b: (---)
      r: false (points exist between a.left and b.right)


  """
  @callback adjacent_right_of?(a :: t(), b :: t()) :: boolean()

  @doc """
  Does `a` contain `b`?

  `a` contains `b` of all points in `b` is also in `a`.


  ## Examples

      a: [-------]
      b:   [---]
      r: true

      a: [---]
      b: [---]
      r: true

      a: [---]
      b: (---)
      r: true

      a: (---)
      b: [---]
      r: false

      a:   [---]
      b: [-------]
      r: false
  """
  @callback contains?(a :: t(), b :: t()) :: boolean()

  @doc """
  Does `a` overlap with `b`?

  `a` overlaps with `b` if any point in `a` is also in `b`.

  ## Examples

      a: [---)
      b:   [---)
      r: true

      a: [---)
      b:     [---)
      r: false

      a: [---]
      b:     [---]
      r: true

      a: (---)
      b:     (---)
      r: false

      a: [---)
      b:        [---)
      r: false
  """
  @callback overlaps?(a :: t(), b :: t()) :: boolean()

  @doc """
  Compute the intersection between `a` and `b`.

  The intersection contains all of the points that are both in `a` and `b`.

  If either `a` or `b` are empty, the returned interval will be empty.

  ## Examples

      a: [----]
      b:    [----]
      r:    [-]

      a: (----)
      b:    (----)
      r:    (-)

      a: [----)
      b:    [----)
      r:    [-)

  """
  @callback intersection(a :: t(), b :: t()) :: t()

  @doc """
  Computes the union of `a` and `b`.

  The union contains all of the points that are either in `a` or `b`.

  If either `a` or `b` are empty, the returned interval will be empty.

  ## Examples

      a: [---)
      b:   [---)
      r: [-----)

  """
  @callback union(a :: t(), b :: t()) :: t()
end
