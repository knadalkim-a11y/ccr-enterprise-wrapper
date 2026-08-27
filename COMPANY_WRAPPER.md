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

## 실행환경과 권한

```text
Native Termux
→ 기본 개발 제어, Git, 문서, Task, PR, 리뷰

사내 Windows
→ install, typecheck, build, 실행, 사내 연동, Claude Code E2E
```

사내 Windows host는 다음 capability를 독립적으로 가진다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

Provider 검증에는 앞의 두 조건이 필요하고 Claude Code E2E에는 세 조건이 모두 필요하다.
Credential이 다른 host/source scope에 묶여 발생한 401은 protocol failure가 아니라 `BLOCKED_CREDENTIAL_HOST_SCOPE`다.

개인 Windows/Linux PC와 cloud runner는 초기 필수가 아니다.
사내 Windows에서 exact candidate를 build하고 실행하는 것은 개발이 아니라 test-only 검증이다.
자세한 기준은 `company/docs/ENVIRONMENTS.md`를 따른다.

## 현재 모델 순서

모델 순서는 architecture가 아니라 serving availability를 따른다.

```text
현재: Gemma first
GLM: serving rollout 완료 후 별도 onboarding
```

활성 Task와 실제 상태는 `project-state.yml`과 `STATUS.md`를 따른다.

## 새 세션 진입점

1. `AGENTS.md`
2. `company/project-state.yml`
3. `company/docs/PROJECT.md`
4. `company/docs/STATUS.md`
5. `company/docs/TRAPS.md`
6. `project-state.yml`의 `current.task_path`
7. 실행환경 검증이 있으면 `company/docs/ENVIRONMENTS.md`
8. 사내 model/Claude Code 검증이면 `company/docs/SECURITY.md`, `company/docs/INTERNAL_VALIDATION.md`

CCR `v3.0.22` 원본 history와 Company foundation은 이미 하나의 `main` ancestry로 통합되었다.

`AI_WORK_REPORT.md`는 임시 scratch로만 사용하며 commit하지 않는다.
공식 작업 증거는 canonical Task의 `Attempts`, `Evidence`, `Recommendation`에 남긴다.

CCR 사용법과 라이선스는 upstream 문서와 root `LICENSE`를 따른다.
Company layer도 별도 표기가 없으면 동일 라이선스를 따른다.
