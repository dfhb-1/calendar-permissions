# HuttonTools — Consolidation & Distribution Plan

Goal: turn this folder into a single, installable PowerShell toolset hosted on GitHub that
(a) is trivial for end users to install, (b) is trivial for them to update, and (c) lets you
add new scripts in the future by dropping in one file.

This document has three parts:

1. **Current state and design decisions** — what exists today and what we are changing.
2. **Target architecture** — the repo layout, install flow, and update flow we are building toward.
3. **Execution phases with Claude Code prompts** — copy/paste prompts, one per phase, each
   self-contained so it can be run in a fresh session.

---

## 1. Current state

| Item | State |
|---|---|
| Repo | `https://github.com/dfhb-1/calendar-permissions` — **public** (as of 2026-09-18), branch `main`, 2 commits. `origin` uses SSH (`git@github.com:dfhb-1/...`); SSH auth verified as `dfhb-1`, so Claude Code can push branches and tags from this machine. |
| `calendar-permissions/CalendarPermissions/` | Module v1.0.0. One function `Add-CalendarPermission`; fully interactive (`Read-Host`), no parameters, no `-WhatIf`. Manifest is the default template (`FunctionsToExport = '*'`, `CompanyName = 'Unknown'`). Committed. |
| `entra-group-members/EntraGroupMembers/` | Module v1.0.0. `Add-EntraGroupMember`, `Remove-EntraGroupMember`. Well-structured: private helpers, comment-based help, `SupportsShouldProcess`, CSV input, logging, explicit exports, PS 5.1 + 7 compatible. **Untracked — not yet committed.** |
| Installers | Two separate `install.ps1` files with different logic. The root one uses `$IsWindows` (breaks on PS 5.1) and doesn't honour OneDrive-redirected Documents. The EntraGroupMembers one handles both. |
| Updating | Manual: `git pull` + rerun `install.ps1`. No version check, no in-shell update command. |
| Tests / CI | None. No Pester or PSScriptAnalyzer locally. |
| Local tooling | macOS, pwsh 7.5.4. No `gh` CLI (not required — SSH covers push/tag; releases are created by GitHub Actions). |

### Problems this plan solves

- Each tool is its own repo-within-a-repo with its own installer and README. Adding a third tool means copying all of that again.
- Two modules installed side by side means two `Import-Module` calls and two things to update.
- No way for an end user to know an update exists or apply it without git knowledge.
- `Add-CalendarPermission` can't be scripted (no parameters) and can't be previewed (no `-WhatIf`).

---

## 2. Design decisions

Each of these is the recommended default. Change it before running Phase 1 if you disagree — the
prompts below reference these names.

| Decision | Choice | Why |
|---|---|---|
| **Module name** | `HuttonTools` | One umbrella module, one `Import-Module`, one thing to update. Existing manifest already says `CompanyName = 'Hutton Builds'`. |
| **Repo name** | Rename `calendar-permissions` → `hutton-tools` | The repo is no longer about calendars. GitHub auto-redirects the old URL, so existing clones keep working. |
| **One module vs. many** | One module, functions in `Public/*.ps1` | Separate modules only pay off when dependencies conflict. Here they don't: both `ExchangeOnlineManagement` and `Microsoft.Graph` are declared as *external* dependencies checked at call time, not import time, so importing `HuttonTools` never fails because Graph isn't installed. |
| **Adding a new tool** | Drop `Public/Verb-Noun.ps1` in, add the name to `FunctionsToExport`, bump version | A Pester test fails if a Public file isn't exported, so you can't forget. A scaffold script (`tools/New-Tool.ps1`) does both steps for you. |
| **Distribution** | GitHub Releases (semver tags `vX.Y.Z`) + a `HuttonTools.zip` asset built by GitHub Actions | Releases give a stable "latest" URL, an immutable artifact per version, and release notes — without needing a PowerShell Gallery / NuGet feed. Because the repo is public, `https://github.com/dfhb-1/hutton-tools/releases/latest/download/HuttonTools.zip` always resolves to the newest asset with **no API call and no credentials**. |
| **Install** | One-liner: `irm https://raw.githubusercontent.com/dfhb-1/hutton-tools/main/install.ps1 \| iex` — plus `./install.ps1` from a clone | `irm \| iex` is the standard PowerShell bootstrap pattern users already know from Scoop, Chocolatey, oh-my-posh, etc. The installer downloads the zip from the `releases/latest/download/` URL above, so it never touches the GitHub API and can't be rate-limited. |
| **Update** | `Update-HuttonTools` built into the module | One unauthenticated call to `api.github.com/repos/.../releases/latest` to learn the newest version, compares to installed `ModuleVersion`, downloads the zip, replaces the install, tells you to reopen the shell. `-CheckOnly` just reports. Unauthenticated API limit is 60 requests/hour per IP — plenty for a version check; if a whole office behind one NAT ever hits it, setting `$env:GITHUB_TOKEN` lifts it (optional, two lines of code). |
| **Install location** | Current-user module path for the edition running the installer (`Documents\PowerShell\Modules` on pwsh 7, `Documents\WindowsPowerShell\Modules` on 5.1, `~/.local/share/powershell/Modules` on macOS/Linux). Honours OneDrive-redirected Documents. No admin needed. | Because it's on `$env:PSModulePath`, PowerShell **auto-imports** the module the first time you call any of its commands. **No `$PROFILE` edit is needed** — the current READMEs suggesting `Add-Content $PROFILE` are unnecessary and should be dropped. |
| **Public vs. private repo** | **Decided: public** (2026-09-18). | `irm \| iex` and `Update-HuttonTools` work with zero credentials; no token discovery, no PAT instructions, no private-repo error branches in the code. Keep it that way: never commit tenant IDs, real group names, or user emails into examples (the existing `scrubbed group name example` commit is the right habit — Phase 1 also scrubs the `@huttonbuilds.com` addresses currently in `EntraGroupMembers` help examples). If the repo ever goes private again, the only change needed is an `Authorization: Bearer $env:GITHUB_TOKEN` header on the two web calls. |
| **PS 5.1 support** | Yes | Windows PowerShell 5.1 is still the default shell on Windows. Costs nothing here except avoiding `$IsWindows` and forcing TLS 1.2 before web calls. |
| **Legacy cleanup** | The new installer removes old `CalendarPermissions` and `EntraGroupMembers` module folders from the user module path | Otherwise two modules export `Add-EntraGroupMember` and whichever imports last wins — confusing to debug. |
| **`Add-CalendarPermission` behaviour** | Make it parameterised (`-Mailbox`, `-User`, `-AccessRights`) with `-WhatIf`. Mandatory parameters still prompt if omitted, so interactive use is unchanged. | Scriptable, previewable, consistent with the Entra commands. |

---

## 3. Target architecture

### Repo layout

```
hutton-tools/
├── HuttonTools/                     # the module — this folder is what gets installed
│   ├── HuttonTools.psd1             # manifest: version, explicit FunctionsToExport
│   ├── HuttonTools.psm1             # dot-sources Private/*.ps1 then Public/*.ps1
│   ├── Public/                      # one file per exported command — ADD NEW TOOLS HERE
│   │   ├── Add-CalendarPermission.ps1
│   │   ├── Add-EntraGroupMember.ps1
│   │   ├── Remove-EntraGroupMember.ps1
│   │   └── Update-HuttonTools.ps1
│   └── Private/                     # shared helpers, not exported
│       ├── Connect-HbExchange.ps1   # ensure Exchange Online session
│       ├── Connect-HbGraph.ps1      # ensure Graph session (was Connect-EgmGraph)
│       ├── Get-HbGitHubRelease.ps1  # release lookup + download (used by Update-HuttonTools)
│       ├── Get-HbInstallPath.ps1    # user module path logic (shared with install.ps1)
│       ├── Invoke-EgmMembershipChange.ps1
│       ├── Resolve-EgmGroup.ps1
│       ├── Get-EgmUserList.ps1
│       └── Write-HbLog.ps1          # (was Write-EgmLog)
├── tests/
│   ├── HuttonTools.Module.Tests.ps1 # manifest valid, every Public file exported, imports clean
│   └── ScriptAnalyzer.Tests.ps1     # PSScriptAnalyzer passes with repo settings
├── tools/
│   └── New-Tool.ps1                 # scaffold a new Public function + export entry
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                   # on push/PR: PSScriptAnalyzer + Pester on Windows + Ubuntu
│   │   └── release.yml              # on tag v*: validate tag == ModuleVersion, zip module, create release
│   └── PULL_REQUEST_TEMPLATE.md
├── install.ps1                      # bootstrap: works from a clone OR piped via irm | iex
├── PSScriptAnalyzerSettings.psd1
├── CHANGELOG.md
├── CONTRIBUTING.md                  # "how to add a tool" in 5 steps
├── README.md
└── .gitignore                       # .DS_Store, *.log, TestResults/
```

### Install flow (`install.ps1`)

```
Detect mode:
  $PSScriptRoot set  → running from a clone.  Source = ./HuttonTools
  $PSScriptRoot empty → piped via irm | iex.   Source = download
        https://github.com/dfhb-1/hutton-tools/releases/latest/download/HuttonTools.zip
        (or .../releases/download/<-Version>/HuttonTools.zip), extract to temp
        No API call, no auth — GitHub serves these redirects for public repos.
Resolve user module path for current edition/OS (OneDrive-aware)
Remove legacy CalendarPermissions / EntraGroupMembers folders if present (say so)
Remove existing HuttonTools folder, copy new one in
Write HuttonTools/install.json  { version, source ("release"|"local"), installedAt, repo }
Test-ModuleManifest on the installed copy — fail loudly if bad
Check external deps (ExchangeOnlineManagement, Microsoft.Graph.Groups, Microsoft.Graph.Users)
  → print Install-Module hint for anything missing; do not auto-install
Print: installed version, path, "open a new shell or Import-Module HuttonTools -Force"
```

Parameters: `-Version <tag>` (pin a release), `-Source <path>` (install from an arbitrary folder), `-KeepLegacy` (skip cleanup).

### Update flow (`Update-HuttonTools`)

```
Read installed version from the loaded module's manifest
GET https://api.github.com/repos/dfhb-1/hutton-tools/releases/latest   (unauthenticated;
  adds Authorization header only if $env:GITHUB_TOKEN happens to be set — rate-limit relief)
Compare [version] — if not newer: "HuttonTools X.Y.Z is up to date." and stop
-CheckOnly → print installed vs latest + release notes URL, stop
Download https://github.com/dfhb-1/hutton-tools/releases/download/<tag>/HuttonTools.zip
  to temp, extract
Run the install.ps1 *from inside the downloaded release* with -Source <extracted module>
  (so the installer always matches the version being installed — one copy of install logic)
Print "Updated X.Y.Z → A.B.C. Open a new PowerShell session to load it."
```

`-Force` reinstalls the latest even if versions match. `-WhatIf` supported.

### Release flow (maintainer)

```
1. Bump ModuleVersion in HuttonTools.psd1, add a CHANGELOG entry, commit to main
2. git tag vX.Y.Z && git push --tags
3. release.yml: checks tag == ModuleVersion, runs tests, zips HuttonTools/ → HuttonTools.zip,
   creates the GitHub Release with the CHANGELOG section as notes
4. Users run Update-HuttonTools
```

### Adding a new tool (contributor)

```
pwsh ./tools/New-Tool.ps1 -Name Get-Something      # creates Public/Get-Something.ps1 from template
                                                    # and adds it to FunctionsToExport
# write the function; use Connect-HbGraph / Connect-HbExchange / Write-HbLog from Private/
Invoke-Pester ./tests                               # proves it's exported and analyzer-clean
# bump version, CHANGELOG, PR, merge, tag
```

---

## 4. Execution phases

Run these in order. Each prompt is self-contained: open Claude Code in
`~/Documents/Powershell` (or the renamed clone) and paste the prompt. Review the diff and
commit between phases — each phase ends with a commit so you can stop anywhere.

Before Phase 1, confirm the names in section 2 (`HuttonTools` module, `hutton-tools` repo). If
you change either, find/replace it in the prompts below. Public vs. private is already decided.

Git workflow for the phases: Claude Code has SSH push access, so each phase can be done on a
branch and pushed (`git push -u origin <branch>`), then merged via a PR on GitHub or a local
`git merge`. Merging to `main` and tagging releases stay with you.

### Phase 0 — Prep (you, not Claude — 5 minutes)

1. Install local test tooling once:
   ```powershell
   Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
   Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
   ```
2. Rename the repo on GitHub: Settings → General → Repository name → `hutton-tools`.
   Then locally: `git remote set-url origin git@github.com:dfhb-1/hutton-tools.git`.
   (GitHub redirects the old name, so this isn't urgent — but the `irm` one-liner and the
   release URLs in the code are written against `hutton-tools`, so do it before Phase 4's
   first release.)
3. ~~Decide public vs. private~~ — done, public.
4. Optional: install the GitHub CLI (`brew install gh && gh auth login`) if you want Claude
   Code to open PRs and draft releases for you. Not required for anything in this plan.

### Phase 1 — Consolidate into one module

**Done when:** `Import-Module ./HuttonTools -Force; Get-Command -Module HuttonTools` lists
`Add-CalendarPermission`, `Add-EntraGroupMember`, `Remove-EntraGroupMember`; the old folders
are gone; everything is committed.

```text
This repo (~/Documents/Powershell, GitHub: dfhb-1/hutton-tools) currently holds two separate
PowerShell modules: calendar-permissions/CalendarPermissions (one function, Add-CalendarPermission,
interactive Read-Host only) and entra-group-members/EntraGroupMembers (Add-EntraGroupMember,
Remove-EntraGroupMember, with private helpers Write-EgmLog, Connect-EgmGraph, Resolve-EgmGroup,
Get-EgmUserList, Invoke-EgmMembershipChange). The entra-group-members folder is untracked.
Read all of it first, including both install.ps1 files and READMEs.

Consolidate them into ONE module named HuttonTools with this layout:

  HuttonTools/HuttonTools.psd1
  HuttonTools/HuttonTools.psm1     -> dot-sources every Private/*.ps1 then Public/*.ps1, then
                                      Export-ModuleMember only the Public function names
  HuttonTools/Public/<Verb-Noun>.ps1   one exported function per file, comment-based help in each
  HuttonTools/Private/<Verb-Noun>.ps1  one helper per file

Rules:
- Manifest: ModuleVersion 1.0.0, new GUID, Author 'Hutton Builds IT', CompanyName 'Hutton Builds',
  PowerShellVersion '5.1', CompatiblePSEditions Desktop+Core, EXPLICIT FunctionsToExport list (no
  wildcards), CmdletsToExport/VariablesToExport/AliasesToExport = @(), PrivateData.PSData with
  Tags, ProjectUri https://github.com/dfhb-1/hutton-tools, and
  ExternalModuleDependencies = ExchangeOnlineManagement, Microsoft.Graph.Groups, Microsoft.Graph.Users.
  Do NOT use RequiredModules — importing HuttonTools must succeed even if Graph/EXO aren't installed;
  dependencies are checked at call time by the Connect-* helpers, as EntraGroupMembers does today.
- Move the Entra functions and helpers over unchanged in behaviour. Rename Write-EgmLog -> Write-HbLog
  and Connect-EgmGraph -> Connect-HbGraph (they're now shared); keep the Egm-prefixed helpers that
  are Entra-specific. Update all call sites.
- Rewrite Add-CalendarPermission as a proper advanced function: [CmdletBinding(SupportsShouldProcess)],
  parameters -Mailbox (Mandatory), -User (Mandatory), -AccessRights (default 'Reviewer', ValidateSet
  of the standard Exchange folder roles), all with comment-based help and examples. Mandatory params
  prompt automatically so interactive use still works. Add Private/Connect-HbExchange.ps1 that throws
  a clear "Install-Module ExchangeOnlineManagement" message if the module is missing and calls
  Connect-ExchangeOnline if Get-ConnectionInformation returns nothing. Call it before
  Add-MailboxFolderPermission, and wrap that call in ShouldProcess.
- Delete calendar-permissions/, entra-group-members/, and the root install.ps1 (a new installer comes
  in the next phase — leave a one-line placeholder install.ps1 that says "coming in Phase 2" is NOT
  wanted; just delete it). Replace README.md with a short placeholder that names the module and lists
  the three commands; the full README is written in a later phase.
- Add .gitignore with .DS_Store, *.log, TestResults/, and remove the tracked .DS_Store files from git.
- The repo is PUBLIC. Scrub the real @huttonbuilds.com addresses and real group names from the
  EntraGroupMembers comment-based help examples — use user@contoso.com / "Sales Team" style
  placeholders. Grep the whole tree for huttonbuilds.com and any GUIDs before committing.
- Must work on Windows PowerShell 5.1 and PowerShell 7 — no $IsWindows, no ternary, no null-coalescing,
  no PS7-only cmdlets.

Verify with pwsh: Test-ModuleManifest ./HuttonTools/HuttonTools.psd1; Import-Module ./HuttonTools -Force;
Get-Command -Module HuttonTools shows exactly the three public commands and none of the private ones;
Get-Help Add-CalendarPermission -Full shows the new parameters. Then commit everything on a branch
named phase-1-consolidate with the message "Consolidate CalendarPermissions and EntraGroupMembers into
HuttonTools module" and push it to origin (SSH access is configured). Do not merge to main.
```

### Phase 2 — Installer

**Done when:** `./install.ps1` from the clone installs the module to the user module path, and
`Get-Content ./install.ps1 | iex` (simulating `irm | iex`) does the same by downloading from GitHub
(this half can only be fully verified after Phase 4 creates the first release — verify the
`-Source` path now and the download path then).

```text
Repo: ~/Documents/Powershell (GitHub dfhb-1/hutton-tools). It contains a PowerShell module in
./HuttonTools (manifest HuttonTools/HuttonTools.psd1) with Public/ and Private/ folders. Read the
module and CONSOLIDATION_PLAN.md section "Install flow" first.

Write ./install.ps1, a single self-contained script (it must not dot-source anything from the repo,
because users will run it via `irm <raw url> | iex` with nothing else present). Requirements:

- Parameters: -Version <string> (a release tag like v1.2.0; default = latest), -Source <path> (install
  from this folder instead of downloading; the folder must contain HuttonTools.psd1), -KeepLegacy (switch).
- Mode detection: if -Source given use it. Else if $PSScriptRoot is non-empty and "$PSScriptRoot/HuttonTools/HuttonTools.psd1"
  exists, install from there (clone mode). Else download mode: the repo is public, so do NOT call the
  GitHub API. Download directly from
    https://github.com/dfhb-1/hutton-tools/releases/latest/download/HuttonTools.zip        (default)
    https://github.com/dfhb-1/hutton-tools/releases/download/<Version>/HuttonTools.zip     (-Version)
  to a temp folder (Invoke-WebRequest follows the redirect), Expand-Archive, and use the extracted
  HuttonTools folder. The zip's root contains HuttonTools/ and install.ps1 side by side (the release
  workflow guarantees this) — locate HuttonTools/HuttonTools.psd1 inside the extracted tree rather
  than assuming a fixed depth. On a 404, print "No release found (tag <Version>)" — or, for latest,
  "No releases published yet" — and exit 1. No token handling, no zipball fallback.
- Target path: current user's module path for the RUNNING edition. Windows: [Environment]::GetFolderPath('MyDocuments')
  joined with 'WindowsPowerShell\Modules' on Desktop edition or 'PowerShell\Modules' on Core (this
  honours OneDrive-redirected Documents). macOS/Linux: $HOME/.local/share/powershell/Modules. Detect
  Windows via $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows (never rely on $IsWindows alone;
  it doesn't exist on 5.1). Create the folder if missing.
- Legacy cleanup unless -KeepLegacy: if CalendarPermissions or EntraGroupMembers folders exist under
  that module root, remove them and print one line saying so (their commands now live in HuttonTools).
- Remove any existing HuttonTools folder in the target, then Copy-Item the new one in.
- Write <target>/HuttonTools/install.json with: version (from the manifest just installed), source
  ("release", "clone", or "path"), installedAt (ISO 8601 UTC), repo ("dfhb-1/hutton-tools").
- Run Test-ModuleManifest on the installed manifest; on failure remove the copied folder and exit 1.
- Dependency check (do NOT auto-install): for each of ExchangeOnlineManagement, Microsoft.Graph.Groups,
  Microsoft.Graph.Users, if Get-Module -ListAvailable finds nothing, print a yellow line with the
  Install-Module command. Note that Install-Module Microsoft.Graph covers both Graph modules.
- Final output (green): "HuttonTools <version> installed to <path>." then (cyan): "Open a new PowerShell
  session, or run: Import-Module HuttonTools -Force". Do not tell users to edit $PROFILE — modules on
  PSModulePath auto-load.
- PS 5.1 compatibility: set [Net.ServicePointManager]::SecurityProtocol to include Tls12 before any web
  call; no $IsWindows-only logic, no PS7 syntax. Use Invoke-RestMethod / Invoke-WebRequest with
  -UseBasicParsing. Set $ErrorActionPreference = 'Stop' and wrap the main body in try/catch so a piped
  `iex` run exits cleanly with a red message rather than a wall of red.
- Clean up the temp folder in a finally block.

Also add Private/Get-HbInstallPath.ps1 to the module containing the same path-resolution logic as a
function (the module's Update command will need it in the next phase); keep install.ps1's copy inline
since it can't import the module. Put a short comment in both pointing at the other.

Verify: pwsh ./install.ps1 installs to ~/.local/share/powershell/Modules/HuttonTools, install.json is
written, and in a NEW pwsh -NoProfile session `Get-Command Add-EntraGroupMember` resolves without an
explicit Import-Module. Then pwsh ./install.ps1 -Source ./HuttonTools does the same. Commit on a
branch phase-2-installer as "Add cross-platform installer with release download and legacy cleanup"
and push it. Do not merge to main.
```

### Phase 3 — `Update-HuttonTools`

**Done when:** `Update-HuttonTools -CheckOnly` reports installed vs latest; `Update-HuttonTools`
replaces the install with the latest release (fully verifiable after Phase 4's first release).

```text
Repo: ~/Documents/Powershell (GitHub dfhb-1/hutton-tools), PowerShell module in ./HuttonTools with
Public/ and Private/ folders and a root install.ps1 that supports -Source <path> and -Version <tag>.
Read install.ps1, HuttonTools/Private/Get-HbInstallPath.ps1, and CONSOLIDATION_PLAN.md section
"Update flow" first.

Add two things to the module:

1. Private/Get-HbGitHubRelease.ps1 — function Get-HbGitHubRelease -Repo 'dfhb-1/hutton-tools'
   [-Tag <string>]. One unauthenticated GET to https://api.github.com/repos/<Repo>/releases/latest
   (or /releases/tags/<Tag>). Returns an object with Version ([version] parsed from tag_name minus
   leading 'v'), Tag, HtmlUrl, PublishedAt, Body (release notes), ZipAssetUrl (browser_download_url
   of the asset named HuttonTools.zip; throw a clear error if the release has no such asset).
   Forces TLS 1.2, uses -UseBasicParsing, sends a User-Agent header (GitHub requires one). If
   $env:GITHUB_TOKEN is set, add "Authorization: Bearer" — purely for rate-limit relief; never
   prompt for or discover a token otherwise. On HTTP 404 throw "No releases found for <Repo>".
   On 403 with an X-RateLimit-Remaining: 0 header, throw a message that names the reset time and
   mentions GITHUB_TOKEN.

2. Public/Update-HuttonTools.ps1 — [CmdletBinding(SupportsShouldProcess)] with -CheckOnly and -Force
   switches, full comment-based help with examples.
   - Installed version: read from (Get-Module HuttonTools).Version, falling back to the manifest at
     $PSScriptRoot/../HuttonTools.psd1. Also read install.json next to the manifest if present and
     show its installedAt in -CheckOnly output.
   - Latest: Get-HbGitHubRelease. Let its "No releases found" / rate-limit errors surface as-is.
   - If latest <= installed and not -Force: write "HuttonTools <v> is up to date." and return.
   - -CheckOnly: print a small table/object: Installed, Latest, PublishedAt, ReleaseUrl, and
     "Run Update-HuttonTools to install." if newer. Return the object so it's scriptable.
   - Otherwise, inside ShouldProcess("HuttonTools <installed> -> <latest>", "Update"): download
     ZipAssetUrl to a temp dir, Expand-Archive, locate the extracted HuttonTools folder AND the
     install.ps1 that shipped with that release (the release zip always contains install.ps1 next
     to the module folder — treat its absence as a corrupt release and stop), then invoke that
     install.ps1 -Source <extracted HuttonTools folder>. Reusing the shipped installer means there
     is exactly one implementation of "how to install".
   - Note: the currently-loaded module files will be overwritten while loaded. That's fine on
     all platforms for script modules, but the new code won't be active in this session. Print
     "Updated <old> -> <new>. Open a new PowerShell session to load the new version." Do NOT try
     to Remove-Module/Import-Module in place — Update-HuttonTools itself is running from the module.
   - Clean up temp in finally. PS 5.1 compatible syntax only.

Add Update-HuttonTools to FunctionsToExport. Also add a -Quiet-free, zero-network "hint" on import:
in HuttonTools.psm1, if install.json exists and is older than 30 days, write one Verbose line
suggesting Update-HuttonTools -CheckOnly. Verbose only — imports must stay silent by default.

Verify with pwsh: Import-Module ./HuttonTools -Force; Update-HuttonTools -CheckOnly. If no release
exists yet on GitHub it should fail with a clear "No releases found" message rather than a raw
exception. Commit on a branch phase-3-update as "Add Update-HuttonTools with GitHub release lookup"
and push it. Do not merge to main.
```

### Phase 4 — Tests, CI, and release automation

**Done when:** `Invoke-Pester ./tests` passes locally; pushing `v1.0.0` produces a GitHub Release
with `HuttonTools.zip` attached; the Phase 2 `irm | iex` install and Phase 3 update now verify
end to end.

```text
Repo: ~/Documents/Powershell (GitHub dfhb-1/hutton-tools), PowerShell module in ./HuttonTools
(Public/, Private/, HuttonTools.psd1, HuttonTools.psm1) plus root install.ps1. Read the module,
install.ps1 and CONSOLIDATION_PLAN.md sections "Repo layout" and "Release flow" first. Pester 5
and PSScriptAnalyzer are installed locally.

1. PSScriptAnalyzerSettings.psd1 at repo root: Severity Warning+Error, exclude
   PSAvoidUsingWriteHost (the tools deliberately use Write-Host for coloured operator output) and
   PSUseShouldProcessForStateChangingFunctions for Private/ helpers only if needed. Keep it minimal.

2. tests/HuttonTools.Module.Tests.ps1 (Pester 5 syntax):
   - Test-ModuleManifest passes.
   - Import-Module succeeds in a clean scope with no errors or warnings.
   - Every file in Public/ defines exactly one function whose name equals the file's basename, and
     that name is in FunctionsToExport; and every FunctionsToExport entry has a matching Public file.
     (This is the test that stops someone forgetting to export a new tool.)
   - No Private/ function name appears in the exported command list.
   - Every Public function has comment-based help with a Synopsis and at least one Example.
   - ModuleVersion parses as [version] with three parts.
   - install.ps1 parses (use [System.Management.Automation.Language.Parser]::ParseFile and assert no
     errors) and does not contain the string '$IsWindows' outside a line that also references PSEdition.
   tests/ScriptAnalyzer.Tests.ps1: Invoke-ScriptAnalyzer -Recurse on HuttonTools/, install.ps1 and
   tools/ with the settings file returns no results; report each finding as its own failed test.

3. .github/workflows/ci.yml: on push to main and on pull_request. Matrix: windows-latest and
   ubuntu-latest. On Windows run the tests under BOTH pwsh and powershell (5.1) — two steps or a
   shell matrix. Steps: checkout, Install-Module Pester/PSScriptAnalyzer -Force, Invoke-Pester
   ./tests -CI (exit non-zero on failure), upload TestResults as an artifact.

4. .github/workflows/release.yml: on push of tags matching v*. Steps: checkout; read ModuleVersion
   from HuttonTools/HuttonTools.psd1 and fail if "v$ModuleVersion" != the tag; run the same tests;
   build the artifact: a zip named HuttonTools.zip whose root contains the HuttonTools/ folder AND
   install.ps1 side by side (Update-HuttonTools relies on that layout); extract the matching
   "## [x.y.z]" section from CHANGELOG.md for the release body; create the GitHub Release with
   softprops/action-gh-release (or gh release create) attaching HuttonTools.zip. Needs
   permissions: contents: write.

5. CHANGELOG.md in Keep a Changelog format with an [Unreleased] section and a [1.0.0] entry
   summarising: consolidated CalendarPermissions + EntraGroupMembers, parameterised
   Add-CalendarPermission, new installer, new Update-HuttonTools.

6. .github/PULL_REQUEST_TEMPLATE.md with a 4-item checklist: tests pass, version bumped if
   user-facing, CHANGELOG updated, help/examples added for new commands.

Also add a test that the URLs hard-coded in install.ps1 and Private/Get-HbGitHubRelease.ps1 all
reference the same owner/repo string (dfhb-1/hutton-tools) so a future rename can't half-apply.

Run Invoke-Pester ./tests locally under pwsh and fix anything it finds in the module (do fix
genuine analyzer findings; do not blanket-suppress). Commit on a branch phase-4-ci as "Add Pester
tests, CI and release workflows" and push it. Do not merge to main and do not create any tags —
tell me the exact commands to tag and push v1.0.0 instead.
```

After merging to `main`, you run (from `main`, after confirming the repo rename in Phase 0 is done):

```powershell
git tag v1.0.0
git push origin main --tags
```

Watch the Actions tab. When the release exists, verify end to end on a Windows machine with
nothing pre-installed:

```powershell
irm https://raw.githubusercontent.com/dfhb-1/hutton-tools/main/install.ps1 | iex
Get-Command -Module HuttonTools
Update-HuttonTools -CheckOnly
```

Also confirm the stable download URL resolves in a browser:
`https://github.com/dfhb-1/hutton-tools/releases/latest/download/HuttonTools.zip`

### Phase 5 — Docs and contributor experience

**Done when:** a colleague can install, use every command, and update from README alone; you can
add a new tool by following CONTRIBUTING.md without re-reading this plan.

```text
Repo: ~/Documents/Powershell (GitHub dfhb-1/hutton-tools), PowerShell module HuttonTools with
Public/ (Add-CalendarPermission, Add-EntraGroupMember, Remove-EntraGroupMember, Update-HuttonTools),
Private/ helpers, root install.ps1, tests/, .github/workflows, CHANGELOG.md. Read all of it and
CONSOLIDATION_PLAN.md first. The repo is public.

1. Rewrite README.md for END USERS. Sections, in this order: one-paragraph what-it-is; Install
   (the irm | iex one-liner first, then "from a clone: ./install.ps1", then "no admin rights
   needed, no $PROFILE changes needed — commands auto-load", then a one-line "pin a version:
   install.ps1 -Version vX.Y.Z"); Prerequisites (Install-Module ExchangeOnlineManagement / Microsoft.Graph, one-time,
   and which commands need which); Update (Update-HuttonTools, -CheckOnly, pinning with
   install.ps1 -Version); Commands — one subsection per public command with a 1-line description
   and 2–3 copy-paste examples pulled from the functions' comment-based help (keep them in sync —
   don't invent new examples); Troubleshooting (module not found after install → wrong edition's
   module path, run installer in the shell you use; "not connected" errors; ambiguous group name;
   dynamic groups can't be edited; 5.1 TLS). Keep it scannable; no marketing.

2. CONTRIBUTING.md for MAINTAINERS: "Adding a tool" as a numbered 6-step list (run
   tools/New-Tool.ps1, write the function using the Private helpers — list them with one line each,
   add help + examples, run Invoke-Pester ./tests, bump ModuleVersion + CHANGELOG, open PR). Then
   "Releasing" (bump version, CHANGELOG, merge, tag vX.Y.Z, push tags, Actions builds the release).
   Then "Conventions": one function per file, Verb-Noun with approved verbs, Hb- prefix for shared
   private helpers, SupportsShouldProcess on anything that changes state, PS 5.1-compatible syntax
   (list the banned PS7 features), Write-HbLog for operator output, throw clear messages naming the
   Install-Module command for missing dependencies.

3. tools/New-Tool.ps1: param -Name (validated against ^[A-Z][a-z]+-[A-Z]\w+$ and the verb must be
   in Get-Verb), optional -Synopsis. Refuses if Public/<Name>.ps1 exists. Writes the file from an
   inline here-string template: comment-based help skeleton (Synopsis, Description, one Parameter,
   one Example), [CmdletBinding(SupportsShouldProcess)], param(), a TODO body with a ShouldProcess
   example. Then inserts the name into FunctionsToExport in HuttonTools.psd1, keeping the list
   sorted and the existing formatting (read the file, regex-replace the FunctionsToExport array,
   write back — don't regenerate the whole manifest). Prints next steps. Add a Pester test in
   tests/ that runs it against a temp copy of the module and asserts the file exists, the export
   was added, and the result still passes Test-ModuleManifest.

4. Update the module-tests so tools/ is analyzer-checked too (if not already).

Run the tests, commit on a branch phase-5-docs as "Add end-user README, contributor guide and
New-Tool scaffold" and push it. Do not merge to main.
```

### Phase 6 — Optional follow-ups (not needed for launch)

Pick these up later as individual prompts if they become worth it:

- **Startup update nudge**: on import, if `install.json` is older than N days, do a non-blocking
  check (cached to a file, at most once per day) and print one line if an update exists. Only if
  users are forgetting to update; it adds network I/O to every new shell.
- **`Get-HuttonTool`**: list all commands with synopsis — a nicer `Get-Command -Module HuttonTools`.
- **Signed releases**: Authenticode-sign the module in `release.yml` if execution policy on
  workstations is `AllSigned`. Needs a code-signing cert.
- **PowerShell Gallery**: now that the repo is public, publishing to the public PowerShell
  Gallery is an option — `Install-Module HuttonTools` / `Update-Module HuttonTools` with no
  custom installer at all. Costs: a Gallery account + API key, the name is global so
  `HuttonTools` must be unused, and it's a public listing. Worth it only if people outside
  your team should find it; for an internal IT toolset the release-zip flow is simpler.
- **Winget/Intune deployment**: push `install.ps1` as an Intune PowerShell script so new IT
  workstations get the toolset automatically.

---

## 5. Migration note for existing users

After Phase 4 ships, anyone with the old modules installed just runs the new install one-liner.
The installer removes `CalendarPermissions` and `EntraGroupMembers` from their module path and
reports it. Command names are unchanged, so any scripts or profiles referencing
`Add-EntraGroupMember` keep working. The only behavioural change is `Add-CalendarPermission`
now takes parameters (it still prompts when called with none).

Old clones of `calendar-permissions` keep working because GitHub redirects the renamed repo, but
users should re-clone `hutton-tools` or update their remote URL if they contribute.
