# UI flow and states

Every screen, its states, destinations and Android Back behaviour. Implemented in `scripts/screens/`; navigation via `Game.go / back / leave / reset_to`.

| Screen | States | Destinations | Back |
|---|---|---|---|
| Boot | load save → normal / recovered from backup / nothing readable (fresh, corrupt file quarantined) / pending awakening | Home (+ "Progress restored" dialog if recovered) or Awakening (if an unlock's reveal never finished) | — |
| Home | idle hero creature | Play → Tutorial (first time) or Level select · Bestiary · Settings | closes app |
| Tutorial | step 1–3; Next disabled until the step's goal is met; blocked feedback "Clear another arrow first."; "Well done." | Next / Start playing → Level select (Home underneath); Skip → same | previous screen |
| Level select | total stars; realm tabs (Mistwood / Cloud Peaks / Ancient Highlands); creature cards: locked / n of 2 / unlocked, best stars + best time per completed level; empty realm → "More creatures are on their way." | Play puzzle N → Puzzle | Home |
| Puzzle | playing (discreet speed timer from the first tap; holds on dialogs, ads, background); exit animation (input locked); blocked pulse + message; hint highlight; complete (input locked, time/stars saved) | Pause dialog; Hint sheet (no hints left); → Results | opens Pause; closes any dialog first |
| Pause (dialog) | — | Resume · Restart puzzle · Level selection · Settings | closes |
| Hint sheet (dialog) | free hints used; M3 adds "Watch ad · Get 1 hint", loading, no-ad-available ("No ad available. You can keep playing.") with rate-limited Retry | Keep playing | closes |
| Results (`level_complete`) | time, par, "New record!" / "First clear" / personal best, 1–3 stars appearing one by one (fade with reduced motion) | Next → earned Awakening, else next unlocked level; Retry → Puzzle; Level selection | Level select |
| Awakening | gathering trails (0–1.2 s), silhouette, reveal, signature move, settle; Skip visible after 1 s while playing; Continue at end; reduced motion = 0.6 s dissolve | Continue → Creature detail (or back to detail when replaying) | skips while playing, continues at end |
| Creature detail | idle loop | Open bestiary; Replay awakening | previous |
| Bestiary | tiles: unlocked (opens detail) / locked (faint still silhouette, "Locked", disabled); "x of N awakened" | tile → detail; Continue adventure → Level select | previous |
| Settings | 3 volume sliders, reduce motion, haptics, Replay tutorial, Privacy options, Privacy policy, Credits dialog | — | closes dialog, else previous |
| Privacy | info page (not a substitute for UMP) | Continue → previous | previous |

Loading: content is local and small; boot is synchronous and shows the ivory boot splash. Ad loading/failed/unavailable states arrive with M3 and reuse the dialog sheet.
