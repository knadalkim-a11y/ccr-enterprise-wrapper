# Dual-Isolated Claude Code Execution

## 목적

기존 Claude Code Enterprise 환경을 변경하지 않고, 사용자가 명시적으로 Company 실행 경로를 선택한 경우에만 CCR와 사내 모델을 사용한다.

사용자에게 보이는 계약은 단순하다.

```text
claude
→ 기존 Enterprise Claude Code

company-claude
→ CCR 전용 Claude Code
```

`company-claude`는 V1의 논리적 명령 이름이다. 실제 `.cmd`, PowerShell launcher 또는 설치 패키지는 후속 구현 Task에서 확정한다.

## 핵심 원칙

```text
CCR service ON/OFF
≠
일반 claude 설정 전환

어떤 명령으로 실행했는가
=
어떤 설정과 모델 경로를 사용하는가
```

| 실행 경로 | CCR service ON | CCR service OFF |
|---|---|---|
| `claude` | Enterprise 정상 | Enterprise 정상 |
| `company-claude` | CCR 경유 사내 모델 | launcher가 CCR를 시작하거나 명확히 실패 |

이미 실행 중인 `company-claude` 세션은 CCR가 중지되어도 Enterprise로 자동 전환하지 않는다.
V1은 모델 경계와 비용 측정을 숨기지 않기 위해 fail-closed를 사용한다.

## 왜 이중 격리가 필요한가

### 1. Claude Code 설정 격리

CCR의 `Only opened from CCR` 프로필은 별도 설정 파일을 만들고, CCR 전용 launcher가 해당 자식 프로세스에만 `CLAUDE_CONFIG_DIR`을 전달한다.

```text
일반 claude
→ %USERPROFILE%\.claude\settings.json

CCR profile
→ %APPDATA%\claude-code-router\profiles\<profile>\claude\settings.json
```

V1에서 허용되는 Claude Code 프로필:

```text
Effect scope: Only opened from CCR
Internal scope value: ccr
Entry mode: CLI only
System default: prohibited
```

CCR용 Base URL, WIF/Federation, model override, apiKeyHelper와 MCP 설정은 CCR 프로필 디렉터리 또는 CCR 자식 프로세스에만 존재해야 한다.

### 2. CCR Runtime side-effect 격리

Stock CCR의 management/gateway 시작과 config 저장은 Claude App Gateway 설정 동기화를 호출할 수 있다.
Windows 기본 대상은 다음이다.

```text
%LOCALAPPDATA%\Claude-3p
```

따라서 `Only opened from CCR`만 사용해도 CCR management process가 실제 Claude Desktop 설정을 변경할 수 있다.

V1은 CCR service process에만 별도 `LOCALAPPDATA`를 제공하는 방식을 먼저 검증한다.

```text
CCR service/admin process
→ LOCALAPPDATA = Company CCR sandbox
→ APPDATA = 기존 값 유지
→ USERPROFILE = 기존 값 유지

일반 claude / Enterprise Claude Desktop
→ 원래 LOCALAPPDATA 유지

company-claude child
→ 원래 LOCALAPPDATA 유지
→ CLAUDE_CONFIG_DIR만 CCR profile로 지정
```

개념적 sandbox 위치:

```text
%APPDATA%\CompanyCCR\runtime-localappdata
```

이 경로는 설계 alias다. 실제 설치 경로는 Wrapper Task에서 확정한다.

### 3. Claude-3p 검증 범위

CCR `v3.0.22`의 확인된 Windows Claude App Gateway write surface는 다음 세 설정 파일이다.

```text
%LOCALAPPDATA%\Claude-3p\claude_desktop_config.json
%LOCALAPPDATA%\Claude-3p\configLibrary\_meta.json
%LOCALAPPDATA%\Claude-3p\configLibrary\8f69f2f1-3275-4ad8-9317-4aa7e972f311.json
```

격리 Gate는 위 파일들의 존재 상태와 내용 fingerprint를 before/during/after 비교한다.
`Claude-3p` 전체 디렉터리에는 앱 캐시나 독립적인 업데이트 파일이 생길 수 있으므로, 전체 tree hash를 Gate로 사용하지 않는다.

개념적 불변성은 실제 `Claude-3p` 영역 전체에 적용되지만, 자동 비교는 CCR가 소스상 쓰는 정확한 설정 surface에 한정하고 마지막에 일반 Claude Desktop smoke로 보완한다.

## Enterprise baseline — 불변 영역

다음은 Company Wrapper가 정상 동작 중일 때 변경하면 안 된다.

```text
%USERPROFILE%\.claude\settings.json
일반 claude 실행 경로와 PATH 우선순위
Windows Process/User/Machine CCR 관련 환경 경계
기존 Enterprise 인증 상태
기존 Enterprise 모델 목록
실제 %LOCALAPPDATA%\Claude-3p의 CCR-managed config surface
일반 Claude Desktop 상태
```

특히 다음 값이 Enterprise 기본 설정에 생기면 `ISOLATION_BREACH`다.

```text
ANTHROPIC_BASE_URL
ANTHROPIC_API_BASE_URL
CLAUDE_AGENT_API_BASE_URL

ANTHROPIC_FEDERATION_RULE_ID
ANTHROPIC_ORGANIZATION_ID
ANTHROPIC_IDENTITY_TOKEN
ANTHROPIC_IDENTITY_TOKEN_FILE
ANTHROPIC_SERVICE_ACCOUNT_ID
ANTHROPIC_WORKSPACE_ID
ANTHROPIC_SCOPE
ANTHROPIC_PROFILE

ANTHROPIC_MODEL
CCR_CLAUDE_CODE_MODEL
CODEXL_CLAUDE_CODE_MODEL
ANTHROPIC_DEFAULT_FABLE_MODEL
ANTHROPIC_DEFAULT_OPUS_MODEL
ANTHROPIC_DEFAULT_SONNET_MODEL
ANTHROPIC_DEFAULT_HAIKU_MODEL
ANTHROPIC_SMALL_FAST_MODEL

apiKeyHelper
CCR_CLAUDE_CODE_MCP_CONFIG
CODEXL_CLAUDE_CODE_MCP_CONFIG
```

원래 Enterprise가 동일 이름의 값을 사용하고 있었다면 삭제가 아니라 원래 값 보존이 기준이다.

## CCR가 변경해도 되는 영역

```text
%APPDATA%\claude-code-router\**
%APPDATA%\CompanyCCR\runtime-localappdata\**
CCR 전용 profile/settings.json
CCR 전용 wrapper/token/MCP 파일
Company Wrapper의 로컬 상태·진단 파일
```

실제 secret, settings 원문, token 파일은 Git 또는 외부 handoff에 포함하지 않는다.

## Launcher 계약

최종 `company-claude`는 논리적으로 다음을 수행한다.

```text
1. Enterprise baseline invariant quick check
2. CCR service health 확인
3. 필요하면 CCR service를 sandbox LOCALAPPDATA로 시작
4. 승인된 CCR profile 존재·scope=ccr·surface=cli 확인
5. 자식 실행 환경에서 원래 LOCALAPPDATA/APPDATA/USERPROFILE 경계를 복원
6. CCR profile launcher로 기존 claude 실행
7. CCR 연결 실패 시 Enterprise로 자동 fallback하지 않고 명확히 실패
8. 세션 종료 후 service lifecycle 정책에 따라 유지 또는 stop
9. Enterprise baseline이 계속 정상인지 Doctor에서 확인
```

서비스용 sandbox `LOCALAPPDATA`를 `company-claude` 자식이 그대로 상속하면 안 된다.
`company-claude` 자식은 원래 Windows 사용자 환경을 유지하고 `CLAUDE_CONFIG_DIR`과 CCR 전용 child-only 값만 추가해야 한다.

초기 검증에서는 launcher 구현 전이므로 Task에 명시된 PowerShell 명령으로 같은 환경 경계를 수동 재현한다.

## 검증 경계

```text
V1-S1-T00
→ CCR management/config-save process의 LOCALAPPDATA sandbox
→ Enterprise 설정과 Claude-3p write surface 불변성

V1-S2 isolated launcher Tasks
→ company-claude 자식이 원래 LOCALAPPDATA를 받는지
→ CCR-scoped CLAUDE_CONFIG_DIR만 적용되는지
→ 일반 claude와 동시에 분리되는지
```

T00 PASS만으로 `company-claude` launcher end-to-end 격리가 증명됐다고 주장하지 않는다.

## 금지된 실행 방식

V1에서는 다음을 사용하지 않는다.

```text
System default Claude Code profile
기본 settings.json에 CCR 설정 덮어쓰기
User/Machine 환경변수에 CCR 값을 영구 저장
일반 claude 명령을 CCR wrapper로 교체
Stock CCR start/save를 실제 LOCALAPPDATA에서 수행
Claude App/Desktop을 CCR에 연결
CCR 장애 시 Enterprise/Sonnet 자동 fallback
수동 settings.ccr.json ↔ settings.json 교체를 정상 운영 방식으로 사용
```

Enterprise settings 백업은 비상 복구용으로 PC 로컬에 둘 수 있지만, 정상 lifecycle은 복구가 필요 없어야 한다.

## Failure classification

| Classification | Meaning |
|---|---|
| `ISOLATION_PRECONDITION` | 안전한 runtime/profile 경계가 아직 준비되지 않음 |
| `ISOLATION_BREACH` | Enterprise 불변 영역이 변경됨 |
| `CLIENT_AUTH_CONFIG_PERSISTENCE` | CCR 인증/Base URL 설정이 Enterprise client에 잔존 |
| `CLAUDE_APP_CONFIG_PERSISTENCE` | 실제 Claude-3p의 CCR-managed config surface에 CCR 설정이 잔존 |
| `RUNTIME_SANDBOX_INCOMPATIBLE` | process-local LOCALAPPDATA 방식으로 Stock CCR를 안정적으로 실행할 수 없음 |
| `CHILD_ENVIRONMENT_LEAK` | service sandbox 환경이 company-claude 자식에 잘못 상속됨 |
| `ENTERPRISE_BASELINE_FAILURE` | CCR와 무관한 Enterprise 기준선 자체가 정상 아님 |

`ISOLATION_BREACH`가 발생하면 해당 Task는 FAIL이다.
사람이 로컬 백업으로 복구할 수 있어도 PASS로 승격하지 않는다.

## V1 Task 순서

```text
V1-S1-T00
→ CCR Runtime sandbox와 Enterprise baseline invariance

V1-S1-T01
→ 격리된 runtime에서 Gemma Provider finalization

V1-S1 later Tasks
→ local gateway completion / streaming / tools

V1-S2
→ Enterprise baseline manifest
→ Only opened from CCR + CLI-only profile
→ company-claude child environment boundary
→ isolated company-claude request
→ stop repeatability
→ workload vertical slice
```

Claude App/Desktop 연결과 `System default`는 별도 Task가 승인되기 전까지 지원 범위 밖이다.

## 현재 상태

- `claude` Enterprise 환경은 수동 복구 후 정상이다.
- Gemma Chat Completions protocol evidence는 유효하다.
- 기존 CCR runtime config는 글로벌 설정 잔존 경험이 있어 그대로 재개하지 않는다.
- process-local `LOCALAPPDATA` sandbox는 소스상 가능한 최소 Wrapper 해법이지만 사내 검증 전까지 확정 구현이 아니다.
- T00은 management/runtime 격리만 검증하며 `company-claude` 자식 격리는 V1-S2에서 별도로 증명한다.
- sandbox가 실패하면 `CCR_DISABLE_CLAUDE_APP_GATEWAY_SYNC` 같은 명시적 최소 Core patch를 증거 기반으로 검토한다.
