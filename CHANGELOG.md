# Changelog

All notable user-facing changes to Lunora are recorded here.

## [1.0.2] - 2026-11-14

### Added
- Added in-app Windows update checks with explicit confirmation.
- Added SHA-256 verification and a database backup before installing an update.
- Added a branded Lunora Windows installer and generated application/tray branding assets.

### Improved
- Preserved the existing installation directory during updates.
- Added bilingual update settings and an automatic update-check preference.

## [1.0.1] - 2026-11-13

### Fixed
- Fixed a database migration failure when the legacy database was missing the `shopping_lists` parent table.
- Hardened the v25 migration preflight and preserved existing shopping item records during the schema repair.
- Added regression coverage for the missing-parent-table scenario and foreign-key integrity.

### Improved
- Improved compatibility with older database schemas during migration.
- Verified the Windows release build and installer in CI.

## [1.0.0]

- Initial stable Windows release.
