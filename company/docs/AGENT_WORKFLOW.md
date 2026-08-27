# Coding Agent Workflow

## 기본 단위

```text
One Task = one validation question
One Session = implementation / review / repair / validation 중 한 번의 시도
One active attempt PR at a time
```

하나의 Task는 여러 Session과 순차적인 Evidence PR을 가질 수 있다.
환경 또는 권한 때문에 한 Attempt의 증거를 먼저 main에 남겨야 할 경우 Task를 닫지 않고 다음 Attempt를 새 짧은 branch/PR로 이어갈 수 있다.
다른 Task를 동시에 진행하지 않는다.

## 상태 흐름

```text
PLANNED → IN_PROGRESS → EXTERNAL_PASS
→ READY_FOR_INTERNAL_VALIDATION
→ INTERNAL_PASS / INTERNAL_FAIL / BLOCKED
→ HUMAN_DECISION → DONE / RETRY / CANCELLED
```

환경/권한 preflight만 실패한 Attempt는 구현 실패와 분리한다.

```text
BLOCKED_ENVIRONMENT
BLOCKED_CREDENTIAL_HOST_SCOPE
BLOCKED_HOST_NOT_APPROVED
BLOCKED_MODEL_NOT_AVAILABLE
```

Task 전체 상태는 실제 next action에 맞춰 `PLANNED`, `READY_FOR_INTERNAL_VALIDATION`, 또는 `BLOCKED`로 유지하고 Attempt evidence를 누적한다.

## 환경 역할

```text
Native Termux
→ Git, 문서, Task, 리뷰, 에이전트 제어, 외부 구현

사내 Windows
→ install, typecheck, build, runtime, 사내 연동의 test-only 검증
```

사내 Windows host는 다음 capability를 독립적으로 갖는다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

- Stock runtime에는 첫 번째 capability가 필요하다.
- Provider/gateway contract에는 첫 번째와 두 번째가 필요하다.
- Claude Code E2E에는 세 capability 모두가 필요하다.

자세한 기준은 `company/docs/ENVIRONMENTS.md`, `SECURITY.md`, `INTERNAL_VALIDATION.md`를 따른다.

## 모델 순서

모델 순서는 serving availability를 따른다.
활성 Task가 Gemma를 가리키면 과거 GLM-first 계획을 적용하지 않는다.
GLM rollout 후에는 새 canonical Task를 생성한다.

## 세션 시작

1. root와 `company/`의 `AGENTS.md`를 따른다.
2. `project-state.yml`과 활성 Task를 읽는다.
3. Task의 Required knowledge만 추가로 읽는다.
4. branch/HEAD/working tree를 보고한다.
5. 활성 Task의 범위와 Stop condition을 재진술한다.
6. 실행 명령이 있으면 OS, architecture, Node/npm 버전을 확인한다.
7. 사내 model request가 있으면 host capability matrix를 `YES / NO / UNKNOWN`으로 보고한다.
8. Credential host scope가 `MISMATCH` 또는 `UNKNOWN`이면 실제 요청을 반복하지 않는다.

## 구현 세션

- 가장 작은 변경으로 Acceptance Criteria를 충족한다.
- 다음 Stage를 위한 추상화를 미리 추가하지 않는다.
- 실행하지 못한 검사는 명시적으로 남긴다.
- 사내 검증 명령은 product code 수정 없이 실행 가능해야 한다.
- 환경 또는 권한 문제를 source/dependency 수정으로 우회하지 않는다.
- 401/403을 분석할 때 host scope 확인 전에는 protocol/auth implementation failure로 단정하지 않는다.

## 리뷰 세션

구현 세션과 별도 세션으로 수행하며 다음을 우선 검토한다.

1. Scope/Allowed Paths 위반
2. CCR 기능 중복 구현
3. Core patch와 신규 dependency
4. 거짓 PASS와 기준 약화
5. Host-scope blocker와 protocol failure의 혼동
6. Key 공유 또는 allowlist 우회
7. 실행환경과 증거 범위의 혼동
8. 보안 경계 위반
9. rollback·Evidence·검증 명령 누락

## AI Work Report

세션 UI 또는 로컬에서 `AI_WORK_REPORT.md`를 임시로 사용할 수 있으나 공식 기록은 아니다.

```text
임시 report
→ 필요한 내용을 활성 Task Attempts/Evidence에 반영
→ STATUS에는 프로젝트 수준 요약만 반영
→ 세션 종료 전 삭제 또는 repository 밖 이동
```

## 사내 검증 반환

사내에서는 수정하지 않는다. 정확한 candidate commit, capability matrix, 명령별 exit code,
재현률, 일반화된 실패 분류, sanitized observation만 동일 Task의 repair session으로 반환한다.

```text
PASS
→ Acceptance Criteria와 Evidence 갱신

FAIL
→ 필요한 host/credential 권한이 준비된 상태에서 contract 실패

BLOCKED
→ credential host scope, model availability, network, 정책 등 선행조건 미충족
```

실제 host/IP, endpoint, key, model ID, raw request/response는 반환하지 않는다.

## 종료

Task의 Attempts를 누적하고 Codex Recommendation을 기록한다.
사람이 Human Decision과 다음 Task 활성화를 수행한다.
세션 종료 전 임시 report와 working tree 상태를 확인한다.
