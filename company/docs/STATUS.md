# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 미검증 범위와 정확한 다음 행동을 기록한다.

## Baseline

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `YES`
- Integration main commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Wrapper version: `pre-v1`
- Development control: Android/Termux External Codex
- Primary validation environment: Internal Windows, pull-only test
- GitHub orchestration: ChatGPT Orchestrator + Human Gate Owner
- GitHub Actions: `DISABLED` — upstream workflows 검토 전까지 유지

## Current

- Stage: `V1-S1`
- Active Task: `V1-S1-T01`
- Active model: `Gemma first`
- Status: `IN_PROGRESS`
- Blocking precondition: `NONE` — 신규 credential의 current-host 사용 가능성 확인
- Goal: Chat Completions 전용 Gemma Provider의 저장·영속화·안전 종료·clean-tree evidence로 Provider-level Task를 닫음
- V1-S0 validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`

## Collaboration roles

```text
CHATGPT_ORCHESTRATOR
→ 설계·GitHub canonical 상태 관리

EXTERNAL_CODEX
→ Android/Termux 구현·branch/commit/PR

INTERNAL_VALIDATOR
→ 사내 Windows pull-only 검증; GitHub write/source 수정 금지

HUMAN_GATE_OWNER
→ 사내 evidence 전달·Gate·다음 Task 승인
```

상세 규칙은 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.
새 설계 세션은 `company/docs/DESIGN_SESSION_PLAYBOOK.md`로 상태를 복원한다.

## Current Gemma Provider evidence

신규 host-authorized credential로 다음이 확인됐다.

```text
Direct OpenAI Chat Completions: PASS
CCR OpenAI Chat Completions Check Connection: PASS
CCR OpenAI Responses Check Connection: FAIL — HTTP 500
```

현재 판정:

```text
Credential host scope: AUTHORIZED
Gemma Chat Completions: SUPPORTED
OpenAI Responses: UNSUPPORTED_OR_INCOMPATIBLE
Responses V1 gating: NON_BLOCKING
```

현재 V1 Gemma 운영 protocol:

```text
Protocol detection mode: manual
Auto detect protocols: OFF
Selected protocol: openai_chat_completions only
```

Chat PASS로 확인된 범위:

- API key와 현재 host/source scope 사용 가능
- CCR에서 사내 Gateway까지 network/TLS path 가능
- Gemma model 식별·권한 가능
- CCR Chat Completions probe 가능

아직 최종 확인이 필요한 범위:

- Provider 저장
- reopen/refresh 후 영속화
- Request logs / Agent observability 안전 상태
- CCR stop exit `0`
- product diff exit `0`
- final Git status clean
- exact final tested HEAD

## Protocol decision

OpenAI Responses HTTP 500은 현재 다음 중 하나다.

```text
사내 Gateway의 /v1/responses 미지원 또는 비호환
CCR Responses request/response contract와 사내 Gateway 간 비호환
```

현재 증거만으로 특정 vLLM replica, CCR defect 또는 전체 Gateway 미지원을 확정하지 않는다.
V1은 Gemma의 공식 upstream protocol을 `openai_chat_completions`로 한정하고 Responses 원인 분석을 별도 non-blocking 확인으로 유예한다.

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PASS | foundation `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| CCR upstream history | PASS | PR #5 merge; pinned ancestry 보존 |
| CCR repository structure | PASS | source, build, docs, license, company layer 존재 |
| Stock CCR internal Windows build | PASS | `V1-S0-T01`; npm ci, typecheck, build:assets, product diff exit `0` |
| Stock CCR Windows runtime smoke | PASS | `V1-S0-T02`; CLI help/start/stop와 runtime directory 생성 확인 |
| V1-S0 Gate | ACCEPTED | install/build/start/stop without product source changes |
| Credential/host scope model | CONFIRMED | credential validity depends on approved host/source scope |
| Current Gemma credential host scope | PASS | direct Chat와 CCR Chat 실제 요청 성공 |
| Gemma Chat Provider connection | PASS_CANDIDATE | CCR Chat Completions Check Connection PASS; persistence/cleanup pending |
| OpenAI Responses compatibility | DEFERRED_NON_BLOCKING | CCR Responses HTTP 500; `UNSUPPORTED_OR_INCOMPATIBLE` |
| GLM serving availability | DEFERRED | serving rollout 대기; availability-driven onboarding |
| Gateway basic completion | UNVERIFIED | Provider Task 완료 후 별도 Task |
| Streaming/tool contract | UNVERIFIED | later V1-S1 Tasks |
| Claude Code E2E | UNVERIFIED | V1-S2, all host capabilities required |
| Managed Local Fleet topology | DESIGN_DEFAULT | PC별 Local CCR data plane, 중앙 analytics plane 분리 |
| Non-developer setup target | DESIGN_ACCEPTED | installer/launcher/doctor가 수동 CCR 설정 제거 |
| Fleet telemetry boundary | DESIGN_ACCEPTED | metadata allowlist; prompt/response/source/raw DB 중앙 수집 금지 |

## Accepted future operating design

```text
N명의 사용자
×
M대의 승인 Windows PC

Model request data plane
→ PC별 Managed Local CCR

Fleet analytics plane
→ privacy-safe 중앙 집계
```

사용자는 CCR UI, endpoint, protocol, model, upstream key, start/stop을 직접 다루지 않는다.
Company installer/launcher/doctor가 PC 단위 설치·설정·업데이트를 담당한다.

V1 1차 절감 지표는 task 성공이 아니라 transport-level 범위로 제한한다.

```text
Transport-level Sonnet avoidance rate
=
기존 정책상 Sonnet 대상 중
자동 Sonnet 호출 없이 routing chain이 정상 종료된 비율
```

Task-level `Successful Sonnet avoidance`와 `Cost per Successful Task`는 V2에서 session/test/result correlation 후 사용한다.

## V1-S0 final evidence

| Item | Result |
|---|---|
| Tested product commit | `97b73a9f4e1fb23d406bb987d0785cefa1f99966` |
| Environment | Microsoft Windows 11 Enterprise, Node `v24.15.0`, npm `11.12.1`, `win32`, `x64` |
| Clean install / typecheck / build assets | `PASS` |
| CLI help / management-only start / stop | `PASS` |
| Runtime data directory | absent before first start; present after start |
| Product diff / final Git status | `PASS` / `CLEAN` |
| V1-S0 Human decision | `ACCEPTED` on `2026-08-27` |

## Open risks

- Imported upstream workflows are not approved. Keep GitHub Actions disabled.
- Responses protocol의 공식 사내 지원 여부는 아직 확인되지 않았다.
- 실제 사용자 prompt 전에 Request logs와 Agent observability/body capture를 OFF로 검증해야 한다.
- Provider `Check Connection` PASS만으로 local gateway, streaming, tools, Claude Code compatibility를 증명할 수 없다.
- GLM rollout과 GLM-specific onboarding은 아직 완료되지 않았다.
- Stock CCR `%APPDATA%`가 사용자 프로필 범위이므로 multi-user Windows에서 PC당 Runtime 하나를 만드는 방식은 V1-S3에서 검증해야 한다.
- CCR의 공식 metadata export/event interface와 최소 routing-chain correlation은 아직 검증되지 않았다.
- Pilot 전 executable baseline policy와 telemetry deduplication schema를 고정해야 한다.
- 사용자별 감사가 필수인지 PC 단위 통계로 충분한지 운영 요구가 아직 확정되지 않았다.

## Last passed gate

- Gate: `V1-S0`
- Decision: `ACCEPTED`
- Validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Date: `2026-08-27`

## Last completed Task

- Task: `V1-S0-T02`
- Decision: `ACCEPTED`
- Tested product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Date: `2026-08-27`

## Exact next action

Internal Validator가 `V1-S1-T01`의 종료 검증만 수행한다.

1. exact HEAD와 clean working tree 기록
2. 기존 Gemma Provider를 Chat-only/manual로 저장
3. reopen/refresh 후 Provider 영속화 확인
4. Request logs와 Agent observability OFF 확인
5. `Connect agent`와 `Let's start` 미진행
6. CCR stop
7. product diff와 final Git status 확인
8. GitHub write 없이 sanitized handoff 반환

그 결과를 Human Gate Owner가 ChatGPT Orchestrator에게 전달한 뒤에만 `V1-S1-T01` 수용과 다음 Task를 결정한다.
