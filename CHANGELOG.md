# Changelog

## HEAD (v0.2.0)

- Various `RuntimeError`s handling bad input to a function has been converted to `ArgumentError`s
- Simplified various things
  - `Point.previous(a)` and `Point.next(a)` became `point_step/2` in the `Interval.Behaviour`.
  - The idea of a "zero" point was removed because it doesn't make sense for all intervals.
  - Special-case for empty intervals, which doesn't require implementation-specific behaviour.
  - `Interval.new/1` now requires a `:module` option of the specific implementation to use,
    however the implementation has a `new/1` that infers this when creating new intervals.
- Ditching the `Interval.Point` protocol in favor of a behaviour for the entire interval.
- Adding `Interval.contains_point?/2`
- Adding `Interval.partition/2`
- Adding `Interval.size/1` and removing the `/2`

## v0.1.3

- Fixed a bug in `Interval.intersection/2` and `Interval.union/2` that causes incorrect bounds
  in some cases.
- The internal `Endpoint` struct has been replaced by a simple 2-tuple.
- Empty intervals are now represented by two identical exclusive points. 
- Added `Interval.size/2`.
- Added parameterized typespec `t:Interval.t/1`

## v0.1.2

- Fixed a correctness bug in intersection, where intersections between
  intervals containing unbounded endpoints would be incorrectly computed.