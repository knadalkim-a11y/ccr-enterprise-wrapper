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

### Host capability matrix

모든 사내 Windows PC가 동일한 권한을 갖는다고 가정하지 않는다.
다음 capability를 독립적으로 판정한다.

| Capability | Meaning |
|---|---|
| `WINDOWS_RUNTIME_ALLOWED` | CCR source/build/runtime을 실행할 수 있음 |
| `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` | 사용할 credential이 현재 host의 실제 source/egress scope에서 허용됨 |
| `CLAUDE_CODE_EXECUTION_ALLOWED` | 해당 PC에서 Claude Code 사용이 승인됨 |

Task별 요구사항:

| Validation | Required capabilities |
|---|---|
| Stock install/build/runtime | `WINDOWS_RUNTIME_ALLOWED` |
| Provider connection, gateway, streaming, tools | `WINDOWS_RUNTIME_ALLOWED` + `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` |
| Claude Code E2E | 세 capability 모두 |

Provider-only 검증과 Claude Code E2E는 정책상 서로 다른 host에서 수행할 수 있다.
다만 E2E까지 같은 runtime data를 재사용하려면 세 capability를 모두 가진 host를 우선한다.

### Credential source identity

Credential의 허용 범위는 반드시 local adapter IP와 같다고 가정하지 않는다.
실제 판정 기준은 다음 중 하나일 수 있다.

```text
PC/device identity
source IP
NAT egress
proxy egress
network segment
user/account
model entitlement
```

Serving 운영자 또는 발급 시스템 기준으로 현재 host의 실제 outbound identity와 allowed scope를 확인한다.
실제 값은 repository에 기록하지 않고 다음 상태만 기록한다.

```text
AUTHORIZED
MISMATCH
UNKNOWN
```

`MISMATCH` 또는 `UNKNOWN`이면 real model request를 반복하지 않는다.

### V1-S0에서 검증한 항목

- Node `>=22` LTS release line
- 실제 Node/npm 버전 기록
- clean `npm ci`
- `npm run typecheck`
- `npm run build:assets`
- 제품 코드와 lockfile 무변경
- Stock CCR CLI 시작·종료
- 실제 설정/runtime directory 생성

### V1-S1 이후 검증할 항목

- host-authorized credential preflight
- 사내 OpenAI-compatible API의 Provider connection
- gateway basic completion
- streaming과 tool round-trip
- 주요 availability 오류 분류
- model별 권장 범위

### V1-S2에서 검증할 항목

- Claude Code 승인 host 여부
- 해당 host에서 유효한 LLM credential
- Claude Code → CCR → 사내 모델 E2E
- Windows 권한, 경로, 방화벽, proxy, TLS
- rollback과 재설치

### Node / install preflight

아래 branch/HEAD/working-tree 확인은 shared checkout을 명시적으로 사용하는
일반 Task의 기본이다.

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
exact candidate commit = recorded
```

Task-approved disposable exact-ref validation에서는 다음이 위 shared-checkout
항목을 대체한다.

```text
canonical repository URL/ref/SHA = Human-approved exact values
approved nonce path = new and empty before bootstrap
prepared bare refs = exact approved main/candidate commits
archive execution-input fingerprint = unchanged after install/build
shared checkout branch/HEAD/status = non-authoritative and not mutated
```

활성 Task가 더 좁은 Node 계약을 명시할 수 있지만 LTS 조건을 생략하려면
근거를 남겨야 한다. V1-S1-T00 A0는 Node `>=22` 이면서
`process.release.lts`가 nonempty인 release만 허용한다.

### Install integrity verification

`npm ci`의 exit code `0`만으로 설치 성공을 확정하지 않는다.
V1-S0에서 첫 `npm ci`가 `0`을 반환했지만 `node_modules/.bin`이 없고 `tsc`를 실행할 수 없었던 단일 사례가 있었다.
`node_modules` 삭제 후 clean rerun에서는 정상 설치되었고 모든 검사가 통과했다.

따라서 다음을 함께 확인한다.

```text
npm ci exit code
+ actual typecheck
+ actual build or runtime command
```

### Test-only 원칙

- 사내에서 source, dependency, script를 수정하지 않는다.
- 실패하면 exact commit과 sanitized observation만 외부 repair session으로 반환한다.
- 사내 endpoint, key, model ID, actual host/IP, proxy, raw log는 외부 repository에 기록하지 않는다.
- `npm ci`가 사내망 정책으로 실패하면 `NETWORK_OR_REGISTRY`로 분류한다.
- Credential host scope mismatch는 `CREDENTIAL_HOST_SCOPE`로 분류하고 protocol/product defect로 단정하지 않는다.
- 다른 PC용 key를 복사하거나 allowlist를 우회하지 않는다.

공식 Windows release 실행은 Stock runtime feasibility를 빠르게 확인하는 보조 방법이다.
Company code를 배포하기 전에는 source checkout의 build 검증도 별도로 필요하다.

## E2 — 선택적 보조 Runner

다음 경우에만 별도 Windows/Linux/macOS PC, CI 또는 PRoot Linux를 고려한다.

- 사내 Windows가 dependency 설치나 build tool 접근을 정책적으로 허용하지 않음
- 반복 가능한 공개 regression runner가 필요함
- 사내 반입 전에 Windows installer/package를 미리 검증해야 함
- internal failure가 OS 문제인지 source 문제인지 구분할 보조 증거가 필요함

보조 runner는 사내 LLM credential 또는 Claude Code 사용 권한을 자동으로 갖지 않는다.

## Task별 기본 환경

| 작업 | 기본 환경 | 선택적 보조 환경 |
|---|---|---|
| 설계, Git, Task, 리뷰 | Native Termux | 없음 |
| Stock install/typecheck/build | 사내 Windows runtime host | 별도 PC/CI/PRoot |
| Provider/gateway/stream/tool | credential-authorized 사내 Windows host | 없음 또는 정책 승인 host |
| Claude Code E2E | Claude Code 승인 + credential-authorized Windows host | 대체 불가 |

## AI Work Report

`AI_WORK_REPORT.md`는 세션 중 임시 scratch/handoff로만 사용할 수 있다.

- commit하지 않는다.
- 공식 증거는 활성 Task의 `Attempts`, `Evidence`, `Recommendation`에 반영한다.
- 프로젝트 수준 요약만 `STATUS.md`에 반영한다.
- 세션 종료 전에 삭제하거나 repository 밖으로 이동한다.
- 종료 시 untracked report 때문에 working tree가 dirty한 상태를 남기지 않는다.
