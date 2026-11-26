# Changelog

All notable user-facing changes to Lunora are recorded here.

## [1.0.7] - 2026-11-26

### Added
- Added configurable dashboard widget placement with independent column and ordering controls.
- Added customizable quick actions with selectable shortcuts, ordering, and visible item count.
- Added configurable smart reminder lead times for tasks and study sessions.

### Improved
- Improved dashboard layout flexibility while preserving saved placement on narrow screens.
- Rescheduled pending task and study reminders when the lead-time preference changes.
- Preserved existing notification delivery behavior and defaulted existing installations to a 15-minute reminder lead time.

## [1.0.4] - 2026-11-15

### Improved
- Completed English localization across the application, including core screens, dialogs, forms, filters, search, empty states, and feedback messages.
- Improved consistency of bilingual labels and dynamic text throughout the interface.

### Fixed
- Fixed remaining Russian text appearing when English is selected.
- Corrected localized labels and plural forms in planner, calendar, books, recipes, wishlist, finance, backup management, and web search screens.

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
