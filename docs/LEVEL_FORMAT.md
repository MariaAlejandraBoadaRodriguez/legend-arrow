# Level format (schema_version 1)

One JSON file per level in `data/levels/`. Coordinates are integer `[x, y]`, origin top-left, y down.

```json
{
  "schema_version": 1,
  "id": "forest_drake_1",
  "creature_id": "forest_drake",
  "difficulty": "tutorial",
  "width": 6,
  "height": 8,
  "seed": 1234,
  "arrows": [
    {"id": "a01", "cells": [[0, 1], [1, 1], [2, 1]]}
  ],
  "solution": ["a01"]
}
```

| Field | Rule |
|---|---|
| `schema_version` | Must equal 1. |
| `id`, `creature_id` | Non-empty, `[a-z0-9_]+`. |
| `difficulty` | `tutorial` (1–8 arrows), `easy` (6–12), `medium` (13–24), `hard` (25–40), `expert` (41–60). |
| `width`, `height` | Integers 2–40. |
| `arrows[]` | 1–60 arrows. Each `id` unique and `[a-z0-9_]+`; `cells` ≥ 2 cells, each in bounds, consecutive cells orthogonally adjacent, no repeated cell within a path, no cell shared with another arrow. **The last cell is the arrowhead; the last segment is the exit direction.** |
| `solution` | Every arrow ID exactly once, in an order that is legal under swept-body rules. |
| `seed` | Optional: generator seed for provenance. |

The board must also be solvable (acyclic blocked-by graph). Validation: `LevelValidator.validate(dict)` (`scripts/core/level_validator.gd`); loading: `LevelData.load_file(path)` always validates.

## Movement rule
Tapping an arrow moves the whole arrow rigidly, one cell at a time, in its head direction until every cell is off the board. It may leave only if no cell of any other arrow lies on the ray from **any** of its cells in that direction. Its own cells never block it.
