---
id: V1-S0-T01
stage: V1-S0
title: Stock CCR external build
kind: spike
status: planned
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

> Pinned CCR `v3.0.22`가 외부 Linux-compatible build runner에서 Company 제품 코드 변경 없이 install, typecheck, build되는가?

## Why now

사내 Provider, setup, doctor를 만들기 전에 Stock CCR 자체와 개발 도구를 확인한다.
`BOOT-T01`과 BOOT Gate가 완료되어 이 Task가 활성화되었다.
외부 build 증거와 사내 Windows target 실행 증거는 분리한다.

## Required knowledge

- root `package.json`
- upstream build/install 문서
- `company/docs/UPSTREAM_SYNC.md`
- `company/docs/ENVIRONMENTS.md`

## In scope

- 실제 package manager와 Node 요구 버전 확인
- 실행환경 preflight
- clean dependency install
- upstream typecheck/build 명령 확인 및 실행
- 우선 Android 장치의 Termux + PRoot Ubuntu에서 Attempt 2 수행
- 환경과 결과를 이 Task 및 STATUS에 기록

## Out of scope

- native Android/Termux 지원을 위한 patch
- Electron GUI/installer 또는 Windows 동작 증명
- 사내 endpoint/model
- CCR 설정 변경
- Wrapper/Static/Telemetry/V2 구현
- Dependency 변경
- CCR Core 수정

## Acceptance criteria

- [x] upstream 공식 install/build 명령 확인
- [x] clean install 결과 기록
- [ ] Linux-compatible runner에서 typecheck 또는 동등 검사 결과 기록
- [ ] Linux-compatible runner에서 Desktop packaging 제외 build asset 결과 기록
- [x] 제품 코드 변경 없음
- [x] 실패 시 원인과 다음 Recommendation 기록

## Environment ladder

1. **Preferred Attempt 2:** 같은 Android 장치의 Termux + PRoot Ubuntu 24.04 + Node 22.
2. PRoot 제약으로 실패 원인을 구분할 수 없는 경우에만 표준 Windows/Linux/macOS PC 또는 CI를 고려한다.
3. Windows Desktop/installer와 사내 실행은 후속 V1-S0 Task에서 사내 Windows로 검증한다.

PRoot 성공은 외부 install/typecheck/build 증거로 사용할 수 있지만 Windows runtime 증거는 아니다.

## Preflight and command sequence

PRoot Ubuntu 내부에서 실행한다.

```bash
git branch --show-current
git rev-parse HEAD
git status --short
uname -a
node --version
npm --version
node -p "process.platform"
node -p "process.arch"
```

진행 조건:

```text
process.platform = linux
Node major = 22
working tree = clean
pinned source/ref = 일치
```

조건이 맞으면 다음을 변경 없이 실행한다.

```bash
npm ci
npm run typecheck
npm run build:assets
```

검증 후:

```bash
git diff --exit-code -- packages package.json package-lock.json
git status --short
```

PRoot 준비 예시는 `company/docs/ENVIRONMENTS.md`를 따른다.

## Internal validation contract

- Required: No
- Internal result: `NOT_REQUIRED`
- 이 Task의 PASS는 사내 Windows 실행 PASS를 의미하지 않는다.

## Stop conditions

- Linux-compatible runner에서도 native dependency 해결 불가
- pinned source/ref 불일치
- 제품 코드 수정 없이는 build 불가능
- PRoot 제약과 CCR source 문제를 구분할 수 없고 대체 runner도 사용하지 않기로 결정함

## Rollback

- 문서 Evidence 변경만 revert한다.

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|
| 1 | implementation | `5fc304ad20b7eba2d6649faa2a6377f783a5e4c8` baseline | `BLOCKED_ENVIRONMENT` — native Android/arm64 Termux native dependency environment | `NOT_REQUIRED` | `RETRY` — use Termux + PRoot Linux + Node 22 before requiring another PC |

## Evidence / limitations

- Baseline CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Repository baseline after BOOT: `b05567891e15a157d8e54fac627618f8214128a7`
- Attempt 1 evidence merged in PR #8 on `2026-08-26`.
- Activated after BOOT Gate `ACCEPTED` on `2026-08-26`.
- GitHub Actions remain disabled while upstream workflows are unreviewed; this Task uses local commands only.
- Pinned source verification: `PASS` — `v3.0.22^{commit}` is `829298cf8bdcc6ddb9120a5a7c790c30227a1937`, the pin is an ancestor of the tested baseline, root package version is `3.0.22`, and no upstream-controlled product path differs from the pin.
- Upstream requirements: root `package.json` requires Node `>=22`; pinned README and install documentation use npm and prescribe `npm ci` for a source checkout. No exact npm version is pinned.
- Attempt 1 environment: Node `v26.4.0`, npm `11.19.0`, `android`/`arm64`, Linux kernel `6.6.102-android15` under native Termux.
- Clean install: `BLOCKED_ENVIRONMENT` — `npm ci` exited `1`. `better-sqlite3@12.11.1` had no prebuilt binary for Node `26.4.0` on `android`/`arm64`; its fallback `node-gyp` configure failed because `android_ndk_path` was undefined.
- Classification: environment/native dependency compatibility. The failure does not establish a pinned source or lockfile defect.
- Stop condition evaluation: `NOT_MET` — native Android/Termux는 Linux-compatible build runner가 아니므로 이 결과만으로 Task를 중단하지 않는다.
- `npm run typecheck` and `npm run build:assets` were not run because the install was incomplete; running them would not be valid evidence.
- Product code diff after the failed install: `PASS` — `packages/**`, `package.json`, and `package-lock.json` remained unchanged.
- Limitation: the Validation question remains unanswered until the same stock commands pass in PRoot Linux or another approved runner.

## Codex recommendation

`RETRY` — prepare Ubuntu 24.04 with PRoot-Distro on the Android device, use Node 22, and rerun `npm ci`, `npm run typecheck`, and `npm run build:assets` unchanged. Consider a separate Windows/Linux PC or CI only if PRoot-specific limitations prevent a conclusive result. Do not modify CCR source, dependencies, or scripts.

## Human decision

`PENDING`
