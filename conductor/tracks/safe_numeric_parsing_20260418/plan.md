# Implementation Plan: Safe Numeric Parsing

## Phase 1: Create the Centralized NumberParser Utility
- [ ] Task: Setup Test Environment for NumberParser
    - [ ] Create `test/core/utils/number_parser_test.dart`
    - [ ] Write failing unit tests for `NumberParser.toDouble` and `NumberParser.toInt` covering various inputs (null, int, double, String with commas, invalid strings).
- [ ] Task: Implement NumberParser Utility
    - [ ] Create `lib/core/utils/number_parser.dart`
    - [ ] Implement `NumberParser` class to make the tests pass.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Create the Centralized NumberParser Utility' (Protocol in workflow.md)

## Phase 2: Refactor Data Models and Repositories
- [ ] Task: Refactor Models & Repositories to use NumberParser
    - [ ] Update `lib/data/models/daily_stats_model.dart`
    - [ ] Update `lib/data/models/stats_summary_model.dart`
    - [ ] Update `lib/data/models/sim_wallet_config.dart`
    - [ ] Update `lib/data/repositories/device_repository.dart`
    - [ ] Update `lib/data/repositories/subscription_repository.dart`
    - [ ] Update `lib/data/repositories/debt_repository.dart`
- [ ] Task: Verification
    - [ ] Run existing tests to ensure no regressions.
    - [ ] Global search for `as int` and `as num` to ensure 0 occurrences in these files.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Refactor Data Models and Repositories' (Protocol in workflow.md)

## Phase 3: Refactor Providers (Optimistic Updates)
- [ ] Task: Refactor Providers to use NumberParser
    - [ ] Update `lib/providers/wallet_provider.dart`
    - [ ] Update `lib/providers/statistics_provider.dart`
    - [ ] Update `lib/presentation/overlays/overlay_provider.dart`
    - [ ] Update `lib/core/widgets/global_overlay_listener.dart`
- [ ] Task: Final Verification
    - [ ] Global search for `.toDouble()` directly on dynamic maps to ensure 0 occurrences.
    - [ ] Run `flutter analyze` to ensure 0 issues.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Refactor Providers (Optimistic Updates)' (Protocol in workflow.md)