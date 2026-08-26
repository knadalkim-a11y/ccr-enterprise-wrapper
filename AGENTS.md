# Repository Agent Instructions

## Session start

작업 전에 다음을 순서대로 수행한다.

1. `git branch --show-current`, `git rev-parse HEAD`, `git status --short`를 확인한다.
2. 저장소 안의 `AGENTS.override.md` 존재 여부를 확인하고 있으면 보고한다.
3. `COMPANY_WRAPPER.md`를 읽는다.
4. `company/project-state.yml`을 읽는다.
5. `company/docs/PROJECT.md`, `company/docs/STATUS.md`, `company/docs/TRAPS.md`를 읽는다.
6. `current.task_path`가 가리키는 활성 Task를 읽는다.
7. 활성 Task의 `Required knowledge`만 추가로 읽는다.
8. install/build/start, native dependency, OS-specific 검증이 있으면 `company/docs/ENVIRONMENTS.md`를 읽고 실행환경 적합성을 먼저 판정한다.

문서가 서로 충돌하면 임의로 해석하지 말고 작업을 중단한 뒤 충돌을 보고한다.

## Task integrity

- 한 세션에서는 활성 Task 하나만 다룬다.
- 하나의 Task는 구현·리뷰·수정 세션과 순차적인 Evidence PR을 여러 번 가질 수 있지만 다른 Task를 병행하지 않는다.
- Task의 In Scope, Out of Scope, Acceptance Criteria, Allowed Paths를 임의로 변경하지 않는다.
- 기준 변경이 필요하면 구현을 멈추고 변경 제안만 기록한다.
- `project-state.yml`의 current Task/Stage를 자동으로 전진시키지 않는다.
- Codex는 Recommendation과 Evidence를 작성할 수 있지만 Stage Gate와 최종 의사결정은 사람이 승인한다.

## Environment suitability

- Native Termux를 기본 제어환경으로 사용하되, 환경이 Task의 증거 조건을 만족하는지 명령 실행 전에 확인한다.
- `process.platform=android`인 native Termux 결과를 일반 Linux/Windows native dependency 증거로 간주하지 않는다.
- 외부 install/typecheck/build는 우선 Termux의 PRoot Linux + Node 22에서 시도할 수 있다.
- PRoot 결과는 Electron GUI, installer 또는 Windows 동작의 증거가 아니다.
- 최종 대상이 사내 Windows이므로 Windows-specific 항목은 사내 test-only 절차에서 반드시 검증한다.
- 환경 조건이 맞지 않으면 이미 알려진 실패 명령을 반복하지 말고 preflight 결과만 보고한다.
- 환경 문제를 통과시키기 위한 source/dependency patch를 하지 않는다.

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
- branch 생성, commit, push는 활성 Task 또는 사용자 지시가 허용할 때만 한다.
- merge, rebase, force-push는 활성 Bootstrap Task의 명시적 절차가 아닌 한 수행하지 않는다.

## Security and evidence

- 실제 사내 endpoint, hostname/IP/proxy, credential, model ID, 권한/RPM,
  prompt, source, raw tool output, 사용자 식별자, 계약 가격을 commit하지 않는다.
- 실행하지 않은 검사를 PASS로 기록하지 않는다.
- 사내에서만 확인 가능한 결과는 `READY_FOR_INTERNAL_VALIDATION`,
  `UNVERIFIED_INTERNAL`, 또는 `BLOCKED`로 기록한다.
- Raw internal evidence는 사내에만 보관한다.

## Temporary work reports

- `AI_WORK_REPORT.md`는 영구 프로젝트 문서가 아니라 세션 중 임시 scratch/handoff다.
- 이 파일을 commit하지 않는다.
- 유효한 내용은 활성 Task의 `Attempts`, `Evidence`, `Recommendation`에 누적한다.
- 프로젝트 수준 요약만 `company/docs/STATUS.md`에 반영한다.
- 세션 종료 전 임시 보고서를 삭제하거나 repository 밖으로 이동한다.
- untracked report 때문에 working tree가 dirty한 상태로 세션을 종료하지 않는다.

## Session finish

활성 Task의 Attempts/Evidence를 누적 갱신하고 다음을 보고한다.

1. 세션 역할과 결과
2. 변경 파일
3. 실행한 명령과 테스트
4. Acceptance Criteria 상태
5. Core patch 여부
6. 미검증 항목과 내부 검증 명령
7. 알려진 제한과 Trap 후보
8. commit SHA 또는 working tree 상태
9. 임시 AI work report 정리 여부
10. 다음 Task를 시작하지 않았다는 확인

## Code review priorities

1. Task 범위 초과
2. 거짓 PASS 또는 검증 불가능한 주장
3. CCR Native 기능의 중복 구현
4. 불필요한 Core 변경
5. 내부정보 유출
6. Acceptance Criteria 약화
7. 미래 Stage를 위한 과도한 abstraction
8. 실행환경과 증거 범위의 혼동
9. 테스트·rollback·문서 증거 누락
