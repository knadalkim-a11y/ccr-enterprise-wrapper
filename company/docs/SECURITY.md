# Security Boundary

저장소는 Public일 수 있다고 가정한다.

## Commit 금지

- 실제 API Key, endpoint, hostname/IP/proxy
- 실제 사내 model ID와 권한/RPM
- 사번·계정·조직명
- 내부 repository/source
- 실제 prompt/response/file/tool result
- 계약 가격과 raw internal logs

## Placeholder

```text
INTERNAL_LLM_BASE_URL
INTERNAL_LLM_API_KEY
INTERNAL_GLM_MODEL_ID
INTERNAL_GEMMA_MODEL_ID
```

## 원칙

- Key 원문은 config export, exception, log, telemetry, snapshot에 넣지 않는다.
- Company body capture 기본값은 OFF 또는 error-only다.
- 외부 fixture는 synthetic만 사용한다.
- Raw internal evidence는 사내에만 보관한다.
- `AGENTS.override.md`는 로컬 전용이며 commit하지 않는다.
