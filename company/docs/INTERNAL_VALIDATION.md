# Internal Validation

사내 환경은 개발이 아니라 검증만 수행한다.

```text
External implementation
→ exact candidate commit
→ internal detached checkout
→ documented commands
→ PASS / FAIL / BLOCKED
→ sanitized result
```

```bash
git fetch origin
git checkout --detach <TESTED_COMMIT_SHA>
git status --short
```

금지:

- 사내 product code 수정
- endpoint/key/model ID/raw evidence 반출
- 다른 commit 결과 재사용
- 미검증 PASS

결과:

- `PASS`: 내부 Acceptance Criteria 충족
- `FAIL`: 구현 또는 contract 실패
- `BLOCKED`: 권한/network/proxy/TLS/모델 미제공
- `SKIPPED`: 비대상
- `UNVERIFIED_INTERNAL`: 실행 전

FAIL은 raw evidence를 사내에 유지하고 sanitized defect Task로 반환한다.
