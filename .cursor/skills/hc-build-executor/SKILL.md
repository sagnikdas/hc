---
name: hc-build-executor
description: Executes phased implementation for the Hanuman Chalisa app with strict shippable checkpoints and non-breaking gates. Use when implementing roadmap tasks, creating MVP slices, or validating release readiness phase by phase.
---
# HC Build Executor

## Purpose

Implement one phase/task at a time without breaking existing behavior.

## Workflow

1. Read `IMPLEMENTATION_PLAN.md`.
2. Pick exactly one open task from `todos/phase-*.md`.
3. Implement only that task and related tests.
4. Run verification for touched modules.
5. Update checklist item statuses.
6. Stop and report before moving to next task.

## Constraints

- Do not mix multiple phases in one coding pass.
- Do not modify unrelated files.
- Keep offline flow functional.
- Ensure new behavior has tests where practical.

## Output Format

- Task implemented
- Files changed
- Commands run
- Result and remaining risks
- Next 1-3 recommended tasks
