---
id: V1-S1-T02
stage: V1-S1
title: Add a non-persisting onboarding management entry
kind: implementation
status: planned
primary_actor: EXTERNAL_CODEX
execution_mode: agent_only
implementation_required: true
internal_validation: required
github_write_allowed: true
candidate_sha: supplied_by_external_codex
instruction_sha: same_as_candidate
merge_policy: internal_pass_required
depends_on:
  - V1-S0-T02
required_capabilities: []
allowed_git_actions:
  - fetch
  - checkout_branch
  - status
  - diff
  - test
  - commit
  - push
  - create_pull_request
allowed_paths:
  - packages/ui/src/pages/home/App.tsx
  - packages/ui/src/pages/home/components/onboarding.tsx
  - packages/ui/src/pages/home/shared/i18n.tsx
  - packages/ui/test/component/onboarding.test.tsx
  - company/tasks/v1-s1/V1-S1-T02-ONBOARDING-SAFE-MANAGEMENT-ENTRY.md
forbidden_paths:
  - packages/core/**
  - packages/cli/**
  - packages/electron/**
  - package.json
  - package-lock.json
human_decision: pending
---

# Add a Non-persisting Onboarding Management Entry

## Status boundary

This Task is a design artifact only and is not active.
Human Gate Owner approval is required before implementation, branch creation or test execution.

## Validation question

> Unfinished onboarding에서 기존 설정 관리 화면으로 들어가는 secondary action을 추가하되, 그 action 자체가 config save, profile apply, onboarding completion, Provider/Gateway operation 또는 model request를 일으키지 않는가?

## Why now

V1-S1-T00 Attempt 1은 management start isolation을 통과했지만 H1 cleanup/save에 도달하지 못해 `BLOCKED`됐다.
Stock UI는 unfinished onboarding에서 main Profile/Settings view를 숨기고, onboarding의 profile submit은 `Connect agent` 의미의 save/apply를 수행한다.
Instruction-only retry로는 같은 blocker가 재현된다.

## Confirmed prerequisites

- T00 A0/H0/A1/A2, A3 cleanup and H2: PASS
- Management start isolation: `TESTED_PASS`
- Config-save isolation: `NOT_TESTED`
- Enterprise invariant breach: `NOT_OBSERVED`
- Candidate source has existing Profile and Settings management views.
- Runtime sandbox passed; Core sync-disable repair is not justified by current Evidence.

## Required knowledge

- `company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md`
- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/docs/AGENT_WORKFLOW.md`
- `packages/ui/src/pages/home/App.tsx`
- `packages/ui/src/pages/home/components/onboarding.tsx`
- `packages/ui/src/pages/home/components/profiles.tsx`
- `packages/ui/src/pages/home/components/settings.tsx`
- `packages/core/src/web/management-server.ts` read-only, especially `saveConfig`

## In scope

- A secondary onboarding action for an existing saved agent profile.
- Ephemeral renderer navigation to the existing Profile management view.
- Clear copy that this manages existing configuration without completing onboarding.
- Targeted component tests and existing type/build/test verification.
- T00 Attempt 2 handoff on the exact repair PR head.

## Out of scope

- Completing or skipping onboarding persistently.
- Creating, editing, enabling or applying a profile as part of the new action.
- Provider/key/model/protocol changes or connectivity checks.
- Gateway lifecycle changes.
- `saveConfig`, Core profile service or Claude App sync changes.
- A special `applyProfile:false` cleanup path.
- Dependency or lockfile changes.
- T01 or any real model request.

## Implementation contract

1. When onboarding is unfinished and at least one saved agent profile exists, render a secondary `Manage existing configuration` action.
2. Clicking it only changes the renderer's active view to the existing Profile management view.
3. The click must not call `saveConfig`, `onSubmitProfile`, `onSubmitProvider`, `onCheckProvider`, `setOnboardingFinished`, Gateway controls, profile launch/apply controls or model APIs.
4. The onboarding-finished marker remains unchanged; reload returns to onboarding.
5. Zero saved profiles preserve the current onboarding UI without the secondary action.
6. Existing onboarding Next/Back/provider/profile behavior remains unchanged.
7. Do not extend onboarding's `deferProfileApplyOnSave` behavior into the management view. T00 must validate the existing stock save/apply path rather than a narrowed bypass.
8. No code outside the allowed product/test paths changes.

## Safety note for T00 Attempt 2

The navigation action itself performs no save.
Before any later H1 edit or save, Human Gate must verify all enabled Providers have `autoFetchModels = OFF`.
Candidate `saveConfig` calls `syncProviderModelAutoRefresh`, which schedules an immediate refresh when this flag is on and may later apply profiles.
If the value is not OFF or cannot be verified without editing, T00 stops before save.

## External validation

Run and record:

```text
npm run typecheck
npm run test:ui
npm run build:assets
git diff --check
git diff -- packages/ui/src/pages/home/App.tsx packages/ui/src/pages/home/components/onboarding.tsx packages/ui/src/pages/home/shared/i18n.tsx packages/ui/test/component/onboarding.test.tsx
git status --short
```

No credential, internal endpoint or Windows host is required for external tests.

## Acceptance criteria

- [ ] unfinished onboarding + saved profile shows the secondary action
- [ ] zero saved profiles do not show the secondary action
- [ ] click invokes only the navigation callback
- [ ] existing Profile management view becomes reachable
- [ ] onboarding marker is not changed and reload returns to onboarding
- [ ] no save/apply/start/probe/model side effect from the action
- [ ] ordinary onboarding behavior remains unchanged
- [ ] translation copy is present
- [ ] targeted UI tests pass
- [ ] root typecheck passes
- [ ] UI test suite passes
- [ ] asset build passes
- [ ] dependency and lockfile unchanged
- [ ] product diff is limited to allowed paths
- [ ] exact candidate and instruction SHA are handed off
- [ ] T00 Attempt 2 is the only internal runtime validation
- [ ] T01 remains blocked

## Stop conditions

- Any Core, gateway, profile-service, dependency or lockfile change appears necessary.
- The action must persist onboarding state or config to work.
- The action triggers Provider/Gateway/model behavior.
- Tests cannot prove the callback-only behavior.
- Product diff exceeds allowed paths.
- Human Gate has not activated this Task.

## Internal validation and merge

`merge_policy: internal_pass_required`.

After external PASS, Human Gate supplies the exact PR head as candidate/instruction SHA.
Internal validation is T00 Attempt 2 on that exact head; no duplicate real-model validation is added.
The repair PR must not merge before T00 PASS and Human decision.

## Sanitized evidence template

```text
Role: EXTERNAL_CODEX
Task ID: V1-S1-T02
Session role: onboarding safe-management entry
Candidate SHA:
Instruction SHA:
Changed paths:
Typecheck:
UI tests:
Asset build:
Action callback-only proof:
Forbidden path diff: 0
Secrets/raw internal evidence exported: NO
GitHub PR:
Next Task started: NO
```

## Attempts

| Attempt | Actor / session role | Candidate | Instruction | External | Internal | Recommendation |
|---:|---|---|---|---|---|---|

## Evidence / limitations

T00 Attempt 1 is the only internal runtime Evidence.
This planned Task contains no product implementation and authorizes no execution.

## Agent recommendation

`NOT_STARTED — AWAIT_HUMAN_GATE_ACTIVATION`

## Human decision

`PENDING`
