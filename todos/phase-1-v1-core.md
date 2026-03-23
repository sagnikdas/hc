# Phase 1 - V1 Core Devotional App (Shippable Public MVP)

## Objective

Ship full offline devotional experience without backend dependency.

## Feature Checklist

### Audio + Counter

- [ ] Add preloaded Hanuman Chalisa audio (voice-1).
- [ ] Implement play/pause/seek.
- [ ] Implement completion detection (`>=95%` playback).
- [ ] Increment counter only once per completed play session.
- [ ] Prevent duplicate increments on replay edge cases.

### Lyrics Sync

- [ ] Add timestamped lyrics JSON.
- [ ] Build optional bottom-sheet lyrics view.
- [ ] Highlight current line in sync with playback position.
- [ ] Keep hidden by default.

### Progress

- [ ] Daily plays counter.
- [ ] Current streak and best streak.
- [ ] Local heatmap (calendar).
- [ ] Weekly summary card.

### Background + Recording

- [ ] Background playback support.
- [ ] Notification/lockscreen media controls.
- [ ] Record user chanting locally.
- [ ] Loop recording N times (11/21/51 preset + custom).
- [ ] Count completed loops correctly.

### UI/UX

- [ ] Minimal main player UI with idol illustration.
- [ ] Smooth transitions + subtle animation only.
- [ ] Accessibility toggles: large text, lyric size.

## Test Plan

- [ ] Unit tests for counter and streak logic.
- [ ] Audio completion edge-case tests (pause/seek/resume).
- [ ] Device test: app minimized for 20 min playback.
- [ ] Airplane mode test: all core features still work.

## Non-Breaking Gates

- [ ] No playback interruption on app background.
- [ ] Counter mismatch rate <1% in test runs.
- [ ] UI responsive at 60fps on mid devices.

## Release Checklist (Phase Ship)

- [ ] Beta release to 20-50 users.
- [ ] Collect crash reports + playback telemetry.
- [ ] Fix top 5 usability issues before next phase.
- [ ] Commit created only after successful build + run.
- [ ] Suggested commit:
  - [ ] `feat(phase-1): ship v1 core devotional experience`
