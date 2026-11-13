# Changelog

All notable user-facing changes to Lunora are recorded here.

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
