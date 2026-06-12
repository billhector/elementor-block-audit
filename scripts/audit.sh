#!/usr/bin/env bash
#
# elementor-block-audit: read-only WordPress + Elementor site audit
#
# Produces two artifacts in the output dir:
#   - audit-report.md       — long-form structured audit
#   - migration-scorecard.md — one-page prospect-facing summary
#
# Run from a WP install root with WP-CLI accessible. Writes NOTHING to the
# source site (no DB writes, no plugin installs, no .htaccess edits).
#
# Usage:  bash audit.sh [output-dir]
#         (default output dir: ./audit-report)

set -euo pipefail

OUT_DIR="${1:-./audit-report}"
RAW_DIR="$OUT_DIR/raw"
mkdir -p "$RAW_DIR"

# ─── Preconditions ────────────────────────────────────────────────────────────

if ! command -v wp >/dev/null 2>&1; then
  echo "ERROR: wp-cli not on PATH. Install or run from a WP-CLI-aware shell." >&2
  exit 1
fi

if ! wp core is-installed 2>/dev/null; then
  echo "ERROR: not a WordPress install (or wp-config.php inaccessible)." >&2
  exit 2
fi

SITE_URL=$(wp option get siteurl 2>/dev/null || echo "")
if [[ -z "$SITE_URL" ]]; then
  echo "ERROR: could not read siteurl. WP-CLI broken?" >&2
  exit 3
fi

echo "==> Auditing $SITE_URL"
echo "==> Output: $OUT_DIR"

# ─── Section 1: Environment ───────────────────────────────────────────────────

echo "==> [1/9] Environment"
WP_VERSION=$(wp core version 2>/dev/null || echo "unknown")
PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
ACTIVE_THEME=$(wp theme list --status=active --field=name 2>/dev/null | head -1 || echo "unknown")
ACTIVE_THEME_VERSION=$(wp theme list --status=active --field=version 2>/dev/null | head -1 || echo "")
wp plugin list --status=active --format=json > "$RAW_DIR/active-plugins.json" 2>/dev/null || echo "[]" > "$RAW_DIR/active-plugins.json"
PLUGIN_COUNT=$(python3 -c "import json; print(len(json.load(open('$RAW_DIR/active-plugins.json'))))" 2>/dev/null || echo "0")

# ─── Section 2: Elementor inventory ───────────────────────────────────────────

echo "==> [2/9] Elementor inventory"
wp db query "SELECT post_type, COUNT(*) AS n FROM wp_postmeta JOIN wp_posts ON wp_postmeta.post_id = wp_posts.ID WHERE meta_key = '_elementor_data' GROUP BY post_type ORDER BY n DESC;" 2>/dev/null > "$RAW_DIR/elementor-counts.txt" || echo "" > "$RAW_DIR/elementor-counts.txt"

ELEMENTOR_POST_COUNT=$(python3 -c "
import sys
lines = open('$RAW_DIR/elementor-counts.txt').read().strip().split('\n')
total = 0
for line in lines[1:]:
    parts = line.split()
    if len(parts) >= 2:
        try: total += int(parts[-1])
        except: pass
print(total)
" 2>/dev/null || echo "0")

if [[ "$ELEMENTOR_POST_COUNT" == "0" ]]; then
  echo "    (no _elementor_data postmeta found — site is not Elementor-built)"
  ELEMENTOR_SITE=false
else
  ELEMENTOR_SITE=true
fi

# ─── Section 3: Distinct widget types + tier classification ───────────────────

echo "==> [3/9] Widget types + classification"

# WP eval extracts {widgetType: count} from _elementor_data JSON across all posts.
wp eval '
$rows = $wpdb->get_col("SELECT meta_value FROM {$wpdb->postmeta} WHERE meta_key = \"_elementor_data\" LIMIT 5000");
$types = [];
foreach ( $rows as $row ) {
    if ( ! $row ) continue;
    $data = json_decode( $row, true );
    if ( ! is_array( $data ) ) continue;
    array_walk_recursive( $data, function ( $v, $k ) use ( &$types ) {
        if ( $k === "widgetType" && is_string( $v ) ) {
            $types[ $v ] = ( $types[ $v ] ?? 0 ) + 1;
        }
    } );
}
arsort( $types );
foreach ( $types as $t => $n ) {
    echo "$t\t$n\n";
}
' 2>/dev/null > "$RAW_DIR/widget-types.tsv" || echo "" > "$RAW_DIR/widget-types.tsv"

# Classify each widget type. Tiers from SKILL.md heuristics.
RAW_DIR="$RAW_DIR" python3 > "$RAW_DIR/widget-classification.tsv" <<'PYEOF'
import os
RAW = os.environ['RAW_DIR']
EASY = {"heading","text-editor","image","button","divider","spacer","columns","column","section","container","html","video","star-rating"}
MEDIUM = {"icon-list","icon-box","accordion","tabs","image-carousel","image-gallery","pricing-table","testimonial","counter","progress","toggle","price-table","call-to-action","alert"}
HARD = {"form","popup","slides","theme-builder","post-grid","posts","portfolio","posts-grid","template","global-widget","loop-grid","loop-carousel","nav-menu","mega-menu","login","subscribe"}

rows = []
try:
    for line in open(f"{RAW}/widget-types.tsv"):
        parts = line.strip().split("\t")
        if len(parts) < 2: continue
        wtype, count = parts[0], int(parts[1])
        if wtype in EASY: tier = "EASY"
        elif wtype in MEDIUM: tier = "MEDIUM"
        elif wtype in HARD: tier = "HARD"
        else: tier = "REVIEW"
        rows.append((wtype, count, tier))
except FileNotFoundError:
    pass
for w, c, t in rows:
    print(f"{w}\t{c}\t{t}")
PYEOF

# Aggregate tier totals.
read -r EASY_COUNT MEDIUM_COUNT HARD_COUNT REVIEW_COUNT < <(python3 <<PYEOF
totals = {"EASY":0,"MEDIUM":0,"HARD":0,"REVIEW":0}
try:
    for line in open("$RAW_DIR/widget-classification.tsv"):
        parts = line.strip().split("\t")
        if len(parts) < 3: continue
        totals[parts[2]] = totals.get(parts[2],0) + int(parts[1])
except FileNotFoundError:
    pass
print(totals["EASY"], totals["MEDIUM"], totals["HARD"], totals["REVIEW"])
PYEOF
)

# ─── Section 4: Plugin classification ─────────────────────────────────────────

echo "==> [4/9] Plugin classification"
python3 > "$RAW_DIR/plugins-classified.tsv" <<PYEOF
import json
UTILITY = {"wordfence","yoast","rank-math","wp-super-cache","w3-total-cache","wp-rocket","updraftplus","backupbuddy","akismet","jetpack","seo-by-rank-math","wp-fastest-cache"}
ELEMENTOR_ONLY = {"elementor","elementor-pro","essential-addons-for-elementor-lite","exclusive-addons-for-elementor","happy-elementor-addons","premium-addons-for-elementor","crocoblock-jet-engine","jet-elements","jet-engine","jet-menu","jet-popup","jet-smart-filters","jet-tabs","jet-tricks","unlimited-elements-for-elementor","powerpack-elements","elements-kit","wp-mega-menu-pro"}

try:
    plugins = json.load(open("$RAW_DIR/active-plugins.json"))
except (FileNotFoundError, json.JSONDecodeError):
    plugins = []

for p in plugins:
    slug = p.get("name", "")
    if slug in ELEMENTOR_ONLY: tier = "ELEMENTOR_ONLY"
    elif slug in UTILITY: tier = "UTILITY"
    else: tier = "RENDERING_OWNER_OR_UNKNOWN"
    print(f"{slug}\t{p.get('version','')}\t{tier}")
PYEOF

read -r UTILITY_PLUGIN_COUNT RENDERING_PLUGIN_COUNT ELEMENTOR_PLUGIN_COUNT < <(python3 <<PYEOF
totals = {"UTILITY":0,"RENDERING_OWNER_OR_UNKNOWN":0,"ELEMENTOR_ONLY":0}
try:
    for line in open("$RAW_DIR/plugins-classified.tsv"):
        parts = line.strip().split("\t")
        if len(parts) >= 3:
            totals[parts[2]] = totals.get(parts[2],0) + 1
except FileNotFoundError:
    pass
print(totals["UTILITY"], totals["RENDERING_OWNER_OR_UNKNOWN"], totals["ELEMENTOR_ONLY"])
PYEOF
)

# ─── Section 5: Performance baseline ──────────────────────────────────────────

echo "==> [5/9] Performance baseline"
AUTOLOAD_KB=$(wp db query "SELECT ROUND(SUM(LENGTH(option_value))/1024) FROM wp_options WHERE autoload = 'yes';" --skip-column-names 2>/dev/null | tr -d '[:space:]' || echo "?")
TTFB_HOME=$(curl -o /dev/null -s -w "%{time_starttransfer}" --max-time 10 "$SITE_URL/" 2>/dev/null || echo "?")

# ─── Section 6: SEO baseline ──────────────────────────────────────────────────

echo "==> [6/9] SEO baseline"
SEO_PLUGIN=$(wp plugin list --status=active --field=name 2>/dev/null | grep -iE "yoast|rank-math|all-in-one-seo|seopress" | head -1 || echo "none")
SITEMAP_COUNT=0
for path in /sitemap_index.xml /sitemap.xml /wp-sitemap.xml; do
  count=$(curl -s --max-time 10 "$SITE_URL$path" 2>/dev/null | grep -c '<loc>' || true)
  if [[ "$count" -gt 0 ]]; then SITEMAP_COUNT=$count; break; fi
done

# ─── Section 7: .htaccess artifacts ───────────────────────────────────────────

echo "==> [7/9] .htaccess artifacts"
HTACCESS_MARKERS=""
if [[ -f ".htaccess" ]]; then
  HTACCESS_MARKERS=$(grep -oE "LSCACHE|LiteSpeed|NON_LSCACHE|dh-|# BEGIN [A-Z_]+" .htaccess 2>/dev/null | sort -u | tr '\n' ',' || echo "")
fi
[[ -z "$HTACCESS_MARKERS" ]] && HTACCESS_MARKERS="(none)"

# ─── Section 8: Elementor custom CSS ──────────────────────────────────────────

echo "==> [8/9] Elementor custom CSS"
CUSTOM_CSS_BYTES=$(wp option get elementor_custom_css --format=json 2>/dev/null | wc -c | tr -d '[:space:]' || echo "0")

# ─── Section 9: wp doctor (if installed) ──────────────────────────────────────

echo "==> [9/9] wp doctor"
DOCTOR_OUTPUT=""
if wp package list 2>/dev/null | grep -q "wp-doctor"; then
  DOCTOR_OUTPUT=$(wp doctor check --all 2>&1 | head -40 || echo "")
else
  DOCTOR_OUTPUT="(wp-doctor not installed; skipped)"
fi

# ─── Time estimate (rough heuristic) ──────────────────────────────────────────

ESTIMATE_HOURS=$(python3 -c "
e=$EASY_COUNT; m=$MEDIUM_COUNT; h=$HARD_COUNT; r=$REVIEW_COUNT
p=$ELEMENTOR_POST_COUNT
# 5 min per easy widget, 30 min per medium, 2 hr per hard, 45 min per review-needed, plus 20 min/page overhead
total_min = e*5 + m*30 + h*120 + r*45 + p*20
print(round(total_min / 60))
")

# ─── Determine overall difficulty ─────────────────────────────────────────────

if [[ "$HARD_COUNT" -gt 5 || "$REVIEW_COUNT" -gt 10 ]]; then
  DIFFICULTY="HARD"
elif [[ "$MEDIUM_COUNT" -gt 20 || "$HARD_COUNT" -gt 0 ]]; then
  DIFFICULTY="MIXED"
else
  DIFFICULTY="EASY"
fi

# ─── Write audit-report.md (long form) ────────────────────────────────────────

NOW=$(date -u +"%Y-%m-%d %H:%M UTC")

cat > "$OUT_DIR/audit-report.md" <<EOF
# Audit report — $SITE_URL

Generated: $NOW

## Source environment

- WP version: \`$WP_VERSION\`
- PHP version: \`$PHP_VERSION\`
- Active theme: \`$ACTIVE_THEME\` $ACTIVE_THEME_VERSION
- Active plugin count: $PLUGIN_COUNT

## Elementor inventory

- Posts/pages with \`_elementor_data\` postmeta: **$ELEMENTOR_POST_COUNT**
- Distinct widget types in use: $(wc -l < "$RAW_DIR/widget-types.tsv" | tr -d '[:space:]')
- Elementor custom CSS size: $CUSTOM_CSS_BYTES bytes

### Breakdown by post type

\`\`\`
$(cat "$RAW_DIR/elementor-counts.txt")
\`\`\`

### Widget classification (top 30)

| Widget type | Instances | Tier |
|---|---|---|
$(head -30 "$RAW_DIR/widget-classification.tsv" | awk -F'\t' '{printf "| %s | %s | %s |\n", $1, $2, $3}')

**Tier totals:**
- EASY: $EASY_COUNT instances (direct WP core block equivalent)
- MEDIUM: $MEDIUM_COUNT instances (pattern-rebuildable)
- HARD: $HARD_COUNT instances (custom block or manual rebuild needed)
- REVIEW: $REVIEW_COUNT instances (unknown widget — needs human classification)

## Plugin classification

| Tier | Count |
|---|---|
| Utility (keep as-is) | $UTILITY_PLUGIN_COUNT |
| Rendering-owner / unknown (migration risk) | $RENDERING_PLUGIN_COUNT |
| Elementor-only (leaves with Elementor) | $ELEMENTOR_PLUGIN_COUNT |

Full list: see \`raw/plugins-classified.tsv\`.

## Performance baseline

- Autoloaded options size: **${AUTOLOAD_KB} KB**
- TTFB (home page): ${TTFB_HOME}s

> Elementor + Pro typically leave 800-1500 KB of autoloaded options. Post-migration this number should drop dramatically once \`_elementor_*\` postmeta is purged.

## SEO baseline

- Active SEO plugin: \`$SEO_PLUGIN\`
- Sitemap URL count: $SITEMAP_COUNT

## .htaccess artifacts

- Markers detected: $HTACCESS_MARKERS

## wp doctor

\`\`\`
$DOCTOR_OUTPUT
\`\`\`

## Raw output

All wp-cli output preserved under \`raw/\` for verification.
EOF

# ─── Write migration-scorecard.md (prospect-facing one-pager) ─────────────────

cat > "$OUT_DIR/migration-scorecard.md" <<EOF
# Migration scorecard — $SITE_URL

**Difficulty:** $DIFFICULTY
**Estimated time (DIY solo):** ~$ESTIMATE_HOURS hours

Generated: $NOW

## Numbers

| Metric | Value |
|---|---|
| Pages using Elementor | $ELEMENTOR_POST_COUNT |
| Distinct widget types | $(wc -l < "$RAW_DIR/widget-types.tsv" | tr -d '[:space:]') |
| Easy widgets (direct block equivalent) | $EASY_COUNT |
| Medium widgets (pattern-rebuildable) | $MEDIUM_COUNT |
| Hard widgets (custom block / manual rebuild) | $HARD_COUNT |
| Unknown widgets (need review) | $REVIEW_COUNT |
| Plugins to keep | $UTILITY_PLUGIN_COUNT |
| Plugins flagged for migration risk | $RENDERING_PLUGIN_COUNT |
| Plugins that leave with Elementor | $ELEMENTOR_PLUGIN_COUNT |
| Autoload bloat | ${AUTOLOAD_KB} KB |

## What this means

EOF

if [[ "$DIFFICULTY" == "EASY" ]]; then
  cat >> "$OUT_DIR/migration-scorecard.md" <<EOF
Your site is mostly built from widgets that map cleanly to core WordPress blocks. A solo migration is feasible. The biggest time sink will be rebuilding patterns from medium-tier widgets and verifying the result page-by-page.
EOF
elif [[ "$DIFFICULTY" == "MIXED" ]]; then
  cat >> "$OUT_DIR/migration-scorecard.md" <<EOF
Your site is migratable but not trivial. You have some widgets that need pattern rebuilds or custom blocks. Plan for ~$ESTIMATE_HOURS hours of focused work, or join the cohort to compress it into a structured 8-week sprint with help.
EOF
else
  cat >> "$OUT_DIR/migration-scorecard.md" <<EOF
Your site has significant complexity — multiple hard-tier widgets, forms, or third-party Elementor-only plugins. A solo migration is risky without a clear playbook. Strongly consider the cohort or hiring help.
EOF
fi

cat >> "$OUT_DIR/migration-scorecard.md" <<EOF

## Time estimate breakdown

| Approach | Estimated time | Risk |
|---|---|---|
| DIY solo | ~$ESTIMATE_HOURS hours | Medium-high if you have HARD widgets or unknown plugins |
| Hire a freelancer | ~$((ESTIMATE_HOURS * 75))-$((ESTIMATE_HOURS * 150)) at \$75-\$150/hr | Variable — quality depends on the dev |
| **WP Block School cohort (8 weeks)** | Built-in pace + support | Low — structured playbook + office hours |

## Next step

- New to the method? Start with the [free mini-course](https://wpblockschool.com/mini).
- Ready to commit? [Join cohort #1](https://wpblockschool.com/cohort).
- Want a second opinion on this scorecard? Reply to your audit email and we'll take a look.

---

*Generated by [elementor-block-audit](https://github.com/billhector/elementor-block-audit) — read-only WordPress + Elementor migration audit. Full report at \`audit-report.md\`.*
EOF

echo ""
echo "✓ Audit complete."
echo "  Report:    $OUT_DIR/audit-report.md"
echo "  Scorecard: $OUT_DIR/migration-scorecard.md"
echo "  Raw data:  $OUT_DIR/raw/"
