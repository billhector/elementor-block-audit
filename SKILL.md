---
name: elementor-block-audit
description: Read-only audit of a WordPress + Elementor site. Produces a structured migration scorecard: every page inventoried, every Elementor widget classified easy/medium/hard for block-theme migration, plugins classified (utility, rendering-owner, Elementor-only), performance and SEO baselines, total time estimate. Free lead-magnet companion to elementor-block-migration. Triggers on prompts like audit my Elementor site, /elementor-block-audit URL, is my site migratable, how much work to leave Elementor, Elementor migration scorecard, or when a prospect fills out the wpblockschool.com audit form. Do NOT use to actually migrate (that is elementor-block-migration); this is read-only diagnosis.
  Coordinator for Bill's upcoming WP+Elementor → block-theme (FSE) migration
  project. Drives an 8-stage checkpoint-gated workflow and delegates domain
  work to existing wp-* skills (`wp-feature-planning`, `wp-block-themes`,
  `wp-block-development`, `wp-rest-api`) plus `superpowers:*` process skills.
  Triggers on prompts like "migrate [site] from Elementor", "rip out Elementor
  on [site]", "Elementor to block theme for [site]", "FSE conversion", "rebuild
  [site] as a block theme", "convert this Elementor page to blocks", or any
  prompt naming a Bill site (billweye, bizplanshop, propertytaxappealguides,
  paycheckfact, etc.) alongside "Elementor", "FSE", "block theme", or
  "rebuild". Also fires when a site is freshly cloned into Local by Flywheel
  with Elementor as the source and Bill asks "where do I start?". The skill
  itself doesn't migrate — it sequences the checkpoints + delegations + user
  approval gates so the migration doesn't ship half-done. Do NOT use for
  WooCommerce migrations (different shape), multisite, or initial site cloning
  into Local (those are upstream prereqs, not this workflow).
version: 1.1.0
---

## Stage map

| # | Stage file | One-line summary |
|---|---|---|
| 01 | `stages/01-audit.md` | Inventory pages, posts, plugins, Elementor data, custom CSS, fonts |
| 02 | `stages/02-design-extract.md` | Extract colors, typography, spacing → `design-tokens.md` + draft `theme.json` |
| 03 | `stages/03-scaffold.md` | Create blank block theme via CBT plugin, activate, apply tokens |
| 04 | `stages/04-templates.md` | Build templates, parts, patterns one-by-one with per-template approval |
| 05 | `stages/05-content.md` | Convert `_elementor_data` JSON → Gutenberg block markup page-by-page |
| 06 | `stages/06-plugin-recon.md` | Audit rendering-owner plugins: keep+adapt / swap / drop |
| 07 | `stages/07-staging.md` | Deploy to staging, run smoke tests, SEO audit, user signoff |
| 08 | `stages/08-cleanup.md` | Purge Elementor data, archive old theme, lint pass |

## Checkpoint contract

Every stage ends with this exact pattern:

```
STAGE N COMPLETE — <what was produced>

Review: <files/URLs to inspect>

Next: stage N+1 will <one-line summary>.
Say `continue`, `revise <part>`, or `skip` to advance.
```

The skill never auto-advances. Ambiguous user replies halt the workflow.

## Decision rules

| Situation | Rule |
|---|---|
| Source not cloned locally | Refuse to start; point at Local by Flywheel + DB import |
| `_elementor_data` postmeta absent | Site is not Elementor; suggest `wp-block-themes` direct |
| CBT plugin not installed locally | Stage 03 installs via `wp plugin install create-block-theme --activate` |
| Stage 02 returns < 3 colors | Likely scrape failure; prompt for manual palette before continuing |
| Stage 04 user rejects template twice | Halt; suggest revising design tokens (stage 02 redo) |
| Stage 05: a single page has > 50 Elementor widgets | Switch to within-page batching: skill converts widgets in groups of 10, user reviews each group, batch continues until page complete |
| Stage 05: site has > 20 pages to convert | Switch to whole-page batching: skill converts 5 pages, user reviews all 5, batch continues |
| Plugin recon finds Elementor-only widgets | Hard flag: "Widget X has no Gutenberg equivalent — manual rebuild needed" |
| Staging smoke test fails | Invoke `superpowers:systematic-debugging`; no silent retries |
| Target host = DH VPS | Stage 07 runs `dh-appendix.md` inline; else skip |
| Cutover request before stage 08 cleanup | Refuse; cleanup must run on staging first |

## Delegated skills

| Skill | Used at | Mode |
|---|---|---|
| `wp-project-triage` | Stage 01 start | Invoked |
| `design-extractor` | Stage 02 start | Invoked |
| `wp-block-themes` | Stages 03–04 | Referenced (canonical FSE knowledge) |
| `html-head-wordpress` | Stage 03–04 | Referenced |
| `wp-block-development` | Stage 04 (if dynamic blocks needed) | Invoked conditionally |
| `wp-plugin-development` | Stage 06 (if rendering-owner plugin) | Invoked conditionally |
| `wp-playground` | Stage 07 (optional pre-staging) | Invoked conditionally |
| `website-pre-launch` | Stage 07 QA | Invoked |
| `seo-audit` | Stage 07 QA | Invoked |
| `wp-phpstan` | Stage 08 lint | Invoked |
| `wp-performance` | Stages 01, 07, 08 | Invoked (baseline capture + verification) |
| `wp-wpcli-and-ops` | Throughout | Referenced for WP-CLI patterns |
| `superpowers:systematic-debugging` | On staging smoke test failure | Invoked |
| `cloudflare-baseline` | Stage 07 (if target zone is on Cloudflare) | Invoked |
| `handoff` | If migration spans sessions | Invoked on user request |
| `context7` | If unusual setup encountered | Invoked conditionally |
| `firecrawl-scrape` | Stage 02 fallback if design-extractor fails | Invoked conditionally |

## Self-improvement

The skill edits its own reference files (`references/gotchas.md`, `references/widget-to-block.md`, host appendices) as new patterns surface during or after a migration run — always under diff-preview + user approval, never silently. Two trigger points: mid-migration discovery (pause checkpoint, propose addition, approve/skip) and end-of-migration retrospective (replay `migration-state.json` deviations, route each to skill file / project memory / drop). On accept, frontmatter `version` bumps and a changelog entry is added. If the skill dir is a git repo, a commit is offered. Full rules in `docs/2026-05-14-design.md` §10.

## Skill state

The skill writes `migration-state.json` in the **project root** (not the skill dir) at each checkpoint:

```json
{
  "stage": 4,
  "target_host": "dh|other",
  "started": "ISO8601",
  "last_checkpoint": "ISO8601",
  "deviations": []
}
```

A `resume` command reads this file and continues from `stage + 1`. State survives session boundaries — pair with `handoff` for multi-session migrations.

## Reference files

- `references/elementor-data-shape.md` — `_elementor_data` JSON structure
- `references/widget-to-block.md` — Elementor widget → Gutenberg block mapping
- `references/gotchas.md` — WP/FSE bugs and workarounds from real migrations
- `references/dh-appendix.md` — DreamHost VPS runbook (SSH, CF SSL, LSCACHE, auto-deploy)
- `templates/theme-json-starter.json` — Baseline with `spacingScale {steps:0}` fix preloaded
- `templates/functions-php-starter.php` — Font preload, heading anchors, render_block_data filter
- `templates/htaccess-security-headers.txt` — Apache HSTS + X-Frame + COOP block

## Changelog

### v1.1.0 — 2026-05-15
- Delegate Cloudflare configuration to the new `cloudflare-baseline` skill
  (separate repo: github.com/billhector/cloudflare-baseline). EBM stage 07
  now invokes it when the staging URL is behind Cloudflare; profile hint is
  `wordpress` or `wordpress-woo` based on audit findings.
- Added `cloudflare-baseline` to delegated skills table in SKILL.md.
- Trimmed `references/dh-appendix.md` §2 (CF SSL section) to a pointer at
  cloudflare-baseline; kept inline why-explanation for the redirect-loop
  case as orientation.
- Stage 07 now has a separate "Cloudflare configuration" section after
  the DH VPS branch, applicable to any CF-fronted staging target (not just
  DH).

### v1.0.5 — 2026-05-15
- Back-ported live billweye.com Goatcounter rollout learnings:
  - Analytics enqueue must use `wp_enqueue_script` + `script_loader_tag`
    filter, not raw `wp_footer` echo (raw echo trips
    `WordPress.WP.EnqueuedResources.NonEnqueuedScript` and fails CI)
  - Beacon should skip `local` / `development` envs via
    `wp_get_environment_type()` to prevent dev traffic polluting prod stats
  - Beacon should skip logged-in users via `is_user_logged_in()` to keep
    admin pageviews out of analytics
- Updated Goatcounter and GA-direct sections in
  `references/analytics-options.md` with the full working enqueue +
  filter + guards pattern, including the load-bearing `phpcs:ignore`
  for the `null` version arg
- Updated stage 03 step 9 Goatcounter/GA branches to call out the
  enqueue pattern explicitly
- Added a "Common pitfalls" table to `references/analytics-options.md`
- Added "Analytics: raw <script> echo trips PHPCS" to
  `references/gotchas.md`

### v1.0.4 — 2026-05-15
- Stage 03 analytics prompt narrowed to 2 primary choices (Goatcounter / GA)
  plus an "Other / None" branch that routes to `references/analytics-options.md`
  for the four alternates (Cloudflare Web Analytics, Plausible, Fathom, Umami
  self-hosted).
- `references/analytics-options.md` now leads with a Primary choices table
  before the full comparison.
- Reflects real-world decision pattern: most new sites pick Goatcounter
  (privacy/editorial) or GA (marketing/conversions); other services are
  edge-case picks worth knowing but rarely defaulted to.

### v1.0.3 — 2026-05-15
- Stage 03 gains an analytics-choice prompt (step 9) covering Goatcounter,
  Cloudflare Web Analytics, Plausible, Fathom, Umami (self-hosted),
  GA/GTM, or None.
- Added `references/analytics-options.md` mapping each service to its
  preconnect origin, CSP entries, snippet, and plugin alternative.
- Updated `templates/functions-php-starter.php` `THEME_SLUG_preconnects()`
  to ship with commented-out per-service examples (stage 03 uncomments the
  picked one mechanically instead of writing from scratch).
- Stage 03 now produces a `csp-notes.md` at project root listing the
  service-specific CSP additions, to be applied at stage 07 via CF Page
  Rule or `templates/htaccess-security-headers.txt`.

### v1.0.2 — 2026-05-15
- Folded `wp-performance` patterns: perf baseline capture at stage 01,
  perf delta check at stages 07 and 08. Verifies Elementor purge actually
  reduces autoloaded options size.
- Folded `seo-audit` patterns: SEO baseline capture at stage 01 (plugin,
  sitemap, robots.txt, top-20 URL inventory), migration-specific SEO smoke
  tests at stage 07 (redirect map, canonical preservation, schema integrity
  via Rich Results Test), regen + verify at stage 08.
- Added `references/performance-baseline.md` (perf measurement workflow).
- Added `references/seo-checklist.md` (migration-specific SEO checklist).
- Added commented `should_load_separate_core_block_assets` opt-in to
  `functions-php-starter.php` for themes with custom stylesheets.
- Added `wp-performance` to delegated skills table.

### v1.0.1 — 2026-05-15
- Folded `html-head-wordpress` patterns into starter `functions.php` (viewport
  meta with `viewport-fit=cover`, dual `theme-color`, refined font preload with
  `fetchpriority="high"` body-font discipline, preconnect helper, favicon
  links).
- Added `templates/site-webmanifest.json` PWA manifest template.
- Added `references/head-patterns.md` block-theme-specific head reference.
- Added stage 03 step 8 covering favicon setup and brand-color editing.
- Added `html-head-wordpress` to delegated skills table.

### v1.0.0 — 2026-05-14
- Initial SKILL.md. Stage map, checkpoint contract, decision rules, delegated skills, self-improvement loop, skill state tracking.

---

## Origin

Bill original (cloned from `elementor-block-migration` template on 2026-06-12 via `~/.claude/scaffold-skill.sh --from elementor-block-migration`). Body structure inherited from the parent skill; replace section contents with this skill's specifics. See `feedback-own-skill-origin-section` memory for the convention.
