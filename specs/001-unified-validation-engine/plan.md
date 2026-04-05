# Implementation Plan: Unified Validation Engine

**Branch**: `001-unified-validation-engine` | **Date**: 2026-03-21 | **Spec**: [Link to Spec](spec.md)
**Input**: Feature specification from `specs/001-unified-validation-engine/spec.md`

## Summary
The Unified Validation Engine feature centralizes all financial validation logic through a single gatekeeper, enforces strict atomic database operations to prevent negative balances, automatically calculates and pre-fills fee data based on wallet type and amount, and ensures the entire application stays reactive to data changes across all screens.

## Technical Context
**Language/Version**: Dart (latest) / Flutter
**Primary Dependencies**: cloud_firestore, provider, rxdart, bot_toast, awesome_dialog
**Storage**: Firebase Firestore (NoSQL)
**Testing**: flutter_test
**Target Platform**: Android, iOS
**Project Type**: Mobile Application
**Constraints**: Firestore runTransaction logic MUST complete successfully before UI acknowledges success.

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
*Reference: `.specify/memory/constitution.md` v1.0.0*

- **P1 Zero-Latency**: Optimistic local mutation before Firestore write. - ✅ PASS
- **P2 Anti-Jank**: `Selector`/`Consumer` only, no root `context.watch`. - ⚠ REVIEW (existing code may use `StreamBuilder`)
- **P3 Zero-Waste**: No `StreamBuilder` for Provider-managed data. - ⚠ REVIEW (plan originally used `snapshots()` streams)
- **P4 Safe Rollback**: `try-catch` + revert on every optimistic write. - ✅ PASS
- **P5 O(1) Lookup**: `Map<String, Model>` in Providers. - ✅ PASS
- **P6 Fetch Shield**: Block auto-fetch after isolate state injection. - ✅ PASS
- **P7 ValueKey**: Composite `ValueKey` on mutable list items. - ✅ PASS

## Project Structure

### Documentation (this feature)
```text
specs/001-unified-validation-engine/
├── plan.md              
├── research.md          
├── data-model.md        
├── quickstart.md        
└── spec.md              
```

### Source Code Changes
```text
lib/
├── data/
│   └── services/
│       └── transaction_validator_service.dart   (NEW file)
├── presentation/
│   ├── providers/
│   │   ├── wallet_provider.dart                 (Update to streams)
│   │   └── overlay_provider.dart                (Refactor state clear & fee auto-calc)
│   └── widgets/
│       ├── debt/
│       └── ...
```

**Structure Decision**: Centralized business logic inside `lib/data/services/transaction_validator_service.dart`. Reactive UI handled inside `wallet_provider.dart` via `snapshots()`.

## Complexity Tracking
| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
