# Upstream Sync

```text
origin   → knadalkim-a11y/ccr-enterprise-wrapper
upstream → musistudio/claude-code-router
```

- Git submodule을 사용하지 않는다.
- 초기 pin은 `v3.0.22` (`829298cf8bdcc6ddb9120a5a7c790c30227a1937`)다.
- 새 release를 자동 반영하지 않는다.
- upstream tag는 `origin`에 자동 또는 일괄 push하지 않는다.

## 최초 history integration

현재 Company foundation history를 유지하면서 upstream history를 결합한다.
정확한 명령과 검증 조건은 `BOOT-T01`이 Source of Truth다.

필수 원칙:

1. 실행 시점의 깨끗한 `origin/main`을 foundation SHA로 고정한다.
2. `v3.0.22^{commit}`이 pinned commit과 정확히 일치하는지 자동 검증한다.
3. pinned CCR commit에서 branch를 만들고 foundation SHA를 `--allow-unrelated-histories`로 merge한다.
4. 통합 merge commit과 두 부모를 기록한다.
5. Company-owned 경로 외의 tree가 pinned CCR commit과 동일한지 검증한다.
6. branch는 `--no-follow-tags`로 push한다.
7. BOOT PR은 **Create a merge commit**으로만 병합한다. Squash/Rebase를 사용하지 않는다.
8. 병합 후 pinned CCR, foundation, 통합 merge commit이 모두 `origin/main`의 ancestor인지 확인한다.

개념 흐름:

```bash
git fetch --prune origin
git fetch upstream "refs/tags/v3.0.22:refs/tags/v3.0.22"

git switch main
git pull --ff-only origin main
FOUNDATION_SHA=$(git rev-parse origin/main)

PIN=829298cf8bdcc6ddb9120a5a7c790c30227a1937
test "$(git rev-parse 'refs/tags/v3.0.22^{commit}')" = "$PIN"

git switch -c bootstrap/upstream-v3.0.22 "$PIN"
git merge --no-ff --allow-unrelated-histories "$FOUNDATION_SHA" \
  -m "merge: establish CCR v3.0.22 company baseline"

git push --no-follow-tags -u origin bootstrap/upstream-v3.0.22
```

force-push로 `main`을 재작성하지 않는다.

## GitHub Actions during initial integration

CCR upstream에는 Pages 배포와 release/publish workflow가 포함될 수 있다.
최초 BOOT PR 병합 전 repository Actions를 일시 비활성화한다.

- upstream tag를 `origin`에 push하지 않는다.
- workflow 내용을 검토하기 전에는 Actions를 다시 활성화하지 않는다.
- Actions 비활성화 여부와 재활성화 결정은 BOOT Evidence에 기록한다.

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
6. upstream `.github/workflows/**` 변화

내부 regression Gate 전에는 `main`에 merge하지 않는다.
공개 `main`을 rebase/force-push하지 않는다.
