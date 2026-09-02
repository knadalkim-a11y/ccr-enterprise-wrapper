# Decision Log

되돌리기 어렵거나 여러 Task에 영향을 주는 결정만 기록한다.
상세 구현 선택과 시도별 결과는 Task Evidence에 남긴다.

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
- Decision: 외부 Codex가 구현하고 사내는 승인된 canonical URL/ref/SHA를 disposable repository에 가져와 문서화된 검증만 수행한다.
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
- Decision: Agent는 Recommendation과 Evidence를 작성할 수 있지만 Stage 통과와 다음 Task 활성화는 사람이 결정한다.

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

- Status: ACCEPTED_AS_V1_DEFAULT
- Decision: N명의 사용자가 공유하는 M대 승인 Windows PC마다 논리적 Local CCR Runtime 하나를 두는 방식을 V1 기본 토폴로지로 검증한다.
- Rationale: Local 장애 격리, host-scoped credential, 현재 CCR Runtime 구조와 잘 맞으며 중앙 Gateway의 SSO/HA/멀티테넌시 범위를 피한다.
- Consequence: 사용자는 CCR UI, endpoint, protocol, model, upstream key, start/stop을 직접 다루지 않는다.
- Consequence: Company installer/launcher/doctor가 PC 단위 설치·설정·업데이트·rollback을 담당한다.
- Validation: `%APPDATA%` 사용자 범위에서 PC당 Runtime 하나를 만드는 구체 방식은 V1-S3에서 검증하며 실패 시 토폴로지를 재검토한다.

## D-010 — Model data plane과 Fleet analytics plane을 분리

- Status: ACCEPTED
- Decision: 모델 요청은 각 PC의 Local CCR가 처리하고, 중앙에는 privacy-safe metrics만 취합한다.
- Rationale: 전체 사용자에게 영향을 주는 중앙 Gateway 장애와 운영 범위를 추가하지 않고도 Fleet 가시성을 확보할 수 있다.
- Consequence: 중앙 Collector는 prompt, response, source, raw tool data, 실제 endpoint/key/model ID를 수집하지 않는다.
- Consequence: 초기에는 approved shared path의 daily JSON/CSV batch를 허용하고, 실시간 Collector는 Pilot에서 필요성이 증명될 때만 만든다.
- Clarification: 중앙 analytics는 중앙 CCR Gateway를 의미하지 않는다.

## D-011 — V1 절감의 1차 KPI는 Transport-level Sonnet avoidance

- Status: ACCEPTED
- Decision: V1은 실제 task 성공을 아직 상관관계로 증명하지 못하므로, 기존 정책상 Sonnet 대상이었던 routing chain 중 자동 Sonnet 호출 없이 정상 종료된 비율을 1차 KPI로 사용한다.
- Name: `Transport-level Sonnet avoidance rate` 또는 `Sonnet-free resolution rate`.
- Rationale: 태스크 난이도와 길이가 달라도 baseline decision과 actual route는 일관되게 집계할 수 있으며, transport 정상 종료를 업무 성공으로 과장하지 않는다.
- Guardrails: Internal-first rate, Sonnet fallback rate, Internal call amplification, token-weighted avoidance, error/latency를 함께 본다.
- Consequence: 사내 모델 호출 횟수만으로 절감을 주장하지 않는다. 내부 모델 시도 후 Sonnet fallback은 avoidance가 아니다.
- Consequence: V1에는 최소 `routing_chain_id`가 필요하고, task/session/test success correlation은 V2로 미룬다.

## D-012 — 비용 환산과 task-level 평가는 단계적으로 확장

- Status: ACCEPTED
- Decision: `Sonnet baseline 대비 추정 외부 비용 회피액`을 2차 지표로 사용하며 `확정 절감액`이라고 표현하지 않는다.
- Rationale: 실제 Sonnet 호출 시 출력 길이, 재시도, 성공률이 달라질 수 있어 counterfactual 비용은 추정치다.
- V1: routing opportunity/routing chain 수준의 transport avoidance를 측정한다.
- V2: session/test/result correlation 후 `Successful Sonnet avoidance`와 Cost per Successful Task를 추가한다.
- Consequence: Cost per Successful Task는 V1 필수 Gate가 아니다.

## D-013 — 역할별 GitHub 권한과 evidence handoff를 분리

- Status: ACCEPTED
- Decision: `CHATGPT_ORCHESTRATOR`, `EXTERNAL_CODEX`, `INTERNAL_VALIDATOR`, `HUMAN_GATE_OWNER`의 권한을 고정한다.
- Internal: 사내 코딩 에이전트는 pull-only `INTERNAL_VALIDATOR`이며 source/Task/STATUS/Gate 수정, branch/commit/push/PR을 하지 않는다.
- External: Android/Termux Codex가 활성 Task 범위의 구현과 GitHub branch/PR을 담당한다.
- Orchestration: ChatGPT는 sanitized evidence를 검토해 canonical GitHub 문서를 관리하며, 사내 검증을 실행한 것처럼 기록하지 않는다.
- Human: 사용자가 사내 evidence 전달, Gate와 다음 Task를 최종 승인한다.
- Rationale: secret boundary, exact commit evidence, GitHub 상태의 단일성을 유지한다.

## D-014 — 새 설계 세션은 GitHub canonical 문서로 무상태 복원

- Status: ACCEPTED
- Decision: 새 ChatGPT 설계 세션은 이전 대화 기억에 의존하지 않고 `DESIGN_SESSION_PLAYBOOK.md`의 읽기 순서와 Context checksum으로 상태를 복원한다.
- Rationale: 긴 대화의 요약 손실과 세션 간 해석 차이를 줄인다.
- Consequence: 거대한 `SESSION_SUMMARY.md`를 중복 유지하지 않고, 현재 상태는 project-state/STATUS/Task, 승인 결정은 DECISIONS에 기록한다.
- Consequence: Chat에서만 합의된 내용은 GitHub 반영 전까지 proposal이며 accepted decision이 아니다.

## D-015 — 현재 Gemma V1 upstream protocol은 Chat Completions로 한정

- Status: ACCEPTED_FOR_CURRENT_GEMMA_PROVIDER
- Decision: 현재 사내 Gemma Provider의 V1 공식 upstream protocol을 `openai_chat_completions`로 고정하고 Auto detect를 끈다.
- Evidence: Direct Chat Completions PASS, CCR Chat Completions PASS, CCR OpenAI Responses HTTP 500.
- Responses: 현재 `UNSUPPORTED_OR_INCOMPATIBLE`, V1 non-blocking, 별도 compatibility 또는 인프라 확인으로 유예한다.
- Rationale: 하나의 검증된 upstream protocol로 Provider/gateway/stream/tool contract를 진행할 수 있고 Claude Code 연동에 Responses가 필수라는 증거가 없다.
- Boundary: 이 결정은 현재 Gemma Provider에 한정하며 GLM이나 다른 Provider의 protocol을 영구 제한하지 않는다.
- UX: 부분 protocol 성공을 더 명확히 보여주는 개선은 후보지만 현재 Core patch를 만들지 않는다.

## D-016 — 작업은 Task-driven Four-Lane workflow로 운영

- Status: ACCEPTED
- Decision: 모든 작업을 `DESIGN → BUILD → VALIDATE → GATE` 네 Lane으로 분리하고, Task 파일 하나에는 검증 질문과 실패 계층 하나만 둔다.
- Design: ChatGPT Orchestrator와 Human Gate Owner가 Task, actor, execution mode, candidate/merge contract를 작성한다.
- Build: 코드 변경이 필요할 때만 External Codex가 branch/PR을 만들며, 내부 검증 지침을 candidate에 포함한다.
- Validate: Internal Validator는 승인된 Task와 canonical URL/ref, exact instruction/candidate SHA 하나만 disposable repository에 fetch/archive해 test-only 검증하고 종료한다.
- Human-assisted: 실제 credential/UI/승인은 Human Step으로 표시하고 Internal Validator는 해당 Step에서 멈췄다가 최소 완료 상태만 받아 재개한다.
- Gate: Human Gate Owner가 PASS/RETRY/BLOCKED/DEFER와 다음 Task를 최종 승인하고 ChatGPT Orchestrator가 canonical 상태를 반영한다.
- Candidate: 구현 Task는 `instruction_sha == candidate_sha == PR head SHA`를 기본으로 한다. Validation-only 예외는 두 SHA와 product tree equivalence를 기록한다. Human-approved `validation_overlay`는 exact control/instruction PR head와 별도 `tested_product_sha`를 사용하고 protected-path equivalence와 full tested-product build plane을 명시한다.
- Merge: `internal_validation: required` 코드 PR은 exact PR head의 `INTERNAL_PASS` 전 병합하지 않는다.
- Rationale: 사외 개발과 사내 비밀 환경 검증을 분리하면서도, 어떤 코드와 어떤 지침이 검증됐는지 재현 가능하게 유지한다.

## D-017 — Enterprise Claude는 불변이며 CCR는 별도 명령과 이중 격리로 실행

- Status: ACCEPTED_AS_V1_DEFAULT
- Decision: 일반 `claude`는 항상 기존 Enterprise 설정·인증·모델을 사용하고, CCR는 별도 논리 명령 `company-claude`로만 실행한다.
- Client isolation: Claude Code profile은 `Only opened from CCR`(`scope=ccr`) + `CLI only`만 허용한다. `System default`는 V1에서 금지한다.
- Runtime isolation: Stock CCR management/service는 process-local sandbox `LOCALAPPDATA`에서 실행해 실제 `%LOCALAPPDATA%\Claude-3p` 동기화 side effect를 격리한다.
- Enterprise invariants: `%USERPROFILE%\.claude\settings.json`, 실제 Claude-3p, User/Machine CCR env, 일반 `claude` resolution, Enterprise auth/models와 일반 Claude Desktop은 변경하지 않는다.
- Failure semantics: CCR service ON/OFF가 일반 `claude`를 자동 전환하지 않는다. `company-claude`는 CCR unavailable 시 Enterprise/Sonnet으로 자동 fallback하지 않고 명확히 실패한다.
- Evidence: 사내 복구에서 CCR Base URL과 WIF/Federation 값이 Enterprise settings에 잔존했고, 실제 Claude-3p의 third-party inference config도 수동 제거가 필요했다.
- Rationale: 복구를 자동화하는 것보다 정상 실행에서 복구가 필요 없는 격리 구조가 안전하고, 모델 경계·비용 측정도 명확하다.
- Validation: `V1-S1-T00`에서 process-local `LOCALAPPDATA` sandbox와 Enterprise before/during/after invariance를 증명한다.
- Consequence: `V1-S1-T01` Provider finalization은 T00 승인 전까지 중단한다.
- Consequence: Claude App/Desktop CCR 연결은 별도 Task 전까지 제외하며, 실제 Claude-3p 불변성은 지금부터 안전 Gate다.
- Fallback: sandbox가 실패한 경우에만 `CCR_DISABLE_CLAUDE_APP_GATEWAY_SYNC` 같은 최소 명시적 Core patch를 증거 기반으로 검토한다.

## D-018 — 설계·repair·review에 비례성과 과설계 검토를 기본 적용

- Status: ACCEPTED
- Decision: 모든 설계·repair·review에서 제안을 `MUST NOW / CONDITIONAL / DEFER`로 나누고, 현재 Stage의 관찰된 실패와 승인된 위협을 막는 최소 절차를 선택한다.
- Human cost: 승인 왕복과 수기 Evidence 전달도 설계 비용과 실패 surface로 계산한다.
- Guardrail: 단순화를 이유로 exact source authority, secret 경계, Enterprise invariant, fail-closed stop을 약화하지 않는다.
- Consequence: 현재 위험을 줄이는 구체적 근거가 없는 새 gate, 상태, attestation, parser, script, 격리 계층은 추가하지 않고 필요성이 증명될 때까지 유예한다.
