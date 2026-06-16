# Pre-migration checklist — before you start an Elementor → blocks migration

Run through this BEFORE you touch the production site or commit to a timeline. Most Elementor migrations that fail, fail because one of these wasn't in place.

Cohort 1 (WP Block School): **Mac or Linux only.** Windows users need WSL2 — see "Operating system" below.

---

## Required (don't skip)

### Local development environment

- [ ] **Local by Flywheel** installed and working. (Alternative: DevKinsta, Studio. Local is what the cohort + skills are tested against.)
- [ ] You can spin up a new blank WordPress site in <2 minutes.
- [ ] You can open a site's WP files in your editor.

### Command-line tools

- [ ] **WP-CLI** on your PATH (`wp --version` returns 2.x). Install: `brew install wp-cli` on Mac.
- [ ] **Git** installed and configured (`git --version`).
- [ ] A code editor that handles PHP + JS + JSON (VS Code, Cursor, Nova, PhpStorm, etc.).

### Backups + safety nets

- [ ] **Full backup of production WP site** — files + database. UpdraftPlus or `wp db export` + zip of `wp-content/` works.
- [ ] **Staging copy** of the production site running locally. You will migrate against this, NOT against prod.
- [ ] You have tested restoring the backup at least once. Untested backups don't count.
- [ ] You know how to push the staging copy back to production when migration is done (Migrate Guru, WP Vivid, manual import, etc.).

### Hosting

- [ ] You know where production is hosted (DreamHost, Kinsta, WP Engine, etc.).
- [ ] You can SFTP/SSH into production if you need to.
- [ ] You know whether your host has any opinions about block themes (most don't, but a few aggressive caching layers can break the Site Editor).

### Time

- [ ] **4–8 hours minimum** for a small content site (≤20 pages, no e-commerce).
- [ ] **20–40 hours** for a content-heavy site (50+ pages, custom CPTs, multiple authors).
- [ ] More for sites with custom Elementor templates, headers/footers, or theme builder use.
- [ ] You have these hours blocked. Don't start mid-week-of-deadlines.

---

## Strongly recommended

### Operating system

- [ ] **Mac or Linux.** The migration skills + fixture-sandbox + most WP-CLI workflows assume Unix. Windows users need WSL2 (Ubuntu under WSL2 is the supported path). Native Windows + Git Bash is NOT supported by the cohort 1 toolchain.

### Inventory + planning

- [ ] **List every page using Elementor.** `wp post list --post_type=page --meta_key=_elementor_edit_mode --format=csv` + same for `post` and any CPTs.
- [ ] **List every Elementor template/header/footer.** Settings → Templates in the WP admin.
- [ ] **Plugin inventory.** `wp plugin list --format=csv`. For each plugin, decide: keep / replace / drop. (Many Elementor-adjacent plugins go away with Elementor — Essential Addons, Crocoblock, etc.)
- [ ] **Theme decision.** What block theme are you migrating TO? Twenty Twenty-Five, Ollie, Frost, custom? Decide BEFORE you start.
- [ ] **Custom CSS audit.** Note every custom-CSS block in Elementor settings + theme customizer. These all need new homes.
- [ ] **Custom code in `functions.php` or a child theme** — list it. Some of it may be unnecessary post-migration.

### Skills + comfort level

- [ ] You're comfortable reading HTML.
- [ ] You can write basic CSS.
- [ ] You can use browser devtools to inspect computed styles + the rendered DOM.
- [ ] You've used the WordPress block editor (Gutenberg) on at least one page. If not, do that first — migration assumes block-editor fluency.

### Acceptance criteria — define "done" upfront

- [ ] What pages MUST look identical to the Elementor version? (Usually: homepage, key landing pages.)
- [ ] What pages can look different/simpler? (Usually: blog posts, low-traffic interior pages.)
- [ ] What's acceptable post-migration: pixel-perfect, "close enough", or "completely rebuilt"?
- [ ] Who signs off? (You? A client? A stakeholder?)
- [ ] What's the rollback plan if the migration goes sideways mid-flight?

---

## Nice to have

- [ ] **Audit run.** Run `elementor-block-audit` against the staging copy to get a scorecard — sets expectations on difficulty and time.
- [ ] **Visual regression tooling** — screenshots of every important page BEFORE you start (Percy, Playwright, or just `cmd-shift-3` enough times).
- [ ] **Analytics snapshot** — pageview counts so you know which pages are worth pixel-perfect attention vs which can be "good enough".
- [ ] **A second site to practice on first** — if you've never done a block migration, try it on a smaller/personal site before tackling a client's.

---

## Red flags — don't migrate yet if any of these are true

- 🛑 You don't have a working backup that you've tested restoring.
- 🛑 The production site is your client's main lead source AND it's the only place that content exists.
- 🛑 You're trying to migrate during a launch / sale / important campaign.
- 🛑 The site uses Elementor Pro's Theme Builder (header/footer/single/archive templates) and you haven't yet decided what block-theme template parts they map to.
- 🛑 The site uses WooCommerce + Elementor's product widgets, and you haven't yet decided whether you're keeping Woo or replacing it.
- 🛑 You're under time pressure to "just finish this." Migrations under time pressure are how sites break.

---

## Once everything above is checked

Move to the migration playbook:

- Run `elementor-block-audit` on the staging copy.
- Use the scorecard to plan order of attack (easy widgets first, hardest pages last).
- Use `elementor-block-migration` against staging.
- Visual diff each migrated page against pre-migration screenshots.
- Once staging looks right, push to production via your chosen migration path.

---

*Maintained alongside [elementor-block-audit](https://github.com/billhector/elementor-block-audit). If you're going through the WP Block School cohort, this checklist is part of week 1 onboarding.*
