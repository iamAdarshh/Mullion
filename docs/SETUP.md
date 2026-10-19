# Local development setup

Everything runs locally on your Mac. No cloud services are needed.

## 1. Prerequisites
| Tool | Install | Check |
|---|---|---|
| macOS 14+ | — | `sw_vers` |
| Xcode (latest stable release from the App Store) | App Store, then open Xcode once to install components | `xcodebuild -version` |
| Command-line tools selected | `sudo xcode-select -s /Applications/Xcode.app` | `xcode-select -p` |
| Homebrew | https://brew.sh | `brew -v` |
| XcodeGen, SwiftLint, SwiftFormat, jq | `brew install xcodegen swiftlint swiftformat jq` | `xcodegen --version` |
| GitHub CLI (optional) | `brew install gh` then `gh auth login` | `gh auth status` |
| Claude Code | See https://code.claude.com/docs/en/overview | `claude --version` |

## 2. Put the starter kit in a git repo
```bash
mkdir -p ~/Developer && cd ~/Developer
unzip ~/Downloads/mullion-starter-kit.zip     # creates ./mullion
cd mullion
git init -b main
git add . && git commit -m "docs: project starter kit"
# optional: publish
gh repo create iamAdarshh/mullion --public --source=. --push
```

## 3. Start building with Claude Code
```bash
cd ~/Developer/mullion
claude
```
Then, inside Claude Code:
```
/kickoff M0
```
The `kickoff` skill reads the roadmap, plans the milestone, and builds it step by step, asking you to run anything that needs your hands (granting permissions, clicking through the UI).

Useful skills in this repo (type `/` to see them all):
| Skill | What it does |
|---|---|
| `/kickoff <milestone>` | Plan and implement a roadmap milestone |
| `/build-and-run` | Regenerate the project, build, and launch the debug app |
| `/add-window-action <name>` | Add a new snapping action end to end (Core math, tests, shortcut, menu, docs) |
| `/write-spec <feature>` | Write a feature spec in `docs/features/` before coding |
| `/write-adr <decision>` | Record an architecture decision |
| `/manual-test <milestone>` | Walk you through the manual test matrix and record the results |
| `/review-branch` | Review the current branch against REVIEW.md using the reviewer subagent |
| `/release <version>` | Run the release checklist |

## 4. Day-to-day commands (available after M0)
```bash
make bootstrap   # xcodegen generate (run after pulling or changing project.yml)
make build       # Debug build
make run         # build + launch Mullion-Debug.app
make test        # core + app tests
make test-core   # fast: swift test on MullionCore only
make lint        # swiftlint + swiftformat --lint
make format      # swiftformat (writes changes)
make clean
```

## 5. Granting Accessibility to the debug build
1. `make run`. The onboarding window appears.
2. Click **Open System Settings** and toggle **Mullion Debug** on under *Privacy & Security → Accessibility*.
3. The app detects the grant within about 1 s.

## Troubleshooting
**Accessibility is on, but nothing moves after a rebuild.** macOS ties the grant to the code signature. Ad-hoc builds change signature on every build. Fix it permanently by signing debug builds with a stable certificate:
- Easiest: in Xcode → Settings → Accounts, add your Apple ID (free) so Xcode creates a **"Apple Development"** certificate. Then set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig` (gitignored; copy `Config/Local.xcconfig.example`).
- As a quick reset: `tccutil reset Accessibility io.github.iamadarshh.mullion.debug`, then grant it again.

**Shortcuts don't fire.** Check for a conflict in *System Settings → Keyboard → Keyboard Shortcuts* and with apps like Raycast, Rectangle or Magnet. Quit other window managers while testing.

**Dragging snaps twice / weird animation.** macOS Sequoia tiling is also active. Turn off *Desktop & Dock → Windows → Drag windows to screen edges to tile*.

**Logs:**
```bash
log stream --predicate 'subsystem BEGINSWITH "io.github.iamadarshh.mullion"' --level debug
```
