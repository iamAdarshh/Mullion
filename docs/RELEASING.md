# Releasing

Versioning follows [SemVer](https://semver.org). The tag format is `vMAJOR.MINOR.PATCH`. Only stable releases go out: prereleases are tagged `-beta.N` and never pushed to the Homebrew cask.

## Checklist
1. [ ] Milestone issues closed, and the manual test matrix for the milestone recorded in its tracking issue
2. [ ] `make lint test` green locally and in CI on `main`
3. [ ] `CHANGELOG.md`: move *Unreleased* entries under the new version with today's date
4. [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`. `MARKETING_VERSION` is always plain `X.Y.Z` (macOS rejects a `-beta.N` suffix in `CFBundleShortVersionString`). A beta keeps the `X.Y.Z` it leads up to and only bumps the build number.
5. [ ] Release build: `make archive`, which produces `build/Mullion.app` (Release, universal arm64 + x86_64, Hardened Runtime, ad-hoc signed) and verifies its signature
6. [ ] **Signing**
   - *With Developer ID:* `make notarize` (uses `xcrun notarytool submit --wait` with a keychain profile, then `xcrun stapler staple`). Not written yet: it comes with the M3 signing decision.
   - *Without:* nothing to do, because `make archive` already ad-hoc signs. Add the Gatekeeper note to the release notes.
7. [ ] `make dmg`, which produces `build/Mullion-X.Y.Z.dmg` and prints its SHA-256. Record it. For a beta: `make dmg RELEASE_VERSION=X.Y.Z-beta.N`.
8. [ ] Smoke test the DMG on a clean user account: install, grant Accessibility, try 3 shortcuts and 1 drag
9. [ ] `git tag vX.Y.Z && git push --tags`, then create the GitHub Release with the DMG and the changelog section
10. [ ] Update the Homebrew cask (own tap `iamAdarshh/homebrew-tap` first; submit to `homebrew/cask` once the project meets its notability requirements)

## Release-note template
```markdown
## Mullion vX.Y.Z

### New
- …

### Fixed
- …

### Install
Download `Mullion-X.Y.Z.dmg`, drag Mullion to Applications, open it and grant Accessibility access.
<!-- unsigned builds only -->
> This build is not notarized, so macOS blocks it on first launch. Open it once, then go to
> System Settings → Privacy & Security and click **Open Anyway** (macOS 15 and later no longer
> offer right-click → Open for this). Or run `xattr -dr com.apple.quarantine /Applications/Mullion.app`.

SHA-256: `…`
```
