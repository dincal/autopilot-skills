# Technical Design Decisions

<!-- Append-only, dated log of DEVELOPMENT design decisions: architecture,
     data model, storage, API contracts, framework/library choices, code
     patterns, infrastructure. UI/UX design belongs in design.md, NOT here.
     Never delete or rewrite existing entries — supersede them with a new entry.
     Entries authored by the user take precedence over agent-observed ones. -->

## Decisions

### 2026-07-07 — 플러그인 아키텍처: 마크다운 프롬프트 + bash 훅
- Context: Claude Code 플러그인 구조 선택
- Decision: 빌드 스텝 없는 순수 콘텐츠 구조 — skills/(SKILL.md + references/), agents/,
  hooks/(bash + python3 JSON 파싱), templates/. 진실 원천은 프롬프트 문서
- Alternatives considered: MCP 서버 동봉 — 배포·유지 복잡도 대비 이득 없음
- Decided by: user

### 2026-07-07 — 병렬 개발: 명시적 git worktree + 백그라운드 에이전트
- Context: N개 기능 동시 개발 방식
- Decision: 기능별 worktree(저장소 밖 형제 디렉토리) + 백그라운드 feature-dev 에이전트.
  Agent tool 내장 worktree isolation 대신 명시적 관리 (브랜치명·수명주기 제어 필요)
- Alternatives considered: 순차 개발(느림), 내장 isolation(수명주기 제어 상실)
- Decided by: user

### 2026-07-07 — GitHub + gh CLI 전제, 폴백 없음
- Decision: PR 생성·리뷰 코멘트·머지 전부 gh. 원격 없으면 개발 스킬은 안내 후 중단
- Decided by: user

### 2026-07-08 — 런 브랜치 구조로 base 절연
- Context: 실행마다 브랜치가 쌓이고 무인모드가 main을 건드리는 문제
- Decision: 런마다 run 브랜치 생성, 기능 PR은 런 브랜치로, base는 runMerge 게이트를
  거친 런 PR 하나로만 접촉. 무인모드는 base 머지 절대 금지(파킹)
- Decided by: user

### 2026-07-08 — 상태 영속: state.json + Stop 훅 계약
- Decision: 모든 단계 전이를 state.json에 기록(중단/재개 근거). keep-alive Stop 훅이
  run.phase 활성 중 턴 종료를 차단하되, features[].agentTask에 기록된 백그라운드 대기는
  허용(하네스 재호출 신뢰). 진전 없는 3회 넛지 후 안전밸브
- Decided by: user

### 2026-07-08 — goal.md 이중 보호
- Decision: 프롬프트 금지 + PreToolUse 훅(일회성 .goal-consent 토큰, 15분 유효,
  Bash 리다이렉트 우회 감지). 무인모드 예외 없음
- Decided by: user

### 2026-07-08 — 리뷰 정책: 중립·증거 기반
- Decision: 차단 화이트리스트 5종 + 입증 책임은 차단자에게. 거부를 위한 리뷰 금지.
  리뷰는 gh pr comment로 게시(자기 PR review 불가), 승인 상태는 오케스트레이터가 관리
- Decided by: user

### 2026-07-08 — 디자인 도구: Claude Design 전용
- Decision: 목업은 claude-design MCP로만. 사용자 승인까지 핑퐁, 무인모드는 에이전트가
  결정 후 Claude Design 프로젝트를 직접 갱신
- Decided by: user

### 2026-07-08 — 기본 머지 방식: rebase
- Decision: git.mergeMethod 기본값 rebase (논리 단위 커밋 보존)
- Decided by: user

### 2026-07-08 — 울트라코드 개발 fan-out: 파일 소유권 분할
- Context: 울트라코드 섹션에 Phase C(기능 개발) 가이드 부재; 멀티파일 피처의 병렬 구현 요구
- Decision: 플랜이 독립 서브태스크 ≥3개일 때만 fan-out/fan-in 워크플로우 사용. 병렬 안전성은
  서브에이전트별 서로소 파일 소유권으로 보장(같은 worktree, 공유 표면은 병렬 단계 편집 금지),
  통합 스테이지가 공유 파일·인터페이스·전체 테스트·커버리지를 전담. WORK SUMMARY 계약과
  오케스트레이터의 worktree/push/PR 소유권은 불변
- Alternatives considered: 서브에이전트별 별도 worktree(머지 오버헤드 과대), 파일 잠금 없는
  자유 병렬(충돌 위험), 항상 fan-out(소형 피처에 낭비)
- Decided by: user (fan-out/fan-in 방향) / agent (임계값·서로소 소유권 세부 — PR #1 ⚠️ 섹션에 공개)

### 2026-07-08 — 울트라코드 Phase C: 다이나믹 워크플로우 위임 (고정 레시피 대체)
- Context: 서브태스크 ≥3 임계값의 고정 fan-out 레시피가 피처 다양성을 담지 못함
- Decision: 오케스트레이터가 피처별 최적 오케스트레이션을 직접 설계 (단일 에이전트 포함).
  하드 제약 6종만 강제. 같은 트리 병렬 쓰기는 파일 소유권 분할 필수, 스코프 중복은
  에이전트별 격리 브랜치 + fan-in 머지(진짜 git 충돌 해소)로만 허용 — 파일시스템 경합은
  충돌 마커 없이 쓰기가 유실되므로 fan-in이 복구할 수 없음
- Alternatives considered: 고정 임계값 레시피(유연성 부족), 무제약 동일 트리 병렬(쓰기 유실)
- Decided by: user

### 2026-07-08 — dev-run 실행 모델: detached 프로세스 → 세션 background shell
- Context: detached 고아 프로세스는 크래시를 아무도 인지 못 하고 세션 종료 후에도 잔존
- Decision: dev 서버를 Bash run_in_background 세션 태스크로 실행 (`echo DEVRUN_PID=$$ && exec <cmd>`
  — 셸 pid가 곧 서버). 훅은 프로세스를 직접 관리하지 않고 merge/pull 시 additionalContext로
  재시작 지시를 주입 → 훅은 항상 턴 중에 발화하므로 클로드가 그 자리에서 수행 (타이밍 동등).
  크래시는 태스크 종료 통지로 즉시 인지, 세션 종료 시 서버도 정리
- Alternatives considered: detached 유지(가시성·정리 열세), 훅 직접 재시작(세션 태스크에 불가)
- Decided by: user
