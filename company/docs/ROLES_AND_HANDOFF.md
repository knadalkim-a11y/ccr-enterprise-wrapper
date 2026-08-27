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

역할별 제한은 일반적인 작업 지시보다 우선한다.
활성 Task가 더 넓은 권한을 암시하더라도 역할 제한을 자동으로 완화하지 않는다.

## 권한 매트릭스

| Capability | ChatGPT Orchestrator | External Android Codex | Internal Coding Agent | Human Gate Owner |
|---|---:|---:|---:|---:|
| Public repository 읽기 | Yes | Yes | Yes, pull/read only | Yes |
| Source 구현·수정 | 원칙적으로 Codex에 위임; 문서·상태 관리 가능 | Yes, 활성 Task 범위 | No | 승인/지시 |
| Branch/commit/push/PR | GitHub 문서·상태 작업 가능 | Yes | No | 필요 시 직접 수행 |
| Issue/Task/STATUS/Gate 갱신 | Sanitized evidence 검토 후 가능 | 외부 구현 evidence 범위 | No | 최종 승인 |
| 사내 명령·UI 검증 | No | No | Yes, test only | 직접 수행 가능 |
| 실제 endpoint/key/model/host 정보 접근 | No | No | 사내 로컬에서만 | 사내 정책 범위 |
| Stage Gate/다음 Task 최종 결정 | Recommendation only | Recommendation only | Recommendation only | Yes |

## CHATGPT_ORCHESTRATOR

책임:

- GitHub의 canonical 문서로 현재 맥락을 복원한다.
- 사용자가 전달한 sanitized internal evidence를 검토한다.
- 설계 선택, Task 분할, Acceptance Criteria, Issue/PR 상태를 정리한다.
- 승인된 문서·상태 변경을 GitHub에 반영한다.
- 코드 구현은 기본적으로 `EXTERNAL_CODEX`에 Task 단위로 위임한다.

금지:

- 실행하지 않은 사내 검증을 PASS로 기록
- 실제 secret/raw internal evidence 요청 또는 저장
- 내부 환경에 접근한 것처럼 주장
- 사람 승인 없이 Stage Gate 또는 다음 Task를 확정

## EXTERNAL_CODEX

기본 환경:

```text
Android / Termux
```

책임:

- 활성 Task 하나의 구현·리뷰·repair를 수행한다.
- branch, commit, push, PR을 사용한다.
- 공개 source, synthetic fixture, 외부에서 실행 가능한 검사를 사용한다.
- 내부 검증이 필요하면 exact candidate commit과 test-only 절차를 문서화한다.

금지:

- 사내 endpoint/key/model/host 정보를 요구하거나 commit
- 내부 raw log를 GitHub에 복사
- 현재 Task를 넘어 다음 Stage를 미리 구현
- Human Gate 없이 `project-state.yml`을 다음 Task로 전진

## INTERNAL_VALIDATOR

기본 환경:

```text
사내 Windows의 코딩 에이전트
```

이 역할은 이름과 무관하게 **코딩을 하지 않는 pull-only 검증자**다.

허용되는 Git 동작:

```powershell
git fetch --prune origin
git pull --ff-only origin <approved-branch>
git checkout --detach <TESTED_COMMIT_SHA>
git rev-parse HEAD
git status --short
git diff --exit-code ...
```

금지되는 Git/파일 동작:

```text
git switch -c / branch 생성
git add / commit / push
git merge / rebase / reset --hard
Issue / PR 생성·수정
Task / STATUS / Gate / project-state 수정
제품 source, dependency, script, lockfile 수정
repository 안에 AI_WORK_REPORT.md 또는 임시 파일 생성
```

책임:

- exact commit을 pull/checkout한다.
- Task에 문서화된 명령과 UI 검증만 수행한다.
- 실제 secret과 raw evidence는 사내 로컬에만 유지한다.
- 결과를 아래 Sanitized Handoff 형식으로 사람에게 반환한다.
- 실패 시 코드를 고치지 않고 failure category를 반환한다.

Working tree가 dirty하면 임의로 정리하지 않고 변경 경로만 보고한 뒤 중단한다.

## HUMAN_GATE_OWNER

책임:

- 사내 host, credential, 정책상 허용 범위를 결정한다.
- Internal Validator의 결과를 외부로 전달 가능한 형태로 정제한다.
- ChatGPT Orchestrator의 설계 제안과 Codex PR을 승인한다.
- Stage Gate와 다음 Task 활성화를 최종 결정한다.

## Canonical handoff 흐름

```text
ChatGPT Orchestrator
→ Task/검증 절차를 GitHub에 기록

External Codex
→ 구현 branch/PR과 외부 evidence

Human Gate Owner
→ 승인된 commit을 사내로 반입

Internal Validator
→ pull-only test + sanitized result

Human Gate Owner
→ sanitized result를 ChatGPT에 전달

ChatGPT Orchestrator
→ Task/STATUS/Gate/Issue 갱신
→ 필요 시 External Codex repair Task
```

Internal Validator가 GitHub 문서를 직접 갱신하지 않는다.
External Codex가 사내 raw evidence를 직접 받지 않는다.

## Sanitized Internal Evidence 최소 형식

```text
Role: INTERNAL_VALIDATOR
Task ID:
Tested commit:
Environment alias:
Capability matrix: YES / NO / UNKNOWN
Commands or UI steps performed:
Exit codes / PASS / FAIL / BLOCKED:
Protocol/provider/model aliases:
Failure classification:
Reproducibility:
Product diff / final git status:
Sanitized observation:
Secrets/raw evidence exported: NO
Git write performed: NO
Next Task started: NO
```

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

- Internal Validator에게 commit/push 또는 source 수정이 지시됨
- External Codex에게 실제 사내 secret/raw evidence가 필요함
- ChatGPT가 실행하지 않은 내부 검사를 PASS로 기록하려 함
- Human Gate 없이 다음 Task/Stage로 전진하려 함
- 서로 다른 역할이 같은 branch 또는 같은 Task 상태를 동시에 수정하려 함
