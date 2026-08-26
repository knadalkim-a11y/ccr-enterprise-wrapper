---
id: V1-S0-T01
stage: V1-S0
title: Stock CCR internal Windows build
kind: spike
status: done
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
human_decision: accepted
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
- [x] 사내 Windows에서 clean `npm ci` 결과 기록
- [x] 사내 Windows에서 `npm run typecheck` 결과 기록
- [x] 사내 Windows에서 Desktop packaging 제외 `npm run build:assets` 결과 기록
- [x] Attempt 1 이후 제품 코드 변경 없음
- [x] Attempt 1 실패 원인과 다음 Recommendation 기록
- [x] Windows 검증 후 제품 코드와 lockfile 무변경 확인

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

$NodeMajor = [int](node -p "process.versions.node.split('.')[0]")
if ($NodeMajor -lt 22) {
  throw "Node.js 22 or newer is required. Found major version $NodeMajor."
}
```

진행 조건:

```text
process.platform = win32
Node major >= 22
사용 중인 Node major가 LTS release line임
working tree = clean
TestedCommit = 기록됨
```

현재 검증 시점에는 Node 22와 Node 24가 LTS release line이며 둘 다 허용한다.
CCR root `package.json`은 Node `>=22`를 요구하고 exact npm version은 pin하지 않는다.
사내에 이미 설치된 지원 LTS 버전을 그대로 검증하며, 실제 실패 증거 없이 Node 22로 강제 downgrade하지 않는다.

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

`npm ci`의 exit code만으로 설치 무결성을 확정하지 않는다.
반드시 후속 `npm run typecheck`와 `npm run build:assets`까지 실행해 실제 도구와 산출물 사용 가능성을 확인한다.

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
- `NODE_MAJOR_COMPATIBILITY`
- `INSTALL_INTEGRITY_ANOMALY`
- `UNKNOWN`

## Stop conditions

- pinned source/ref 불일치
- Node major가 22 미만이거나 LTS가 아닌 Node line만 사용할 수 있음
- 사내 Windows에서도 제품 코드 수정 없이는 dependency install/build 불가
- 사내 정책으로 build 검증을 수행할 수 없고 대체 증거 경로도 승인되지 않음

## Rollback

- 사내 working copy를 폐기하거나 exact candidate commit으로 reset한다.
- 외부 repository에는 Evidence 문서 변경만 남긴다.

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|
| 1 | implementation | `5fc304ad20b7eba2d6649faa2a6377f783a5e4c8` baseline | `BLOCKED_ENVIRONMENT` — native Android/arm64 Termux native dependency environment | `NOT_REQUIRED` | `RETRY` — validate unchanged on internal Windows with a supported Node LTS major >= 22 |
| 2 | validation | `97b73a9f4e1fb23d406bb987d0785cefa1f99966` | `NOT_REQUIRED` | `PASS` — Windows install, typecheck, build assets, product diff all passed | `GO` — proceed to Stock CCR Windows runtime smoke |

## Attempt 2 evidence

- Task: `V1-S0-T01`
- Tested commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Environment: reported as Microsoft Windows 11 Enterprise `10.0.2231`, Node `v24.15.0`, npm `11.12.1`, `win32`, `x64`
- Working tree before test: `CLEAN`
- Final successful `npm ci`: `PASS`, exit `0`
- `npm run typecheck`: `PASS`, exit `0`
- `npm run build:assets`: `PASS`, exit `0`
- Product diff: `PASS`, exit `0`
- Final Git status: `CLEAN` — no output
- Failure classification: `N/A` — final validation sequence passed
- Reproducibility: `1/1`
- Sanitized observation: the first `npm ci` returned exit `0`, but `node_modules/.bin` was absent and the first typecheck reported that `tsc` was not recognized. After deleting `node_modules` and rerunning `npm ci`, installation integrity was restored and all required checks passed.
- Interpretation: this single observation is not evidence of a CCR source defect or a confirmed intermittent npm defect. Preserve it as an install-integrity recheck condition; future validators must run typecheck/build rather than trusting the `npm ci` exit code alone.

## Evidence / limitations

- Baseline CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Repository baseline after BOOT: `b05567891e15a157d8e54fac627618f8214128a7`
- Attempt 1 evidence merged in PR #8 on `2026-08-26`.
- GitHub Actions remain disabled while upstream workflows are unreviewed; this Task used local Windows commands only.
- Pinned source verification: `PASS` — `v3.0.22^{commit}` is the pinned commit, the pin is an ancestor of the tested baseline, root package version is `3.0.22`, and no upstream-controlled product path differs from the pin.
- Upstream requirements: root `package.json` requires Node `>=22`; source checkout uses npm and `npm ci`; exact npm version is not pinned.
- Attempt 1 stop condition evaluation: `NOT_MET` — native Termux is not the target Windows validation environment.
- Attempt 2 answers the validation question with `PASS` for the tested Windows environment and exact commit.
- Remaining V1-S0 work: Stock CCR CLI/runtime start-stop smoke and runtime/config path evidence.

## Codex recommendation

`GO` — accept the Windows build validation and proceed to `V1-S0-T02` Stock CCR internal Windows runtime smoke. Keep the one-time install-integrity anomaly as a recheck note, not as a product failure.

## Human decision

`ACCEPTED` — `V1-S0-T01` Windows build validation passed on `2026-08-26`.
