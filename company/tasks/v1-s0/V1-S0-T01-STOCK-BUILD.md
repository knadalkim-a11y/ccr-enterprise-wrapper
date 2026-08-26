---
id: V1-S0-T01
stage: V1-S0
title: Stock CCR external build
kind: spike
status: blocked
session_role: implementation
internal_validation: not-required
depends_on:
  - BOOT-T01
allowed_paths:
  - company/tasks/v1-s0/V1-S0-T01-STOCK-BUILD.md
  - company/docs/STATUS.md
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: pending
---

# Stock CCR External Build

## Validation question

> Pinned CCR `v3.0.22`가 외부 환경에서 Company 제품 코드 변경 없이 install, typecheck, build되는가?

## Why now

사내 Provider, setup, doctor를 만들기 전에 Stock CCR 자체와 개발 도구를 확인한다.
`BOOT-T01`과 BOOT Gate가 완료되어 이 Task가 활성화되었다.

## Required knowledge

- root `package.json`
- upstream build/install 문서
- `company/docs/UPSTREAM_SYNC.md`

## In scope

- 실제 package manager와 Node 요구 버전 확인
- clean dependency install
- upstream typecheck/build 명령 확인 및 실행
- 환경과 결과를 이 Task 및 STATUS에 기록

## Out of scope

- 사내 endpoint/model
- CCR 설정 변경
- Wrapper/Static/Telemetry/V2 구현
- Dependency 변경
- CCR Core 수정

## Acceptance criteria

- [ ] upstream 공식 install/build 명령 확인
- [ ] clean install 결과 기록
- [ ] typecheck 또는 동등 검사 결과 기록
- [ ] Desktop packaging 제외 build asset 결과 기록
- [ ] 제품 코드 변경 없음
- [ ] 실패 시 원인과 다음 Recommendation 기록

## Initial command candidates

Codex가 pinned upstream 문서와 package scripts를 확인한 뒤 확정한다.

```bash
node --version
npm --version
npm ci
npm run typecheck
npm run build:assets
```

## Internal validation contract

- Required: No
- Internal result: `NOT_REQUIRED`

## Stop conditions

- 지원 외부 환경에서 native dependency 해결 불가
- pinned source/ref 불일치
- 제품 코드 수정 없이는 build 불가능

## Rollback

- 문서 Evidence 변경만 revert한다.

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|
| 1 | implementation | `5fc304ad20b7eba2d6649faa2a6377f783a5e4c8` baseline | `BLOCKED` — `npm ci` failed on Android/arm64 native dependency install | `NOT_REQUIRED` | `RETRY` — use a supported host with Node 22+; do not patch CCR source or dependencies |

## Evidence / limitations

- Baseline CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Repository baseline after BOOT: `b05567891e15a157d8e54fac627618f8214128a7`
- Activated after BOOT Gate `ACCEPTED` on `2026-08-26`.
- GitHub Actions remain disabled while upstream workflows are unreviewed; this Task uses local commands only.
- Pinned source verification: `PASS` — `v3.0.22^{commit}` is `829298cf8bdcc6ddb9120a5a7c790c30227a1937`, the pin is an ancestor of the tested baseline, root package version is `3.0.22`, and no upstream-controlled product path differs from the pin.
- Upstream requirements: root `package.json` requires Node `>=22`; pinned README and install documentation use npm and prescribe `npm ci` for a source checkout. No exact npm version is pinned.
- Attempt 1 environment: Node `v26.4.0`, npm `11.19.0`, `android`/`arm64`, Linux kernel `6.6.102-android15` under Termux.
- Clean install: `BLOCKED` — `npm ci` exited `1`. `better-sqlite3@12.11.1` had no prebuilt binary for Node `26.4.0` on `android`/`arm64`; its fallback `node-gyp` configure failed because `android_ndk_path` was undefined.
- Classification: environment/native dependency compatibility. The failure does not establish a pinned source or lockfile defect.
- Stop condition triggered: native dependency resolution failed in the available external environment. `npm run typecheck` and `npm run build:assets` were not run because the install was incomplete; running them would not be valid evidence.
- Product code diff after the failed install: `PASS` — `packages/**`, `package.json`, and `package-lock.json` remained unchanged.
- Limitation: the Validation question remains unanswered until the same stock commands pass on a supported Node 22+ host environment.

## Codex recommendation

`RETRY` — rerun `npm ci`, `npm run typecheck`, and `npm run build:assets` unchanged on a supported Linux, macOS, or Windows host with Node 22+ (prefer Node 22 LTS for the retry). Do not modify CCR source, dependencies, or scripts to accommodate Termux/Android.

## Human decision

`PENDING`
