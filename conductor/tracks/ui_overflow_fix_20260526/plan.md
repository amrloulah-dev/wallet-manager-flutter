# Plan: Fix UI Overflow in StatItemWidget (BUG-05)

## Phase 1: Implement Fix

- [ ] Task: Write failing widget test for `StatItemWidget` overflow
    - [ ] Create test file `test/presentation/screens/statistics/stat_item_widget_test.dart`
    - [ ] Test case: Render `StatItemWidget` with a very long label in a constrained width — verify no overflow error
    - [ ] Test case: Render with subtitle — verify both label and subtitle display correctly
    - [ ] Run tests — confirm they fail (Red Phase)

- [ ] Task: Apply `Flexible` wrapper and `TextOverflow.ellipsis` fix
    - [ ] Wrap `Column` in `Flexible(fit: FlexFit.loose)`
    - [ ] Add `overflow: TextOverflow.ellipsis` and `maxLines: 1` to label `Text`
    - [ ] Add `overflow: TextOverflow.ellipsis` and `maxLines: 1` to subtitle `Text`
    - [ ] Add `const SizedBox(width: 12)` between `Flexible` column and value `Text`
    - [ ] Run tests — confirm they pass (Green Phase)

- [ ] Task: Conductor - User Manual Verification 'Phase 1: Implement Fix' (Protocol in workflow.md)
