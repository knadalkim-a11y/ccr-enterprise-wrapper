# Company Layer Agent Instructions

- `company/project-state.yml`과 활성 Task가 Company 작업의 현재 기준이다.
- Company-owned 구현은 기본적으로 `company/` 아래에 둔다.
- upstream 경로 수정은 Task가 허용하고 config/extension으로 해결 불가한 증거가 있을 때만 한다.
- 가장 작은 vertical experiment로 다음 투자 결정을 위한 증거를 만든다.
- V1 Task에서 V2 abstraction을 추가하지 않는다.
- 외부에서는 synthetic mock과 CCR 기존 test utility를 우선 사용한다.
- 사내 검증은 product code 수정 없이 실행 가능해야 한다.
- Trap은 재현 또는 코드 근거, 회피법, 적용 버전, Task/commit 증거가 있을 때만 등록한다.
- Task 파일이 Issue/PR보다 우선하는 유일한 요구사항 Source of Truth다.
