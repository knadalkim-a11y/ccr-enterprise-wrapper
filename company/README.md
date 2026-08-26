# Company Layer

```text
CCR upstream
= Gateway · protocol conversion · Provider/model · Native routing
  retry/fallback · streaming · tools · observability · extensions

Wrapper V1
= 사내 설치·연결·호환성·진단·검증 기반

Wrapper V2
= Native-first 반복 품질 실패 개입
```

정책은 제품 버전과 별개다.

- `native`: V1 기본
- `force-model`: 검증·수동 우회
- `static-economy`: V1 선택 실험
- `adaptive-quality`: V2

현재 상태와 활성 Task는 `project-state.yml` 및 `docs/STATUS.md`를 따른다.
개발 절차는 `docs/AGENT_WORKFLOW.md`, 사내 검증 절차는 `docs/INTERNAL_VALIDATION.md`를 따른다.
