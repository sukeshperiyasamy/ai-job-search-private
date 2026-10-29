# Search Queries for Job Scraper

<!-- SETUP: Customize these queries based on your skills, target roles, and location -->

## Installed portal CLIs (primary for `/scrape`)

`/scrape` discovers every portal skill under `.agents/skills/*/SKILL.md` and runs its CLI first. Shipped country-agnostic CLIs include `linkedin-search` and `freehire-search`; Danish demos and any skill you add with `/add-portal` are included the same way. You do **not** need a matching `site:` line below for those CLIs to run.

The `site:` query templates in this file are the **WebSearch fallback** — for portals without a CLI, company career pages, or when a CLI fails.

**Language scope:** write every query category in every language listed in your CLAUDE.md Languages table (typically 1-2, sometimes more). A posting requiring a language you have *not* declared, as a job condition, is excluded before scoring; a posting requiring a *higher level* than you declared in a language you *do* work in is flagged for your own judgment, not excluded — see `04-job-evaluation.md`'s Language Gate, the single source of truth for this rule. Translate each category's keywords rather than machine-translating word-for-word (e.g. "Frontend Developer" -> "Desarrollador Frontend", not a literal word-for-word translation) if you work in more than one language.

## Search Sites

Primary (your market's job boards - scaffold one with `/add-portal`):
- **naukri.com** - India's largest general job board (no CLI installed yet; scaffold one with `/add-portal`, WebSearch `site:` queries until then)
- **linkedin.com/jobs** - LinkedIn job listings (filter: India / Bengaluru, Chennai, Coimbatore); also covered by `linkedin-search` CLI
- **in.indeed.com** - Indeed India (WebSearch fallback)
- **freehire** - covered by the `freehire-search` CLI

Secondary (company career pages via Google):
- Direct Google searches with `site:` filters for known target companies

## Query Categories

Queries are grouped by priority. Write **each category in every language from your Languages table** (see Language scope above). Combine each query with your location terms (e.g. your city, region, or metro area) where the site supports it.

**Organize by function, not job title.** The same underlying work carries different titles across companies and markets (a "Data Scientist" role at one employer may be posted as "Insights Analyst" or "Data Consultant" at another). Name each priority category after the function it covers, and list several plausible job titles as query variants within that category rather than betting an entire priority tier on one exact title string.

### Priority 1: Medical Device R&D and Systems Engineering

These match the most desired direction: industry R&D in medical devices. Fresher / entry-level, full-time only (exclude "intern").

```
site:naukri.com "medical device" "R&D engineer" Bengaluru
site:naukri.com "medical device" "systems engineer" Chennai
site:naukri.com "biomedical engineer" "R&D" Coimbatore
site:naukri.com "product development engineer" "medical devices" India
site:linkedin.com/jobs "Medical Device R&D Engineer" India
site:linkedin.com/jobs "Medical Device Systems Engineer" India
```

### Priority 2: Embedded / Firmware and Biosignal Engineering

Matches Arduino/ESP32/Raspberry Pi prototyping and EMG/biosignal work. Entry-level only; the experience is prototype-level.

```
site:naukri.com "embedded engineer" "medical" Bengaluru
site:naukri.com "firmware engineer" "medical device" Chennai OR Coimbatore
site:naukri.com "biosignal" OR "biomedical signal processing" engineer India
site:linkedin.com/jobs "Embedded Firmware Engineer" medical India
```

### Priority 3: Medical Device Software and Healthcare AI/ML

Adjacent roles building on Python signal processing and software skills.

```
site:naukri.com "medical device software engineer" India
site:naukri.com "healthcare" "machine learning engineer" fresher Bengaluru
site:naukri.com "digital health" OR "healthtech" "software engineer" Chennai
site:linkedin.com/jobs "Healthcare AI Engineer" India
site:linkedin.com/jobs "medical software engineer" Bengaluru
```

### Priority 4: Broader Diagnostics, Biosensor and Verification Roles

Wider net: diagnostics, biosensors, V&V and validation roles that use the lab and documentation background.

```
site:naukri.com "diagnostics" "R&D" scientist OR engineer India
site:naukri.com "biosensor" OR "Raman" engineer India
site:naukri.com "verification and validation" "medical device" Bengaluru
site:linkedin.com/jobs "biomedical engineer" Bengaluru OR Chennai OR Coimbatore
```

## Location Filter

When evaluating results, verify the job location is within reasonable commute distance from your home. Define acceptable areas:
- Ideal: Bengaluru, Chennai, Coimbatore (and surrounding areas)
- Acceptable: other Indian cities with medical-device or healthtech hubs, such as Hyderabad, Pune, Mumbai, Delhi NCR, Ahmedabad
- Borderline: remote or hybrid roles based elsewhere in India (note the on-site requirement)
- Flag: roles outside India

## Language Filter

Your working languages and levels are in CLAUDE.md's Languages table. When filtering scraped results, apply `04-job-evaluation.md`'s Language Gate: a posting requiring a language you haven't declared at all is excluded; a posting requiring a higher level than you declared in a language you do work in is not excluded, flag it clearly instead (see `job-scraper/SKILL.md`'s Step 3 "Quick Fit Assessment" for how the flag surfaces in `/scrape` output). Postings simply *written* in a language you don't work in, that don't require it on the job, are fine.

## Date Filter

Only include jobs posted within the last 14 days, or with an application deadline that has not yet passed. If a posting date cannot be determined, include it but flag as "date unknown".

## Adapting Queries

If the user specifies a focus area, select queries from the matching category and also generate 2-3 custom queries for that focus. For example:
- "/scrape [focus_area]" -> relevant category queries + custom focus-specific queries
