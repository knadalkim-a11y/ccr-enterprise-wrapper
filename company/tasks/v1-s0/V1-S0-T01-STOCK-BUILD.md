---
id: V1-S0-T01
stage: V1-S0
title: Stock CCR internal Windows build
kind: spike
status: planned
session_role: validation
internal_validation: required
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

# Stock CCR Internal Windows Build

## Validation question

> Pinned CCR `v3.0.22`가 실제 target인 사내 Windows에서 Company 제품 코드 변경 없이 install, typecheck, build되는가?

## Why now

사내 Provider, setup, doctor를 만들기 전에 Stock CCR 자체가 실제 target Windows에서 재현 가능한지 확인한다.
Android/Termux는 개발 제어환경으로 유지하고, native addon과 Windows 동작의 증거는 사내 Windows에서 직접 수집한다.

## Required knowledge

- root `package.json`
- upstream build/install 문서
- `company/docs/UPSTREAM_SYNC.md`
- `company/docs/ENVIRONMENTS.md`

## In scope

- 정확한 candidate commit을 사내 Windows에 pull
- Node/npm과 Windows preflight 기록
- clean dependency install
- upstream typecheck/build 명령 실행
- 제품 코드와 lockfile 무변경 확인
- 민감정보를 제거한 결과를 Task와 STATUS에 기록

## Out of scope

- 사내에서 source/dependency/script 수정
- native Android/Termux 지원 patch
- Provider/model 설정
- Wrapper/Static/Telemetry/V2 구현
- CCR Core 수정
- Desktop installer 패키징과 사내 모델 E2E

## Acceptance criteria

- [x] upstream 공식 install/build 명령 확인
- [x] native Termux Attempt 1 결과 기록
- [ ] 사내 Windows에서 clean `npm ci` 결과 기록
- [ ] 사내 Windows에서 `npm run typecheck` 결과 기록
- [ ] 사내 Windows에서 Desktop packaging 제외 `npm run build:assets` 결과 기록
- [x] Attempt 1 이후 제품 코드 변경 없음
- [x] Attempt 1 실패 원인과 다음 Recommendation 기록
- [ ] Windows 검증 후 제품 코드와 lockfile 무변경 확인

## Windows preflight and commands

사내 Windows PowerShell에서 실행한다.

```powershell
git switch main
git fetch --prune origin
git pull --ff-only origin main

$TestedCommit = git rev-parse HEAD

git branch --show-current
git status --short
node --version
npm --version
node -p "process.platform"
node -p "process.arch"
```

진행 조건:

```text
process.platform = win32
Node major = 22
working tree = clean
TestedCommit = 기록됨
```

조건이 맞으면 다음을 변경 없이 실행한다.

```powershell
npm ci
npm run typecheck
npm run build:assets
```

검증 후:

```powershell
git diff --exit-code -- packages package.json package-lock.json
git status --short
```

명령별 exit code, 실행환경, 핵심 결과만 기록한다.
사내 주소, 인증정보, 실제 모델명, raw log는 외부 repository에 기록하지 않는다.

## Internal validation contract

- Required: Yes
- Expected state before test: `READY_FOR_INTERNAL_VALIDATION`
- Result values: `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED_INTERNAL`
- 사내에서는 코드를 수정하지 않는다.
- 실패 시 exact commit, 오류 분류, 재현률, sanitized observation만 외부 repair session으로 반환한다.

## Failure classification

- `NETWORK_OR_REGISTRY`
- `NATIVE_DEPENDENCY`
- `LOCKFILE`
- `TYPECHECK`
- `BUILD`
- `WINDOWS_ENVIRONMENT`
- `UNKNOWN`

## Stop conditions

- pinned source/ref 불일치
- 사내 Windows에서도 제품 코드 수정 없이는 dependency install/build 불가
- 사내 정책으로 build 검증을 수행할 수 없고 대체 증거 경로도 승인되지 않음

## Rollback

- 사내 working copy를 폐기하거나 exact candidate commit으로 reset한다.
- 외부 repository에는 Evidence 문서 변경만 남긴다.

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|
| 1 | implementation | `5fc304ad20b7eba2d6649faa2a6377f783a5e4c8` baseline | `BLOCKED_ENVIRONMENT` — native Android/arm64 Termux native dependency environment | `NOT_REQUIRED` | `RETRY` — validate unchanged on internal Windows with Node 22 |

## Evidence / limitations

- Baseline CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Repository baseline after BOOT: `b05567891e15a157d8e54fac627618f8214128a7`
- Attempt 1 evidence merged in PR #8 on `2026-08-26`.
- GitHub Actions remain disabled while upstream workflows are unreviewed; this Task uses local Windows commands only.
- Pinned source verification: `PASS` — `v3.0.22^{commit}` is the pinned commit, the pin is an ancestor of the tested baseline, root package version is `3.0.22`, and no upstream-controlled product path differs from the pin.
- Upstream requirements: root `package.json` requires Node `>=22`; source checkout uses npm and `npm ci`.
- Attempt 1 environment: Node `v26.4.0`, npm `11.19.0`, `android`/`arm64`, native Termux.
- Attempt 1 clean install: `BLOCKED_ENVIRONMENT` — `better-sqlite3` had no Android/arm64 prebuilt binary and native fallback required Android-specific build configuration.
- Attempt 1 stop condition evaluation: `NOT_MET` — native Termux is not the target Windows validation environment.
- Attempt 1 product code diff: `PASS` — `packages/**`, `package.json`, and `package-lock.json` remained unchanged.
- Limitation: the Validation question remains unanswered until the same stock commands run on internal Windows.

## Codex recommendation

`READY_FOR_INTERNAL_VALIDATION` — pull the current approved `main` commit on internal Windows, use Node 22, and run the documented commands unchanged. Do not modify CCR source, dependencies, or scripts in the internal environment.

## Human decision

`PENDING`
