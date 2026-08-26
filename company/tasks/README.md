# Task System

Task 파일이 요구사항과 Acceptance Criteria의 유일한 Source of Truth다.
GitHub Issue와 PR은 Task 파일을 링크하고 진행 대화와 Evidence만 담는다.

## 규칙

- Task는 validation question 하나를 가진다.
- Task는 여러 Codex 세션을 가질 수 있다.
- 세션 하나는 활성 Task 하나만 다룬다.
- 각 Task는 Allowed Paths와 Out of Scope를 명시한다.
- Attempts는 덮어쓰지 않고 누적한다.
- Codex는 Recommendation을 작성하고, Human Decision은 사용자가 작성한다.
- Task 완료가 Stage Gate 통과를 자동으로 의미하지 않는다.
- `project-state.yml`의 current Task 변경은 사람의 별도 결정으로 수행한다.
