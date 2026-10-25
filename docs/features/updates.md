# Feature spec: In-app updates

**Milestone:** v1.1 (signed releases and updates). **Status:** Accepted. **Inspired by:** Rectangle (Sparkle)

## Summary
Mullion checks for new releases, shows what changed, and installs an update in place with one click, keeping the Accessibility permission. It uses [Sparkle](https://sparkle-project.org) ([ADR-0008](../adr/0008-in-app-updates-with-sparkle.md)) with releases signed by a stable certificate ([ADR-0007](../adr/0007-self-signed-release-certificate.md)). Network access is opt-in: nothing is fetched until the user asks or agrees to automatic checks.

## User stories
- As a user, I want Mullion to tell me when a new version is out, so I don't have to watch GitHub.
- As a user, I want to install an update with one click and keep using my shortcuts straight away, without re-granting Accessibility or clicking *Open Anyway* again.
- As a privacy-minded user, I want Mullion to make no network requests unless I've agreed to it.
- As a user on a slow or metered connection, I want to check manually and turn automatic checks off.
- As the maintainer, I want an update to reach users only once I've published its release, after the smoke test.

## Data model
Nothing new is persisted by Mullion. Sparkle keeps its own preferences in Mullion's `UserDefaults` (`SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SULastCheckTime`, the skipped version). They aren't part of the config export: whether to check for updates is a choice per Mac, like *Launch at login*.

Info.plist keys (set at build time):

| Key | Value |
|---|---|
| `SUFeedURL` | `https://github.com/iamAdarshh/Mullion/releases/latest/download/appcast.xml` |
| `SUPublicEDKey` | the EdDSA public key (base64) |
| `SUScheduledCheckInterval` | `86400` (one day) |
| `SUEnableSystemProfiling` | `NO` |
| `SUEnableAutomaticChecks` | *not set*: Sparkle asks on the second launch |

## Behaviour
| Input | Effect |
|---|---|
| First launch | No update check and no prompt. The Accessibility onboarding has the stage to itself. |
| Second launch | Sparkle asks once: *Check for updates automatically?* The answer sets *Check for updates automatically* in Settings → General. Until it's answered, nothing is fetched. |
| Menu → **Check for Updates…** | Checks now, even if automatic checks are off. Shows *You're up to date* or the update window. Disabled while a check is already running. Works while Accessibility access is missing. |
| Scheduled check (automatic checks on) | At most once a day. If an update is found, the menu gets **Update Available: Mullion X.Y.Z…** at the top, and the update window opens without taking focus from the app you're using. Errors (offline, GitHub down) are only logged. |
| Update window | Shows the new version and its release notes (the CHANGELOG section). Buttons: **Install Update**, **Remind Me Later**, **Skip This Version**. |
| **Install Update** | Downloads the ZIP, verifies its EdDSA signature, quits Mullion, replaces the app where it is installed, and relaunches it. The Accessibility permission and *Launch at login* stay as they were. |
| Settings → General: **Check for updates automatically** | On or off. Off means Mullion never contacts the network on its own. |
| Settings → General: **Download and install updates automatically** | Off by default, and disabled while automatic checks are off. When on, an update is downloaded in the background and installed when Mullion quits, or on the next relaunch, without asking. |
| Settings → General: last checked | *Last checked: <date>*, or *Never*. |

## Implementation notes
- **Dependency:** Sparkle 2.10.0, pinned exactly, added to the app target in `project.yml` (ADR-0005). MullionCore stays free of dependencies.
- **Updater:** one `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate:userDriverDelegate:)`, owned by the `@MainActor` app delegate. *Check for Updates…* calls `checkForUpdates(_:)`, and its enabled state follows `updater.canCheckForUpdates`, which is observed with key-value observation.
- **Menu bar app:** Mullion is `LSUIElement`, so it has no Dock icon to bring forward.
  - Before a user-initiated check, the app activates itself so Sparkle's window comes to the front.
  - Scheduled checks use Sparkle's gentle reminders (`SPUStandardUserDriverDelegate.supportsGentleScheduledUpdateReminders` = `true`), which drive the *Update Available* menu item instead of stealing focus.
- **Settings:** a small `@Observable` `UpdateSettings` model on `@MainActor` wraps `automaticallyChecksForUpdates`, `automaticallyDownloadsUpdates` and `lastUpdateCheckDate`, for the SwiftUI General tab. Strings go in `Localizable.xcstrings`.
- **Signing:** non-sandboxed apps don't need Sparkle's XPC services. The `Downloader.xpc` and `Installer.xpc` services are removed from the embedded framework at build time. `Autoupdate` and `Updater.app` stay, and are signed with the release certificate. The app has `disable-library-validation` (ADR-0007).
- **Release workflow (`release.yml`):**
  - Downloads Sparkle's release tools (`Sparkle-2.10.0.tar.xz`, SHA-256 pinned).
  - Signs `Mullion-X.Y.Z.zip` with `sign_update` and the `SPARKLE_ED_PRIVATE_KEY` secret.
  - Writes `appcast.xml` with one item per stable release:
    - `sparkle:version` = `CURRENT_PROJECT_VERSION`, which must increase with every release;
    - `sparkle:shortVersionString` = `MARKETING_VERSION`;
    - `sparkle:minimumSystemVersion` = `14.0`;
    - `sparkle:edSignature`, `length`, and the release notes as inline HTML in `<description>`, generated from the CHANGELOG section, so showing them needs no second request.
  - Uploads `appcast.xml` as a release asset of the draft. GitHub's `latest` URL only resolves to published, non-pre-release releases.
- **Threads:** Sparkle does its network and install work on its own queues and calls back on the main thread. No AX work is involved.
- **Permissions:** none new. Installing into `/Applications` as a standard user may ask for an administrator password, which Sparkle's installer handles.
- **Public APIs only** (ADR-0003): Sparkle uses public frameworks; nothing here touches private API or SIP.

## Edge cases
- **Running from the DMG or from Downloads with the quarantine flag (App Translocation):** the app can't replace itself, and Sparkle says so and asks the user to move it to Applications.
- **Offline or GitHub unreachable:** a manual check shows Sparkle's error. A scheduled check only logs.
- **A bad or missing signature** in the downloaded update: rejected, and the installed app is left untouched.
- **Updating from 1.0.x:** not possible, because those builds don't contain Sparkle. 1.1.0 is installed by hand once, and its release notes explain the last re-grant of Accessibility.
- **Homebrew installs:** Sparkle updates the app in place. The cask sets `auto_updates true`, so `brew upgrade` doesn't fight it.
- **Accessibility missing:** updates still work. After relaunch, the usual onboarding and warning logic applies.
- **Mullion mid-drag when installing:** the install only starts after the user clicks *Install Update*, or at quit, so there's no drag in progress.
- **Skipped version:** Sparkle won't offer it again. A newer version is offered as usual.

## Acceptance criteria
- **UP-1:** On a fresh install, Mullion makes no network request until the user agrees to automatic checks or chooses *Check for Updates…*. Verify with a network monitor across first launch, second launch with the prompt declined, and an hour of use.
- **UP-2:** The second launch shows the automatic-check prompt once. The answer is reflected in Settings → General, and the prompt doesn't come back.
- **UP-3:** *Check for Updates…* with no newer version shows *You're up to date*.
- **UP-4:** With a newer version in the feed, the update window shows its version and release notes, and *Install Update* replaces the app and relaunches the new version.
- **UP-5:** After an update, shortcuts and drag-to-snap work without re-granting Accessibility.
- **UP-6:** After an update, no Gatekeeper prompt appears.
- **UP-7:** An update whose EdDSA signature doesn't match is rejected, and the installed app still launches unchanged.
- **UP-8:** With *Download and install updates automatically* on, a found update is installed when Mullion quits, without any prompt. It is off by default.
- **UP-9:** Draft and pre-release (`-beta`) releases are never offered.
- **UP-10:** *Launch at login* is still on after an update.
- **UP-11:** With *Check for updates automatically* off, no request is made over 24 hours of use.
- **UP-12:** *Check for Updates…* is disabled while a check runs, and works while Accessibility access is missing.
- **UP-13:** A scheduled check that finds an update adds *Update Available: Mullion X.Y.Z…* to the menu and doesn't take focus from the frontmost app.

## Decisions (2026-10-25)
- **Release notes** are inline HTML generated from the CHANGELOG section, not a `sparkle:releaseNotesLink` to the GitHub page, so no web view and no second request.
- **Check interval:** one day (Sparkle's default).
- **No badge** on the menu bar icon while an update waits; the *Update Available* menu item is enough.

## Open questions
None.
