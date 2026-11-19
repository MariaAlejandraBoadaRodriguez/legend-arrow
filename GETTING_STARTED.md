# Quick guide — starting Legend Arrow in Claude Code

## 1. Create the GitHub repository
- github.com → **New** repository
- Name: **legend-arrow** · Visibility: **Private** · do NOT tick "Add README" (the kit already has one)
- Click **Create repository**

## 2. Upload the kit
- On the empty repository page: **uploading an existing file**
- Unzip `legend-arrow-kit.zip` and drag **all the contents** of the `legend-arrow/` folder (including `.gitignore`; if the browser hides it, upload it later with "Add file")
- Message: `chore: add design inputs and Claude instructions` → **Commit changes**

## 3. Open Claude Code
- claude.ai/code → pick the **legend-arrow** repository → new session
- If it asks about network/environment permissions: choose **Trusted / full network** (it needs to download Godot, the Android SDK and Gradle)

## 4. First session
- Copy and paste the block from `docs/prompts/01_KICKOFF.md`
- Let it work. When it finishes it reports PASS/FAIL/BLOCKED, the commit SHA and the Actions link

## 5. Following sessions
- Always paste `docs/prompts/02_CONTINUE.md` → it resumes from `docs/PROGRESS.md`
- If Actions is red → paste **PROMPT 3 (Fix CI)**
- At M5/M6 → paste **PROMPT 4 (Final tests)**

## 6. Try it on your computer
- Download the APK from the **Actions** tab → latest green run → Artifacts
- Android Studio → Device Manager → start the emulator → **drag the APK** onto the emulator window

## Milestone order
M0 audit + CI · M1 puzzle engine + tests · M2 playable slice (APK) · M3 ads/consent · M4 24 levels + 12 creatures · M5 emulator E2E tests · M6 AAB + QA_REPORT + release checklist · v0.2: see `docs/ROADMAP.md`
