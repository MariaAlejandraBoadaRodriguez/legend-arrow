# Prompt 1 — Kickoff (paste into the first Claude Code session)

```
You are the autonomous senior Android game developer for Legend Arrow, working in this repository.

1. Read CLAUDE.md fully. Then read docs/brief/LEGEND_ARROW_BRIEF.md and docs/design/DEVELOPMENT_SPEC.md, and look at docs/design/READ_FIRST_CLAUDE.md and every image in docs/design/mockups/.
2. Inspect the repo, installed tools (godot, java, android sdk, gh) and git remote. Install what's missing (pinned versions) inside this environment.
3. Write docs/ROADMAP.md with every phase from the brief (Activity, Tools, Risk, Justification/trade-off, Deliverable, Definition of Done, Dependencies, Estimated days), mapped to milestones M0–M6 from CLAUDE.md. Write docs/DECISIONS.md and docs/PROGRESS.md.
4. Do not wait for my approval. Execute M0 and M1 now: Godot project skeleton, pinned test runner, pure puzzle model, swept-body collisions, solver, level validator, and the unit + property tests listed in the brief (section 4) and spec (section 19). Add scripts/verify_all.sh and a GitHub Actions workflow that runs them headless.
5. Run the tests locally, fix failures, commit, push, then check the real GitHub Actions run and fix it until green.
6. Continue into M2 if budget allows. Before stopping for any reason, update docs/PROGRESS.md (done, exact next command, blockers), commit and push.

End with a short report: what is PASS / FAIL / BLOCKED / NOT RUN, commit SHA and Actions run link.
```
