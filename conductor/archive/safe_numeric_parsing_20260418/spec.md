# Track Specification: Safe Numeric Parsing

## Overview
This track addresses the elimination of strict type casting (`as int`, `as num`) on dynamic JSON and Firestore data. This is a critical refactoring task to prevent fatal crashes resulting from unexpected type mismatches (e.g., a `double` arriving when an `int` is expected).

## Functional Requirements
- **Centralized Parsing Utility:** Create a `NumberParser` utility class (`lib/core/utils/number_parser.dart`) with `toDouble` and `toInt` static methods.
- **Strict Defaults:** The parser will use `0.0` and `0` as the default fallback values for any parsing failures.
- **Model & Repository Refactoring:** Replace all unsafe numeric casting in `fromMap` factory constructors and repository logic with `NumberParser`.
  - Affected files: `daily_stats_model.dart`, `stats_summary_model.dart`, `sim_wallet_config.dart`, `device_repository.dart`, `subscription_repository.dart`, `debt_repository.dart`.
- **Provider Refactoring:** Refactor providers performing optimistic updates to use `NumberParser` instead of unsafe `.toDouble()` casts on dynamic map values.
  - Affected files: `wallet_provider.dart`, `statistics_provider.dart`, `overlay_provider.dart`, `global_overlay_listener.dart`.
- **Unit Testing:** Implement unit tests for the `NumberParser` utility before refactoring other layers.

## Non-Functional Requirements
- Ensure robust parsing of strings containing commas (e.g. `"1,000"` -> `1000.0`).
- Ensure no occurrences of `as int` or `as num` remain in the specified files.
- The project must compile successfully (`flutter analyze` returns 0 issues).

## Acceptance Criteria
- `NumberParser` utility is implemented and fully unit tested.
- Global search for `as num` returns 0 results in the target files.
- Global search for `.toDouble()` directly on dynamic maps is eliminated.
- All tests and `flutter analyze` pass with 0 issues.