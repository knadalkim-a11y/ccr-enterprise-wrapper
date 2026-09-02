# Roles and Evidence Handoff

## 목적

이 프로젝트는 서로 다른 권한과 실행환경을 가진 주체가 협업한다.
역할을 섞으면 사내 비밀이 외부로 이동하거나, 사내 검증 환경에서 코드가 분기되거나,
GitHub 상태와 실제 검증 결과가 충돌할 수 있다.

모든 세션은 시작할 때 자신의 역할을 아래 중 하나로 명시한다.

```text
CHATGPT_ORCHESTRATOR
EXTERNAL_CODEX
INTERNAL_VALIDATOR
HUMAN_GATE_OWNER
```

역할별 제한은 일반 작업 지시보다 우선한다.

## 권한 매트릭스

| Capability | ChatGPT Orchestrator | External Android Codex | Internal Validator | Human Gate Owner |
|---|---:|---:|---:|---:|
| Public repository 읽기 | Yes | Yes | Yes, pull/read only | Yes |
| Source 구현·수정 | 기본적으로 Codex에 위임 | 활성 Task 범위에서 Yes | No | 승인/지시 |
| Branch/commit/push/PR | docs/state 작업 가능 | Yes | No | 필요 시 직접 수행 |
| Issue/Task/STATUS/Gate 갱신 | Sanitized evidence 검토 후 가능 | 외부 구현 evidence 범위 | No | 최종 승인 |
| 사내 명령·UI 검증 | No | No | Yes, test only | 직접 수행·보조 가능 |
| 실제 endpoint/key/model/host 접근 | No | No | 사내 로컬에서만 | 사내 정책 범위 |
| Task 선택·Stage Gate 최종 결정 | Recommendation only | Recommendation only | No | Yes |

## `CHATGPT_ORCHESTRATOR`

책임:

- GitHub canonical 문서로 현재 맥락을 복원한다.
- 검증 질문을 Task 파일 단위로 나눈다.
- `primary_actor`, `execution_mode`, candidate contract, merge policy를 정한다.
- 사용자가 전달한 sanitized internal evidence를 검토한다.
- 승인된 Task/STATUS/Gate/Issue/docs를 GitHub에 반영한다.
- 코드 구현은 기본적으로 `EXTERNAL_CODEX`에 위임한다.

금지:

- 실행하지 않은 사내 검증을 PASS로 기록
- secret/raw internal evidence 요청 또는 저장
- 내부 환경에 접근한 것처럼 주장
- Human Gate 없이 다음 Task/Stage 확정

## `EXTERNAL_CODEX`

기본 환경:

```text
Android / Termux
```

책임:

- 활성 Task 하나의 구현·review·repair를 수행한다.
- branch, commit, push, PR을 사용한다.
- 공개 source, synthetic fixture, 외부 검사를 사용한다.
- 내부 검증이 필요하면 코드와 test instruction을 같은 candidate에 포함한다.
- exact PR head SHA와 외부 Evidence를 반환한다.

금지:

- 사내 endpoint/key/model/host 요구 또는 commit
- 내부 raw log를 GitHub에 복사
- 다음 Stage를 미리 구현
- Human Gate 없이 `project-state.yml` 전진
- 내부 PASS가 필요한 PR의 자동 병합

## `INTERNAL_VALIDATOR`

기본 환경:

```text
사내 Windows의 코딩 에이전트
```

이 역할은 이름과 무관하게 **코딩하지 않는 pull-only 검증자**다.

### 허용되는 Git 동작

```powershell
git init --bare <TASK_APPROVED_DISPOSABLE_PATH>
git fetch --no-tags <CANONICAL_URL> +<APPROVED_REF>:<APPROVED_LOCAL_REF>
git show <APPROVED_INSTRUCTION_SHA>:<TASK_PATH_OR_TASK_LISTED_REQUIRED_KNOWLEDGE_PATH>
git archive --format=zip --output=<APPROVED_LOCAL_PATH> <TASK_APPROVED_COMMIT_SHA>
git rev-parse / cat-file / hash-object without -w / merge-base
git diff --exit-code -- <approved-paths>
git diff --name-only -z --no-renames <approved-base> <approved-candidate> --
```

이 동작은 활성 Task가 명시적으로 허용하고 repository 밖의 Task-approved local
nonce workspace일 때만 가능하다. Exact head를 test-only로 materialize하며
source/Git history/GitHub write는 하지 않지만 disposable local object/ref/file은
생성한다. 기존 shared checkout의 `origin`, fetchspec, branch 또는 HEAD를 권한
근거로 사용하지 않으며 `pull`, `--prune`, shared checkout 변경은 기본 금지다.

### 금지되는 동작

```text
Task 또는 다음 Task 자율 선택
branch 생성
git add / commit / push
git merge / rebase / reset --hard
Issue / PR 생성·수정
Task / STATUS / Gate / project-state 수정
제품 source, dependency, script, lockfile 수정
repository 안에 AI_WORK_REPORT.md 또는 임시 파일 생성
```

책임:

- Human Gate Owner가 승인한 Task 하나와 exact SHA만 실행한다.
- Task에 문서화된 명령·UI 단계만 수행한다.
- Human Step 직전에 멈추고 사람의 로컬 작업을 기다린다.
- 실제 secret과 raw evidence는 사내 로컬에 유지한다.
- 실패 시 코드를 고치지 않고 failure category를 반환한다.
- Sanitized Evidence를 반환하고 다음 Task를 시작하지 않는다.

Task-approved disposable path가 이미 존재하거나 비어 있지 않으면 임의로
정리하지 않고 중단한다. 기존 shared checkout의 working tree 상태는
candidate 권한 또는 검증 입력으로 사용하지 않는다.

## `HUMAN_GATE_OWNER`

책임:

- 사내 host, credential, 정책 허용 범위를 결정한다.
- Internal Validator가 수행할 Task와 candidate/instruction SHA를 승인한다.
- Human-assisted Task의 실제 UI·credential·승인 Step을 수행한다.
- 에이전트에는 secret이 아니라 최소 완료 상태만 반환한다.
- Internal Validator 결과를 외부 전달 가능한 sanitized 형태로 정제한다.
- Stage Gate와 다음 Task 활성화를 최종 결정한다.

## Canonical handoff 흐름

```text
1. CHATGPT_ORCHESTRATOR
   → Task spec와 검증 절차를 GitHub에 기록

2. EXTERNAL_CODEX — 구현이 필요한 경우
   → 구현 PR + exact candidate SHA

3. HUMAN_GATE_OWNER
   → Task, instruction SHA, candidate SHA 승인

4. INTERNAL_VALIDATOR
   → pull-only test + 필요한 Human Step 대기 + sanitized result

5. HUMAN_GATE_OWNER
   → sanitized result를 ChatGPT에 전달

6. CHATGPT_ORCHESTRATOR
   → Task/STATUS/Gate/Issue 갱신
   → 필요 시 External Codex repair Task
```

Internal Validator가 GitHub 문서를 직접 갱신하지 않는다.
External Codex가 사내 raw evidence를 직접 받지 않는다.

Source verification 단계의 에이전트 지시 거부, ref 부재 또는 SHA 불일치는
`PRE_EXECUTION_HANDOFF_BLOCKED` 사건이다. Approved Task-phase command/runtime UI·A0가
시작되지 않았다면 Attempt를 소비하거나 formal Task result/category로
기록하지 않는다. 다만 이미 실행한 source-verification command와 disposable
local write는 Evidence에 사실대로 남긴다.

## Candidate / instruction handoff

모든 사내 검증 handoff에는 다음이 포함돼야 한다.

```text
Canonical repository URL
Candidate fetch ref
Task path
instruction_sha
candidate_sha
Authorized phase
merge policy
required capability matrix
execution mode
```

### 권장 단일 SHA

```text
instruction_sha == candidate_sha == PR head SHA
```

제품 변경과 그 제품을 검증할 지침이 같은 immutable commit에 있다.

### 두 SHA 예외

Validation-only Task에서 과거 product commit을 재사용하는 경우:

```text
instruction_sha: 최신 승인 Task 지침
candidate_sha: 실제 tested product commit
product tree equivalence: 비교 범위와 결과
```

두 SHA가 다르면 Evidence에도 둘 다 남긴다.

### Human-approved validation overlay 예외

활성 Task가 명시적으로 승인할 때만 다음을 허용한다.

```text
candidate_role: validation_overlay
candidate_sha == instruction_sha == exact control/instruction PR head
tested_product_sha: exact prior validated product commit
protected-path equivalence: exact scope/result
build plane: full tested_product_sha archive
```

Candidate는 이 예외에서 제품 commit이 아니다. Overlay SHA, tested product SHA와
equivalence를 Handoff/Evidence에서 분리하며 candidate whole-tree equivalence를
주장하지 않는다.

## Human-assisted handoff

Task는 Actor Step을 순서대로 표시한다.

```text
A1 [INTERNAL_VALIDATOR]
→ Preflight / service start

H1 [HUMAN_GATE_OWNER]
→ Key 입력 / UI 선택 / 승인

A2 [INTERNAL_VALIDATOR]
→ 결과 확인 / cleanup / sanitized evidence
```

규칙:

- Internal Validator는 H1 전에 멈춘다.
- Human Gate Owner는 실제 key/endpoint/model ID를 agent output에 복사하지 않는다.
- Agent에는 `COMPLETED / NOT_COMPLETED`, `PASS / FAIL / BLOCKED`, sanitized category만 반환한다.
- Human Step 완료가 다음 Task 승인까지 의미하지 않는다.

## 코드 PR 병합 handoff

```text
internal_validation: required
merge_policy: internal_pass_required
```

이면 exact PR head의 내부 PASS 전 merge하지 않는다.
Repair commit으로 PR head가 바뀌면 변경 영향에 따라 재검증한다.

Validation-only Task에는 제품 PR이 없으며, 사내 결과를 받은 뒤 ChatGPT Orchestrator가 docs/state 변경을 별도 반영한다.

## Sanitized Internal Evidence 최소 형식

Internal Validator는 사람이 이해할 수 있는 평문 설명을 먼저 제공하고, 마지막에
수기 전달용 compact capsule을 덧붙인다. Capsule은 설명을 대체하지 않는다.
`RAW=NO`는 실행 과정을 숨겼다는 뜻이 아니라 sanitized handoff/capsule에
secret/raw 내부 자료를 싣지 않았다는 뜻이다. 허용된 subprocess/network의
미관측 behavior에 대한 host-wide attestation은 아니다.

```text
Role: INTERNAL_VALIDATOR
Task ID:
Session role:
Instruction SHA:
Candidate SHA:
Environment alias: <sanitized Human-supplied label; not hostname/user/device ID>
Capability matrix: YES / NO / UNKNOWN
Commands or UI steps performed:
Human steps completed:
Exit codes / PASS / FAIL / BLOCKED:
Protocol/provider/model aliases:
Failure classification:
Reproducibility:
Product diff / fingerprint:
Existing shared checkout final status: NOT_APPLICABLE / CLEAN / DIRTY
Sanitized observation:
Secrets/raw evidence included in sanitized handoff: NO
Agent-requested GitHub/remote write: NONE / YES
Agent-authored source/history: NONE / YES
Agent-targeted existing shared checkout mutation: NONE / YES
Disposable local Git/workspace write: YES / NO
Agent-requested runtime/config/service action: NONE / YES
Unobserved child side effects: NOT_APPLICABLE / NOT_OBSERVED / NOT_CLAIMED
Next Task started: NO
```

Lifecycle/subprocess가 허용된 경우 이 Evidence는 host-wide 무변경 attestation이
아니다. Agent가 요청하거나 관찰한 범위와 관찰하지 않은 child effect를 분리한다.

외부로 반환하지 않는 항목:

```text
실제 endpoint, API key, model ID
실제 hostname, IP, proxy, egress
Windows 사용자명, 사번, 조직명
management URL/token
raw request/response, prompt, source, tool result
raw CCR DB/log/trace
```

## 역할 충돌 처리

다음 상황에서는 실행하지 않고 충돌을 보고한다.

- Internal Validator에게 source 수정, commit/push, Task 선택이 지시됨
- Approved candidate/instruction SHA가 없음
- External Codex에게 실제 사내 secret/raw evidence가 필요함
- ChatGPT가 실행하지 않은 내부 검사를 PASS로 기록하려 함
- Human Gate 없이 다음 Task/Stage로 전진하려 함
- 서로 다른 역할이 같은 Task 상태나 branch를 동시에 수정하려 함
