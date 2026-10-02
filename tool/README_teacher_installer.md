# BayMath Teacher Windows installer

The setup EXE installs the Teacher and Administrator desktop app for the
current Windows user. It includes the Flutter release files and the Visual C++
runtime DLLs needed by the app. It creates Desktop and Start Menu shortcuts
and an entry in Windows Installed apps for uninstalling.

## Build

Install the free [NSIS compiler](https://nsis.sourceforge.io/Download) and
the Flutter Windows build prerequisites, then run from the project root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/build_teacher_installer.ps1
```

The script builds `lib/main_staff.dart`, takes the version from `pubspec.yaml`,
and writes a single file such as
`build/installers/BayMath-Teacher-Setup-0.1.0.exe`. Share that EXE with
teachers; they do not need the Flutter release folder.

To repackage an already-built Windows release without rebuilding Flutter:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/build_teacher_installer.ps1 -SkipFlutterBuild
```

The output under `build/` is ignored by Git. Rebuild the installer after app
changes, and update the version in `pubspec.yaml` when releasing a new version.
