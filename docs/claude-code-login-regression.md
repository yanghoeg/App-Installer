# Claude Code 버전 핀과 로그인 복구

설치 방식과 버전의 기준은 [claude_code.sh](../domain/installers/claude_code.sh)입니다.
현재 `CLAUDE_CODE_PIN_VERSION`은 **2.1.261**이고 해당 tarball의 SHA-256이
`CLAUDE_CODE_TARBALL_SHA256`에 등록되어 있습니다. 설치기는 npm 전역 패키지 대신
ARM64 바이너리를 받아 `$PREFIX/share/claude-code`에 배치하고 `grun` 래퍼로 실행합니다.

소스 주석에는 이 핀의 실기기 `/login` 확인 기록이 있습니다. 이는 새 버전이나 다른
기기에서의 로그인 검증을 대신하지 않으며 자동 스모크 검사와도 구분해야 합니다.

## 설치와 업그레이드 동작

- 설치와 GUI 업그레이드 모두 고정 버전을 사용합니다. 핀을 비워야 npm `latest`를
  조회하므로 GUI의 업그레이드가 항상 업스트림 최신 버전을 뜻하지는 않습니다.
- 설치 버전은 `$PREFIX/share/claude-code/VERSION`에 기록합니다.
- GUI 업그레이드는 기록된 기존 바이너리를 `claude.bak.v<버전>`으로 백업합니다.
  같은 이름의 백업이 있으면 보존하며, 가능하면 `package.json`도 함께 백업합니다.
- 다운로드 실패나 `grun …/claude --version` 실패 시 기존 버전 백업으로 복원을
  시도합니다. 버전 기록·백업이 없는 설치에는 이 복원을 보장할 수 없습니다.
- 스모크 검사는 바이너리 실행만 확인합니다. `/login`, 브라우저 복귀, 실제 요청은
  검사하지 않으며 최초 설치에는 이 업그레이드용 백업·스모크 절차가 없습니다.
- 새 `~/.claude/settings.json`에는 `DISABLE_AUTOUPDATER=1`을 넣습니다. 기존 파일은
  수정하지 않으므로 이미 설정 파일이 있다면 자동 갱신 설정도 직접 확인해야 합니다.

CLI의 `install claude_code`는 이미 설치된 항목을 건너뜁니다. 업그레이드는 GUI의
**업그레이드**를 사용하며 `app-install.sh`에 `upgrade`나 `rollback` 명령은 없습니다.

## 백업에서 수동 복원

Termux의 **App Installer 저장소 폴더**에서 실행합니다. 기본 셸이 zsh여도 Bash 함수가
올바르게 로드되도록 `bash -c`를 사용합니다.

```bash
# 수정 시각이 가장 최근인 사용 가능한 백업 복원
bash -c 'source domain/installers/claude_code.sh; app_rollback_claude_code'

# 복원 후 바이너리 실행 확인
claude --version
```

특정 백업을 고르려면 위 함수에 백업 파일명의 버전 접미사를 인자로 전달합니다.
해당 `claude.bak.v<버전>`이 없으면 실패합니다. 버전을 지정하지 않았을 때의 선택 기준은
백업 파일의 수정 시각이며 버전 번호의 대소가 아닙니다. 복원은 바이너리·버전 기록·래퍼와
존재하는 `package.json` 백업을 바꾸며 사용자 인증·설정 파일을 되돌리지는 않습니다.
`claude --version` 확인 후 필요한 경우 실제 `/login`과 요청도 따로 검증하세요.

**신규 설치에는 이전 버전 백업이 없습니다.** 소스의 버전 상수만 과거 값으로 바꾸는
것을 복구 절차로 쓰지 마세요. 해시가 등록되지 않은 버전은 `fetch_verified`가 경고만
내고 검증을 생략합니다. 다른 버전을 배포하려면 아래의 핀 갱신 절차를 따릅니다.

## 핀 갱신과 실기기 확인

1. 후보 버전의 공식 릴리스·보안 안내와 ARM64 tarball을 확인합니다.
2. tarball을 출처의 무결성 정보와 대조하고 `CLAUDE_CODE_PIN_VERSION`과
   `CLAUDE_CODE_TARBALL_SHA256`을 함께 갱신합니다. 핀만 바꾸지 않습니다.
3. [호스트 테스트](../README.ko.md#테스트)로 다운로드 실패·업그레이드·복원 경로를 확인합니다.
4. 기존 버전 기록과 백업을 확보한 실기기에서 GUI 업그레이드를 실행합니다. 이 경로가
   백업을 만들므로 이미 설치된 바이너리에 `app_install_claude_code`를 직접 호출해
   업그레이드 절차를 우회하지 않습니다.
5. `claude --version`, `/login`의 URL 표시·브라우저 인증·터미널 복귀, 인증 후 실제 요청을
   각각 확인합니다. 로그인 시험에서는 기존 환경 토큰이 결과를 가리지 않는지도 확인합니다.
6. 실패하면 사용 가능한 백업으로 복원하고 재현 조건을 보고합니다. 새 핀의 버전 스모크
   성공을 로그인 회귀 해결로 표시하지 않습니다.

## 브라우저 로그인이 어려운 환경

브라우저 로그인이 가능한 PC 등에서 `claude setup-token`으로 토큰을 만든 뒤 Termux의
`CLAUDE_CODE_OAUTH_TOKEN`으로 사용할 수 있습니다. 이는 공식 문서의 비대화형 인증
방식이며 Termux `/login` 회귀가 해결되었음을 뜻하지는 않습니다.
[공식 인증 안내](https://code.claude.com/docs/en/authentication#generate-a-long-lived-token)를
참고하세요.

```bash
# 브라우저 인증이 가능한 환경
claude setup-token

# Termux: 발급받은 토큰을 넣어 실행
export CLAUDE_CODE_OAUTH_TOKEN='your-token'
claude
```

환경 토큰이 남아 있으면 다음 세션에서도 사용하므로 `/login` 자체를 시험할 때는
`unset CLAUDE_CODE_OAUTH_TOKEN` 후 실행하고 셸 프로필·설정 파일의 토큰 주입도 확인합니다.
토큰 값은 테스트 로그나 이 문서에 기록하지 않습니다.
