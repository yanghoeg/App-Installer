# App Installer 실기기 검증 체크리스트

이 파일은 검증 절차이며 완료된 테스트 결과나 진행 로그가 아닙니다.
현재 앱 ID와 설치 대상은 [README.ko.md](README.ko.md#지원-앱-목록), 구현 목록은
[domain/apps.sh](domain/apps.sh)를 기준으로 합니다. 호스트 테스트와 실제 설치
스크립트의 차이는 부모 저장소의 [설치 검증 안내](../tests/INSTALL_MATRIX.md)를 참고하세요.

## 환경 확인

- 기기 모델·GPU, Android·Termux 버전, Termux APK 배포 경로를 확인합니다.
- 부모 저장소와 App Installer 커밋, 변경된 작업 트리, 실제 설치한 패키지 버전을 기록합니다.
- `~/.config/termux-xfce/config`의 `PROOT_DISTRO`, `PROOT_USER`, `DISPLAY_SERVER`,
  `PROOT_SHELL`과 실제 rootfs 경로를 확인합니다.
- X11과 Wayland는 별도 세션으로 확인합니다. Anland는
  [알려진 문제](../docs/wayland-anland.md#known-blockers)가 남은 실험적 경로입니다.

## 확인할 항목

| 대상 | 환경 | 확인 내용 |
|------|------|-----------|
| 기본 desktop·proot | native 전용, Ubuntu, Arch | 새 설치와 재실행, 선택한 셸, `prun` 진입 및 GUI 명령, 저장 설정 보존 |
| native GUI | `thunderbird`, `vlc`, `gimp`, `inkscape`, `audacity` | 설치 → 메뉴 실행 → 종료 → 제거. native 앱을 배포판별 설치 결과로 중복 집계하지 않음 |
| Notion | Termux native | Firefox 웹 런처, 기존 AppImage 런처 업그레이드, 기존 데이터 보존과 제거 범위 |
| proot GUI | Ubuntu / Arch의 `vscode`, `libreoffice`, `nautilus`, `dbeaver`, `burpsuite`, `teams`, `thorium`, `sasm` | `prun-gui` 실행, 인자·파일 경로 전달, 현재 DISPLAY, 설치·제거 실패 시 런처 상태 |
| proot CLI | `miniforge`, `onepassword` | 컨테이너 셸에서 명령 실행과 제거 |
| Tor Browser | 기존 `tor_browser` 설치만 | GUI에서 제거 항목 표시, 상태 확인·제거. 신규 설치 성공을 기대하지 않음 |
| native 입력기 | `korean_input`, `nimf` | 선택 전환, 선택된 입력기만 자동 시작, 제거 후 선택 해제, XFCE 재시작 후 한글 입력 |
| proot 입력기 | `korean_proot` | 컨테이너 로그인 프로필, Ubuntu nimf, Arch nimf 또는 fcitx5 폴백, 앱에서 한글 입력 |
| UI 번역 | `korean_locale` | 카탈로그 ZIP 설치, gettext 훅 빌드, native 앱 번역, 제거 후 세션 재시작 |
| GPU | `gpu_native`, `gpu_proot` | 실제 렌더러, KGSL/Turnip 검사 결과, 소프트웨어 폴백, 제거 후 설정 정리 |
| Wine | `wine`, `hangover`와 각 Windows 앱 | 백엔드 전환, 분리된 prefix, 앱 실행, 공용 런처의 상태 판정과 제거 대상 |
| AI·개발 CLI | `claude_code`, `codex`, `llama_cpp` 등 | 실행·인증 또는 모델 로드. `--version` 성공과 실제 기능 성공을 구분 |
| Termux API | `api_*` 항목 | APK·패키지 연결, 요청한 Android 기능. `api_conky_battery`는 XFCE Generic Monitor에 수동 추가 |
| 캡처·세션 | X11 / Wayland | `screenshot`의 full/region/window, 시작·재시작·종료, 자식 프로세스 정리 |

`wayvnc`는 wlroots용이며 Anland/KWin에서는 지원하지 않습니다. 앱 목록에 있다고
현재 데스크탑에서 실행 가능한 것으로 판정하지 않습니다.

## 결과 구분

각 항목은 **통과 / 실패 / 미실행 / 해당 없음** 중 하나로 보고하고 재현 명령과 필요한
로그를 연결합니다. CLI 전용 앱에 메뉴 아이콘이 없는 것은 실패가 아닙니다.
새 버전의 인증 검증에는 [Claude Code 복구 안내](docs/claude-code-login-regression.md)를
참고하세요. 이 체크리스트의 존재나 호스트 테스트 통과만으로 실기기 통과를 표시하지 않습니다.
