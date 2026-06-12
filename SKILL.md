---
name: elementor-block-audit
description: Read-only audit of a WordPress + Elementor site. Produces a structured migration scorecard — every page inventoried, every Elementor widget classified easy/medium/hard for block-theme migration, plugins classified (utility / rendering-owner / Elementor-only), performance and SEO baselines, total time estimate. Free lead-magnet companion to elementor-block-migration. Triggers on prompts like "audit my Elementor site", "/elementor-block-audit <URL>", "is my site migratable", "how much work to leave Elementor", "Elementor migration scorecard", or when a prospect runs the wpblockschool.com audit form. Do NOT use to actually migrate (that is elementor-block-migration); this is read-only diagnosis.
version: 1.0.0
---

# Elementor Block Audit

A non-destructive read-only audit of a WordPress + Elementor site. Inventories every page, classifies every Elementor widget against block-theme equivalents, classifies every plugin by migration risk, captures performance + SEO baselines, and produces a one-page migration scorecard.

This is the FREE giveaway / mini-course deliverable for WP Block School. It is upstream of `elementor-block-migration` which actually does the migration. Audit = read only. Migration = read + write.

## Who runs this

| Audience | Trigger |
|---|---|
| Prospects evaluating WP Block School | Audit form on wpblockschool.com, returns this skill running against their URL |
| Solo devs deciding Elementor exit timing | "audit my Elementor site", "is my site migratable", "/elementor-block-audit" |
| Bill, scoping client work | "scope X site for migration" |

## Preconditions

- Source site cloned into Local by Flywheel OR direct WP-CLI access to a live site (read-only commands only — this skill writes NOTHING to the source)
- DB accessible via WP-CLI (`wp option get siteurl` succeeds)
- A target output directory specified (default: `./audit-report/`)

If preconditions fail: halt, explain, do NOT guess past them.

## What the audit produces

A single `audit-report.md` plus a one-page `migration-scorecard.md`. The scorecard is the prospect-facing artifact — concise enough to attach to a sales-page CTA or email.

### audit-report.md (long form)

```markdown
# Audit report — <site name>

Generated: <ISO date>

## Source environment
- WP version, PHP version, active theme + plugins (versions)

## Elementor inventory
- Posts/pages with `_elementor_data` postmeta: <count by post_type>
- Distinct widget types in use: <list>
- Elementor custom CSS: <yes/no + size>
- Elementor Pro features detected: <theme builder, popups, forms, etc.>

## Plugin classification
- Utility (SEO, cache, backup, security): <list — mostly stays>
- Rendering-owner (CPTs, frontend routes, custom widgets): <list — migration risk>
- Elementor-only (Elementor add-ons): <list — leaves with Elementor>

## Performance baseline
- Autoloaded options size: <KB> (Elementor + Pro often >1MB autoload bloat)
- TTFB sample (home + 1 inner page)
- `wp doctor check --all` summary

## SEO baseline
- Active SEO plugin + version
- Sitemap URL + URL count
- Robots.txt highlights
- Top-20 URL inventory (basis for post-migration redirect map)

## .htaccess artifacts
- LSCACHE / LiteSpeed blocks: <yes/no>
- DreamHost markers: <yes/no>
- Custom rewrite blocks: <yes/no>

## Widget-to-block migration map
For every distinct widget type found, classify:
- **EASY** — direct block equivalent (heading, paragraph, image, button, columns)
- **MEDIUM** — pattern-rebuildable (icon-list, accordion, tabs, pricing-table)
- **HARD** — needs custom block or manual rebuild (forms, popups, theme builder templates, Elementor-only widgets)
```

### migration-scorecard.md (short form — prospect-facing)

```markdown
# Migration scorecard — <site name>

**TL;DR:** Your site is **<EASY | MIXED | HARD>** to migrate off Elementor.

## Numbers
- Pages using Elementor: <N>
- Distinct widget types: <N>
- Easy widgets: <X> · Medium: <Y> · Hard: <Z>
- Plugins to keep: <N> · Plugins to replace: <N> · Plugins to drop with Elementor: <N>
- Autoload bloat from Elementor: <KB>

## Time estimate
| Approach | Estimated time | Risk |
|---|---|---|
| DIY solo | <N> hours | Medium-high if you have HARD widgets |
| Hire a freelancer | <$N> at $<rate>/hr | Variable — quality depends on dev |
| **WP Block School cohort (8 weeks)** | Done in cohort #1 timeline | Low — built-in support |

## Next step
Reading this report cold? Start with the [WP Block School free mini-course](https://wpblockschool.com/mini). Ready to commit? [Join cohort #1](https://wpblockschool.com/cohort).
```

## Audit script

Run `scripts/audit.sh` (lives in this repo). Steps:

1. **Count Elementor-loaded posts:**
   ```bash
   wp db query "SELECT post_type, COUNT(*) FROM wp_postmeta JOIN wp_posts ON wp_postmeta.post_id = wp_posts.ID WHERE meta_key = '_elementor_data' GROUP BY post_type;"
   ```

2. **List distinct Elementor widget types** (parse `_elementor_data` JSON, extract `widgetType` values):
   ```bash
   wp db query "SELECT meta_value FROM wp_postmeta WHERE meta_key = '_elementor_data';" --skip-column-names | python3 -c "import sys,json,re; types=set(); [types.update(re.findall(r'\"widgetType\":\s*\"([^\"]+)\"', line)) for line in sys.stdin]; print('\n'.join(sorted(types)))"
   ```

3. **Elementor custom CSS:**
   ```bash
   wp option get elementor_custom_css --format=json
   ```

4. **All Elementor postmeta keys:**
   ```bash
   wp db query "SELECT DISTINCT meta_key FROM wp_postmeta WHERE meta_key LIKE '\\_elementor%';"
   ```

5. **.htaccess artifacts:** grep for `# BEGIN LSCACHE`, `# BEGIN NON_LSCACHE`, `<IfModule LiteSpeed>`, `dh-` markers.

6. **Autoloaded options size:**
   ```bash
   wp db query "SELECT ROUND(SUM(LENGTH(option_value))/1024) AS autoload_kb FROM wp_options WHERE autoload = 'yes';"
   ```

7. **TTFB sample:**
   ```bash
   curl -o /dev/null -s -w "TTFB: %{time_starttransfer}s\n" http://<local-url>/
   ```

8. **SEO plugin + sitemap:**
   ```bash
   wp plugin list --status=active | grep -iE "yoast|rank|all-in-one"
   curl -s http://<local-url>/sitemap_index.xml | grep -c '<loc>'
   ```

9. **WP doctor:**
   ```bash
   wp doctor check --all
   ```

## Widget classification heuristics

| Tier | Examples | Reasoning |
|---|---|---|
| EASY | heading, text-editor, image, button, divider, spacer, columns, html | Direct WP core block equivalents |
| MEDIUM | icon-list, icon-box, accordion, tabs, image-carousel, pricing-table, testimonial, counter | Can rebuild as a pattern using core blocks + minimal CSS |
| HARD | form, popup, theme-builder template, post-grid w/ ACF dynamic data, slides w/ animation, any third-party Elementor-only widget | Needs custom block, plugin replacement, or manual rebuild |

If a widget type isn't in this table, default to MEDIUM and flag for human review.

## Decision rules

| Situation | Rule |
|---|---|
| `_elementor_data` postmeta count = 0 | Site is NOT actually Elementor-built. Return a 1-line report saying so. Do not produce a full scorecard. |
| No WP-CLI access available | Fall back to remote-only mode: scrape the site with firecrawl-scrape, extract Elementor markers from rendered HTML. Lower precision; mark report as "remote-only sampling". |
| User asks to actually migrate something | STOP. This skill is read-only. Hand off to `elementor-block-migration`. |
| User runs the skill on a non-WordPress site | Detect via missing `wp-config.php` + missing `wp_options` table. Halt. |
| Plugin has both Elementor widgets AND rendering responsibilities (e.g., MetForm, CrocoBlock) | Classify under BOTH "rendering-owner" AND "Elementor-only" in the report. Flag for explicit replacement decision. |

## What this skill explicitly does NOT do

- Migrate anything (use `elementor-block-migration`)
- Write to the source database
- Install plugins, modify .htaccess, or change theme
- Backup the site (assume user has their own backup hygiene before running)
- Estimate cost in dollars beyond the time × rate calculation in the scorecard

## Reference files

- `scripts/audit.sh` — the wp-cli audit script (see Audit script above)
- `references/widget-tiers.md` — full widget classification table (expanded version of the Heuristics table above)
- `references/scorecard-template.md` — the prospect-facing one-pager Markdown template

(These reference files are planned for v1.1 — currently inlined in this SKILL.md.)

## Notes

- This skill is the **free lead-magnet** for WP Block School. Output should always end with a soft CTA to either the free mini-course (low-friction) or the paid cohort (high-intent prospects). Don't make the CTA pushy — the scorecard's numbers should speak for themselves.
- When the migration skill (`elementor-block-migration`) updates its widget-classification logic or audit script, mirror the relevant changes here. Initially the two skills duplicate audit logic (strict-subset architecture, locked 2026-06-12); refactor to a shared lib post-cohort #1.

---

## Origin

Bill original (cloned from `elementor-block-migration` template on 2026-06-12 via `~/.claude/scaffold-skill.sh --from elementor-block-migration`). Body fully rewritten on creation — only the frontmatter shape + `## Origin` convention carried over from parent. Strategic role: free giveaway for the WP Block School mini-course funnel, sits upstream of the paid migration skill. See `feedback-own-skill-origin-section` memory for the convention.
