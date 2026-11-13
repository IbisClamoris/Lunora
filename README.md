# Lunora — Your Personal World

Lunora is a personal desktop workspace for organizing everyday life.

**Version:** 1.0.0  
**Platform in this release:** Windows 64-bit  
**License:** GNU General Public License v3.0 (GPL-3.0)

## Features

- Home dashboard
- Calendar and planner
- Personal diary
- Book collection and reading tracking
- Personal finance records
- Movies and TV shows
- Recipes and shopping lists
- Wishes and learning plan
- Knowledge base
- Multiple interface themes

## Get the application

Download the Windows installer from the [latest GitHub Release](../../releases/latest).

## Build from source

### Requirements

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml` (`^3.13.7`)
- Windows 10/11 64-bit
- Visual Studio with the **Desktop development with C++** workload
- CMake and Windows SDK (normally installed with the Visual Studio workload)

### Steps

1. Install Flutter and configure it for Windows desktop development.
2. Clone this repository.
3. From the repository root, run:

```powershell
flutter doctor -v
flutter pub get
flutter run -d windows
```

To create a release build:

```powershell
flutter build windows --release
```

The generated application will be under `build\windowsdunner\Release`.

## Data and privacy

Lunora stores application data in the user's application-support location, outside the installation directory. Do not commit personal databases, exports, backups, or other user data to this repository.

## Contributing

Bug reports and proposed changes are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request.

## License

This project is distributed under the GNU General Public License, version 3. See [LICENSE](LICENSE). Third-party dependencies and assets may have their own licenses and notices; those terms remain applicable.
