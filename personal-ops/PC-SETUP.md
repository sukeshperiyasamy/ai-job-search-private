# Setting this up on another computer

The repo on GitHub holds the code and your public profile. Your **private** files (resumes, tracker,
generated applications, `.env`) are gitignored, so they are NOT in the clone. Move them with a backup.

## 1. On the old machine

```powershell
powershell -ExecutionPolicy Bypass -File personal-ops\update.ps1 -Action backup
```

Copy the newest folder under `%USERPROFILE%\Backups\ai-job-search\` to the new machine with a USB
drive or other private transfer. Do not email it and do not put it in a git repo: it contains your
resumes. Also make sure `git push origin personal` has been run so the new machine gets the latest
commits.

## 2. On the new machine (Windows)

Install the tools (official winget packages):

```powershell
winget install --id Git.Git -e
winget install --id Python.Python.3.13 -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Oven-sh.Bun -e
winget install --id GitHub.cli -e
winget install --id MiKTeX.MiKTeX -e --scope user
npm install -g @anthropic-ai/claude-code
```

Open a **new** terminal so PATH refreshes, then:

```powershell
initexmf --set-config-value=[MPM]AutoInstall=1
python -m pip install pyyaml pypdf
git config --global user.name  "<your name>"
git config --global user.email "<your email>"
gh auth login --web --git-protocol https --scopes repo   # you sign in yourself in the browser
claude                                                   # sign in to Claude Code on this machine
```

Claude Code sign-in is per machine. Do not copy `~/.claude` credential files between computers.

## 3. Get the code

```powershell
git clone https://github.com/sukeshperiyasamy/ai-job-search-private.git ai-job-search
cd ai-job-search
git switch personal
git remote add upstream https://github.com/ai-job-search-dev/ai-job-search.git
git remote set-url --push upstream DISABLED
git remote -v
```

`upstream` must show `DISABLED` for push. `master` mirrors upstream; work on `personal`.

## 4. Restore your private files

```powershell
robocopy "<path-to-backup>\20261029-xxxxxx" . /E /XF repo.bundle MANIFEST.txt
```

This puts `documents/`, generated CVs and letters, the tracker and any `.env` back in place.
Then check nothing private is tracked:

```powershell
git status          # should be clean
python tools\security_guards.py
```

## 5. Install and verify

```powershell
python tools\install_portal_clis.py
python -m unittest discover -s tests -t .
cd cv; lualatex -interaction=nonstopmode main_example.tex; cd ..
```

If the three `reset` tests fail on Windows, put Git's bash first: `$env:Path = 'C:\Program Files\Git\bin;' + $env:Path`
(`personal-ops\update.ps1` does this for you when it runs the tests).

## 6. Use it

Run `claude` inside the repo, then `/scrape`, `/rank`, `/apply <posting>`.
Compile PDFs with `lualatex` (CV) and `xelatex` (cover letter) as in `SETUP.md`.

## Keeping both machines in sync

* Profile and template changes: commit on `personal`, `git push origin personal` on one machine,
  `git pull` on the other.
* Private files do not sync through git. Re-run the backup and restore when they change, or keep
  `documents/` in a private encrypted cloud folder.
* Do the upstream updates on one machine (`personal-ops\update.ps1 -Action check`), push, then pull
  on the other.
