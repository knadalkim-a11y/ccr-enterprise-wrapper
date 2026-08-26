---
id: V1-S0-T01
stage: V1-S0
title: Stock CCR external build
kind: spike
status: blocked
session_role: implementation
internal_validation: not-required
depends_on:
  - BOOT-T01
allowed_paths:
  - company/tasks/v1-s0/V1-S0-T01-STOCK-BUILD.md
  - company/docs/STATUS.md
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: pending
---

# Stock CCR External Build

## Validation question

> Pinned CCR `v3.0.22`가 외부 환경에서 Company 제품 코드 변경 없이 install, typecheck, build되는가?

## Why now

사내 Provider, setup, doctor를 만들기 전에 Stock CCR 자체와 개발 도구를 확인한다.
`BOOT-T01`이 완료되고 사람이 이 Task를 활성화한 뒤에만 시작한다.

## Required knowledge

- root `package.json`
- upstream build/install 문서
- `company/docs/UPSTREAM_SYNC.md`

## In scope

- 실제 package manager와 Node 요구 버전 확인
- clean dependency install
- upstream typecheck/build 명령 확인 및 실행
- 환경과 결과를 이 Task 및 STATUS에 기록

## Out of scope

- 사내 endpoint/model
- CCR 설정 변경
- Wrapper/Static/Telemetry/V2 구현
- Dependency 변경
- CCR Core 수정

## Acceptance criteria

- [ ] upstream 공식 install/build 명령 확인
- [ ] clean install 결과 기록
- [ ] typecheck 또는 동등 검사 결과 기록
- [ ] Desktop packaging 제외 build asset 결과 기록
- [ ] 제품 코드 변경 없음
- [ ] 실패 시 원인과 다음 Recommendation 기록

## Initial command candidates

Codex가 pinned upstream 문서와 package scripts를 확인한 뒤 확정한다.

```bash
node --version
npm --version
npm ci
npm run typecheck
npm run build:assets
```

## Internal validation contract

- Required: No
- Internal result: `NOT_REQUIRED`

## Stop conditions

- 지원 외부 환경에서 native dependency 해결 불가
- pinned source/ref 불일치
- 제품 코드 수정 없이는 build 불가능

## Rollback

- 문서 Evidence 변경만 revert한다.

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|

## Evidence / limitations

- Baseline CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`

## Codex recommendation

`PENDING`

## Human decision

`PENDING`
