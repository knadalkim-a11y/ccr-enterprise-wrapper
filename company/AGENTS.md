# Company Layer Agent Instructions

- 모든 세션은 `CHATGPT_ORCHESTRATOR`, `EXTERNAL_CODEX`, `INTERNAL_VALIDATOR`, `HUMAN_GATE_OWNER` 중 역할 하나를 선언한다.
- 역할별 권한과 handoff는 `company/docs/ROLES_AND_HANDOFF.md`, 실행 흐름은 `company/docs/AGENT_WORKFLOW.md`를 따른다.
- Task 작성과 분할은 `company/tasks/README.md`와 `TASK_TEMPLATE.md`를 따른다.
- `One Task = one validation question + one failure layer + one canonical file`이다.
- Provider, Runtime isolation, Profile, Completion, Streaming, Tool, Claude Code E2E를 하나의 Task에 묶지 않는다.
- 같은 질문의 preflight, Human Step, cleanup, product diff는 Task 내부 Step으로 둔다.
- Task는 `primary_actor`, `execution_mode`, `candidate_sha`, `instruction_sha`, `merge_policy`를 명시한다.
- 사내 코딩 에이전트는 이름과 무관하게 pull-only `INTERNAL_VALIDATOR`다.
- Internal Validator는 Task를 스스로 선택하지 않고 승인된 Task와 exact SHA 하나만 수행한다.
- Internal Validator는 Task/STATUS/Gate/source를 수정하거나 branch/commit/push/PR을 수행하지 않는다.
- Human-assisted Task에서 Internal Validator는 Human Step 직전에 멈추고, 실제 secret이 아닌 완료 상태만 받아 재개한다.
- 내부 검증이 필요한 코드 PR은 exact PR head의 `INTERNAL_PASS` 전 병합하지 않는다.
- 새 ChatGPT 설계 세션은 `company/docs/DESIGN_SESSION_PLAYBOOK.md`의 Context checksum으로 상태를 복원한다.
- `company/project-state.yml`과 활성 Task가 Company 작업의 현재 기준이다.
- Company-owned 구현은 기본적으로 `company/` 아래에 둔다.
- upstream 경로 수정은 Task가 허용하고 config/extension/wrapper로 해결 불가한 증거가 있을 때만 한다.
- 가장 작은 vertical experiment로 다음 투자 결정을 위한 증거를 만든다.
- V1 Task에서 V2 abstraction을 추가하지 않는다.
- 외부에서는 synthetic mock과 CCR 기존 test utility를 우선 사용한다.
- 사내 검증은 product code 수정 없이 실행 가능해야 한다.
- Trap은 재현 또는 코드 근거, 회피법, 적용 버전, Task/commit 증거가 있을 때만 등록한다.
- Task 파일이 Issue/PR보다 우선하는 유일한 요구사항 Source of Truth다.
- 모델 순서는 serving availability를 따르며 과거 GLM-first/Gemma-first 가정을 자동 적용하지 않는다.
- 사내 model request 전에 `WINDOWS_RUNTIME_ALLOWED`, `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST`, 필요 시 `CLAUDE_CODE_EXECUTION_ALLOWED`를 확인한다.
- Host/source scope mismatch의 401/403은 `BLOCKED_CREDENTIAL_HOST_SCOPE`이며 protocol/model/CCR failure로 기록하지 않는다.
- 일부 protocol 실패를 Provider 전체 실패로 확대하지 않는다. 현재 Gemma V1 운영 protocol은 `openai_chat_completions` only다.
- 실제 host/IP, endpoint, key, model ID, raw internal evidence를 repository에 기록하지 않는다.
- Key 공유, allowlist 우회, 승인되지 않은 proxy/tunnel/relay를 사용하지 않는다.

## Claude Code isolation rules

- Claude/CCR 관련 Task는 `company/docs/CLAUDE_CODE_ISOLATION.md`를 Required knowledge로 포함한다.
- 일반 `claude`는 Enterprise lane이며 Company Wrapper가 command, PATH, settings, auth, model을 수정하지 않는다.
- CCR lane의 논리 명령은 `company-claude`이며 실제 launcher 구현 전에는 Task의 수동 equivalent만 사용한다.
- V1 Claude Code profile은 `Only opened from CCR`(`scope=ccr`) + `CLI only`다.
- `System default` profile은 V1에서 금지한다.
- Claude App/Desktop CCR 연결은 별도 승인 Task 전까지 금지한다.
- `Only opened from CCR`만으로 전체 Runtime이 격리된다고 가정하지 않는다.
- Stock CCR management/service는 승인된 process-local sandbox `LOCALAPPDATA`에서만 start/save한다.
- User/Machine scope에 CCR env를 영구 저장하지 않는다.
- CCR service ON/OFF로 일반 `claude`를 자동 전환하지 않는다.
- `company-claude`는 CCR unavailable 시 Enterprise/Sonnet으로 자동 fallback하지 않고 fail-closed한다.
- Enterprise settings, actual Claude-3p, normal `claude` resolution, User/Machine env가 바뀌면 `ISOLATION_BREACH`다.
- 수동 backup 복구가 성공해도 isolation Task를 PASS로 기록하지 않는다.
- Enterprise smoke 후 모든 Claude client를 종료한 다음 baseline fingerprint를 잡는다.
- V1-S1-T00 승인 전에는 V1-S1-T01, `Connect agent`, `Let's start`, real model request를 시작하지 않는다.
- Runtime sandbox가 실패한 증거가 있을 때만 explicit Claude App sync-disable 같은 최소 Core patch를 검토한다.

## Fleet and savings rules

- 설치·Fleet·Telemetry·절감 평가 Task는 `company/docs/FLEET_OPERATING_MODEL.md`를 Required knowledge로 포함한다.
- Managed Local Fleet의 중앙 집계는 metadata-only이며 prompt, response, source, file path, raw tool data, raw DB/log를 전송하지 않는다.
- 중앙 analytics를 이유로 중앙 CCR Gateway, SSO, HA, Control Plane을 미리 구현하지 않는다.
- V1 절감 주장은 `baseline policy version`, `baseline model class`, `actual model`, `fallback`, 최소 `routing_chain_id`를 함께 기록해야 한다.
- 사내 모델 호출 수만으로 절감을 주장하지 않으며, Sonnet fallback chain은 Transport-level Sonnet avoidance로 세지 않는다.
- `Successful Sonnet avoidance`, `Cost per Successful Task`, task-level success는 session/test/result correlation이 있는 V2 전에는 V1 필수 Gate로 만들지 않는다.
- 일반 `claude` 사용과 `company-claude` 사용을 동일한 CCR avoidance 집계로 섞지 않는다.
