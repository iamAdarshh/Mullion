# ADR-0007: Sign releases with a stable self-signed certificate

- **Status:** Accepted
- **Date:** 2026-10-25
- **Deciders:** @iamAdarshh

## Context
v1.0.x releases are ad-hoc signed ([ADR-0002](0002-distribution-outside-app-store.md)). An ad-hoc app's *designated requirement*, which is what macOS stores with its Accessibility permission, is just the hash of that exact build (`designated => cdhash H"…"`). Every release has a new hash, so macOS treats each update as a different app: the old switch stays on in *Privacy & Security → Accessibility*, but it belongs to the old build. Turning it off and on doesn't help. Updating to 1.0.1 meant quitting Mullion, removing it from that list with **–** (or running `tccutil reset Accessibility io.github.iamadarshh.mullion`), and granting the permission again, which we can't ask of users on every update.

Constraints: there is no paid Apple Developer account; in-app updates ([ADR-0008](0008-in-app-updates-with-sparkle.md)) replace the app in place and need the permission to survive; the Hardened Runtime stays on.

A spike on 2026-10-25 confirmed both halves of the plan on macOS 27:
- Two different builds (different CDHash) signed with the same self-signed certificate have the same designated requirement, `identifier "…" and certificate leaf = H"…"`. Replacing the first with the second kept the Accessibility permission without touching System Settings.
- With the Hardened Runtime, a framework signed with that certificate fails to load: "mapping process and mapped file (non-platform) have different Team IDs". Self-signed certificates have no Team ID, so library validation can't match them. With the `com.apple.security.cs.disable-library-validation` entitlement it loads.

## Options considered
1. **Keep ad-hoc signing and improve the instructions.** Free and nothing to manage. But every update still drops the permission, and in-app updates would leave the app broken until the user re-grants it by hand.
2. **A self-signed code-signing certificate, kept for years.**
   - Pros: free; the designated requirement is stable, so the permission survives updates (spike); works in CI with the certificate as a secret.
   - Cons: Gatekeeper still blocks the first download (*Open Anyway* stays); the maintainer must keep the private key safe, because losing or replacing the certificate resets every user's permission once; embedded frameworks need `disable-library-validation`, which weakens one Hardened Runtime check.
3. **A free "Apple Development" certificate** (Apple ID personal team). Has a Team ID, so no library-validation entitlement. But it's meant for development, not distribution, it expires every year, it's tied to a personal Apple ID, and Gatekeeper still blocks the download.
4. **A paid Developer ID with notarization** ($99/year). The best experience: no *Open Anyway*, a stable identity, no entitlement. But a recurring cost the project doesn't have yet. Moving to it later resets the permission once, like any certificate change.

## Decision
We will sign releases from v1.1.0 with a **self-signed code-signing certificate** (option 2), because it fixes the permission reset for free and is the prerequisite for in-app updates. A Developer ID (option 4) stays the long-term upgrade.

- **Certificate:** common name `Mullion Release`, RSA 3072, valid 10 years, `codeSigning` extended key usage. Created once by the maintainer.
- **Custody:** the `.p12` and its password are backed up in the maintainer's password manager, and stored as secrets in the GitHub `release` environment (`MULLION_SIGNING_P12_BASE64`, `MULLION_SIGNING_P12_PASSWORD`). Only `release.yml` reads them, after the environment's approval. The `.p12` alone can authorise an update: Sparkle accepts an update whose code signature matches the installed app's, even with a new EdDSA key ([ADR-0008](0008-in-app-updates-with-sparkle.md)). Protect it like the EdDSA key.
- **Build:** `release.yml` imports the certificate into a temporary keychain that is deleted afterwards, and `make archive` signs with `MULLION_CODE_SIGN_IDENTITY="Mullion Release"`. The expected designated requirement, `identifier "io.github.iamadarshh.mullion" and certificate leaf = H"<SHA-1>"`, is committed in `Config/release-designated-requirement.txt`, and CI fails unless the archived app and Sparkle's embedded code (`Sparkle.framework`, `Autoupdate`, `Updater.app`) match it exactly. A certificate replaced by mistake (same name, new key) can't ship. The certificate's SHA-1 is also published in SECURITY.md, so anyone can check a download.
- **Entitlement:** `com.apple.security.cs.disable-library-validation` in `App/Mullion.entitlements`, with a comment saying why. The rest of the Hardened Runtime stays on.
- **Debug builds** are unchanged: ad-hoc, or an Apple Development certificate through `Config/Local.xcconfig` (SETUP.md).

## Consequences
- Positive: the Accessibility permission survives updates, whether installed by hand, by Homebrew or by Sparkle. No paid account needed.
- Negative / accepted trade-offs:
  - Gatekeeper still blocks the first download; the *Open Anyway* instructions stay.
  - Updating from 1.0.x to 1.1.0 resets the permission one last time; the 1.1.0 release notes explain it.
  - With library validation off, the app can load any validly signed library, not only its own. Mullion loads no plug-ins, and the Hardened Runtime still blocks `DYLD_*` environment variables and unsigned code.
  - The certificate must never change. If it's lost or replaced, every user re-grants once, and Sparkle's code-signature fallback stops matching.
- Follow-ups: the signing setup in `release.yml` and `make archive`, RELEASING.md steps for creating and backing up the certificate, and a Developer ID ADR if the project ever gets one.
