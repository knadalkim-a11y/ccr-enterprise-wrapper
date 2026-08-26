---
id: V1-S0-T02
stage: V1-S0
title: Stock CCR internal Windows runtime smoke
kind: spike
status: planned
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
human_decision: pending
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

- [ ] exact product commit `97b73a9f4e1fb23d406bb987d0785cefa1f99966` 사용 또는 동등한 product tree임을 기록
- [ ] working tree clean
- [ ] source-built CLI entrypoint 존재
- [ ] CLI `--help` exit `0`
- [ ] `start --no-open --no-gateway` exit `0`
- [ ] `%APPDATA%\claude-code-router` 존재 여부 기록
- [ ] `stop` exit `0`
- [ ] 제품 코드와 lockfile 무변경
- [ ] authenticated management URL/token을 외부 Evidence에 기록하지 않음

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

진행 조건:

```text
TestedCommit = 97b73a9f4e1fb23d406bb987d0785cefa1f99966
또는 해당 commit과 product-controlled tree가 동일함
process.platform = win32
working tree = clean
$Cli exists = True
```

CLI entrypoint 확인:

```powershell
node $Cli --help
$HelpExit = $LASTEXITCODE
```

Provider와 gateway 없이 최소 service start/stop:

```powershell
node $Cli start --no-open --no-gateway
$StartExit = $LASTEXITCODE

Start-Sleep -Seconds 2

$CcrData = Join-Path $env:APPDATA "claude-code-router"
$DataDirExists = Test-Path $CcrData

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

## Evidence / limitations

- Build-validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- `V1-S0-T01` passed on internal Windows with Node `v24.15.0`, npm `11.12.1`, `win32`, `x64`.
- This Task intentionally starts management-only mode with `--no-gateway`; it does not prove provider or model request compatibility.
- A PASS here completes the minimum Stock CCR install/build/start evidence required for the V1-S0 Gate.

## Codex recommendation

`PENDING`

## Human decision

`PENDING`
