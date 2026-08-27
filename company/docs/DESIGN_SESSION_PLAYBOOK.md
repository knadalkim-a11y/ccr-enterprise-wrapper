# Stateless Design Session Playbook

## 목적

새 ChatGPT 설계 세션은 이전 대화의 길이, 기억, 요약에 의존하지 않는다.
이 저장소의 canonical 문서만 읽고도 현재 상태, 이미 결정된 사항, 미해결 질문,
활성 Task와 정확한 다음 행동을 복원할 수 있어야 한다.

이 문서는 현재 상태를 복제하는 장문의 세션 요약이 아니다.
현재 상태는 `project-state.yml`, `STATUS.md`, 활성 Task에만 기록하고,
이 문서는 새 세션이 그 정보들을 읽고 판단하는 절차를 정의한다.

## 새 설계 세션 역할

새 설계 세션은 다음 역할로 시작한다.

```text
Role: CHATGPT_ORCHESTRATOR
```

역할 경계는 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.

## Canonical source map

| 질문 | Source of Truth |
|---|---|
| 지금 어느 Stage/Task인가 | `company/project-state.yml` |
| 사람이 이해할 현재 상태와 blocker | `company/docs/STATUS.md` |
| 무엇을 만들고 무엇을 만들지 않는가 | `company/docs/PROJECT.md` |
| 장기 Stage와 Gate 구조 | `company/docs/STAGES.md` |
| 되돌리기 어려운 승인 결정 | `company/docs/DECISIONS.md` |
| 현재 Task의 범위·증거·다음 판단 | `project-state.yml`의 `current.task_path` |
| 반복 함정 | `company/docs/TRAPS.md` |
| 역할과 GitHub 권한 | `company/docs/ROLES_AND_HANDOFF.md` |
| 사내 검증 규칙 | `company/docs/INTERNAL_VALIDATION.md` |
| 비밀·Telemetry 경계 | `company/docs/SECURITY.md` |
| 설치/Fleet/절감 설계 | `company/docs/FLEET_OPERATING_MODEL.md` |
| CCR 원본 기능 | 활성 Task가 지정한 upstream source/docs |

GitHub Issue와 PR은 전달·리뷰 수단이다.
Task 파일과 위 canonical 문서보다 우선하지 않는다.

## 새 세션 읽기 순서

1. `COMPANY_WRAPPER.md`
2. `company/project-state.yml`
3. `company/docs/STATUS.md`
4. `company/docs/PROJECT.md`
5. `company/docs/DECISIONS.md`
6. `company/docs/STAGES.md`
7. `company/docs/ROLES_AND_HANDOFF.md`
8. `project-state.yml`의 `current.task_path`
9. 활성 Task의 `Required knowledge`
10. 관련이 있을 때만 `TRAPS.md`, `SECURITY.md`, `INTERNAL_VALIDATION.md`, `FLEET_OPERATING_MODEL.md`

모든 문서를 매번 전부 읽지 않는다.
현재 Task와 설계 질문에 필요한 canonical 문서만 추가로 읽는다.

## Context checksum

새 세션은 설계나 작업 지시 전에 다음을 먼저 보고한다.

```text
Repository main SHA:
Wrapper version:
Current Stage:
Current Task ID/path:
Current status/blocker:
Last passed Gate:
Validated product commit:
Active model/protocol decision:
Open risks relevant to current Task:
Exact next action:
Role boundaries for this action:
```

이 값들이 문서끼리 충돌하면 임의로 해석하지 않는다.
충돌한 파일과 값을 먼저 보고하고, 문서 수정 제안만 한다.

## 사실·결정·제안의 구분

새 세션은 모든 내용을 아래 셋 중 하나로 구분한다.

```text
CONFIRMED FACT
→ 실제 code/doc/internal sanitized evidence로 확인됨

ACCEPTED DECISION
→ DECISIONS.md 또는 Human Gate에 기록됨

PROPOSAL / OPEN QUESTION
→ 아직 검증 또는 사람 승인 전
```

과거 대화에서 논의됐지만 GitHub에 반영되지 않은 내용은 자동으로 승인된 결정이 아니다.
필요하면 제안으로 다시 검토하고, 승인 후 canonical 문서에 기록한다.

## 설계 변경 기록 위치

- 현재 Task의 범위·증거 변화: 활성 Task
- 현재 blocker·다음 행동 변화: `STATUS.md`
- 기계 판독 상태 변화: `project-state.yml`
- 여러 Task에 영향을 주는 결정: `DECISIONS.md`
- Stage/Gate 구조 변화: `STAGES.md`
- 제품 목적·책임 경계 변화: `PROJECT.md`
- 반복 가능한 함정: `TRAPS.md`
- 보안·정보 경계: `SECURITY.md`
- 역할·handoff 변화: `ROLES_AND_HANDOFF.md`

같은 사실을 여러 문서에 장문으로 복제하지 않는다.
상위 문서는 요약과 링크만 갖고, 상세 Evidence는 Task에 둔다.

## 설계 세션 종료 체크리스트

세션에서 실제 결정이나 상태 변경이 있었다면 종료 전에 확인한다.

1. 활성 Task의 사실과 Evidence가 최신인가
2. `STATUS.md`의 Current/Next action이 실제 상태와 일치하는가
3. `project-state.yml`이 Task/STATUS와 일치하는가
4. 새로운 승인 결정이 `DECISIONS.md`에 기록됐는가
5. 새 함정이 등록 조건을 충족할 때만 `TRAPS.md`에 추가됐는가
6. Issue/PR이 canonical Task를 정확히 가리키는가
7. 다음 Task/Stage는 Human Gate 승인 없이 전진하지 않았는가
8. 실제 endpoint/key/model/host/raw evidence가 tracked content에 없는가
9. Internal Validator에게 GitHub write 또는 source 수정이 요구되지 않았는가
10. 새 세션이 읽을 정확한 다음 행동이 한 문장으로 남아 있는가

변경이 없었다면 억지로 문서를 수정하지 않는다.

## 긴 대화의 처리 원칙

- Chat history는 참고 자료이며 Source of Truth가 아니다.
- 대화가 길어졌다고 별도의 거대한 `SESSION_SUMMARY.md`를 누적하지 않는다.
- 중요한 내용은 발생 즉시 알맞은 canonical 문서로 승격한다.
- 임시 reasoning, 브레인스토밍, 폐기된 안은 GitHub에 모두 남기지 않는다.
- 폐기된 안이 미래 혼동을 일으킬 때만 `DEFERRED` 또는 Decision 기록으로 남긴다.

## 새 설계 세션 시작용 프롬프트

아래를 새 ChatGPT 세션에 복사할 수 있다.

```text
Role: CHATGPT_ORCHESTRATOR

Repository:
knadalkim-a11y/ccr-enterprise-wrapper

이전 ChatGPT 대화의 기억에 의존하지 말고 GitHub를 Source of Truth로 사용하라.
먼저 다음을 순서대로 읽어라.

1. COMPANY_WRAPPER.md
2. company/project-state.yml
3. company/docs/STATUS.md
4. company/docs/PROJECT.md
5. company/docs/DECISIONS.md
6. company/docs/STAGES.md
7. company/docs/ROLES_AND_HANDOFF.md
8. project-state.yml의 current.task_path
9. 활성 Task의 Required knowledge

설계나 실행 지시 전에 다음 Context checksum을 보고하라.

- main SHA
- Current Stage/Task/status/blocker
- Last passed Gate와 validated product commit
- Confirmed facts
- Accepted decisions
- Open questions/risks
- Exact next action
- 이번 행동에 참여하는 주체별 역할과 GitHub 권한

문서가 충돌하면 작업을 진행하지 말고 충돌을 먼저 보고하라.
사내 코딩 에이전트는 pull-only INTERNAL_VALIDATOR이며 GitHub write나 source 수정을 시키지 마라.
Human Gate 승인 없이 다음 Task/Stage를 활성화하지 마라.
```

## 현재 대화에서 새로운 사실을 받았을 때

사용자가 사내 검증 결과를 붙이면:

1. `ROLES_AND_HANDOFF.md`의 sanitized evidence 형식인지 확인한다.
2. 기존 Task Acceptance Criteria와 모순 여부를 검토한다.
3. PASS/FAIL/BLOCKED를 환경·권한·protocol·quality로 분리한다.
4. 불완전한 증거를 전체 Gate PASS로 확대하지 않는다.
5. 승인된 범위에서 Task/STATUS/Gate/Issue를 GitHub에 갱신한다.
6. 다음 내부 검증은 작은 검증 질문 하나로 나눈다.
