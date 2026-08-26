# Execution Environment Strategy

## 원칙

개발 제어와 Git 작업은 Android/Termux에서 수행한다.
제품 검증은 실제 배포 대상인 사내 Windows에서 수행한다.

```text
Native Termux
→ 개발 제어 · Git · 문서 · Task · PR · 리뷰

사내 Windows
→ install · typecheck · build · 실행 · 사내 연동 · Claude Code E2E

별도 PC / CI / PRoot Linux
→ 두 기본 환경만으로 결론을 낼 수 없을 때만 선택
```

개인 Windows/Linux PC와 cloud runner는 필수가 아니다.
사내 Windows에서 고정 commit을 build하고 실행하는 것은 개발이 아니라 test-only 검증이다.

## E0 — Native Termux

### 적합

- Git clone/fetch/branch/commit/push
- Issue/PR 관리와 Codex 세션 제어
- 설계·Task·Evidence·리뷰 문서 작성
- source inspection과 native dependency가 필요 없는 작은 코드 변경
- 공개 mock 또는 순수 JavaScript 검사

### 최종 증거로 사용하지 않는 항목

- `process.platform=android`에서 native Node addon 설치
- Electron Desktop 실행·패키징
- Windows 경로·권한·프록시 동작
- 사내 API와 실제 모델 검증

`V1-S0-T01` Attempt 1에서 native Termux의 `npm ci`는
`better-sqlite3` Android/arm64 설치 단계에서 `BLOCKED_ENVIRONMENT`였다.
이 결과를 Stock CCR source failure로 해석하지 않으며 같은 native Termux 환경에서 반복하지 않는다.

## E1 — 사내 Windows

사내에서는 개발하지 않고 정확한 candidate commit을 pull하여 test-only로 검증한다.
현재 프로젝트의 실제 target environment이므로 build와 runtime 증거의 기본 환경이다.

### V1-S0에서 검증할 항목

- Node `>=22`이며 LTS release line인지
- 실제 사용한 Node/npm 버전 기록
- clean `npm ci`
- `npm run typecheck`
- `npm run build:assets`
- 제품 코드와 lockfile 무변경
- Stock CCR CLI/Desktop 시작·종료
- 실제 설정 위치와 기본 로그 위치

CCR root `package.json`은 Node `>=22`를 요구한다.
검증 환경은 이 조건을 만족하는 LTS major를 사용하며, 현재 검증 시점에는 Node 22와 Node 24를 허용한다.
사내에 이미 설치된 지원 LTS 버전이 있으면 그대로 먼저 검증하고, 실제 compatibility 실패 증거 없이 특정 major로 강제 교체하지 않는다.
exact npm version은 upstream에서 pin하지 않으므로 Node 배포에 포함된 npm 버전을 기록해 사용한다.

### 이후 Windows에서 검증할 항목

- 사내 승인 설치·업데이트 절차
- Windows 설정 위치, 권한, 경로, 방화벽, 프록시, TLS
- 사내 OpenAI-compatible API의 completion, streaming, tool round-trip
- Claude Code → CCR → 사내 모델 E2E
- rollback과 재설치

### Preflight

```powershell
git branch --show-current
git rev-parse HEAD
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
Node release line = LTS
working tree = clean
정확한 candidate commit = 기록됨
```

### Install integrity verification

`npm ci`의 exit code `0`만으로 설치 성공을 확정하지 않는다.
`V1-S0-T01`에서 첫 `npm ci`가 `0`을 반환했지만 `node_modules/.bin`이 없고 `tsc`를 실행할 수 없었던 단일 사례가 있었다.
`node_modules` 삭제 후 clean rerun에서는 정상 설치되었고 모든 검사가 통과했다.

따라서 검증자는 반드시 다음을 함께 확인한다.

```text
npm ci exit code
+ 실제 후속 typecheck
+ 실제 build 또는 runtime command
```

필요할 때는 아래처럼 설치 도구 존재를 보조 확인할 수 있다.

```powershell
Test-Path node_modules\.bin\tsc.cmd
```

exit `0`인데 후속 도구가 없으면:

1. 제품 코드나 dependency를 수정하지 않는다.
2. `INSTALL_INTEGRITY_ANOMALY`로 기록한다.
3. `node_modules`만 삭제하고 clean `npm ci`를 한 번 재시도한다.
4. 최초 현상과 재시도 결과를 모두 Evidence에 남긴다.
5. 반복 재현되기 전에는 CCR 또는 npm의 확정 결함으로 단정하지 않는다.

### Test-only 원칙

- 사내에서 source, dependency, script를 수정하지 않는다.
- 실패하면 정확한 commit SHA와 민감정보를 제거한 관찰만 외부 repair session으로 반환한다.
- 사내 주소, 모델명, 인증정보, raw log는 외부 repository에 기록하지 않는다.
- `npm ci`가 사내망 정책으로 실패하면 제품 결함으로 단정하지 않고 `NETWORK_OR_REGISTRY`로 분류한다.
- Node 24에서 native dependency나 build가 실패하면 즉시 source를 수정하지 않고 `NODE_MAJOR_COMPATIBILITY` 가능성을 분리해 기록한다. 필요할 때만 Node 22 재검증을 비교 증거로 사용한다.

공식 Windows release 실행은 Stock runtime feasibility를 빠르게 확인하는 보조 방법이다.
Company code를 배포하기 전에는 source checkout의 build 검증도 별도로 필요하다.

## E2 — 선택적 보조 Runner

다음 경우에만 별도 Windows/Linux/macOS PC, CI 또는 PRoot Linux를 고려한다.

- 사내 Windows가 dependency 설치나 build tool 접근을 정책적으로 허용하지 않음
- 반복 가능한 공개 regression runner가 필요함
- 사내 반입 전에 Windows installer/package를 미리 검증해야 함
- internal failure가 OS 문제인지 source 문제인지 구분할 보조 증거가 필요함

PRoot Linux는 선택적 실험 환경일 뿐 기본 경로가 아니다.
PRoot 성공은 Windows 동작을 증명하지 않으며, PRoot 실패도 곧바로 CCR source defect를 뜻하지 않는다.

## Task별 기본 환경

| 작업 | 기본 환경 | 선택적 보조 환경 |
|---|---|---|
| 설계, Git, Task, 리뷰 | Native Termux | 없음 |
| Stock install/typecheck/build | 사내 Windows | 별도 PC/CI/PRoot |
| CLI/Desktop smoke | 사내 Windows | 외부 Windows |
| 사내 Provider/모델 | 사내 Windows | 대체 불가 |
| Claude Code E2E | 사내 Windows | 외부 mock은 보조만 |

## AI Work Report

`AI_WORK_REPORT.md`는 세션 중 임시 scratch/handoff로만 사용할 수 있다.

- commit하지 않는다.
- 공식 증거는 활성 Task의 `Attempts`, `Evidence`, `Recommendation`에 반영한다.
- 프로젝트 수준 요약만 `STATUS.md`에 반영한다.
- 세션 종료 전에 삭제하거나 repository 밖으로 이동한다.
- 종료 시 untracked report 때문에 working tree가 dirty한 상태를 남기지 않는다.
