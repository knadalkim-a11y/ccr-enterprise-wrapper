---
id: DEFERRED-GLM-ONBOARDING
stage: V1-S1
status: deferred
superseded_by: company/tasks/v1-s1/V1-S1-T01-GEMMA-PROVIDER-CHECK.md
---

# Deferred GLM Provider Onboarding

이 파일은 최초 GLM-first 계획의 기록이다.
현재 serving 환경에서는 Gemma를 먼저 사용할 수 있고 GLM은 아직 rollout 대기 중이므로
활성 Task는 `V1-S1-T01-GEMMA-PROVIDER-CHECK.md`로 전환되었다.

이 파일을 실행 가능한 canonical Task로 사용하지 않는다.
GLM model이 실제 serving 환경에 들어오면 당시의 endpoint contract, credential host scope,
사용 가능한 validation host를 확인한 뒤 새 Task ID로 GLM onboarding Task를 생성한다.

## 유지할 원칙

- 모델 순서는 availability에 따라 바뀔 수 있으며 architecture dependency가 아니다.
- GLM-specific Claude Code vertical slice 전에 GLM Provider와 gateway basic completion을 별도로 통과해야 한다.
- 실제 endpoint, key, model ID, host/IP는 repository에 기록하지 않는다.
- Credential이 host/source scope에 묶여 있으면 해당 scope가 승인된 host에서만 검증한다.
