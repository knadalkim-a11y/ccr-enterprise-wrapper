# Company CCR Wrapper

이 저장소는 `musistudio/claude-code-router`를 공통 Runtime으로 사용하고,
사내 설치·호환성 검증·진단·품질 개입에 필요한 Company layer만 추가한다.

## 핵심 방향

```text
CCR upstream
= Gateway · protocol conversion · Provider/model · Native routing
  retry/fallback · streaming · tools · observability · extensions

Wrapper V1
= 사내 설치·연결·호환성·진단·검증 기반

Wrapper V2
= CCR Native를 유지하면서 검증된 반복 품질 실패에만 개입
```

정책(`native`, `force-model`, `static-economy`, `adaptive-quality`)은 제품 버전과 별개다.

## 새 세션 진입점

1. `AGENTS.md`
2. `company/project-state.yml`
3. `company/docs/PROJECT.md`
4. `company/docs/STATUS.md`
5. `company/docs/TRAPS.md`
6. `project-state.yml`의 `current.task_path`

현재 저장소는 Company foundation만 먼저 기록한다. CCR `v3.0.22` 원본 이력 반입은
활성 Bootstrap Task가 담당하며, 완료 전에는 Stock CCR build가 검증되었다고 간주하지 않는다.

CCR 사용법과 라이선스는 upstream 문서와 root `LICENSE`를 따른다. Company layer도 별도 표기가 없으면 동일 라이선스를 따른다.
