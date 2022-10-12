# Changelog

## HEAD (v0.1.4)

- Adding `Interval.contains_point?/2`
- Adding `Interval.partition/2`

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