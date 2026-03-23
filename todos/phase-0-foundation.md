# Phase 0 - Foundation (Shippable Internal Alpha)

## Objective

Create a stable, testable app foundation before feature work.

## Deliverables

- [ ] Flutter app initialized with flavor-ready structure (`dev`, `prod`).
- [ ] 3-tab navigation scaffold (`Play`, `Progress`, `Profile`).
- [ ] App theme system (light/dark + saffron accent palette).
- [ ] Local DB initialized (SQLite).
- [ ] Data models created:
  - [ ] `PlaySession`
  - [ ] `DailyStat`
  - [ ] `UserSettings`
  - [ ] `Recording`
- [ ] Repository interfaces + implementations.
- [ ] Analytics event interface with no-op fallback.
- [ ] CI checks:
  - [ ] `flutter analyze`
  - [ ] unit tests
  - [ ] Android debug build

## Folder Structure

- [ ] `lib/core/` (theme, constants, utils)
- [ ] `lib/features/play/`
- [ ] `lib/features/progress/`
- [ ] `lib/features/profile/`
- [ ] `lib/data/local/`
- [ ] `lib/data/models/`
- [ ] `lib/data/repositories/`

## Non-Breaking Gates (Must Pass)

- [ ] App starts in <2.5 sec on mid-range device.
- [ ] No red-screen crashes during 10-minute nav test.
- [ ] DB migrations versioned and reversible.
- [ ] All existing tests pass.

## Suggested Commands

- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter run -d <device>`

## Release Checklist (Phase Ship)

- [ ] Internal APK/IPA build works.
- [ ] Smoke test script executed.
- [ ] Changelog written for Phase 0 baseline.
- [ ] Commit created only after successful build + run.
- [ ] Suggested commit:
  - [ ] `feat(phase-0): complete foundation shippable baseline`
