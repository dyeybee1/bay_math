param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $ProjectRoot 'assets\icons\baymath_mascot_source.png'
$masterPath = Join-Path $ProjectRoot 'assets\icons\baymath_mascot_app_icon.png'
$windowsIconPath = Join-Path $ProjectRoot 'windows\runner\resources\app_icon.ico'
$navy = [System.Drawing.Color]::FromArgb(255, 6, 26, 75)

function New-PaddedPng {
  param(
    [System.Drawing.Image]$Source,
    [int]$Size,
    [double]$ArtworkScale,
    [string]$Destination
  )

  $parent = Split-Path -Parent $Destination
  [System.IO.Directory]::CreateDirectory($parent) | Out-Null
  $bitmap = [System.Drawing.Bitmap]::new(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  try {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear($navy)
      $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
      $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

      $artworkSize = [int][Math]::Round($Size * $ArtworkScale)
      $offset = [int][Math]::Floor(($Size - $artworkSize) / 2)
      $destinationRect = [System.Drawing.Rectangle]::new(
        $offset,
        $offset,
        $artworkSize,
        $artworkSize
      )
      $graphics.DrawImage($Source, $destinationRect)
    }
    finally {
      $graphics.Dispose()
    }

    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $bitmap.Dispose()
  }
}

function Get-PaddedIcoDibBytes {
  param(
    [System.Drawing.Image]$Source,
    [int]$Size,
    [double]$ArtworkScale
  )

  $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) (
    'baymath-icon-{0}-{1}.png' -f $Size, [Guid]::NewGuid().ToString('N')
  )
  try {
    New-PaddedPng -Source $Source -Size $Size `
      -ArtworkScale $ArtworkScale -Destination $tempPath
    $bitmap = [System.Drawing.Bitmap]::FromFile($tempPath)
    try {
      $stream = [System.IO.MemoryStream]::new()
      $writer = [System.IO.BinaryWriter]::new($stream)
      try {
        # BITMAPINFOHEADER. ICO stores XOR and AND masks in one image, so the
        # header height is doubled even though the visible bitmap is square.
        $writer.Write([UInt32]40)
        $writer.Write([Int32]$Size)
        $writer.Write([Int32]($Size * 2))
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]0)
        $writer.Write([UInt32]($Size * $Size * 4))
        $writer.Write([Int32]0)
        $writer.Write([Int32]0)
        $writer.Write([UInt32]0)
        $writer.Write([UInt32]0)

        # DIB pixels are bottom-up and stored BGRA.
        for ($y = $Size - 1; $y -ge 0; $y--) {
          for ($x = 0; $x -lt $Size; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            $writer.Write([byte]$pixel.B)
            $writer.Write([byte]$pixel.G)
            $writer.Write([byte]$pixel.R)
            $writer.Write([byte]$pixel.A)
          }
        }

        # The source is opaque; an all-zero AND mask keeps every pixel visible.
        $maskRowBytes = [int]([Math]::Ceiling($Size / 32.0) * 4)
        $writer.Write([byte[]]::new($maskRowBytes * $Size))
        $writer.Flush()
        return $stream.ToArray()
      }
      finally {
        $writer.Dispose()
        $stream.Dispose()
      }
    }
    finally {
      $bitmap.Dispose()
    }
  }
  finally {
    if (Test-Path -LiteralPath $tempPath) {
      Remove-Item -LiteralPath $tempPath -Force
    }
  }
}

function Write-BitmapIco {
  param(
    [System.Drawing.Image]$Source,
    [int[]]$Sizes,
    [double]$ArtworkScale,
    [string]$Destination
  )

  $images = @()
  foreach ($size in $Sizes) {
    $imageBytes = [byte[]](Get-PaddedIcoDibBytes `
      -Source $Source `
      -Size $size `
      -ArtworkScale $ArtworkScale)
    $images += ,$imageBytes
  }
  $stream = [System.IO.File]::Open(
    $Destination,
    [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::Write
  )
  try {
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
      $writer.Write([UInt16]0)
      $writer.Write([UInt16]1)
      $writer.Write([UInt16]$Sizes.Count)

      $offset = 6 + (16 * $Sizes.Count)
      for ($index = 0; $index -lt $Sizes.Count; $index++) {
        $size = $Sizes[$index]
        $writer.Write([byte]($(if ($size -ge 256) { 0 } else { $size })))
        $writer.Write([byte]($(if ($size -ge 256) { 0 } else { $size })))
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$images[$index].Length)
        $writer.Write([UInt32]$offset)
        $offset += $images[$index].Length
      }

      foreach ($imageBytes in $images) {
        $writer.Write([byte[]]$imageBytes)
      }
    }
    finally {
      $writer.Dispose()
    }
  }
  finally {
    $stream.Dispose()
  }
}

$source = [System.Drawing.Image]::FromFile($sourcePath)
try {
  # The approved square source already includes continuous, mask-safe padding.
  New-PaddedPng -Source $source -Size 1024 -ArtworkScale 1.0 `
    -Destination $masterPath

  $legacySizes = @{
    'mdpi' = 48
    'hdpi' = 72
    'xhdpi' = 96
    'xxhdpi' = 144
    'xxxhdpi' = 192
  }
  foreach ($density in $legacySizes.Keys) {
    $resourceDirectory = Join-Path $ProjectRoot "android\app\src\main\res\mipmap-$density"
    New-PaddedPng -Source $source -Size $legacySizes[$density] `
      -ArtworkScale 1.0 `
      -Destination (Join-Path $resourceDirectory 'ic_launcher.png')
    New-PaddedPng -Source $source -Size $legacySizes[$density] `
      -ArtworkScale 1.0 `
      -Destination (Join-Path $resourceDirectory 'ic_launcher_round.png')
  }

  # Adaptive foreground canvases are 108 dp. The source's built-in padding
  # keeps every visible element inside round and squircle launcher masks.
  $adaptiveSizes = @{
    'mdpi' = 108
    'hdpi' = 162
    'xhdpi' = 216
    'xxhdpi' = 324
    'xxxhdpi' = 432
  }
  foreach ($density in $adaptiveSizes.Keys) {
    $resourceDirectory = Join-Path $ProjectRoot "android\app\src\main\res\drawable-$density"
    New-PaddedPng -Source $source -Size $adaptiveSizes[$density] `
      -ArtworkScale 1.0 `
      -Destination (Join-Path $resourceDirectory 'ic_launcher_foreground.png')
  }

  Write-BitmapIco `
    -Source $source `
    -Sizes @(16, 24, 32, 48, 64, 128, 256) `
    -ArtworkScale 1.0 `
    -Destination $windowsIconPath
}
finally {
  $source.Dispose()
}

Write-Output "Generated BayMath app icons from $sourcePath"
