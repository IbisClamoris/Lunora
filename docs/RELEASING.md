# Release and versioning guide

This guide describes the supported release process for Lunora.

## Single source of truth

The application version is defined in the `version` field of `pubspec.yaml`.

For a release such as `1.0.2`:

1. Update `pubspec.yaml` to `version: 1.0.2+3`.
2. Update the current version and release notes in `README.md` and `CHANGELOG.md`.
3. Commit and merge the change into `main`.
4. Create and push the matching annotated tag `v1.0.2` on the release commit.

The semantic version before `+` is used for the installer filename, Windows file version, GitHub Release name, and tag. The integer after `+` is the Flutter build number.

The workflow rejects a tag if it does not match the semantic version in `pubspec.yaml`.

## Publish a release

After the tag is pushed, **Flutter CI and Windows release** automatically:

1. Checks out the tagged source.
2. Installs the pinned Flutter SDK.
3. Runs `flutter test`.
4. Builds the Windows x64 release.
5. Builds `Lunora-Setup-<version>.exe` with Inno Setup.
6. Calculates the installer SHA-256 digest and writes a sidecar file named `Lunora-Setup-<version>.exe.sha256`.
7. Publishes a GitHub Release with generated release notes and attaches the installer and checksum.

The release job uses the repository-provided `GITHUB_TOKEN`. Do not add a personal access token or any secret to the Flutter application or installer.

A release is not published if tests, packaging, checksum generation, or tag/version validation fail.

## Verify a download

Download both the installer and its matching `.sha256` file from the same GitHub Release.

In PowerShell, run:

```powershell
Get-FileHash .\Lunora-Setup-1.0.2.exe -Algorithm SHA256
Get-Content .\Lunora-Setup-1.0.2.exe.sha256
```

Compare the hexadecimal hash from the first command with the hash in the checksum file. They must match exactly. Replace `1.0.2` with the version you downloaded.

The checksum detects accidental corruption or a mismatched download. It is not a digital signature and does not independently prove publisher identity.

## Important data-safety rule

The installer must update application binaries without deleting the user's application data. Never add database, settings, theme, backup, or personal-content directories to installer cleanup or uninstall deletion rules without a separate, explicitly reviewed data-migration plan.

## Troubleshooting

- **Tag/version mismatch:** confirm that the tag is exactly `v<version>`, matching `pubspec.yaml`.
- **No release was published:** inspect the failed job in the Actions run. The publish job runs only for tags beginning with `v` and only after the build job succeeds.
- **Checksum mismatch:** do not run the installer. Download both files again from the same release and compare the hashes.
- **Installer missing:** inspect the Inno Setup build step and ensure the expected output filename was produced.
