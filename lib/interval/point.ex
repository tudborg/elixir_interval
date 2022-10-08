defprotocol Interval.Point do
  @moduledoc """
  The `Interval.Point` protocol defines a set of functions the `Interval`
  module needs to use a value as a point in an interval.

  Implementing this protocol for a type allows you to use that type
  as a point in the Interval type.

  ## Point Types

  `Interval` accepts two kinds of point types:

  - Discrete
  - Continuous

  ### Discrete

  A discrete point type is one where the number of points in a bounded
  interval is finite and knowable.

  Every discrete point has a concept of the `next/1` and `previous/1` point
  (in contrast to something like a real number where there exists an infinite
  number of points between two other points)

  ### Continuous

  The continuous point type is for points where there exists (at least conceptually) an
  infinite number of points between two other points.  
  Examples of this are floats, points in time, etc.
  
  These points have no useful notion of the "next" and "previous" point,
  and implements these functions as raising an error.

  ## Default Implementations

  This library ships with implementations for

  - `Date` (discrete)
  - `Integer` (discrete)
  - `DateTime` (continuous)
  - `Float` (continuous)

  If you wish to implement the `Interval.Point` protocol for one of
  these types yourself, you can disable the built-in implementation by
  setting the module to false under the `:interval` OTP application:

  ```
  import Config

  config :interval, Date, false
  ```
  """

  @doc """
  Compare two interval points (of the same time) and returns if
  a is

  - less than
  - equal
  - greater than

  b
  """
  @spec compare(t(), t()) :: :lt | :eq | :gt
  def compare(a, b)

  @doc """
  Returns if the Point lies on a discrete (like integer)
  or a continuous line (like floats).

  If the value given is not a valid Point, then this function
  must return `:invalid`
  """
  @spec type(t()) :: :discrete | :continuous | :invalid
  def type(a)

  @doc """
  Given a point A, return the next value after A.
  If the point type is continuous then this error must raise an error
  """
  @spec next(t()) :: t()
  def next(a)

  @doc """
  Given a point A, return the previous value after A.
  If the point type is continuous then this error must raise an error
  """
  @spec previous(t()) :: t()
  def previous(a)

  @doc """
  Return the smallest (left-most) of the two points.
  """
  @spec min(t(), t()) :: t()
  def min(a, b)

  @doc """
  Return the largest (right-most) of the two points.
  """
  @spec max(t(), t()) :: t()
  def max(a, b)
end
