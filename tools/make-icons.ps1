# Генерация иконок приложения (без прозрачности, как требует iOS).
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot "..\YumiBrowser\Resources"
$out = [System.IO.Path]::GetFullPath($out)
New-Item -ItemType Directory -Force -Path $out | Out-Null

$items = @(
  @{ Name = "Icon-20.png";      Size = 20 },
  @{ Name = "Icon-20@2x.png";   Size = 40 },
  @{ Name = "Icon-20@3x.png";   Size = 60 },
  @{ Name = "Icon-29.png";      Size = 29 },
  @{ Name = "Icon-29@2x.png";   Size = 58 },
  @{ Name = "Icon-29@3x.png";   Size = 87 },
  @{ Name = "Icon-40.png";      Size = 40 },
  @{ Name = "Icon-40@2x.png";   Size = 80 },
  @{ Name = "Icon-40@3x.png";   Size = 120 },
  @{ Name = "Icon-60@2x.png";   Size = 120 },
  @{ Name = "Icon-60@3x.png";   Size = 180 },
  @{ Name = "Icon-76.png";      Size = 76 },
  @{ Name = "Icon-76@2x.png";   Size = 152 },
  @{ Name = "Icon-83.5@2x.png"; Size = 167 },
  @{ Name = "Icon-1024.png";    Size = 1024 }
)

foreach ($item in $items) {
  $s = $item.Size
  $bmp = New-Object System.Drawing.Bitmap($s, $s)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $rect = New-Object System.Drawing.Rectangle(0, 0, $s, $s)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      $rect,
      [System.Drawing.Color]::FromArgb(255, 47, 111, 237),
      [System.Drawing.Color]::FromArgb(255, 122, 59, 255),
      45.0)
  $g.FillRectangle($brush, $rect)

  # полупрозрачный круг для глубины
  $halo = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 255, 255, 255))
  $g.FillEllipse($halo, [int](-$s * 0.25), [int]($s * 0.45), [int]($s * 1.3), [int]($s * 1.3))

  $fontSize = [float]($s * 0.52)
  $font = New-Object System.Drawing.Font("Segoe UI Semibold", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center

  $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 0, 0, 0))
  $shift = [int][Math]::Max(1, $s * 0.02)
  $r = New-Object System.Drawing.RectangleF(0, $shift, $s, $s)
  $g.DrawString("Y", $font, $shadow, $r, $fmt)

  $white = [System.Drawing.Brushes]::White
  $r2 = New-Object System.Drawing.RectangleF(0, 0, $s, $s)
  $g.DrawString("Y", $font, $white, $r2, $fmt)

  $path = Join-Path $out $item.Name
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

  $font.Dispose(); $brush.Dispose(); $halo.Dispose(); $shadow.Dispose(); $g.Dispose(); $bmp.Dispose()
  Write-Host "icon: $($item.Name) $s"
}
