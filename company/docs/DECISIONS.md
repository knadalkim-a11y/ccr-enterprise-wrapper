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
