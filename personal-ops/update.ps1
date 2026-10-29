<#
.SYNOPSIS
  Safe upstream update workflow for this personal ai-job-search checkout.

.DESCRIPTION
  check   Fetch upstream (read-only) and report: new commits/tags, release notes,
          changed files, which of YOUR files upstream also changed, and a
          dry-run merge prediction. Changes nothing.
  backup  Copy every git-ignored personal file (documents/, generated CVs and
          letters, tracker, salary data, .env, scraper state) plus a git bundle
          to a folder OUTSIDE the repo.
  merge   backup, then merge the chosen upstream ref into a NEW branch
          update/<ref>-<stamp> cut from 'personal' (never into personal itself),
          stop on any conflict, run the checks, write a report. The merge is left
          UNCOMMITTED for you to review. Nothing is pushed or deployed.

  Never used: git reset --hard, git clean, git push --force, git push.

.EXAMPLE
  powershell -File personal-ops\update.ps1 -Action check
  powershell -File personal-ops\update.ps1 -Action merge -Ref v1.8.0
#>
[CmdletBinding()]
param(
    [ValidateSet('check', 'backup', 'merge')]
    [string]$Action = 'check',
    # Upstream ref to compare/merge. A release tag (v1.8.0) is preferred over upstream/master.
    [string]$Ref = 'upstream/master',
    [string]$Remote = 'upstream',
    [string]$PersonalBranch = 'personal',
    [string]$BackupRoot = (Join-Path $HOME 'Backups\ai-job-search'),
    [switch]$SkipTests
)

# 'Continue' on purpose: native tools (git, python) write progress/warnings to stderr and
# must not abort the script. Failures are checked explicitly through $script:Rc / exit codes.
$ErrorActionPreference = 'Continue'
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location $Root
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Lines = New-Object System.Collections.Generic.List[string]

function Say([string]$Text = '') { Write-Host $Text; $Lines.Add($Text) }
function G { $o = & git @args 2>&1; $script:Rc = $LASTEXITCODE; return $o }
function Section([string]$Title) { Say ''; Say "## $Title" }

function Assert-Setup {
    $null = G remote get-url $Remote
    if ($script:Rc -ne 0) { throw "Remote '$Remote' is not configured." }
    $null = G rev-parse --verify --quiet $PersonalBranch
    if ($script:Rc -ne 0) { throw "Branch '$PersonalBranch' does not exist." }
}

function Save-Report([string]$Name) {
    $dir = Join-Path $Root 'reports'          # gitignored
    New-Item -ItemType Directory -Force $dir | Out-Null
    $path = Join-Path $dir "$Name-$Stamp.md"
    Set-Content -Path $path -Value $Lines -Encoding utf8
    Write-Host "`nReport written: $path"
}

# ---------------------------------------------------------------- check
function Invoke-Check {
    Assert-Setup
    Say "# Upstream update check ($Stamp)"
    Section 'Fetch (read-only)'
    $null = G fetch $Remote --tags
    if ($script:Rc -ne 0) { throw 'git fetch failed' }
    Say "Fetched $Remote with tags."

    $null = G rev-parse --verify --quiet "$Ref^{commit}"
    if ($script:Rc -ne 0) { throw "Ref '$Ref' not found after fetch." }

    $base = (G merge-base $PersonalBranch $Ref | Select-Object -First 1).ToString().Trim()
    $behind = [int](G rev-list --count "$base..$Ref" | Select-Object -First 1)
    $curTag = (G describe --tags --abbrev=0 $base | Select-Object -First 1)
    $latestTag = (G tag --sort=-v:refname | Select-Object -First 1)
    Say "Current upstream base : $($base.Substring(0,8)) (nearest tag: $curTag)"
    Say "Target ref           : $Ref"
    Say "Latest upstream tag  : $latestTag"
    Say "Upstream commits not yet in '$PersonalBranch': $behind"
    if ($behind -eq 0) {
        Say ''
        Say 'Up to date with this ref. Nothing to merge.'
        return @{ Behind = 0; Base = $base }
    }

    Section 'Release notes'
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $tag = if ($Ref -match '^v\d') { $Ref } else { $latestTag }
        $slug = ((G remote get-url $Remote | Select-Object -First 1) -replace '.*github.com[:/]', '' -replace '\.git$', '')
        $notes = & gh release view $tag --repo $slug 2>&1
        if ($LASTEXITCODE -eq 0) { $notes | ForEach-Object { Say $_ } } else { Say "(no GitHub release found for $tag)" }
    }
    Say ''
    Say 'CHANGELOG.md lines added upstream:'
    (G diff $base $Ref -- CHANGELOG.md) | Where-Object { $_ -match '^\+[^+]' } | Select-Object -First 80 | ForEach-Object { Say $_ }

    Section 'Upstream commits (max 60)'
    G log --oneline --no-decorate -60 "$base..$Ref" | ForEach-Object { Say $_ }

    Section 'Files changed upstream'
    $upChanged = @(G diff --name-only $base $Ref)
    G diff --name-status $base $Ref | ForEach-Object { Say $_ }

    Section 'Review carefully (security / permission / dependency surfaces)'
    $risky = $upChanged | Where-Object {
        $_ -match '^\.claude/(settings\.json|agents/|commands/)' -or $_ -match '^\.github/' -or
        $_ -eq 'tools/security_guards.py' -or $_ -match 'package\.json$' -or $_ -match 'SKILL\.md$'
    }
    if ($risky) { $risky | ForEach-Object { Say "  ! $_" } } else { Say '  none' }

    Section 'Your personalized files that upstream also changed'
    $mine = @(G diff --name-only $base $PersonalBranch)
    $overlap = $mine | Where-Object { $upChanged -contains $_ }
    if ($overlap) { $overlap | ForEach-Object { Say "  ! $_" } } else { Say '  none' }

    Section 'Dry-run merge prediction (touches nothing)'
    $mt = G merge-tree --write-tree --name-only $PersonalBranch $Ref
    if ($script:Rc -eq 0) { Say 'Clean merge predicted.' }
    else {
        Say 'CONFLICTS predicted in:'
        $mt | Select-Object -Skip 1 | Where-Object { $_ -and $_ -notmatch '^(Auto-merging|CONFLICT)' } | ForEach-Object { Say "  ! $_" }
    }

    Section 'Repo helper tools'
    foreach ($cmd in @(@('tools/check_upstream_updates.py', '--no-fetch', '--remote', $Remote), @('tools/upstream_triage.py', '--remote', $Remote))) {
        Say "> python $($cmd -join ' ')"
        & python @cmd 2>&1 | Select-Object -First 40 | ForEach-Object { Say "  $_" }
    }
    return @{ Behind = $behind; Base = $base; Overlap = $overlap }
}

# --------------------------------------------------------------- backup
function Invoke-Backup {
    Assert-Setup
    $dest = Join-Path $BackupRoot $Stamp
    New-Item -ItemType Directory -Force $dest | Out-Null
    # Everything G ignores but that exists on disk = personal/generated data.
    $files = G ls-files --others --ignored --exclude-standard |
        Where-Object { $_ -notmatch '(^|/)node_modules/' -and $_ -notmatch '(^|/)__pycache__/' -and $_ -notmatch '(^|/)bun\.lock$' -and $_ -notmatch '\.(aux|log|out|fls|fdb_latexmk|synctex\.gz)$' }
    $n = 0
    foreach ($f in $files) {
        $target = Join-Path $dest $f
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath (Join-Path $Root $f) -Destination $target -Force
        $n++
    }
    $null = G bundle create (Join-Path $dest 'repo.bundle') --branches --tags
    $head = (G rev-parse HEAD | Select-Object -First 1)
    @("created=$Stamp", "head=$head", "branch=$(G branch --show-current)", "ignored_files_copied=$n") |
        Set-Content (Join-Path $dest 'MANIFEST.txt')
    Say "Backup: $dest  ($n personal files + repo.bundle)"
    Say 'This folder holds private data (CVs, tracker, .env). Keep it OUTSIDE any git repo.'
    return $dest
}

# ---------------------------------------------------------------- merge
function Invoke-Merge {
    Assert-Setup
    $dirty = G status --porcelain --untracked-files=no
    if ($dirty) { throw "Tracked files have uncommitted changes. Commit or stash them first:`n$($dirty -join "`n")" }
    $cur = (G branch --show-current | Select-Object -First 1)
    if ($cur -ne $PersonalBranch) { throw "Run from branch '$PersonalBranch' (currently '$cur')." }

    $info = Invoke-Check
    if ($info.Behind -eq 0) { return }

    Section 'Backup'
    $null = Invoke-Backup

    $safe = ($Ref -replace '[^A-Za-z0-9._-]', '-')
    $branch = "update/$safe-$Stamp"
    Section "Merge into new branch $branch"
    $null = G switch -c $branch $PersonalBranch
    if ($script:Rc -ne 0) { throw "Could not create $branch" }
    $out = G merge --no-ff --no-commit $Ref
    $mergeRc = $script:Rc
    $out | ForEach-Object { Say $_ }

    $conflicts = @(G diff --name-only --diff-filter=U)
    if ($mergeRc -ne 0 -or $conflicts.Count -gt 0) {
        Say ''
        Say 'STOPPED: merge conflicts. Nothing was overwritten and nothing was committed.'
        $conflicts | ForEach-Object { Say "  CONFLICT: $_" }
        Say ''
        Say "Resolve in the working tree (keep your data, adopt upstream methodology), or abandon with:"
        Say "  git merge --abort ; git switch $PersonalBranch"
        Save-Report 'update-conflict'
        exit 2
    }

    Section 'Dependency / configuration migration check'
    $staged = @(G diff --cached --name-only)
    $dep = $staged | Where-Object { $_ -match 'package\.json$' -or $_ -match 'tools/install_portal_clis\.py$' }
    if ($dep) {
        Say 'Dependency files changed - after approval run: python tools/install_portal_clis.py'
        $dep | ForEach-Object { Say "  ! $_" }
    } else { Say 'No portal CLI manifest changes.' }
    $cfg = $staged | Where-Object { $_ -match '^\.claude/settings\.json$' -or $_ -match '^\.github/' }
    if ($cfg) { Say 'Permission/CI config changed - read these diffs before committing:'; $cfg | ForEach-Object { Say "  ! $_" } }

    Section 'Checks'
    # On Windows the repo's shell tests can pick up the WSL bash.exe launcher, which fails when no
    # distro is installed. Put Git for Windows' bash first for the test run.
    $gitBin = Join-Path (Split-Path (Split-Path (Get-Command git).Source)) 'bin'
    if (Test-Path (Join-Path $gitBin 'bash.exe')) { $env:Path = "$gitBin;$env:Path" }
    $failed = @()
    $steps = @(
        @{ N = 'security_guards'; A = @('tools/security_guards.py') },
        @{ N = 'lint_skills'; A = @('tools/lint_skills.py') }
    )
    if (-not $SkipTests) { $steps += @{ N = 'unittest'; A = @('-m', 'unittest', 'discover', '-s', 'tests', '-t', '.') } }
    foreach ($s in $steps) {
        $o = & python @($s.A) 2>&1
        if ($LASTEXITCODE -eq 0) { Say "PASS  $($s.N)" }
        else { Say "FAIL  $($s.N)"; $o | Select-Object -Last 15 | ForEach-Object { Say "      $_" }; $failed += $s.N }
    }
    if ($SkipTests) { Say 'SKIPPED unittest (-SkipTests)' }

    Section 'Result'
    Say "Branch: $branch (merge staged, NOT committed)"
    Say "Failed checks: $(if ($failed) { $failed -join ', ' } else { 'none' })"
    Say 'Deployment implications: none automatic. Nothing was pushed or deployed.'
    Say ''
    Say 'Next (your decision):'
    Say "  1. Review:  git diff --cached --stat ; git diff --cached"
    Say "  2. Commit:  git commit -m `"merge $Ref into personal`""
    Say "  3. Adopt:   git switch $PersonalBranch ; git merge --ff-only $branch"
    Say "  4. Push only after approval: git push origin $PersonalBranch"
    Save-Report 'update-merge'
    if ($failed) { exit 3 }
}

switch ($Action) {
    'check'  { $null = Invoke-Check; Save-Report 'update-check' }
    'backup' { $null = Invoke-Backup }
    'merge'  { Invoke-Merge }
}

