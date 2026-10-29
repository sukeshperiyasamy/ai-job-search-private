# Personal operations: backup, restore, safe upstream updates

This repo is a **personal checkout** of
[ai-job-search-dev/ai-job-search](https://github.com/ai-job-search-dev/ai-job-search).
Nothing in `personal-ops/` is part of upstream, so it never conflicts with upstream updates.

> **This repository is public.** Anything committed and pushed is world-readable. Never commit
> phone numbers, addresses, resumes, `.env`, tracker files or generated applications. They are
> gitignored; keep it that way (`python tools/security_guards.py` verifies the ignore rules).

## Branches and remotes

| Name | Meaning |
|---|---|
| `upstream` (remote) | Official repo. Fetch only; its push URL is set to `DISABLED`. |
| `origin` (remote) | Your GitHub repo. |
| `master` | Untouched mirror of upstream. Never commit personal work here. |
| `personal` | Your profile and customizations. This is the branch you work on. |
| `update/<ref>-<stamp>` | Temporary branch the update script creates for each upstream merge. |

## Where your personal data lives

| What | Where | In git? |
|---|---|---|
| Profile, search queries, CV and letter templates | `CLAUDE.md`, `.claude/skills/job-application-assistant/01-07*.md`, `.claude/skills/job-scraper/search-queries.md`, `cv/main_example.tex` | **Yes** (public) |
| Resumes, diplomas, references, postings, application archives | `documents/**` | No |
| Generated CVs / cover letters | `cv/main_*`, `cover_letters/cover_*` | No |
| Application tracker, salary data | `job_search_tracker.csv`, `salary_data.json` | No |
| Scraper state, research cache, reports | `**/job_scraper/seen_jobs.json`, `company_research/*.json`, `reports/` | No |
| Secrets | `.env`, `.env.*`, `.claude/settings.local.json` | No |

Claude Code credentials are stored by Claude Code itself under `~/.claude`, outside this repo.

## Backup

```powershell
powershell -ExecutionPolicy Bypass -File personal-ops\update.ps1 -Action backup
```

Writes `%USERPROFILE%\Backups\ai-job-search\<timestamp>\` containing every gitignored file that
exists (same relative paths), `repo.bundle` (all branches and tags) and `MANIFEST.txt`.
Use `-BackupRoot D:\path` to change the location. The folder holds private data: keep it outside
any git repo, and copy it to an encrypted drive or private cloud storage yourself.

## Restore

```powershell
# personal files: copy a backup folder back over the repo (it only adds/overwrites those files)
robocopy "$HOME\Backups\ai-job-search\<timestamp>" . /E /XF repo.bundle MANIFEST.txt

# whole repo history on a new machine
git clone "$HOME\Backups\ai-job-search\<timestamp>\repo.bundle" ai-job-search
```

Afterwards re-add remotes (`origin`, `upstream`), run `python tools/install_portal_clis.py`, and
check `git remote -v` (the `upstream` push URL must read `DISABLED`:
`git remote set-url --push upstream DISABLED`).

## Safe upstream update procedure

Prefer **release tags** over `upstream/master`. Nothing below deploys, pushes or force-anything.

1. **Check (read-only):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File personal-ops\update.ps1 -Action check
   ```
   Shows new commits and tags, GitHub release notes (if `gh` is logged in), CHANGELOG additions,
   changed files, a list of security/permission/dependency files to read carefully, which of
   *your* files upstream also changed, a dry-run conflict prediction, and the repo's own
   `check_upstream_updates.py` / `upstream_triage.py` output. Saved to `reports/`.
2. **Merge into a review branch** (must be run from a clean `personal`):
   ```powershell
   powershell -ExecutionPolicy Bypass -File personal-ops\update.ps1 -Action merge -Ref v1.8.0
   ```
   It runs a **backup first**, creates `update/v1.8.0-<stamp>` from `personal`, and merges the tag
   with `--no-commit`. Then:
   * **Conflict:** it stops, lists the files, exits with code 2 and changes nothing else. Resolve
     by hand (keep your data, adopt the methodology change) or `git merge --abort`.
   * **Clean:** it runs `security_guards`, `lint_skills` and the full unit-test suite, flags
     dependency-manifest changes (then run `python tools/install_portal_clis.py` yourself), and
     writes `reports/update-merge-<stamp>.md`. Exit code 3 means a check failed.
3. **Review** the staged merge: `git diff --cached --stat`, then read the "Review carefully" files
   (especially `.claude/settings.json`, `.claude/agents/`, `.claude/commands/`, `.github/`,
   `tools/security_guards.py`, `package.json`). Upstream permission changes widen what the agent
   may do, so treat them like any dependency update.
4. **Commit and adopt** once you approve:
   ```powershell
   git commit -m "merge v1.8.0 into personal"
   git switch personal
   git merge --ff-only update/v1.8.0-<stamp>
   git push origin personal        # only when you decide to publish
   ```
5. **Rollback** if something is wrong after adopting (non-destructive):
   `git revert -m 1 <merge-commit>`, or restore from the backup bundle.

Notes:
* Do not bump `framework_version` in files you personalized. `check_upstream_updates.py` uses
  those markers to tell which of your files a release touched.
* Never run `git reset --hard`, `git clean -fd` or force-push as part of an update. The script
  does none of them.
* Unattended automation is deliberately absent. The upstream repo's weekly `upstream-watch.yml`
  workflow only opens an issue and can be enabled later if you want a reminder.
* On Windows the script puts Git for Windows' `bin` first on `PATH` while it runs the tests.
  Otherwise the repo's shell-script tests can pick up the WSL `bash.exe` launcher and fail with
  three `reset` test errors when no WSL distro is installed.

## Tested

Exercised on a throwaway clone that started at `v1.7.2` plus the profile commit and merged
`v1.7.3` (124 upstream files): clean merge with the full test suite passing, the conflict-stop path
(exit code 2, nothing overwritten), backup contents, and `check` on the real repo. Not tested: a
real future release, `gh release view` output and the optional `-SkipTests` switch on a real update.
