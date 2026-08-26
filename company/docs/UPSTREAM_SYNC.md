# Upstream Sync

```text
origin   → knadalkim-a11y/ccr-enterprise-wrapper
upstream → musistudio/claude-code-router
```

- Git submodule을 사용하지 않는다.
- 초기 pin은 `v3.0.22` (`829298cf8bdcc6ddb9120a5a7c790c30227a1937`)다.
- 새 release를 자동 반영하지 않는다.

## 최초 history integration

현재 Company foundation history를 유지하면서 upstream history를 결합한다.
정확한 절차와 검증 조건은 `BOOT-T01`이 Source of Truth다.

개념 흐름:

```bash
git remote add upstream https://github.com/musistudio/claude-code-router.git
git fetch upstream --tags
git switch -c bootstrap/upstream-v3.0.22 829298cf8bdcc6ddb9120a5a7c790c30227a1937
git merge --no-ff --allow-unrelated-histories origin/main \
  -m "merge: establish CCR v3.0.22 company baseline"
```

이 branch는 upstream commit과 foundation main을 모두 ancestor로 가져야 한다.
force-push로 main을 재작성하지 않는다.

## 이후 update

```bash
git fetch upstream --tags
git switch main
git pull --ff-only origin main
git switch -c chore/upstream-vX.Y.Z
git merge --no-ff vX.Y.Z
```

Update 전 확인:

1. `company/patches/CORE_PATCHES.md`
2. config/schema migration
3. Provider/routing/Profile/extension 변화
4. Claude Code compatibility
5. SQLite/native dependency

내부 regression Gate 전에는 main에 merge하지 않는다.
공개 main을 rebase/force-push하지 않는다.
