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

## 실행환경

```text
Native Termux
→ 기본 개발 제어, Git, 문서, Task, 리뷰

Termux + PRoot Linux
→ 외부 install/typecheck/build 우선 runner

사내 Windows
→ 실제 대상 환경의 test-only 검증
```

개인 Windows/Linux PC와 cloud runner는 초기 필수가 아니다.
다만 Windows-specific 증거는 V1 완료 전에 사내 Windows에서 반드시 확보한다.
자세한 기준은 `company/docs/ENVIRONMENTS.md`를 따른다.

## 새 세션 진입점

1. `AGENTS.md`
2. `company/project-state.yml`
3. `company/docs/PROJECT.md`
4. `company/docs/STATUS.md`
5. `company/docs/TRAPS.md`
6. `project-state.yml`의 `current.task_path`
7. 실행환경 검증이 있으면 `company/docs/ENVIRONMENTS.md`

CCR `v3.0.22` 원본 history와 Company foundation은 이미 하나의 `main` ancestry로 통합되었다.
현재 Stage와 활성 Task는 `company/project-state.yml`과 `company/docs/STATUS.md`를 따른다.

`AI_WORK_REPORT.md`는 임시 scratch로만 사용하며 commit하지 않는다.
공식 작업 증거는 canonical Task의 `Attempts`, `Evidence`, `Recommendation`에 남긴다.

CCR 사용법과 라이선스는 upstream 문서와 root `LICENSE`를 따른다.
Company layer도 별도 표기가 없으면 동일 라이선스를 따른다.
