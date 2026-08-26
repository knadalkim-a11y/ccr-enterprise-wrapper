# Execution Environment Strategy

## 원칙

개발 제어와 Git 작업은 가능한 한 Android/Termux에서 수행한다.
다만 Task의 증거가 특정 OS ABI, native dependency 또는 Windows 동작을 요구하면
제품 코드를 우회 수정하지 않고 필요한 실행환경으로만 이동한다.

```text
Termux native
→ 기본 개발·Git·문서·에이전트 제어

Termux + PRoot Linux
→ 외부 install/typecheck/build 및 비-GUI 실행 검증의 우선 대안

사내 Windows
→ 실제 배포 대상 환경의 test-only 검증

별도 PC/CI
→ 위 두 환경으로 증명할 수 없을 때만 선택
```

개인 Windows/Linux PC는 초기 필수 자산이 아니다. 그러나 최종 대상이 사내 Windows이므로
Windows에서의 설치·실행·경로·권한·프록시·Claude Code 연동 증거는 V1 완료 전 반드시 필요하다.
그 증거는 사내 Windows의 test-only 절차로 얻을 수 있다.

## E0 — Native Termux

### 적합

- Git clone/fetch/branch/commit/push
- Issue/PR 관리와 Codex 세션 제어
- 설계·Task·Evidence·리뷰 문서 작성
- source inspection과 native dependency가 필요 없는 작은 코드 변경
- 공개 mock 또는 순수 JavaScript 검사

### 부적합 또는 비최종 증거

- `process.platform=android`에서 native Node addon 설치
- Electron Desktop 실행·패키징
- Windows 경로·권한·프록시 동작
- 사내 API와 실제 모델 검증

`V1-S0-T01` Attempt 1에서 native Termux의 `npm ci`는
`better-sqlite3` Android/arm64 설치 단계에서 `BLOCKED_ENVIRONMENT`였다.
이 결과를 Stock CCR source failure로 해석하지 않는다.

## E1 — Termux + PRoot Linux

Android 장치 안에서 일반 Linux userland를 사용하기 위한 우선 build runner다.
PRoot는 root 권한 없이 Linux filesystem/userland를 제공하지만 실제 VM이나 완전한 container isolation은 아니다.

### 허용하는 증거

아래 preflight를 만족하고 제품 코드를 수정하지 않은 경우:

- `npm ci`
- `npm run typecheck`
- `npm run build:assets`
- CLI 또는 비-GUI smoke test

### Preflight

```text
process.platform = linux
process.arch = arm64 또는 x64
Node major = 22
working tree = clean
package.json / package-lock.json = pinned source와 일치
```

### 한계

- PRoot 특유의 filesystem, ptrace, namespace 제한은 남는다.
- Electron GUI, system tray, installer, Windows 동작을 증명하지 않는다.
- PRoot에서만 발생하는 실패를 곧바로 CCR source defect로 분류하지 않는다.
- 오류를 통과시키기 위한 dependency/source patch를 하지 않는다.
- `/sdcard` 또는 Android shared storage에서 `npm ci`를 실행하지 않는다. symlink, execute bit, filesystem semantics가 build를 왜곡할 수 있다.
- native Termux와 PRoot 사이에서 `node_modules`를 공유하거나 복사하지 않는다.

### 권장 초기 구성

Native Termux:

```bash
pkg update
pkg install proot-distro
proot-distro install ubuntu:24.04 --name ccr-ubuntu
proot-distro login ccr-ubuntu
```

PRoot Ubuntu 내부:

```bash
apt update
apt install -y git curl ca-certificates build-essential python3 pkg-config

git clone https://github.com/nvm-sh/nvm.git ~/.nvm
cd ~/.nvm
git checkout v0.40.6
. ./nvm.sh
nvm install 22
nvm use 22

node --version
npm --version
node -p "process.platform"
node -p "process.arch"
```

검증용 repository는 PRoot 내부 filesystem에 별도로 clone한다.

```bash
cd ~
git clone https://github.com/knadalkim-a11y/ccr-enterprise-wrapper.git
cd ccr-enterprise-wrapper
git switch main
git pull --ff-only origin main
```

build 결과는 Task Evidence로 요약하고, 공식 문서 갱신과 push는 native Termux의 Codex 세션에서 수행해도 된다.
PRoot clone에 credential을 추가할 필요는 없다.

Node/nvm 버전은 Task 시작 시 다시 확인한다. 이 명령은 개발 편의를 위한 예시이며
Company product installer나 사내 배포 방식이 아니다.

## E2 — 사내 Windows (Target Validation)

사내 환경에서는 개발하지 않고 정확한 candidate commit을 pull하여 test-only로 검증한다.

### 반드시 Windows에서 검증할 항목

- 사내 승인 설치·업데이트 절차
- Desktop/CLI 실행과 프로세스 종료
- `%APPDATA%` 등 실제 설정 위치
- Windows 권한, 경로, 방화벽, 프록시, TLS
- 사내 OpenAI-compatible endpoint와 개인 API Key
- GLM/Gemma completion, streaming, tool round-trip
- Claude Code → CCR → 사내 모델 E2E
- rollback과 재설치

실패 시 사내에서 코드를 고치지 않는다. 정확한 candidate SHA와 sanitized observation만 외부 repair session으로 반환한다.

## E3 — 별도 Windows/Linux/macOS PC 또는 CI (Optional)

다음 경우에만 사용한다.

- PRoot 제약 때문에 외부 build 결과를 구분할 수 없음
- x64 또는 실제 OS native addon 증거가 필요함
- Windows installer/package를 사내 반입 전에 미리 검증해야 함
- 반복 가능한 matrix regression이 필요함

Codex Cloud나 GitHub Actions는 필수가 아니다. 사용한다면 고정 commit·고정 Node·고정 명령을 실행하는
결정적 runner로만 취급하고, 프로젝트 판단과 Source of Truth는 repository Task에 유지한다.

## Task별 기본 환경

| 작업 | 기본 환경 | 보조/최종 환경 |
|---|---|---|
| 설계, Git, Task, 리뷰 | Native Termux | 없음 |
| Stock install/typecheck/build | Termux + PRoot Linux | 표준 PC/CI 선택 |
| CLI 비-GUI smoke | PRoot Linux | 사내 Windows |
| Desktop/installer | 사내 Windows | 외부 Windows 선택 |
| 사내 Provider/모델 | 사내 Windows | 대체 불가 |
| Claude Code E2E | 사내 Windows | 외부 mock은 보조만 |

## AI Work Report

`AI_WORK_REPORT.md`는 세션 중 임시 scratch/handoff로만 사용할 수 있다.

- commit하지 않는다.
- 공식 증거는 활성 Task의 `Attempts`, `Evidence`, `Recommendation`에 반영한다.
- 프로젝트 수준 요약만 `STATUS.md`에 반영한다.
- 세션 종료 전에 삭제하거나 repository 밖으로 이동한다.
- 종료 시 untracked report 때문에 working tree가 dirty한 상태를 남기지 않는다.
