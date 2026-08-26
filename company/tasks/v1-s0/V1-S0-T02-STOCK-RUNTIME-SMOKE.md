---
id: V1-S0-T02
stage: V1-S0
title: Stock CCR internal Windows runtime smoke
kind: spike
status: done
session_role: validation
internal_validation: required
depends_on:
  - V1-S0-T01
allowed_paths:
  - company/tasks/v1-s0/V1-S0-T02-STOCK-RUNTIME-SMOKE.md
  - company/docs/STATUS.md
  - company/gates/V1-S0.md
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: accepted
---

# Stock CCR Internal Windows Runtime Smoke

## Validation question

> Build가 검증된 pinned CCR `v3.0.22` CLI가 사내 Windows에서 provider 설정 없이 start/stop되고 예상 runtime 경로를 생성하는가?

## Why now

`V1-S0-T01`에서 source checkout의 install, typecheck, build가 통과했다.
Provider contract로 넘어가기 전에 Stock CCR 자체의 최소 실행 가능성과 Windows runtime 경로를 확인한다.

## Required knowledge

- `packages/cli/README.md`
- `company/docs/ENVIRONMENTS.md`
- `company/tasks/v1-s0/V1-S0-T01-STOCK-BUILD.md`
- `company/gates/V1-S0.md`

## In scope

- `V1-S0-T01`에서 검증한 exact product commit과 build artifacts 사용
- source-built CLI entrypoint의 help 실행
- provider/gateway 없이 detached management service start/stop
- Windows CCR data directory 생성 여부 확인
- 제품 코드와 lockfile 무변경 확인
- 민감정보를 제거한 결과 기록

## Out of scope

- Provider/model/client key 설정
- gateway model request
- Claude Code 연결
- Desktop installer/package
- 사내에서 source/dependency/script 수정
- Wrapper/Static/Telemetry/V2 구현
- CCR Core 수정

## Acceptance criteria

- [x] exact product commit `97b73a9f4e1fb23d406bb987d0785cefa1f99966` 사용 또는 동등한 product tree임을 기록
- [x] working tree clean
- [x] source-built CLI entrypoint 존재
- [x] CLI `--help` exit `0`
- [x] `start --no-open --no-gateway` exit `0`
- [x] `%APPDATA%\claude-code-router` 존재 여부 기록
- [x] `stop` exit `0`
- [x] 제품 코드와 lockfile 무변경
- [x] authenticated management URL/token을 외부 Evidence에 기록하지 않음

## Windows commands

사내 Windows PowerShell에서 `V1-S0-T01`을 통과한 checkout을 사용한다.

```powershell
$TestedCommit = git rev-parse HEAD

git status --short
node --version
npm --version
node -p "process.platform"
node -p "process.arch"

$Cli = "packages/cli/dist/main/cli.js"
Test-Path $Cli
```

CLI entrypoint 확인:

```powershell
node $Cli --help
$HelpExit = $LASTEXITCODE
```

Provider와 gateway 없이 최소 service start/stop:

```powershell
$CcrData = Join-Path $env:APPDATA "claude-code-router"
$DataDirExistedBefore = Test-Path $CcrData

node $Cli start --no-open --no-gateway
$StartExit = $LASTEXITCODE

Start-Sleep -Seconds 2
$DataDirExistsAfter = Test-Path $CcrData

node $Cli stop
$StopExit = $LASTEXITCODE
```

마지막 무변경 확인:

```powershell
git diff --exit-code -- packages package.json package-lock.json
$ProductDiffExit = $LASTEXITCODE

git status --short
```

출력된 authenticated management URL에는 private token이 포함될 수 있다.
URL, query string, token, local runtime file contents를 외부 repository 또는 보고서에 복사하지 않는다.
exit code, data directory 존재 여부, sanitized observation만 기록한다.

## Internal validation contract

- Required: Yes
- Result values: `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED_INTERNAL`
- 사내에서는 코드를 수정하지 않는다.
- 실패 시 exact commit, 오류 분류, 재현률, sanitized observation만 외부 repair session으로 반환한다.

## Failure classification

- `CLI_ENTRYPOINT`
- `STARTUP`
- `SHUTDOWN`
- `RUNTIME_PATH`
- `PORT_CONFLICT`
- `WINDOWS_ENVIRONMENT`
- `UNKNOWN`

## Stop conditions

- CLI entrypoint가 build 결과에 없음
- provider 설정 없이 management-only service를 시작할 수 없음
- stop 명령으로 detached service를 정상 종료할 수 없음
- 제품 코드 수정 없이는 smoke test를 완료할 수 없음

## Rollback

- 실행 중이면 `node packages/cli/dist/main/cli.js stop`을 수행한다.
- 필요하면 사내 working copy를 폐기한다.
- runtime data 삭제는 별도 승인 없이 수행하지 않는다.

## Attempts

| Attempt | Session role | Commit | Internal | Recommendation |
|---:|---|---|---|---|
| 1 | validation | `97b73a9f4e1fb23d406bb987d0785cefa1f99966` | `PASS` — CLI help, management-only start/stop, runtime path, product diff 모두 통과 | `GO` — accept V1-S0 Gate and proceed to V1-S1 |

## Attempt 1 evidence

- Task: `V1-S0-T02`
- Tested product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Environment: same internal Windows baseline as `V1-S0-T01` — Microsoft Windows 11 Enterprise reported as `10.0.2231`, Node `v24.15.0`, npm `11.12.1`, `win32`, `x64`
- Working tree before test: `CLEAN`
- CLI entrypoint exists: `TRUE`
- CLI help: `PASS`, exit `0`
- Runtime data directory existed before: `FALSE`
- Management-only start: `PASS`, exit `0`
- Runtime data directory exists after: `TRUE`
- Stop: `PASS`, exit `0`
- Product diff: `PASS`, exit `0`
- Final Git status: `CLEAN` — no output
- Failure classification: `N/A`
- Reproducibility: `1/1`
- Sanitized observation: 기존 clean checkout에서 CLI 존재 확인부터 help, management-only start/stop, 제품 파일 diff까지 전 항목이 한 번에 예상대로 통과했다. runtime data directory는 최초 실행 시 새로 생성되었고 서비스 종료 후에도 source tree에는 변경이 남지 않았다.
- Security evidence: authenticated management URL, query token, runtime database content, internal absolute paths를 외부 기록에 포함하지 않았다.

## Evidence / limitations

- Build-validated and runtime-tested product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- `V1-S0-T01` passed on internal Windows with Node `v24.15.0`, npm `11.12.1`, `win32`, `x64`.
- This Task intentionally used management-only mode with `--no-gateway`; it does not prove provider, model, gateway request, streaming, or tool compatibility.
- Together, `V1-S0-T01` and `V1-S0-T02` satisfy the minimum Stock CCR install/build/start/stop evidence for the V1-S0 Gate.

## Codex recommendation

`GO` — accept the V1-S0 Gate and begin V1-S1 with one internal GLM provider connection check. Do not infer streaming, tool calling, or Claude Code compatibility from this smoke test.

## Human decision

`ACCEPTED` — `V1-S0-T02` internal Windows runtime smoke passed on `2026-08-27`.
