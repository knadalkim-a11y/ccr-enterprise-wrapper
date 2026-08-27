# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 다음 결정을 기록한다.

## Baseline

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `YES`
- Integration main commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Wrapper version: `pre-v1`
- Development control: Android/Termux
- Primary validation environment: Internal Windows, test only
- GitHub Actions: `DISABLED` — upstream workflows 검토 전까지 유지

## Current

- Stage: `V1-S1`
- Active Task: `V1-S1-T01`
- Active model: `Gemma first`
- Status: `BLOCKED`
- Blocker: `CREDENTIAL_HOST_SCOPE`
- Goal: Stock CCR에서 사내 Gemma custom Provider 한 개와 모델 한 개의 basic `Check Connection`을 source 수정 없이 검증
- V1-S0 validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`

## Current operating constraint

사내 LLM credential은 모든 사내 PC에서 공통으로 사용할 수 있는 값이 아니라,
발급 정책에 따라 특정 host, source IP, NAT/proxy egress, device 또는 account scope에 묶일 수 있다.
현재 사용 가능한 credential은 선택한 validation host의 outbound scope에 허용되지 않아 `401`이 발생했다.

이 결과는 다음을 뜻하지 않는다.

```text
CCR protocol failure
Gemma model failure
일반적인 API authorization implementation failure
```

현재 분류:

```text
BLOCKED_CREDENTIAL_HOST_SCOPE
```

## Host capability model

사내 Windows PC의 역할은 다음 세 권한으로 분리한다.

| Capability | Meaning | V1-S1 Provider check | V1-S2 Claude Code E2E |
|---|---|---:|---:|
| `WINDOWS_RUNTIME_ALLOWED` | CCR를 build/run할 수 있음 | Required | Required |
| `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` | credential이 현재 host/source scope에서 허용됨 | Required | Required |
| `CLAUDE_CODE_EXECUTION_ALLOWED` | 해당 PC에서 Claude Code 사용이 승인됨 | Not required | Required |

Provider-only 검증과 Claude Code E2E는 서로 다른 PC에서 수행할 수 있다.
다만 E2E까지 같은 설정을 재사용하려면 세 권한이 모두 있는 host를 우선 선택한다.

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PASS | foundation `9c117d73aa9732e599aeb4e706566` 기록은 BOOT evidence 참조 |
| CCR upstream history | PASS | PR #5 merge; pinned ancestry 보존 |
| CCR repository structure | PASS | source, build, docs, license, company layer 존재 |
| Stock CCR internal Windows build | PASS | `V1-S0-T01`; npm ci, typecheck, build:assets, product diff exit `0` |
| Stock CCR Windows runtime smoke | PASS | `V1-S0-T02`; CLI help/start/stop와 runtime directory 생성 확인 |
| V1-S0 Gate | ACCEPTED | internal Windows install/build/start/stop demonstrated without product source changes |
| Credential/host scope model | CONFIRMED | credential validity depends on approved execution host/source scope |
| Gemma Provider connection check | BLOCKED_CREDENTIAL_HOST_SCOPE | selected validation host에서 credential scope mismatch로 `401`; protocol check 미완료 |
| GLM serving availability | DEFERRED | serving rollout 대기; 현재 active model order는 Gemma first |
| Gateway basic completion | UNVERIFIED | Gemma Provider check 이후 별도 Task |
| Streaming/tool contract | UNVERIFIED | later V1-S1 Tasks |
| Claude Code E2E | UNVERIFIED | Claude Code 승인 host + host-authorized credential 필요 |

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

- Imported upstream workflows are not yet approved for this repository. Keep GitHub Actions disabled.
- Credential 발급 범위가 validation host와 일치하지 않으면 Provider, gateway, streaming, tool, Claude Code 검증이 모두 401에서 차단될 수 있다.
- `401`은 host scope가 확인되기 전에는 protocol/auth implementation 실패로 분류하지 않는다.
- 실제 source identity는 local IP가 아니라 NAT/proxy egress일 수 있으므로 serving 운영자 기준 확인이 필요하다.
- GLM rollout은 아직 완료되지 않았다. GLM-specific task는 service availability가 확인된 뒤 새로 생성한다.
- Gemma Provider `Check Connection` output may include internal diagnostics; only sanitized categories may be returned externally.

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

## Next action

1. Gemma validation을 수행할 사내 Windows host를 선택한다.
2. Serving 운영 기준에서 그 host의 실제 outbound identity/source scope를 확인한다.
3. 해당 host에서 허용되는 별도 credential을 발급받거나 승인된 절차로 기존 scope를 확장한다.
4. 정책상 허용된다면 이미 credential이 유효한 다른 Windows host에서 Provider-only check를 수행할 수 있다.
5. Claude Code E2E는 반드시 `WINDOWS_RUNTIME_ALLOWED`, `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST`, `CLAUDE_CODE_EXECUTION_ALLOWED`가 모두 충족되는 host에서 수행한다.
6. Scope가 정렬된 뒤 `V1-S1-T01-GEMMA-PROVIDER-CHECK.md`만 재실행한다.
7. GLM은 serving rollout이 완료된 뒤 별도 onboarding Task를 만든다.
