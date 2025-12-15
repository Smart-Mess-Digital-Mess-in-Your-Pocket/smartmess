# Icons / Launcher Icon

This project uses a vector SVG for the SmartMess icon and a script to generate a 1024x1024 PNG which `flutter_launcher_icons` can use to generate platform-specific launcher icons.

Steps to generate launcher icons locally (Windows / PowerShell):

1. Install ImageMagick (https://imagemagick.org) and ensure `magick` is on PATH.
2. From project root run:

   ```powershell
   pwsh ./scripts/generate_icons.ps1
   ```

   This creates `assets/icon.png` (1024x1024) from `assets/icons/smartmess_icon.svg`.

3. Or run the all-in-one generator which creates required PNGs for each platform and the .ico for Windows, then run the launcher icon generator:

   ```powershell
   pwsh ./scripts/generate_all_icons.ps1
   flutter pub get
   flutter pub run flutter_launcher_icons:main
   ```

4. Verify icons on Android / iOS / web / desktop (build and run on device/emulator).

Notes:
- If you don't have ImageMagick, you can also convert the SVG to a PNG using an online tool or a vector editor (e.g. Inkscape) and save it as `assets/icon.png` (1024x1024).
- If you prefer, I can generate standard PNG sizes and update platform-specific icon files directly; tell me if you want me to do that next.
