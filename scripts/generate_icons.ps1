# Generates a 1024x1024 PNG icon from the SVG asset and places it at assets/icon.png.
# Requires ImageMagick (magick) to be installed and on PATH.

$svg = "assets/icons/smartmess_icon.svg"
$png = "assets/icon.png"

if (-not (Test-Path $svg)) {
  Write-Error "SVG icon not found at $svg."
  exit 1
}

$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
  Write-Error "ImageMagick (magick) not found. Install it and add to PATH: https://imagemagick.org"
  exit 1
}

Write-Host "Generating $png from $svg (1024x1024)..."
magick "$svg" -background none -resize 1024x1024 "$png"
if ($LASTEXITCODE -eq 0) {
  Write-Host "Created $png"
} else {
  Write-Error "magick failed with exit code $LASTEXITCODE"
}
