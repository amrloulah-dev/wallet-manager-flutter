# Implementation Plan: Safe Numeric Parsing

## Phase 1: Create the Centralized NumberParser Utility [checkpoint: 62ee01d]
- [x] Task: Setup Test Environment for NumberParser
    - [x] Create `test/core/utils/number_parser_test.dart`
    - [x] Write failing unit tests for `NumberParser.toDouble` and `NumberParser.toInt` covering various inputs (null, int, double, String with commas, invalid strings). [062e061]
- [x] Task: Implement NumberParser Utility
    - [x] Create `lib/core/utils/number_parser.dart`
    - [x] Implement `NumberParser` class to make the tests pass. [7d87f43]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Create the Centralized NumberParser Utility' (Protocol in workflow.md) [62ee01d]

## Phase 2: Refactor Data Models and Repositories [checkpoint: 777a1e6]
- [x] Task: Refactor Models & Repositories to use NumberParser
    - [x] Update `lib/data/models/daily_stats_model.dart`
    - [x] Update `lib/data/models/stats_summary_model.dart`
    - [x] Update `lib/data/models/sim_wallet_config.dart`
    - [x] Update `lib/data/repositories/device_repository.dart`
    - [x] Update `lib/data/repositories/subscription_repository.dart`
    - [x] Update `lib/data/repositories/debt_repository.dart` (and `lib/providers/debt_provider.dart`) [ed23e1a]
- [x] Task: Verification
    - [x] Run existing tests to ensure no regressions.
    - [x] Global search for `as int` and `as num` to ensure 0 occurrences in these files. [ed23e1a]
- [x] Task: Conductor - User Manual Verification 'Phase 2: Refactor Data Models and Repositories' (Protocol in workflow.md) [777a1e6]

## Phase 3: Refactor Providers (Optimistic Updates) [checkpoint: 7ec8d89]
- [x] Task: Refactor Providers to use NumberParser
    - [x] Update `lib/providers/wallet_provider.dart`
    - [x] Update `lib/providers/statistics_provider.dart`
    - [x] Update `lib/presentation/overlays/overlay_provider.dart`
    - [x] Update `lib/core/widgets/global_overlay_listener.dart` [8e6fc44]
- [x] Task: Final Verification
    - [x] Global search for `.toDouble()` directly on dynamic maps to ensure 0 occurrences.
    - [x] Run `flutter analyze` to ensure 0 issues. [8e6fc44]
- [x] Task: Conductor - User Manual Verification 'Phase 3: Refactor Providers (Optimistic Updates)' (Protocol in workflow.md) [7ec8d89]