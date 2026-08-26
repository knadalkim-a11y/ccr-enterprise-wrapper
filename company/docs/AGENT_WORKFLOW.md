# Coding Agent Workflow

## 기본 단위

```text
One Task = one validation question
One Session = implementation / review / repair / validation 중 한 번의 시도
One active attempt PR at a time
```

하나의 Task는 여러 Session과 순차적인 Evidence PR을 가질 수 있다.
환경 때문에 한 Attempt의 증거를 먼저 main에 남겨야 할 경우 Task를 닫지 않고 다음 Attempt를 새 짧은 branch/PR로 이어갈 수 있다.
다른 Task를 동시에 진행하지 않는다.

## 상태 흐름

```text
PLANNED → IN_PROGRESS → EXTERNAL_PASS
→ READY_FOR_INTERNAL_VALIDATION
→ INTERNAL_PASS / INTERNAL_FAIL / BLOCKED
→ HUMAN_DECISION → DONE / RETRY / CANCELLED
```

환경 preflight만 실패한 Attempt는 Task 전체 상태를 `BLOCKED`로 바꾸지 않는다.
Task는 `PLANNED`를 유지하고 Attempt 결과를 `BLOCKED_ENVIRONMENT`로 누적한다.
Bootstrap처럼 내부 검증이 필요 없는 Task는 `EXTERNAL_PASS → HUMAN_DECISION`으로 진행한다.

## 환경 역할

```text
Native Termux
→ Git, 문서, Task, 리뷰, 에이전트 제어

Termux + PRoot Linux
→ install, typecheck, build:assets, 비-GUI smoke의 우선 runner

사내 Windows
→ 실제 배포 대상의 test-only 검증
```

자세한 기준은 `company/docs/ENVIRONMENTS.md`를 따른다.
개인 Windows/Linux PC나 Codex Cloud는 초기 필수가 아니다.
다만 Windows-specific 제품 증거는 최종적으로 사내 Windows에서 확보한다.

## 세션 시작

1. root와 `company/`의 `AGENTS.md`를 따른다.
2. `project-state.yml`과 활성 Task를 읽는다.
3. Task의 Required knowledge만 추가로 읽는다.
4. branch/HEAD/working tree를 보고한다.
5. 활성 Task의 범위와 Stop condition을 한 문단으로 재진술한다.
6. 실행 명령이 있으면 OS, architecture, `process.platform`, Node/npm 버전을 확인한다.
7. 환경이 Task 증거에 부적합하면 명령을 반복하지 않고 preflight 결과만 보고한다.

## 구현 세션

- 가장 작은 변경으로 Acceptance Criteria를 충족한다.
- 다음 Stage를 위한 추상화를 미리 추가하지 않는다.
- 실행하지 못한 검사는 명시적으로 남긴다.
- 사내 검증 명령은 product code 수정 없이 실행 가능해야 한다.
- 환경 문제를 source/dependency 수정으로 우회하지 않는다.

## 리뷰 세션

구현 세션과 별도 세션으로 수행하며 다음을 우선 검토한다.

1. Scope/Allowed Paths 위반
2. CCR 기능 중복 구현
3. Core patch와 신규 dependency
4. 거짓 PASS와 기준 약화
5. 실행환경과 증거 범위의 혼동
6. 보안 경계 위반
7. rollback·Evidence·검증 명령 누락

## AI Work Report

세션 UI 또는 로컬에서 `AI_WORK_REPORT.md`를 임시로 사용할 수 있으나 공식 기록은 아니다.

```text
임시 report
→ 필요한 내용을 활성 Task Attempts/Evidence에 반영
→ STATUS에는 프로젝트 수준 요약만 반영
→ 세션 종료 전 삭제 또는 repository 밖 이동
```

report 파일은 commit하지 않으며, working tree에 untracked 상태로 남기지 않는다.

## 사내 FAIL 반환

사내에서는 수정하지 않는다. 정확한 candidate commit, 재현률, 일반화된 실패 분류,
sanitized observation만 동일 Task의 repair session으로 반환한다.
사내 Windows 검증은 개발이 아니라 target-environment evidence 수집이다.

## 종료

Task의 Attempts를 누적하고 Codex Recommendation을 기록한다.
사람이 Human Decision과 다음 Task 활성화를 수행한다.
세션 종료 전 임시 report와 working tree 상태를 확인한다.
