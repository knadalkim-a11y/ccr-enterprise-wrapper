# Coding Agent Workflow

## 기본 단위

```text
One Task = one validation question = one short branch/PR
One Session = implementation / review / repair 중 한 번의 시도
```

하나의 Task는 여러 Session을 가질 수 있다. 다른 Task를 동시에 진행하지 않는다.

## 상태 흐름

```text
PLANNED → IN_PROGRESS → EXTERNAL_PASS
→ READY_FOR_INTERNAL_VALIDATION
→ INTERNAL_PASS / INTERNAL_FAIL / BLOCKED
→ HUMAN_DECISION → DONE / RETRY / CANCELLED
```

Bootstrap처럼 내부 검증이 필요 없는 Task는 `EXTERNAL_PASS → HUMAN_DECISION`으로 진행한다.

## 세션 시작

1. root와 `company/`의 `AGENTS.md`를 따른다.
2. `project-state.yml`과 활성 Task를 읽는다.
3. Task의 Required knowledge만 추가로 읽는다.
4. branch/HEAD/working tree를 보고한다.
5. 활성 Task의 범위와 Stop condition을 한 문단으로 재진술한다.

## 구현 세션

- 가장 작은 변경으로 Acceptance Criteria를 충족한다.
- 다음 Stage를 위한 추상화를 미리 추가하지 않는다.
- 실행하지 못한 검사는 명시적으로 남긴다.
- 사내 검증 명령은 product code 수정 없이 실행 가능해야 한다.

## 리뷰 세션

구현 세션과 별도 세션으로 수행하며 다음을 우선 검토한다.

1. Scope/Allowed Paths 위반
2. CCR 기능 중복 구현
3. Core patch와 신규 dependency
4. 거짓 PASS와 기준 약화
5. 보안 경계 위반
6. rollback·Evidence·검증 명령 누락

## 사내 FAIL 반환

사내에서는 수정하지 않는다. 정확한 candidate commit, 재현률, 일반화된 실패 분류,
sanitized observation만 동일 Task의 repair session으로 반환한다.

## 종료

Task의 Attempts를 누적하고 Codex Recommendation을 기록한다.
사람이 Human Decision과 다음 Task 활성화를 수행한다.
