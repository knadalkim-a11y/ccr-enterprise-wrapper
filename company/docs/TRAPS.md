# Trap Registry

반복 가능하고 검증된 함정만 기록한다. 미확인 현상은 활성 Task 또는 `STATUS.md` blocker에 둔다.

## 등록 조건

- 재현되었거나 코드/공식 문서 근거가 있음
- 다시 발생할 가능성이 있음
- 회피 또는 탐지 방법이 있음
- 적용 CCR/Wrapper 버전이 명확함
- 관련 Task와 commit 증거가 있음

## Template

```markdown
## TRAP-XXX — Title

- Status: ACTIVE / RESOLVED / RECHECK
- Scope:
- Applies to:
- Symptom:
- Root cause:
- Avoid:
- Detect:
- Evidence: Task / commit / upstream path
- Recheck when:
```

현재 등록된 Trap: **NONE**
