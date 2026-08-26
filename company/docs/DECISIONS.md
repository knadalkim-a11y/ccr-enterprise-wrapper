# Decision Log

되돌리기 어렵거나 여러 Task에 영향을 주는 결정만 기록한다.
상세 구현 선택은 Task Evidence에 남긴다.

## D-001 — CCR을 공통 Runtime으로 사용

- Status: ACCEPTED
- Decision: Gateway, protocol conversion, Provider/model, Native routing을 새로 구현하지 않는다.
- Rationale: CCR upstream 기능을 보존하고 유지보수 범위를 줄인다.

## D-002 — Native-first 제품 방향

- Status: ACCEPTED
- Decision: V1/V2는 라우팅 알고리즘 세대가 아니라 Company Wrapper의 제품 성숙도다.
- Rationale: `static-economy`는 선택 실험이고, CCR Native 기능을 제한하지 않는다.

## D-003 — 외부 개발, 사내 테스트 전용

- Status: ACCEPTED
- Decision: 외부 Codex가 구현하고 사내는 정확한 commit을 pull해 문서화된 검증만 수행한다.
- Rationale: 사내에서 발생한 임시 수정과 외부 코드의 분기를 방지한다.

## D-004 — 하나의 Git repository와 upstream history 보존

- Status: ACCEPTED
- Decision: submodule 없이 CCR history와 Company layer를 한 저장소에 둔다.
- Rationale: 사내에서 하나의 repository를 그대로 pull/mirror한다.

## D-005 — Public-safe tracked content

- Status: ACCEPTED
- Decision: 저장소 visibility와 무관하게 tracked 파일에는 사내 비밀·원문 증거를 넣지 않는다.

## D-006 — 사람 중심 Gate

- Status: ACCEPTED
- Decision: Codex는 Recommendation과 Evidence를 작성할 수 있지만 Stage 통과와 다음 Task 활성화는 사람이 결정한다.
