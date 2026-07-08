# Changelog

<!-- Format follows Keep a Changelog (https://keepachangelog.com/).
     Versions are cut from git tags by /autopilot-sync.
     The autopilot dev loop appends merged features to [Unreleased].
     Entry format: - <description> (<feature IDs>, PR #<n>) -->

## [Unreleased]

## [0.23.5] - 2026-07-08
- 브랜치 문서 유실 방지: 피처 브랜치 생성 시(Phase C) 그 브랜치의 첫 커밋으로 브랜치 문서를 커밋하도록 변경 — 문서가 피처 브랜치와 함께 살며 PR·머지를 타고 run 브랜치에 도착. 이전엔 문서가 커밋 안 된 채(untracked) 방치돼 Phase E run 브랜치 pull/rebase 때 클로버·유실됐음. dev/review 갱신도 worktree의 피처 브랜치에서 커밋(에이전트 실행 사이에만), Phase E는 공용 문서(todo/CHANGELOG/CLAUDE 스냅샷)만 run 브랜치 커밋

## [0.23.4] - 2026-07-08
- 증분 갭 분석(기준 원장) 철회: 매 phase마다 state.json에 criteria/goalHash를 누적하던 방식이 과함 — `criteria`/`goalHash` 스키마 삭제, FULL/INCREMENTAL 스캔 구분·Phase E 증거 접기 제거. Phase A는 goal.md와 현재 프로젝트 상태를 참고해 todo를 고르거나 새로 작성하는 단순 갭 분석으로 환원, goal-met은 원장 없는 high bar로 복귀 (run.agentTask 런 레벨 대기는 유지)

## [0.23.3] - 2026-07-08
- 프롬프트 문구 정리: 스킬·에이전트·프로토콜 전반을 간결·명확화 — 동어반복(`(fast means fast)`), 모호 표현(`proved things`), 중복 절, 장황한 주의문 4곳 제거. 동작·가드레일·트리거 문구는 불변, 나머지 13개 파일은 이미 간결하여 무편집

## [0.23.0] - 2026-07-08
- 증분 갭 분석: 기준 원장(state.criteria)이 검증 결과를 축적 — Phase E가 E2E 리뷰 증거를 접어 넣고, Phase A는 unmet/unknown 기준만 점검 (FULL 스캔은 원장 부재·goal 변경·종료 확인 패스에만). 울트라코드 갭 파인더도 필요 기준에만 스폰
- 런 레벨 대기 필드 run.agentTask 추가 — 갭 분석 워크플로우 등 피처 밖 백그라운드 작업 대기를 Stop 훅이 인정

## [0.22.0] - 2026-07-08
- dev-run을 세션 background shell로 전환: 세션 태스크 가시화, 크래시 종료 통지, 세션 종료 시 자동 정리. 머지/pull 시 훅이 재시작 지시를 additionalContext로 주입하고 클로드가 즉시 수행 (dev-run.sh는 kill/stop/status/hook로 재편)

## [0.21.0] - 2026-07-08
- dev-run 훅 행 수정: 서버 완전 분리 기동 + 훅의 비동기 재시작 즉시 반환 (AP-003)
- 승인 게이트 가시성: 초안을 branch 문서에 선작성하고 게이트 질문 preview에 전문 임베드 — 모든 ask 게이트 적용 (AP-002)
- branch 문서 status를 PR 생성 시 merged로 선기록, 미머지 폐쇄 시 abandoned 정정 (AP-004)
- 울트라코드 Phase C를 다이나믹 워크플로우 설계로 전환 — 구조는 위임, 하드 제약 6종만 강제 (AP-005)

## [0.20.0] - 2026-07-08
- 울트라코드 Phase C 개발 가이드: 플랜이 독립 서브태스크 3개 이상일 때 서로소 파일 소유권 fan-out + 통합 fan-in 워크플로우로 병렬 구현 (AP-001)

## [0.19.1] - 2026-07-08
- 저장소 셀프 관리 초기화: `.autopilot/`(goal·config·design·tech-design·todo·CHANGELOG·branch), CLAUDE.md, .gitignore
- 규칙 추가: main에 피처가 들어갈 때마다 plugin.json 버전 업 + 태그 필수 (CLAUDE.md Conventions)

## [0.19.0] - 2026-07-08
- 오토파일럿 런 시작 시 dev 서버 자동 기동 (`devRun.autoStart`)

## [0.18.1] - 2026-07-08
- keep-alive Stop 훅이 백그라운드 에이전트 대기(`features[].agentTask`) 중 턴 종료를 허용

## [0.18.0] - 2026-07-08
- 리모트 브랜치 위생: init이 GitHub `delete_branch_on_merge` 설정 활성화, 런 PR `--delete-branch`, 폐기 브랜치 원격 삭제, sync에 원격 정리 단계

## [0.17.2] - 2026-07-08
- `parallelFeatures`는 상한이지 쿼터가 아님을 명문화

## [0.17.1] - 2026-07-08
- 기본 `git.mergeMethod`를 rebase로 변경

## [0.17.0] - 2026-07-08
- Claude Design 전용 목업 승인 플로우 (`/autopilot-design` 핑퐁, 루프 내 디자인 개입, 무인모드 Claude Design 동기화)
- `/autopilot-stop` 커맨드: 런 정리 + 런 PR 사용자 승인 머지

## [0.16.2] - 2026-07-08
- Claude Design MCP 등록 방법 정정 (공식 엔드포인트 + /design-login)

## [0.16.1] - 2026-07-08
- 디자인 도구 안내 문구 수정

## [0.16.0] - 2026-07-08
- `/autopilot-design` 커맨드 + design.md 살아있는 Style Guide 섹션 (루프가 UI 기능 Goal Prompt에 규칙 복사)

## [0.15.0] - 2026-07-08
- `/autopilot-dev-run` 커맨드: 관리형 dev 서버 + 머지/pull 트리거 자동 재시작 훅

## [0.14.2] - 2026-07-08
- 리뷰 정책을 중립·증거 기반으로 재정의 (입증 책임은 차단자에게, 거부를 위한 리뷰 금지)

## [0.14.1] - 2026-07-08
- 한국어 사용설명서(README.ko.md) 추가

## [0.14.0] - 2026-07-08
- keep-alive Stop 훅: 런 활성 중 조용한 턴 종료 차단 + `paused` 상태 + 안전밸브

## [0.13.0] - 2026-07-07
- `ultracode` 설정: 루프 내 Workflow 멀티에이전트 오케스트레이션 (갭 분석 팬아웃, 플랜 저지, 반박 검증 리뷰)

## [0.12.0] - 2026-07-07
- 리뷰를 PR 코멘트로 게시 (자기 PR review 불가 버그 수정) + `review.reviewerModel` 오버라이드

## [0.11.0] - 2026-07-07
- design.md(UI/UX)와 tech-design.md(기술) 분리, sync가 잘못 들어간 항목 1회 이동

## [0.10.1] - 2026-07-07
- 루프 계속이 기본값임을 강제 (1 이터레이션 조기 종료 수정)

## [0.10.0] - 2026-07-07
- 런 브랜치 구조: 기능 PR은 런 브랜치로, base는 `approvals.runMerge` 게이트를 거친 런 PR로만 접촉 (무인모드는 base 머지 금지)

## [0.9.0] - 2026-07-07
- 테스트 커버리지 강제: `testing.coverage`(기본 80%), WORK SUMMARY coverage 필드, 리뷰 기준 반영

## [0.8.0] - 2026-07-07
- `/autopilot-init` 프로젝트 개요 인자 (인자 > 조사 도출 > 질문 우선순위)

## [0.7.1] - 2026-07-07
- `/autopilot-project-review` focus 인자 제거

## [0.7.0] - 2026-07-07
- `/autopilot-project-review` 커맨드: 냉정한 시장 반응 평가 + goal/todo 인터뷰 반영

## [0.6.0] - 2026-07-07
- 모든 PR 본문 최상단에 ⚠️ "사용자 동의 없이 임의로 결정한 사항" 섹션 강제

## [0.5.0] - 2026-07-07
- 무인모드(`unattended`): 질문 없이 안전 기본값으로 진행, 막힌 기능은 파킹

## [0.4.0] - 2026-07-07
- `/autopilot-config` 커맨드: 스키마 검증 기반 설정 인터뷰

## [0.3.1] - 2026-07-07
- 플러그인 매니페스트 훅 중복 참조 수정 (설치 실패 버그)

## [0.3.0] - 2026-07-07
- `/autopilot-todo` 커맨드: 인터뷰로 user 소스 todo 추가

## [0.2.0] - 2026-07-07
- `/autopilot-init` GitHub 저장소 인자 (기존 연결 / gh 생성)

## [0.1.0] - 2026-07-07
- 최초 릴리스: /autopilot-goal·init·sync, autopilot-dev 루프 스킬, 에이전트 3종(feature-dev·code-reviewer·e2e-tester), goal.md 보호 훅, 템플릿·마켓플레이스
