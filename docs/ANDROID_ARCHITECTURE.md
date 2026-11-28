# Lunora Android and synchronization architecture

## Goals

- Keep the existing Windows release stable while Android support is developed on a feature branch.
- Reuse the existing Flutter feature modules, repositories, localization, theme system, and database migrations where practical.
- Support both cloud synchronization and direct local-network synchronization.
- Keep the app fully usable offline. The local database remains the source of truth for the device.
- Preserve user data during platform changes, upgrades, synchronization, and restore operations.

## Current repository baseline

- Lunora is a Flutter application with a shared `lib/` codebase and a Windows runner.
- The database is at schema version 27 and currently uses `sqflite_common_ffi`.
- Application files are stored below the directory provided by `path_provider`.
- The app has six themes, Russian and English localization, notifications, imports/exports, and backup/restore flows.
- There is no Android runner in the current repository baseline.

## Platform foundation

### Database

- Windows continues to use `sqflite_common_ffi`.
- Android and iOS use the native `sqflite` plugin.
- Both backends use the same `Database` API, schema, migration callbacks, and database version.
- Database paths must be built with the `path` package. Platform-specific path separators must not be hard-coded.
- Existing Windows database files and migration history must remain untouched.

### Platform services

Platform-specific behavior must be isolated behind services or platform adapters. Windows-only behavior includes the system tray, window management, executable updater, and Windows installer. Android must use Android-compatible equivalents where applicable and must not invoke Windows update or tray flows.

File access must use app-scoped directories by default. User-selected files and folders must go through platform file-picker APIs and must not assume unrestricted filesystem access.

### User interface

The existing feature pages and domain logic should be reused where they work well on narrow screens. The app shell and navigation should adapt to mobile:
- compact top app bar;
- bottom navigation for primary destinations;
- drawer or secondary navigation for the full section list;
- touch-sized controls and responsive forms;
- no desktop title bar, sidebar, tray, or hover-only interaction on Android.

The six existing themes and both locales remain shared application features.


### Compatibility audit findings

- The custom Windows title bar now exits before registering window listeners on non-Windows targets and is not rendered there.
- Startup tray initialization already has a Windows-only runtime guard; the Windows updater is only entered from the Windows-gated startup flow.
- The recipe search service currently depends directly on `webview_flutter_windows`. Android needs a platform-neutral search implementation or an Android WebView adapter before this feature can be considered supported there.
- The Android runner has not yet been generated. A real Android build is still required before claiming platform compatibility.

## Synchronization model

### Offline-first local data

Each device has its own local SQLite database. All normal reads and writes continue to work without a network connection. Synchronization is a transport layer that exchanges changes; it must not be required to open or use the app.

### Shared synchronization engine

Cloud and local-network synchronization must use the same change format, validation, conflict handling, and attachment transfer logic. Only the transport differs:
- **Cloud transport:** authenticated HTTPS communication with a hosted sync service.
- **Local transport:** direct device-to-device transfer over the same trusted local network, with explicit pairing and user approval.

This avoids maintaining two subtly different synchronization implementations.

### Record identity and change tracking

Before enabling synchronization, every synchronizable record must have a stable globally unique identifier. The sync layer will need metadata such as:
- record identifier and entity type;
- device identifier and change identifier;
- creation and modification timestamps;
- deletion tombstone rather than immediate physical deletion;
- monotonically increasing local revision or equivalent change sequence;
- synchronization state and server revision where applicable.

The exact schema must be designed after auditing all repositories, migrations, attachment relationships, and delete operations. Do not add speculative sync columns to every table before that audit.

### Conflict and deletion safety

- A remote change must never silently overwrite a newer local edit.
- Deletions must be represented as tombstones until all participating sync targets have acknowledged them or the retention policy safely permits compaction.
- Conflicting edits must be detected and surfaced or preserved as recoverable copies. A simple global last-write-wins policy is not sufficient for personal records.
- Sync operations must be idempotent so retries cannot duplicate records or attachments.
- Import, restore, and synchronization must remain distinct operations with explicit user-visible outcomes.

### Attachments

Images, covers, diary media, and other files must be tracked separately from database rows. The sync layer should transfer attachments by content hash, verify integrity, and avoid retransmitting unchanged files. Database records must not become permanently broken if an attachment transfer is interrupted.

### Security and privacy

- Cloud sync requires authenticated, encrypted transport and a clear account/device authorization model.
- Local sync requires explicit pairing, a short-lived pairing secret or equivalent proof, and confirmation on both devices.
- Secrets must be stored using platform-secure storage, not plain preferences or the SQLite database.
- The user must be able to see connected devices and revoke them.
- The app must explain what data is synchronized and provide a way to disable synchronization.

## Implementation sequence

1. Establish Android-compatible database and storage foundations without changing the Windows behavior.
2. Generate the Android project and configure application identity, icons, permissions, and build settings.
3. Audit desktop-only imports and isolate Windows-only services.
4. Build the mobile app shell and responsive navigation.
5. Verify database creation, all migrations through schema version 27, and backup/restore on Android.
6. Audit record IDs, timestamps, deletes, relationships, and attachment references across every repository.
7. Design and test the sync change log, tombstones, conflict recovery, and idempotency.
8. Implement local-network pairing and synchronization using the shared engine.
9. Implement cloud authentication, device management, and synchronization using the same engine.
10. Test Windows-to-Android and Android-to-Android synchronization, offline edits, concurrent edits, deletions, retries, and restore scenarios.

## Non-goals for the initial Android foundation

- Do not remove or replace the Windows implementation.
- Do not change the current released version or create a release tag as part of Android groundwork.
- Do not enable automatic cloud uploads before authentication, security, conflict recovery, and privacy controls are implemented.
- Do not assume a backend provider or cloud database before comparing cost, privacy, operational burden, and portability.
