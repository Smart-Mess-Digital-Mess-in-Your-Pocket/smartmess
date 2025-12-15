# Generates platform-specific app icons from the SVG and places them in the appropriate platform folders.
# Requires ImageMagick (magick) on PATH.
# Usage: pwsh ./scripts/generate_all_icons.ps1

$svg = "assets/icons/smartmess_icon.svg"
if (-not (Test-Path $svg)) { Write-Error "SVG not found at $svg"; exit 1 }

$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) { Write-Error "ImageMagick (magick) not found. Install it from https://imagemagick.org"; exit 1 }

function Make-PNG($size, $out) {
  Write-Host "Generating $out ($size x $size)"
  magick "$svg" -background none -resize ${size}x${size} "$out"
}

# Ensure output dir exists
New-Item -ItemType Directory -Force -Path assets/iconset | Out-Null

# Android mipmap sizes
$androidSizes = @{
  'mipmap-mdpi' = 48;
  'mipmap-hdpi' = 72;
  'mipmap-xhdpi' = 96;
  'mipmap-xxhdpi' = 144;
  'mipmap-xxxhdpi' = 192;
}
foreach ($folder in $androidSizes.Keys) {
  $size = $androidSizes[$folder]
  $out = "android/app/src/main/res/$folder/ic_launcher.png"
  Make-PNG $size $out
}

# Web icons
Make-PNG 192 "web/icons/Icon-192.png"
Make-PNG 512 "web/icons/Icon-512.png"
Copy-Item "web/icons/Icon-192.png" "web/icons/Icon-maskable-192.png" -Force
Copy-Item "web/icons/Icon-512.png" "web/icons/Icon-maskable-512.png" -Force

# iOS AppIcon entries (explicit pixel sizes)
$iosSizes = @(
  @{ size = 20; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png' },
  @{ size = 40; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png' },
  @{ size = 60; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png' },
  @{ size = 29; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png' },
  @{ size = 58; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png' },
  @{ size = 87; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png' },
  @{ size = 40; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png' },
  @{ size = 80; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png' },
  @{ size = 120; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png' },
  @{ size = 120; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png' },
  @{ size = 180; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png' },
  @{ size = 76; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png' },
  @{ size = 152; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png' },
  @{ size = 167; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png' },
  @{ size = 1024; dest = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png' }
)

# Create iOS icons
foreach ($item in $iosSizes) {
  $size = $item.size
  $dest = $item.dest
  $destDir = Split-Path $dest -Parent
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  Make-PNG $size $dest
}

# macOS AppIcon sizes
$macosSizes = @{
  16 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png';
  32 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png';
  64 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png';
  128 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png';
  256 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png';
  512 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png';
  1024 = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png';
}
foreach ($s in $macosSizes.Keys) { Make-PNG $s $macosSizes[$s] }

# Windows: create .ico from a set of PNGs
$winPngs = @()
$winSizes = @(256,48,32,16)
foreach ($s in $winSizes) {
  $out = "windows/runner/resources/icon_${s}.png"
  Make-PNG $s $out
  $winPngs += $out
}
# Create .ico
$icoOut = "windows/runner/resources/app_icon.ico"
$cmd = "magick " + ($winPngs -join " ") + " $icoOut"
Write-Host "Generating $icoOut"
Invoke-Expression $cmd

Write-Host "All icons generated. You can now run:
  flutter pub get
  flutter pub run flutter_launcher_icons:main
to let the launcher icons package populate platform icons as needed."
