# Coding Agent Workflow

## 기본 단위

```text
One Task = one validation question
One Session = implementation / review / repair / validation 중 한 번의 시도
One active attempt PR at a time
```

하나의 Task는 여러 Session과 순차적인 Evidence PR을 가질 수 있다.
다른 Task를 동시에 진행하지 않는다.

## 역할별 Lane

상세 권한은 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.

```text
CHATGPT_ORCHESTRATOR
→ 설계·상태 복원·sanitized evidence 검토·canonical 문서/Issue 관리

EXTERNAL_CODEX
→ Android/Termux에서 구현·review·repair·branch/commit/push/PR

INTERNAL_VALIDATOR
→ 사내 Windows에서 exact commit pull/checkout과 test-only 검증
→ GitHub write, source 수정, Task/STATUS 수정 금지

HUMAN_GATE_OWNER
→ 사내 권한·evidence 전달·Gate·다음 Task 최종 승인
```

Internal Validator가 Task Evidence를 GitHub에 직접 쓰지 않는다.
사내 결과는 Human Gate Owner를 거쳐 ChatGPT Orchestrator가 canonical 문서에 반영한다.

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

Task 전체 상태는 실제 next action에 맞추고 Attempt evidence를 누적한다.

## 환경과 권한

```text
Native Termux
→ 외부 구현과 GitHub 작업

사내 Windows
→ test-only 검증
```

사내 Windows host capability:

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

- Stock runtime에는 첫 번째 capability가 필요하다.
- Provider/gateway contract에는 첫 번째와 두 번째가 필요하다.
- Claude Code E2E에는 세 capability 모두가 필요하다.

자세한 기준은 `ENVIRONMENTS.md`, `SECURITY.md`, `INTERNAL_VALIDATION.md`를 따른다.

## 모델 순서

모델 순서는 serving availability를 따른다.
활성 Task가 Gemma를 가리키면 과거 GLM-first 계획을 적용하지 않는다.
GLM rollout 후에는 새 canonical Task를 생성한다.

## 세션 시작

1. 역할을 선언한다.
2. root와 `company/`의 `AGENTS.md`를 따른다.
3. `project-state.yml`과 활성 Task를 읽는다.
4. Task의 Required knowledge만 추가로 읽는다.
5. branch/HEAD/working tree를 보고한다.
6. 활성 Task의 범위와 Stop condition을 재진술한다.
7. 실행 명령이 있으면 OS, architecture, Node/npm 버전을 확인한다.
8. 사내 model request가 있으면 host capability matrix를 `YES / NO / UNKNOWN`으로 보고한다.
9. Credential host scope가 `MISMATCH` 또는 `UNKNOWN`이면 실제 요청을 반복하지 않는다.

새 ChatGPT 설계 세션은 `DESIGN_SESSION_PLAYBOOK.md`의 Context checksum을 먼저 작성한다.

## EXTERNAL_CODEX 구현 세션

- 가장 작은 변경으로 Acceptance Criteria를 충족한다.
- 다음 Stage를 위한 추상화를 미리 추가하지 않는다.
- 실행하지 못한 검사는 명시적으로 남긴다.
- 사내 검증 명령은 product code 수정 없이 실행 가능해야 한다.
- 환경 또는 권한 문제를 source/dependency 수정으로 우회하지 않는다.
- 401/403을 분석할 때 host scope 확인 전에는 protocol/auth implementation failure로 단정하지 않는다.
- 활성 Task가 허용한 branch/commit/push/PR만 수행한다.

## EXTERNAL_CODEX 리뷰 세션

구현 세션과 별도 세션으로 수행하며 다음을 우선 검토한다.

1. 역할/권한 위반
2. Scope/Allowed Paths 위반
3. CCR 기능 중복 구현
4. Core patch와 신규 dependency
5. 거짓 PASS와 기준 약화
6. Host-scope blocker와 protocol failure의 혼동
7. Key 공유 또는 allowlist 우회
8. 실행환경과 증거 범위의 혼동
9. 보안 경계 위반
10. rollback·Evidence·검증 명령 누락

## INTERNAL_VALIDATOR 세션

사내 코딩 에이전트는 pull-only validation agent다.

허용:

```text
fetch / pull --ff-only / detached checkout
read-only source inspection
Task에 문서화된 명령·UI 검증
rev-parse / status / diff --exit-code
sanitized 결과 출력
```

금지:

```text
source/dependency/script/lockfile 수정
Task/STATUS/Gate/project-state 수정
branch/commit/push/PR/Issue
repository 안의 AI_WORK_REPORT 또는 임시 파일
실제 endpoint/key/model/host/raw evidence 반출
```

Working tree가 dirty하면 임의로 복원하지 않고 경로만 보고한 뒤 중단한다.
결과는 `ROLES_AND_HANDOFF.md`의 Sanitized Internal Evidence 형식으로 Human Gate Owner에게 반환한다.

## AI Work Report

External Codex는 세션 UI 또는 로컬에서 `AI_WORK_REPORT.md`를 임시로 사용할 수 있으나 공식 기록은 아니다.

```text
임시 report
→ 필요한 내용을 활성 Task Attempts/Evidence에 반영
→ STATUS에는 프로젝트 수준 요약만 반영
→ 세션 종료 전 삭제 또는 repository 밖 이동
```

Internal Validator는 repository 안에 report를 만들지 않는다.

## 사내 검증 반환

```text
PASS
→ ChatGPT Orchestrator가 Acceptance Criteria와 Evidence 갱신 제안

FAIL
→ External Codex repair session 후보

BLOCKED
→ credential host scope, model availability, network, 정책 등 선행조건 분리
```

반환 필수:

```text
Task ID
exact tested commit
capability matrix
명령/UI 단계와 exit code
PASS / FAIL / BLOCKED
failure category
reproducibility
product diff / final git status
sanitized observation
Git write performed: NO
```

## 종료

- External Codex는 Task Evidence와 PR을 갱신하고 다음 Task를 시작하지 않는다.
- Internal Validator는 GitHub를 수정하지 않고 sanitized handoff만 반환한다.
- ChatGPT Orchestrator는 Human Gate Owner가 전달한 evidence를 검토해 canonical 문서를 갱신한다.
- Human Gate Owner만 최종 Gate와 다음 Task 활성화를 승인한다.
