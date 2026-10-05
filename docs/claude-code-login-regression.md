# Claude Code 버전 핀과 로그인 복구

설치 방식과 버전의 기준은 [claude_code.sh](../domain/installers/claude_code.sh)입니다.
현재 `CLAUDE_CODE_PIN_VERSION`은 **2.1.286**이고 해당 tarball의 SHA-256이
`CLAUDE_CODE_TARBALL_SHA256`에 등록되어 있습니다(직전 핀 2.1.261의 해시도 롤백 재설치
검증용으로 남겨 둡니다). 설치기는 npm 전역 패키지 대신 ARM64 바이너리를 받아
`$PREFIX/share/claude-code`에 배치하고 `grun` 래퍼로 실행합니다.

현재 핀 2.1.286은 **실기기 `/login`을 2026-10-01 에 확인했습니다**(아래 변경 이력).
이 기록은 해당 기기·해당 버전에 한합니다 — 새 버전이나 다른 기기에서의 로그인 검증을
대신하지 않으며 자동 스모크 검사와도 구분해야 합니다.

## 설치와 업그레이드 동작

- 설치와 GUI 업그레이드 모두 고정 버전을 사용합니다. 핀을 비워야 npm `latest`를
  조회하므로 GUI의 업그레이드가 항상 업스트림 최신 버전을 뜻하지는 않습니다.
- 설치 버전은 `$PREFIX/share/claude-code/VERSION`에 기록합니다.
- 다운로드는 `$PREFIX/share/claude-code/.stage`에 푼 뒤 `rename`으로 바꿔 끼웁니다.
  실행 중인 claude 위에 제자리로 덮어쓰면 그 세션이 SIGBUS로 죽기 때문입니다 —
  `grun`은 `ld.so`가 바이너리를 mmap으로 올리므로 커널 deny-write(`ETXTBSY`)가 안 걸립니다.
- 복원(`app_rollback_claude_code`)도 같은 이유로 `claude.restore`에 복사한 뒤 `rename`
  으로 바꿔 끼웁니다. 제자리 덮어쓰기는 실행 중 세션을 죽이고, 복사가 끊기면 짧은
  파일이 남아 다음 실행이 `ld.so`의 `file too short`로 깨집니다.
- `$PREFIX/bin/claude` 래퍼는 `grun` 실행 전에 `env -u LD_PRELOAD`로 LD_PRELOAD를 떼어냅니다.
  부모 `domain/termux_env.sh`가 RC에 넣는 bionic `force_gettext.so`가 glibc 바이너리의
  `libdl.so` 로딩을 깨뜨리기 때문입니다.
- GUI 업그레이드는 기록된 기존 바이너리를 `claude.bak.v<버전>`으로 백업합니다.
  같은 이름의 백업이 있으면 보존하며, 가능하면 `package.json`도 함께 백업합니다.
- 다운로드 실패나 `grun …/claude --version` 실패 시 기존 버전 백업으로 복원을
  시도합니다. 버전 기록·백업이 없는 설치에는 이 복원을 보장할 수 없습니다.
- 스모크 검사는 바이너리 실행만 확인합니다. `/login`, 브라우저 복귀, 실제 요청은
  검사하지 않으며 최초 설치에는 이 업그레이드용 백업·스모크 절차가 없습니다.
- 새 `~/.claude/settings.json`에는 `DISABLE_AUTOUPDATER=1`을 넣습니다. 기존 파일은
  수정하지 않으므로 이미 설정 파일이 있다면 자동 갱신 설정도 직접 확인해야 합니다.

CLI의 `install claude_code`는 이미 설치된 항목을 건너뛰지만, 건너뛰기 전에
`app_verify_claude_code`(= 스모크 검사)로 바이너리가 실제로 로드되는지 확인합니다.
내용이 깨진 설치본은 `app_is_installed_claude_code`의 실행권한 검사를 통과하므로,
이 확인이 없으면 재설치로 복구할 수 없었습니다. 업그레이드는 GUI의 **업그레이드**를
사용하며 `app-install.sh`에 `upgrade`나 `rollback` 명령은 없습니다.

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

## 변경 이력

### 2026-10-01 (2) — 손상된 설치본 복구 경로, 롤백 스왑

증상: 실기기에서 claude 가 `file too short`로 실행되지 않았습니다. 바이너리는
`$PREFIX/share/claude-code/claude`(2.1.286) 그대로였고 디렉터리 mtime 상 설치기가
건드린 흔적은 없었습니다 — 리뷰 서브에이전트 14개가 돌던 중 Android LMK 가 Termux 를
통째로 죽인 시점(14:20)을 전후로 같은 inode 의 내용만 깨졌습니다. 2.1.286 자체는 정상
(tarball 재다운로드 SHA-256 일치, `grun …/claude --version` 성공)이었고 복구는
`app_rollback_claude_code 2.1.261` 로 했습니다.

- `app-install.sh install claude_code` 로는 복구가 안 됐습니다. `app_is_installed_claude_code`
  가 `-x` 만 보므로 깨진 바이너리도 "이미 설치되어 있습니다"로 빠졌습니다 →
  `app_verify_<id>` 훅(`domain/apps.sh`의 `app_verify`)을 추가하고 `cmd_install` 이
  확인 실패 시 재설치로 복구하게 했습니다. Claude Code 의 훅은 기존 스모크 검사입니다.
- `app_rollback_claude_code` 가 `cp -f` 로 제자리 덮어쓰기를 했습니다 → download 와 같은
  staging + `rename` 스왑으로 교체. 240MB 파일로 실측하니 제자리 덮어쓰기는 매핑된
  프로세스에 SIGBUS 111,221 회를 일으키고(MAP_PRIVATE COW 페이지까지 덮임) `rename`
  스왑은 0 회였습니다.

  회귀 테스트: `tests/test_domain_apps.sh` → "롤백 → 제자리 덮어쓰기 대신 rename 으로 교체",
  "app_verify — 설치본 무결성 확인"; `tests/test_cli.sh` → corrupt/healthy Claude install.

### 2026-10-01 — 핀 2.1.261 → 2.1.286, 설치기 버그 2건 수정

- npm `@anthropic-ai/claude-code-linux-arm64` latest 추종. **보안 상향은 아닙니다** —
  GitHub advisory DB 전수 조회 기준 `@anthropic-ai/claude-code`의 미해소 하한 최댓값은
  여전히 2.1.163이라 직전 핀 2.1.261도 이미 그 위였습니다.
- tarball SHA-256을 npm `integrity`(sha512)·`shasum`(sha1) 양쪽과 교차 대조해 등록.
- 2.1.262~2.1.286 CHANGELOG에 런처/심링크 덮어쓰기(2.1.207류) 항목 없음.
- 이번 상향과는 별개의 기존 버그 2건을 함께 고쳤습니다.
  1. 래퍼가 `env -u LD_PRELOAD`를 빠뜨려, 기기에 손으로 넣어 둔 해제가 설치·업그레이드·
     복원 때마다 되돌아갔습니다.
  2. 다운로드가 실행 중 바이너리 위에 제자리로 풀어, claude 안에서 업그레이드하면 그
     세션이 죽었습니다 → staging + `rename` 스왑으로 교체.

  회귀 테스트: `tests/test_domain_apps.sh` → "claude_code — 래퍼 LD_PRELOAD 해제 + 세션 보존 스왑".
- **실기기 `/login` 2026-10-01 확인.** 위 "핀 갱신과 실기기 확인" 5단계대로
  사인인 URL 표시 → 브라우저 인증 → 터미널 복귀 → 인증 후 실제 요청까지 정상.
  `CLAUDE_CODE_OAUTH_TOKEN`·`ANTHROPIC_API_KEY` 가 환경과 셸 프로필 어디에도 없어
  기존 토큰이 결과를 가리지 않는 조건이었다. 롤백용 백업은
  `claude.bak.v2.1.261`·`claude.bak.v2.1.132` 가 남아 있다.

### 2026-09-05 — 핀 2.1.132 → 2.1.261

- GHSA-7835-87q9-rgvv (HIGH, `>=2.1.38 <2.1.163`)와 같은 하한의 GHSA-fg94-h982-f3mm 해소.
- 실기기 `/login` 2026-09-06 확인.
