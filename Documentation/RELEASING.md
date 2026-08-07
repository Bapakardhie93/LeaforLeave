# Releasing LeafOrLeave

## Local verification

Run the repeatable release gate from the repository root:

```bash
./scripts/verify-release.sh
```

It runs the complete unit and integration suite, builds the Release configuration without local signing, and validates the generated app metadata.

## Signed distribution

1. Confirm the marketing version and build number in the Xcode target.
2. Run `./scripts/verify-release.sh` and require a green result.
3. Archive the `LeafOrLeave` scheme with the Release configuration.
4. Export with a Developer ID Application certificate for direct distribution, or upload through App Store Connect for Mac App Store distribution.
5. For direct distribution, submit the exported app, ZIP, or DMG with `notarytool`, wait for acceptance, and staple the ticket.
6. Verify the final artifact with `codesign --verify --deep --strict`, `spctl --assess`, and a clean macOS user account.
7. Publish release notes and retain the matching dSYM.

Signing identities and notarization credentials intentionally remain outside the repository and CI logs.

## Data migration promise

The File menu can export and import a versioned JSON backup containing settings, workspace templates, bookmarks, and archived tabs. Passwords, cookies, browsing history, and live tab sessions are deliberately excluded.
