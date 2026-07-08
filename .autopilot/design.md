# UI/UX Design

<!-- Two sections with different rules:
     ## Style Guide — the LIVING look-and-feel contract for the whole project.
        Maintained by /autopilot-design through user interviews; rewritten in
        place. The dev loop copies its relevant rules into every UI feature's
        Goal Prompt constraints.
     ## Decisions — append-only, dated log of user-facing design decisions.
        Never delete or rewrite entries — supersede them with a new entry.
     Development/technical design (architecture, data model, stack choices)
     belongs in tech-design.md, NOT here. -->

## Style Guide

<!-- Not established — this plugin has no graphical UI surface.
     Its "user interface" is conversational: slash commands, interview
     questions, reports, and PR bodies. Run /autopilot-design only if a
     visual surface is ever added. -->

## Decisions

### 2026-07-08 — 대화형 UX 관례 (관찰)
- Context: 플러그인의 사용자 접점은 슬래시 커맨드·인터뷰·보고서·PR 본문임
- Decision: 인터뷰는 AskUserQuestion으로 후보 2~3개 + 추천안 제시, 보고서는 결과 우선,
  PR 본문은 ⚠️ 임의 결정 섹션이 항상 최상단, 생성 문서는 config.language(ko) / 코드·커밋은 영어
- Alternatives considered: 자유 서술형 질문 — 선택지 기반이 결정 속도와 기록 품질에서 우세
- Decided by: agent (observed from code)
