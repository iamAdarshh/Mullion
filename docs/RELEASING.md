# Releasing

Versioning follows [SemVer](https://semver.org). The tag format is `vMAJOR.MINOR.PATCH`. Only stable releases go out: prereleases are tagged `-beta.N` and never pushed to the Homebrew cask.

## Checklist
1. [ ] Milestone issues closed, and the manual test matrix for the milestone recorded in its tracking issue
2. [ ] `make lint test` green locally and in CI on `main`
3. [ ] `CHANGELOG.md`: move *Unreleased* entries under the new version with today's date
4. [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
5. [ ] Release build: `make archive`, which produces `build/Mullion.app` (Release, Hardened Runtime)
6. [ ] **Signing**
   - *With Developer ID:* `make notarize` (uses `xcrun notarytool submit --wait` with a keychain profile, then `xcrun stapler staple`)
   - *Without:* ad-hoc sign (`codesign --force --deep -s - build/Mullion.app`) and add the Gatekeeper note to the release notes
7. [ ] `make dmg`, which produces `build/Mullion-X.Y.Z.dmg`. Record its SHA-256.
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
> This build is not notarized. On first launch, right-click Mullion.app → Open, or run
> `xattr -dr com.apple.quarantine /Applications/Mullion.app`.

SHA-256: `…`
```
