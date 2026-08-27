# Canonical Task

- Task ID:
- Task file:
- Stage:
- Session role: `implementation / review / repair / docs`
- Primary actor:

## Scope completed

-

## Explicitly not implemented

-

## Candidate contract

- Candidate SHA:
- Instruction SHA:
- Product tree equivalence: `SAME_SHA / DOCUMENTED_EXCEPTION / NOT_APPLICABLE`
- Internal validation: `REQUIRED / NOT_REQUIRED`
- Merge policy: `internal_pass_required / external_pass_only / not_applicable`

## Validation

```text
commands and results
```

- External: `NOT_RUN / PASS / FAIL`
- Internal: `NOT_REQUIRED / READY_FOR_INTERNAL_VALIDATION / PASS / FAIL / BLOCKED`
- Human steps required: `YES / NO`
- Human steps completed: `YES / NO / NOT_REQUIRED`

## Merge gate

- [ ] PR head is the exact candidate SHA recorded above
- [ ] Task instructions are present at the recorded instruction SHA
- [ ] If internal validation is required, exact candidate received `INTERNAL_PASS`
- [ ] No repair commit was added after the last internal PASS without impact review
- [ ] Human Gate Owner approved merge

`merge_policy: internal_pass_required`이면 위 조건 충족 전 병합하지 않는다.

## Safety

- [ ] Task scope and Allowed Paths respected
- [ ] Acceptance Criteria not weakened
- [ ] No internal values or raw evidence committed
- [ ] No unnecessary CCR Core change
- [ ] New dependency absent or explicitly approved
- [ ] Internal Validator was not asked to edit source or GitHub
- [ ] Next Task/Stage was not started automatically

## Risks / rollback

-
