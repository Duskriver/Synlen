param(
  [double]$Scale = 0.66
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root 'assets/icons/icon_opaque.png'
$targetPath = Join-Path $root 'assets/icons/icon_opaque_android12.png'
$canvasSize = 1840

$source = [System.Drawing.Image]::FromFile($sourcePath)
try {
  $bitmap = New-Object System.Drawing.Bitmap($canvasSize, $canvasSize)
  try {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([System.Drawing.Color]::Black)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

      $drawSize = [int]([Math]::Round($canvasSize * $Scale))
      $offset = [int]([Math]::Round(($canvasSize - $drawSize) / 2))
      $graphics.DrawImage($source, $offset, $offset, $drawSize, $drawSize)
    } finally {
      $graphics.Dispose()
    }

    $bitmap.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $bitmap.Dispose()
  }
} finally {
  $source.Dispose()
}

Write-Output "Generated $targetPath with scale $Scale"
