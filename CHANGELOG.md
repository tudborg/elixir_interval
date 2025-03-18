# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.1-dev

### Added

- `Interval.format/1` formats an interval as a string.
- `Interval.parse/2` parses a string into an interval.
- Interval module functions `format/1` and `parse/1` that delegates to the above.
- Interval callback `point_format/1` for customizing how a point is formattet.
- Interval callback `point_parse/1` to parse a string into a point.

## 2.0.0

No changes from `alpha.2`


## 2.0.0-alpha.2

### Added

- `partition/2` now also accepts an interval as it's second argument.

### Fixed

- `adjacent?/2` is now exposed on the interval module via `defdelegate` in the using macro.

## 2.0.0-alpha.1 - 2025-03-10

### Added

- `exclusive_left?/1` and `exclusive_right?/1`
- `adjacent?/2` (which just checks for adjacency in both directions)
- `new/1` now accepts option `empty: boolean()`
- `union/2` will raise `Interval.IntervalOperationError` when the intervals are disjoint.

### Fixed

- `contains?/2` bug - issue #29
- `contains?/2` bug - empty interval was never contained by anything which doesn't align with Postgres.


## [1.0.0] - 2025-03-04

### Added

- All interval implementations now defdelegate all Interval API functions, such that you can
  call e.g. `union/2` on your own Interval type: `MyInterval.union(a, b)`
- Introducing a `new/3` helper that takes arguments `new(left, right, bounds \\ "[)")`.

### Changed

- All builtins are now suffixed with "Interval" which makes aliasing easier, e.g. `alias Interval.DateInterval`
- Interval modules must now implement `point_normalize/1` instead of `point_valid?/1`, which
  allows the module to coerce values into canonical values (i.e. -0.0 to +0.0, for OTP 27)

### Deprecated

### Removed

- Removed the Inspect protocol. Inspect now outputs the struct as-is.
- `size/1` - Currently no good way of doing it generally. You can easily implement this yourself.
- `new/1` will no longer accept `:unbound` (this came from the Ecto.Type, but not it handles this conversion interally to not polute `Interval`)

### Fixed

## [v0.3.4] - 2023-03-01

### Added

- Added `Inspect` protocol implementation for all intervals created with `use Interval`
  (which includes all builtin types) so they now look like `#Interval.Float<[1.0, 3.0)>`
  instead of `%Interval.Float{left: {:inclusive, 1.0}, right: {:exclusive, 3.0}}`
- Support for intervals of `NaiveDateTime`.
- A Logo. For no good reason.

### Changed

### Deprecated

### Removed

### Fixed

- Fixed typespec on `size/1` for `Interval.DateTime`
- Fixed dialyzer warnings.
- Incorrect docs for `union/2` (#25)

## [v0.3.3] - 2022-11-22

### Added

### Changed

### Deprecated

### Removed

### Fixed

- The optional dependencies was also specified as test and dev only, which
  is not what we want. We want them optional, but all environments.

### Security

## [v0.3.2] - 2022-11-22

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Issue #19. Could not compile when the dependant project did not have Ecto included,
  which was a bug.

### Security

## [v0.3.1] - 2022-11-21

### Added

- Added type and typespecs for builtin types.
- Added additional documentation in `Interval`

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [v0.3.0] - 2022-11-21

### Added

- Mostly automatic support `Ecto.Type` (including for builtin interval types)
- `left/1` and `right/1` to extract the left and right values from the interval.
- Builtin `Jason.Encoder` support.
- `Interval.__using__` option `jason_encoder` for including encoder. Defaults to `true`.
- `Interval.to_map/1` to convert an Interval struct to a map suitible for JSON and similar serialization.
- `Interval.Decimal` for `Decimal` support.

### Changed

- `Interval.__using__` option `discrete` is now optional, and defaults to `false`

### Deprecated

### Removed

### Fixed

### Security

## [v0.2.0] - 2022-10-27

### Added

- Allow opting out of built in implementations by configuring `:interval, Interval.Float: false`
- Adding `Interval.Intervalable` protocol, which allows you to define what interval implementation
  to use for value types. This is purely for ergonomic reasons.
- Special-case for empty intervals, which doesn't require implementation-specific behaviour.
- Adding `Interval.contains_point?/2`
- Adding `Interval.partition/2`
- Adding `Interval.size/1`

### Changed

- Various `RuntimeError`s handling bad input to a function has been converted to `ArgumentError`s
- `Point.previous(a)` and `Point.next(a)` became `point_step/2` in the `Interval.Behaviour`.
- `Interval.new/1` now requires a `:module` option of the specific implementation to use,
  however the implementation has a `new/1` that infers this when creating new intervals.

### Removed

- The idea of a "zero" point was removed because it doesn't make sense for all intervals.
- Removed the `Interval.Point` protocol in favor of a behaviour for the entire interval.
- Removed `Interval.size/2`

## [v0.1.3] - 2022-10-12

### Added

- Added `Interval.size/2`.
- Added parameterized typespec `t:Interval.t/1`

### Changed

- The internal `Endpoint` struct has been replaced by a simple 2-tuple.
- Empty intervals are now represented by two identical exclusive points. 

### Fixed

- Fixed a bug in `Interval.intersection/2` and `Interval.union/2` that causes incorrect bounds
  in some cases.

## [v0.1.2] - 2022-10-10

### Fixed

- Fixed a correctness bug in intersection, where intersections between
  intervals containing unbounded endpoints would be incorrectly computed.