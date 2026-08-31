# Company CCR Wrapper

이 저장소는 `musistudio/claude-code-router`를 공통 Runtime으로 사용하고,
사내 설치·호환성 검증·진단·품질 개입에 필요한 Company layer만 추가한다.

## 핵심 방향

```text
CCR upstream
= Gateway · protocol conversion · Provider/model · Native routing
  retry/fallback · streaming · tools · observability · extensions

Wrapper V1
= 사내 설치·연결·격리·호환성·진단·검증 기반

Wrapper V2
= CCR Native를 유지하면서 검증된 반복 품질 실패에만 개입
```

정책(`native`, `force-model`, `static-economy`, `adaptive-quality`)은 제품 버전과 별개다.

## Claude Code 실행 계약

기존 Enterprise Claude 환경을 덮어쓰지 않고 실행 경로를 분리한다.

```text
claude
→ 기존 Enterprise Claude Code
→ 기존 settings/auth/models

company-claude
→ CCR 전용 Claude Code
→ isolated CCR profile + Local CCR + internal model
```

`company-claude`는 V1의 논리적 명령 이름이다. 실제 `.cmd`, PowerShell launcher 또는 패키지는 후속 구현 Task에서 확정한다.

CCR service ON/OFF는 일반 `claude`의 설정을 자동 전환하지 않는다.
이미 실행 중인 Company 세션도 CCR가 중지되면 Enterprise/Sonnet으로 자동 fallback하지 않고 명확히 실패한다.

V1 Claude Code profile:

```text
Effect scope: Only opened from CCR
Internal scope: ccr
Entry mode: CLI only
System default: prohibited
Claude App/Desktop CCR integration: deferred
```

`Only opened from CCR`는 Claude Code settings를 격리하지만, Stock CCR management start/config save는 별도로 `%LOCALAPPDATA%\Claude-3p`를 동기화할 수 있다.
따라서 CCR service/admin process도 process-local sandbox `LOCALAPPDATA`에서 실행해야 한다.

상세 계약은 `company/docs/CLAUDE_CODE_ISOLATION.md`를 따른다.

## 실행환경과 권한

```text
Native Termux
→ 기본 개발 제어, Git, 문서, Task, PR, 리뷰

사내 Windows
→ install, typecheck, build, 실행, 사내 연동, Claude Code E2E
```

사내 Windows host는 다음 capability를 독립적으로 가진다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

Provider 검증에는 앞의 두 조건이 필요하고 Claude Code E2E에는 세 조건이 모두 필요하다.
Credential이 다른 host/source scope에 묶여 발생한 401은 protocol failure가 아니라 `BLOCKED_CREDENTIAL_HOST_SCOPE`다.

개인 Windows/Linux PC와 cloud runner는 초기 필수가 아니다.
사내 Windows에서 exact candidate를 build하고 실행하는 것은 개발이 아니라 test-only 검증이다.
자세한 기준은 `company/docs/ENVIRONMENTS.md`를 따른다.

## 협업 역할

```text
CHATGPT_ORCHESTRATOR
→ 설계, 상태 복원, sanitized evidence 검토, GitHub canonical 문서 관리

EXTERNAL_CODEX
→ Android/Termux에서 Task 단위 구현·리뷰·branch/commit/PR

INTERNAL_VALIDATOR
→ 사내 Windows에서 pull-only test; GitHub write와 source 수정 금지

HUMAN_GATE_OWNER
→ 사내 권한·secret/UI 작업·evidence 전달·Stage Gate·다음 Task 승인
```

상세 권한과 handoff는 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.
사내 코딩 에이전트는 이름과 관계없이 `INTERNAL_VALIDATOR`이며 pull-only다.

## 현재 모델·프로토콜 순서

모델 순서는 architecture가 아니라 serving availability를 따른다.

```text
현재: Gemma first
GLM: serving rollout 완료 후 별도 onboarding
```

현재 Gemma V1 protocol:

```text
openai_chat_completions only
Auto detect OFF
openai_responses HTTP 500 → deferred non-blocking
```

활성 Task와 실제 상태는 `company/project-state.yml`과 `company/docs/STATUS.md`를 따른다.

## 현재 안전 선행조건

사내 복구에서 Router stop 후에도 Claude Code의 CCR Base URL/WIF/Federation 설정과 Claude Desktop의 third-party inference 설정이 남는 현상이 확인됐다.

따라서 현재 활성 Task는 Provider finalization이 아니라:

```text
V1-S1-T00
→ sandbox CCR Runtime
→ Enterprise settings/actual Claude-3p/env/normal claude invariance
```

이다.

T00 PASS 전에는:

```text
actual LOCALAPPDATA에서 Stock CCR start/save 금지
System default profile 금지
Connect agent / Let's start 금지
real model request 금지
V1-S1-T01 재개 금지
```

## 운영 토폴로지와 절감 측정

V1의 기본 운영 목표는 다음이다.

```text
N명의 사용자
×
M대의 승인 Windows PC

Model request data plane
→ PC별 Managed Local CCR

Fleet analytics plane
→ privacy-safe 중앙 집계
```

사용자는 endpoint, protocol, model, key, CCR start/stop을 직접 설정하지 않는다.
Company installer, `company-claude` launcher, doctor가 PC 단위 설치·설정·격리·업데이트를 담당한다.

중앙 통계 취합은 중앙 CCR Gateway를 의미하지 않는다.
Local CCR의 장애 격리는 유지하고, prompt/response/source 없이 모델·토큰·fallback·오류 같은 metadata만 모은다.

V1은 실제 task 성공을 아직 상관관계로 증명하지 못하므로 1차 지표를 다음처럼 제한한다.

```text
Transport-level Sonnet avoidance rate
=
기존 정책상 Sonnet 대상 중
자동 Sonnet 호출 없이 routing chain이 정상 종료된 비율
```

Task-level `Successful Sonnet avoidance`와 `Cost per Successful Task`는 session/test/result correlation이 있는 V2에서 사용한다.
Sonnet fallback rate와 internal call amplification을 함께 보며,
비용 환산은 `Sonnet baseline 대비 추정 외부 비용 회피액`이라는 2차 지표로만 표현한다.
상세 기준은 `company/docs/FLEET_OPERATING_MODEL.md`를 따른다.

## 새 구현·검증 세션 진입점

1. `AGENTS.md`
2. `company/docs/ROLES_AND_HANDOFF.md`
3. `company/project-state.yml`
4. `company/docs/PROJECT.md`
5. `company/docs/STATUS.md`
6. `company/docs/TRAPS.md`
7. `project-state.yml`의 `current.task_path`
8. 실행환경 검증이면 `company/docs/ENVIRONMENTS.md`
9. Claude/CCR Task이면 `company/docs/CLAUDE_CODE_ISOLATION.md`
10. 사내 model 검증이면 `company/docs/SECURITY.md`, `company/docs/INTERNAL_VALIDATION.md`
11. 설치·Fleet·Telemetry·절감 Task이면 `company/docs/FLEET_OPERATING_MODEL.md`

## 새 설계 세션 진입점

이전 ChatGPT 대화의 기억을 전제로 하지 않는다.

1. `company/docs/DESIGN_SESSION_PLAYBOOK.md`
2. `company/project-state.yml`
3. `company/docs/STATUS.md`
4. `company/docs/PROJECT.md`
5. `company/docs/DECISIONS.md`
6. `company/docs/STAGES.md`
7. `company/docs/ROLES_AND_HANDOFF.md`
8. 활성 Task와 Required knowledge

새 설계 세션은 작업 전에 Context checksum을 보고한다.
현재 상태를 별도 거대 세션 요약 파일에 복제하지 않고 canonical 문서에서 복원한다.

CCR `v3.0.22` 원본 history와 Company foundation은 이미 하나의 `main` ancestry로 통합되었다.

`AI_WORK_REPORT.md`는 임시 scratch로만 사용하며 commit하지 않는다.
공식 작업 증거는 canonical Task의 `Attempts`, `Evidence`, `Recommendation`에 남긴다.
Internal Validator는 repository 안에 report를 만들지 않고 sanitized text만 반환한다.

CCR 사용법과 라이선스는 upstream 문서와 root `LICENSE`를 따른다.
Company layer도 별도 표기가 없으면 동일 라이선스를 따른다.
