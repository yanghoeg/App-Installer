# Claude Code 버전 핀(2.1.132) — Termux `/login` 회귀 추적 기록

최종 갱신: 2026-09-02

## 요약

- `domain/installers/claude_code.sh`의 `CLAUDE_CODE_PIN_VERSION="2.1.132"`는 **의도된 고정**이다.
  일정 버전 이상에서 Termux 환경의 `/login`(브라우저 OAuth)이 실패해 이 버전에 묶어 두었다
  (핀 커밋 c92ebf3 · 9086b6a, 2026-07 — "v2.1.207에서 로그인 회귀 발생 사례").
- 업스트림에서 이 회귀가 **고쳐졌다는 확증은 없다**. Termux 를 직접 언급한 이슈·CHANGELOG 항목이 없다.
- 기기 테스트가 가능해지기 전까지 핀을 올리지 않는다. 테스트 가능해지면 아래 계획대로 **후보 1개만** 시험한다.

## 핀 유지의 대가 (보안 advisory)

2.1.132 에는 공개된 취약점 2건이 걸려 있다.

| Advisory | 심각도 | 영향 범위 | 수정 버전 |
|---|---|---|---|
| GHSA-7835-87q9-rgvv | HIGH (샌드박스 탈출) | `>=2.1.38, <2.1.163` | 2.1.163 |
| GHSA-fg94-h982-f3mm | — | `>=0.2.54, <2.1.163` | 2.1.163 |

핀을 올리는 목표 하한 = **2.1.163 이상**.

## 이슈 조사 (anthropics/claude-code, 2026-09-02 기준)

Termux `/login` 회귀를 직접 기술한 이슈는 없다. 관련만 존재:

- #22398 — Termux 에서 PKCE `s256` 실패 (stale 로 자동 종료, 해결 안 됨)
- #50270 · #84639 · #86798 · #76565 — SSH/헤드리스 환경 OAuth 실패류

## CHANGELOG 인증 관련 타임라인 (원문 직접 대조)

| 버전 | 내용 | 의미 |
|---|---|---|
| 2.1.207 | 오토업데이터가 `~/.local/bin/claude` 커스텀 런처/심링크를 매 릴리스 덮어쓰던 문제 수정. `/doctor`가 외부관리 런처를 보고 | 핀 커밋이 지목한 회귀 지점. 런처/경로 처리 변경이 `grun` 래퍼 구조와 충돌했을 가능성이 가장 높다 |
| 2.1.208 | "(2.1.207 regression)" 핫픽스 | 2.1.207 이 깨진 릴리스였음을 업스트림이 인정 |
| 2.1.243 | `/login` over SSH 개선: 사인인 URL 즉시 표시 | 헤드리스 로그인 경로 개선 |
| 2.1.248 | Console 사인인이 URL 표시 전 OAuth 에러로 실패하던 문제 수정, API-key 사인인 폴백 추가 | Termux 증상과 가장 유사하나 Termux 언급 없음 |

2.1.132 → 2.1.207 사이에는 `/login` 관련 변경 항목이 없다.

npm arm64 타볼(`@anthropic-ai/claude-code-linux-arm64`) 존재 확인: 2.1.132 / 2.1.207 / 2.1.250 / 2.1.257 / 2.1.258 모두 200.

## 기기 테스트 계획

1. **2.1.258** 을 설치해 `/login` 시험. 성공하면 `CLAUDE_CODE_PIN_VERSION` 을 그 버전으로 갱신한다.
2. 실패하면 bisect 하한 = **2.1.169** (advisory 수정 직후, 2.1.207 이전). 2.1.169 성공 / 2.1.258 실패면 그 사이를 이분 탐색.
3. 시험 방법: 핀 값만 바꿔 `app_install_claude_code` 재실행 → `claude` 실행 → `/login`.
   `~/.claude/settings.json` 의 `DISABLE_AUTOUPDATER=1` 은 그대로 둔다.

## 핀 유지 중 우회 — 브라우저 OAuth 없이 로그인

PC 등 정상 환경에서 장기 토큰을 발급해 Termux 에 환경변수로 넘긴다 (공식 docs `code.claude.com/docs/en/authentication`).

```bash
# PC (로그인 가능한 환경)
claude setup-token          # 출력된 토큰 복사

# Termux
export CLAUDE_CODE_OAUTH_TOKEN='<토큰>'
claude
```

제약:
- Pro / Max / Team / Enterprise 플랜 필요.
- `--bare` 모드에서는 이 변수를 읽지 않는다.
- Remote Control · 커넥터 등 브라우저 세션이 필요한 기능은 안 된다.
