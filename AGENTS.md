# Repository Agent Instructions

## Session role declaration

모든 세션은 실행 전에 자신의 역할을 하나만 선언한다.

```text
CHATGPT_ORCHESTRATOR
EXTERNAL_CODEX
INTERNAL_VALIDATOR
HUMAN_GATE_OWNER
```

상세 권한과 handoff는 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.
역할 제한은 아래의 일반 규칙보다 우선한다.

특히 `INTERNAL_VALIDATOR`는 사내 코딩 에이전트이더라도 pull-only test agent다.
이 역할은 source·Task·STATUS·Gate를 수정하거나 branch/commit/push/PR을 수행하지 않는다.

## Session start

작업 전에 다음을 순서대로 수행한다.

1. 역할을 선언한다.
2. `git branch --show-current`, `git rev-parse HEAD`, `git status --short`를 확인한다.
3. 저장소 안의 `AGENTS.override.md` 존재 여부를 확인하고 있으면 보고한다.
4. `COMPANY_WRAPPER.md`를 읽는다.
5. `company/project-state.yml`을 읽는다.
6. `company/docs/PROJECT.md`, `company/docs/STATUS.md`, `company/docs/TRAPS.md`를 읽는다.
7. `current.task_path`가 가리키는 활성 Task를 읽는다.
8. 활성 Task의 `Required knowledge`만 추가로 읽는다.
9. install/build/start, native dependency, OS-specific 검증이 있으면 `company/docs/ENVIRONMENTS.md`를 읽고 실행환경 적합성을 먼저 판정한다.
10. 사내 Provider/model/Claude Code 요청이 있으면 `company/docs/SECURITY.md`와 `company/docs/INTERNAL_VALIDATION.md`를 읽고 host capability matrix를 먼저 판정한다.
11. 새 ChatGPT 설계 세션이면 `company/docs/DESIGN_SESSION_PLAYBOOK.md`의 Context checksum을 먼저 작성한다.

문서가 서로 충돌하면 임의로 해석하지 말고 작업을 중단한 뒤 충돌을 보고한다.

## Task integrity

- 한 세션에서는 활성 Task 하나만 다룬다.
- 하나의 Task는 구현·리뷰·수정 세션과 순차적인 Evidence PR을 여러 번 가질 수 있지만 다른 Task를 병행하지 않는다.
- Task의 In Scope, Out of Scope, Acceptance Criteria, Allowed Paths를 임의로 변경하지 않는다.
- 기준 변경이 필요하면 구현을 멈추고 변경 제안만 기록한다.
- `project-state.yml`의 current Task/Stage를 자동으로 전진시키지 않는다.
- Agent는 Recommendation과 Evidence를 작성할 수 있지만 Stage Gate와 최종 의사결정은 사람이 승인한다.
- 모델 순서를 기억이나 과거 문서로 추측하지 않고 활성 Task를 따른다. Serving availability에 따라 Gemma/GLM 순서가 바뀔 수 있다.

## Role-specific GitHub rules

### CHATGPT_ORCHESTRATOR

- GitHub canonical 문서, Task, STATUS, Gate, Issue/PR을 검토·정리할 수 있다.
- 사용자가 전달한 sanitized evidence만 사용한다.
- 사내 검증을 직접 실행한 것처럼 기록하지 않는다.
- 코드 구현은 원칙적으로 `EXTERNAL_CODEX` Task로 분리한다.

### EXTERNAL_CODEX

- 활성 Task가 허용한 branch/commit/push/PR을 수행할 수 있다.
- 사내 secret/raw evidence 없이 구현·외부 검증을 수행한다.
- Human Gate 없이 다음 Task/Stage를 활성화하지 않는다.

### INTERNAL_VALIDATOR

허용되는 Git 동작은 pull/read/검증에 한정한다.

```text
git fetch --prune origin
git pull --ff-only
git checkout --detach <approved SHA>
git rev-parse HEAD
git status --short
git diff --exit-code
```

다음은 금지한다.

```text
branch 생성
git add / commit / push
git merge / rebase / reset --hard
Issue / PR 작성 또는 수정
Task / STATUS / Gate / project-state 수정
제품 source/dependency/script/lockfile 수정
repository 안의 임시 report 생성
```

Internal Validator는 결과를 사람에게 sanitized text로 반환하고, GitHub 반영은 ChatGPT Orchestrator 또는 External Codex가 담당한다.

## Environment suitability

- Native Termux는 기본 개발 제어환경이다.
- `process.platform=android`인 native Termux 결과를 Windows/native-addon 증거로 간주하지 않는다.
- Stock install/typecheck/build와 Windows-specific 실행 증거는 기본적으로 사내 Windows의 test-only 절차에서 수집한다.
- 별도 PC, CI, PRoot Linux는 사내 Windows만으로 결과를 구분할 수 없을 때만 Task가 명시적으로 허용한다.
- 환경 조건이 맞지 않으면 이미 알려진 실패 명령을 반복하지 말고 preflight 결과만 보고한다.
- 환경 문제를 통과시키기 위한 source/dependency patch를 하지 않는다.
- 사내 Windows에서는 코드를 수정하지 않고 exact candidate commit만 검증한다.

## Internal host capabilities

사내 Windows PC의 권한을 다음 세 항목으로 분리한다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

- Provider/gateway/stream/tool Task에는 앞의 두 항목이 필요하다.
- Claude Code E2E에는 세 항목이 모두 필요하다.
- Credential이 존재한다는 사실만으로 현재 host에서 사용할 수 있다고 가정하지 않는다.
- Host/source scope가 `MISMATCH` 또는 `UNKNOWN`이면 real model request를 반복하지 않는다.
- Scope mismatch의 401/403은 `BLOCKED_CREDENTIAL_HOST_SCOPE`로 기록하며 protocol, model 또는 CCR source failure로 분류하지 않는다.
- Host scope가 `AUTHORIZED`로 확인된 뒤에도 401/403이 발생할 때만 일반 `AUTHORIZATION` failure를 검토한다.

## Architecture boundary

해결 우선순위는 다음과 같다.

1. CCR configuration
2. CCR 공식 extension/plugin
3. Company wrapper
4. 명시적으로 승인된 최소 Core patch

CCR upstream은 공통 Runtime이다. 대체 Gateway, Provider manager, protocol converter,
routing engine, model registry, control plane을 새로 만들지 않는다.
Core 변경은 활성 Task가 명시적으로 허용한 경우만 가능하며
`company/patches/CORE_PATCHES.md`에 기록한다.

## Change safety

- Task의 Allowed Paths 밖 파일을 수정하지 않는다.
- 관련 없는 기존 변경을 되돌리거나 포함하지 않는다.
- 신규 production dependency는 Task가 명시적으로 허용한 경우만 추가한다.
- 테스트를 삭제·skip·완화하여 PASS를 만들지 않는다.
- branch 생성, commit, push는 역할과 활성 Task가 모두 허용할 때만 한다.
- merge, rebase, force-push는 명시적 절차가 아닌 한 수행하지 않는다.
- Internal Validator의 working tree가 dirty하면 임의로 정리하지 않고 변경 경로만 보고한다.

## Security and evidence

- 실제 사내 endpoint, hostname/IP/proxy, credential, model ID, 권한/RPM,
  credential이 허용된 실제 PC/source identity, prompt, source, raw tool output,
  사용자 식별자, 계약 가격을 commit하지 않는다.
- 실행하지 않은 검사를 PASS로 기록하지 않는다.
- 사내에서만 확인 가능한 결과는 `READY_FOR_INTERNAL_VALIDATION`,
  `UNVERIFIED_INTERNAL`, 또는 `BLOCKED`로 기록한다.
- Raw internal evidence는 사내에만 보관한다.
- Key 공유, allowlist 우회, 승인되지 않은 proxy/tunnel/relay를 제안하거나 구현하지 않는다.

## Temporary work reports

- `AI_WORK_REPORT.md`는 영구 프로젝트 문서가 아니라 세션 중 임시 scratch/handoff다.
- 이 파일을 commit하지 않는다.
- External Codex가 사용한 유효한 내용은 활성 Task의 `Attempts`, `Evidence`, `Recommendation`에 누적한다.
- Internal Validator는 repository 안에 report를 만들지 않고 최종 sanitized text만 출력한다.
- 프로젝트 수준 요약만 `company/docs/STATUS.md`에 반영한다.
- 세션 종료 전 임시 보고서를 삭제하거나 repository 밖으로 이동한다.
- untracked report 때문에 working tree가 dirty한 상태로 세션을 종료하지 않는다.

## Session finish

### EXTERNAL_CODEX

활성 Task의 Attempts/Evidence를 누적 갱신하고 다음을 보고한다.

1. 세션 역할과 결과
2. 변경 파일
3. 실행한 명령과 테스트
4. Acceptance Criteria 상태
5. Core patch 여부
6. 미검증 항목과 내부 검증 명령
7. Host capability matrix와 blocker category
8. 알려진 제한과 Trap 후보
9. commit SHA 또는 working tree 상태
10. 임시 AI work report 정리 여부
11. 다음 Task를 시작하지 않았다는 확인

### INTERNAL_VALIDATOR

GitHub 파일을 수정하지 않고 `ROLES_AND_HANDOFF.md`의 Sanitized Internal Evidence 형식만 출력한다.
반드시 다음을 포함한다.

```text
Tested commit
수행한 명령/UI 단계
PASS / FAIL / BLOCKED와 exit code
Capability matrix
Product diff / final git status
Secrets/raw evidence exported: NO
Git write performed: NO
Next Task started: NO
```

### CHATGPT_ORCHESTRATOR

사용자에게 받은 sanitized evidence를 검토한 뒤 승인된 범위에서만 Task/STATUS/Gate/Issue를 갱신한다.
새 설계 세션이면 `DESIGN_SESSION_PLAYBOOK.md`의 종료 체크리스트를 따른다.

## Code review priorities

1. 역할·GitHub 권한 위반
2. Task 범위 초과
3. 거짓 PASS 또는 검증 불가능한 주장
4. CCR Native 기능의 중복 구현
5. 불필요한 Core 변경
6. 내부정보 유출
7. Credential 공유 또는 host allowlist 우회
8. Host-scope blocker와 protocol failure의 혼동
9. Acceptance Criteria 약화
10. 미래 Stage를 위한 과도한 abstraction
11. 실행환경과 증거 범위의 혼동
12. 테스트·rollback·문서 증거 누락
