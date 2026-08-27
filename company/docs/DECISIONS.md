# Decision Log

되돌리기 어렵거나 여러 Task에 영향을 주는 결정만 기록한다.
상세 구현 선택은 Task Evidence에 남긴다.

## D-001 — CCR을 공통 Runtime으로 사용

- Status: ACCEPTED
- Decision: Gateway, protocol conversion, Provider/model, Native routing을 새로 구현하지 않는다.
- Rationale: CCR upstream 기능을 보존하고 유지보수 범위를 줄인다.

## D-002 — Native-first 제품 방향

- Status: ACCEPTED
- Decision: V1/V2는 라우팅 알고리즘 세대가 아니라 Company Wrapper의 제품 성숙도다.
- Rationale: `static-economy`는 선택 실험이고, CCR Native 기능을 제한하지 않는다.

## D-003 — 외부 개발, 사내 테스트 전용

- Status: ACCEPTED
- Decision: 외부 Codex가 구현하고 사내는 정확한 commit을 pull해 문서화된 검증만 수행한다.
- Rationale: 사내에서 발생한 임시 수정과 외부 코드의 분기를 방지한다.

## D-004 — 하나의 Git repository와 upstream history 보존

- Status: ACCEPTED
- Decision: submodule 없이 CCR history와 Company layer를 한 저장소에 둔다.
- Rationale: 사내에서 하나의 repository를 그대로 pull/mirror한다.

## D-005 — Public-safe tracked content

- Status: ACCEPTED
- Decision: 저장소 visibility와 무관하게 tracked 파일에는 사내 비밀·원문 증거를 넣지 않는다.

## D-006 — 사람 중심 Gate

- Status: ACCEPTED
- Decision: Codex는 Recommendation과 Evidence를 작성할 수 있지만 Stage 통과와 다음 Task 활성화는 사람이 결정한다.

## D-007 — 사내 Windows host 권한을 세 capability로 분리

- Status: ACCEPTED
- Decision: `WINDOWS_RUNTIME_ALLOWED`, `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST`, `CLAUDE_CODE_EXECUTION_ALLOWED`를 서로 독립적으로 판정한다.
- Rationale: CCR 실행 가능 PC, credential 사용 가능 host/source scope, Claude Code 승인 PC가 서로 일치하지 않을 수 있다.
- Consequence: Provider/gateway 검증에는 앞의 두 capability가 필요하고 Claude Code E2E에는 세 capability 모두가 필요하다.
- Consequence: Host/source scope mismatch의 401/403은 `BLOCKED_CREDENTIAL_HOST_SCOPE`이며 protocol, model 또는 CCR source failure가 아니다.
- Security: Key 공유, allowlist 우회, 승인되지 않은 proxy/tunnel/relay를 사용하지 않는다.

## D-008 — 내부 모델 onboarding 순서는 serving availability를 따름

- Status: ACCEPTED
- Decision: GLM-first 또는 Gemma-first를 architecture invariant로 두지 않는다. 현재는 사용 가능한 Gemma부터 V1-S1 contract를 검증하고 GLM은 serving rollout 후 별도 onboarding한다.
- Rationale: 모델 배포 일정 때문에 protocol/transport 검증 전체를 불필요하게 대기시키지 않는다.
- Consequence: V1-S1 transport Gate는 우선 사용 가능한 모델 한 개로 증명할 수 있다.
- Consequence: 각 모델의 V1-S2 workload 전에 해당 모델의 Provider와 gateway basic completion을 별도로 통과해야 한다.

## D-009 — V1 기본 배포 토폴로지는 Managed Local Fleet

- Status: ACCEPTED
- Decision: N명의 사용자가 공유하는 M대 승인 Windows PC마다 논리적 Local CCR Runtime 하나를 두는 방식을 V1 기본 토폴로지로 한다.
- Rationale: Local 장애 격리, host-scoped credential, 현재 CCR Runtime 구조와 가장 잘 맞으며 중앙 Gateway의 SSO/HA/멀티테넌시 범위를 피한다.
- Consequence: 사용자는 CCR UI, endpoint, protocol, model, upstream key, start/stop을 직접 다루지 않는다.
- Consequence: Company installer/launcher/doctor가 PC 단위 설치·설정·업데이트·rollback을 담당한다.
- Validation: `%APPDATA%` 사용자 범위에서 PC당 Runtime 하나를 만드는 구체 방식은 V1-S3에서 검증한다.

## D-010 — Model data plane과 Fleet analytics plane을 분리

- Status: ACCEPTED
- Decision: 모델 요청은 각 PC의 Local CCR가 처리하고, 중앙에는 privacy-safe metrics만 취합한다.
- Rationale: 전체 사용자에게 영향을 주는 중앙 Gateway 장애와 운영 범위를 추가하지 않고도 Fleet 가시성을 확보할 수 있다.
- Consequence: 중앙 Collector는 prompt, response, source, raw tool data, 실제 endpoint/key/model ID를 수집하지 않는다.
- Consequence: 초기에는 approved shared path의 daily JSON/CSV batch를 허용하고, 실시간 Collector는 Pilot에서 필요성이 증명될 때만 만든다.
- Clarification: 중앙 analytics는 중앙 CCR Gateway를 의미하지 않는다.

## D-011 — V1 절감의 1차 KPI는 Successful Sonnet avoidance

- Status: ACCEPTED
- Decision: 서로 다른 태스크의 평균 비용보다, 기존 정책상 Sonnet 대상이었던 resolution chain 중 Sonnet 호출 없이 종료된 비율을 V1 핵심 KPI로 사용한다.
- Rationale: 태스크 난이도와 길이가 달라도 각 routing opportunity의 baseline decision과 actual route는 일관되게 집계할 수 있다.
- Guardrails: Internal-first rate, Sonnet fallback rate, Internal call amplification, token-weighted avoidance, success/error/latency를 함께 본다.
- Consequence: 사내 모델 호출 횟수만으로 절감을 주장하지 않는다. 내부 모델 시도 후 Sonnet fallback은 successful avoidance가 아니다.
- Consequence: 동일 작업을 Sonnet으로 중복 실행하지 않고 versioned baseline policy를 metadata로 기록한다.

## D-012 — 비용 환산과 task-level 평가는 단계적으로 확장

- Status: ACCEPTED
- Decision: `Sonnet baseline 대비 추정 외부 비용 회피액`을 2차 지표로 사용하며 `확정 절감액`이라고 표현하지 않는다.
- Rationale: 실제 Sonnet 호출 시 출력 길이, 재시도, 성공률이 달라질 수 있어 counterfactual 비용은 추정치다.
- V1: routing opportunity/resolution chain 수준의 Sonnet avoidance를 측정한다.
- V2: session/test/result correlation 후 task-level success와 Cost per Successful Task를 추가한다.
- Consequence: Cost per Successful Task는 V1 필수 Gate가 아니다.
