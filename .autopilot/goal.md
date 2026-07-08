# Project Goal

<!-- MANAGED BY /autopilot-goal ONLY.
     Agents must NEVER modify this file without explicit user consent.
     To change goals, run /autopilot-goal. -->

## Ultimate Goal

goal만 정하면 기능 선정부터 개발·리뷰·머지까지 전체 개발 사이클을 자율 운영하는,
개인/소규모 팀용 Claude Code 오토파일럿 플러그인의 표준이 된다.

## Target Users

- 1차: Eddie 본인의 사이드 프로젝트
- 2차: 지인 소규모 개발자 그룹 (마켓플레이스로 설치)

## Success Criteria

- 무인모드 런이 사람 개입 없이 멈춤 없이 완주하고, 생산된 모든 PR이 규약
  (⚠️ 임의 결정 자백 섹션, 테스트 동반)을 준수한다.
- 루프 이탈(조기 종료, goal.md 무단 수정, 프로토콜 위반)이 연속 여러 런 동안 0건에 수렴한다.
- 실제 앱 프로젝트 1개가 오토파일럿 루프만으로 goal.md의 MVP 수준까지 개발된다.

## Short-Term Goals

1. 루프 풀사이클 실전 검증 — done when: 샘플 프로젝트에서 loop 모드(병렬 2)로
   기능 선정 → 병렬 개발 → 리뷰 → 런 브랜치 머지 → 런 PR까지 전 경로가 1회 이상
   무사히 완주하고, 발견된 프로토콜 이탈이 모두 수정되어 배포된다.

## Non-Goals

- GitHub 외 호스팅(GitLab/Bitbucket 등) 지원 — GitHub + gh CLI 전제 유지
- Claude Design 외 디자인 툴(Figma 등) 연동
- CI/CD 파이프라인 대체 — 책임 범위는 PR 머지까지
- 사람 리뷰의 완전 대체 — 에이전트 리뷰는 보조 장치

## Constraints

- Claude Code v2.1+, GitHub 원격 + 인증된 gh CLI, python3 필수
- 플러그인 내부 프롬프트/스킬 본문은 English, 생성 문서는 config.language(ko)
- 빌드 스텝 없는 마크다운 + bash + JSON 구조 유지

## History

- 2026-07-08: 최초 작성 (/autopilot-init 인라인 인터뷰), 사용자 승인
