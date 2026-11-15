$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '../..')
$resourceDir = Join-Path $root 'windows/runner/resources'
$brandingDir = Join-Path $root 'assets/branding'
New-Item -ItemType Directory -Force -Path $resourceDir,$brandingDir | Out-Null

function Draw-LunoraIcon([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  $rect = New-Object System.Drawing.Rectangle(0,0,$size,$size)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,[System.Drawing.Color]::FromArgb(255,41,32,68),[System.Drawing.Color]::FromArgb(255,17,23,46),45)
  $radius = [single]($size * .23)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $radius*2
  $path.AddArc(0,0,$d,$d,180,90); $path.AddArc($size-$d,0,$d,$d,270,90)
  $path.AddArc($size-$d,$size-$d,$d,$d,0,90); $path.AddArc(0,$size-$d,$d,$d,90,90); $path.CloseFigure()
  $g.FillPath($bg,$path)
  $scale = $size/256.0
  $moonBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,244,224,190))
  $g.FillEllipse($moonBrush,[single](55*$scale),[single](42*$scale),[single](150*$scale),[single](170*$scale))
  $cut = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,26,29,54))
  $g.FillEllipse($cut,[single](99*$scale),[single](25*$scale),[single](142*$scale),[single](165*$scale))
  $star = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,239,190))
  $points = @()
  for($i=0;$i -lt 10;$i++){ $a=(-90+$i*36)*[Math]::PI/180; $r=if($i%2 -eq 0){20}else{8}; $points += [System.Drawing.PointF]::new([single](185*$scale+$r*$scale*[Math]::Cos($a)),[single](64*$scale+$r*$scale*[Math]::Sin($a))) }
  $g.FillPolygon($star,$points)
  $g.Dispose(); $bg.Dispose(); $path.Dispose(); $moonBrush.Dispose(); $cut.Dispose(); $star.Dispose()
  return $bmp
}

function Draw-LunoraWizardArt([int]$width,[int]$height) {
  $bmp = New-Object System.Drawing.Bitmap($width,$height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $rect = New-Object System.Drawing.Rectangle(0,0,$width,$height)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,[System.Drawing.Color]::FromArgb(255,48,34,79),[System.Drawing.Color]::FromArgb(255,13,20,46),35)
  $g.FillRectangle($bg,$rect)

  # Subtle atmospheric glow and fine orbital arcs.
  $glow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24,210,184,151))
  $g.FillEllipse($glow,-42,36,248,248)
  $glow.Dispose()
  $orbitPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(55,230,211,185),1)
  $g.DrawEllipse($orbitPen,-34,42,228,228)
  $g.DrawEllipse($orbitPen,-18,58,196,196)
  $orbitPen.Dispose()

  $rand = New-Object System.Random(17)
  for($i=0;$i -lt 42;$i++){
    $x=$rand.Next(7,$width-7); $y=$rand.Next(7,$height-7); $r=if($i%8 -eq 0){2.1}else{1.0}
    $alpha=if($i%3 -eq 0){190}else{90}
    $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha,248,229,197))
    $g.FillEllipse($b,[single]($x-$r),[single]($y-$r),[single]($r*2),[single]($r*2)); $b.Dispose()
  }

  # Brand mark.
  $cx=$width/2.0; $cy=91.0; $s=91.0
  $moon=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,246,226,193))
  $g.FillEllipse($moon,[single]($cx-$s*.42),[single]($cy-$s*.48),[single]($s*.84),[single]($s*.96))
  $cut=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,31,27,60))
  $g.FillEllipse($cut,[single]($cx-$s*.03),[single]($cy-$s*.60),[single]($s*.78),[single]($s*.90))
  $star=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,239,204))
  $points=@()
  for($i=0;$i -lt 10;$i++){ $a=(-90+$i*36)*[Math]::PI/180; $r=if($i%2 -eq 0){10}else{4}; $points += [System.Drawing.PointF]::new([single]($cx+34+$r*[Math]::Cos($a)),[single]($cy-23+$r*[Math]::Sin($a))) }
  $g.FillPolygon($star,$points)

  $titleFont=New-Object System.Drawing.Font('Segoe UI Semibold',17,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $tagFont=New-Object System.Drawing.Font('Segoe UI',8,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $titleBrush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,250,239,220))
  $tagBrush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220,211,199,218))
  $format=New-Object System.Drawing.StringFormat
  $format.Alignment=[System.Drawing.StringAlignment]::Center
  $g.DrawString('LUNORA',$titleFont,$titleBrush,(New-Object System.Drawing.RectangleF(0,166,$width,28)),$format)
  $g.DrawString('YOUR PERSONAL WORLD',$tagFont,$tagBrush,(New-Object System.Drawing.RectangleF(0,197,$width,18)),$format)
  $linePen=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(125,222,195,160),1)
  $g.DrawLine($linePen,49,229,115,229)
  $g.DrawString('A little universe, just for you',$tagFont,$tagBrush,(New-Object System.Drawing.RectangleF(6,239,$width-12,30)),$format)

  $moon.Dispose(); $cut.Dispose(); $star.Dispose(); $titleFont.Dispose(); $tagFont.Dispose()
  $titleBrush.Dispose(); $tagBrush.Dispose(); $format.Dispose(); $linePen.Dispose(); $bg.Dispose(); $g.Dispose()
  return $bmp
}

$large = Draw-LunoraIcon 256
$pngStream = New-Object System.IO.MemoryStream
$large.Save($pngStream,[System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $pngStream.ToArray()
$iconStream = [System.IO.File]::Create((Join-Path $resourceDir 'app_icon.ico'))
$writer = New-Object System.IO.BinaryWriter($iconStream)
$writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]1)
$writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
$writer.Write([UInt16]1); $writer.Write([UInt16]32)
$writer.Write([UInt32]$pngBytes.Length); $writer.Write([UInt32]22)
$writer.Write($pngBytes)
$writer.Dispose(); $iconStream.Dispose(); $pngStream.Dispose()
$smallWizard = Draw-LunoraIcon 55
$smallWizard.Save((Join-Path $brandingDir 'wizard_small.bmp'),[System.Drawing.Imaging.ImageFormat]::Bmp)
$smallWizard.Dispose()
$large.Dispose()

$wizard = Draw-LunoraWizardArt 164 314
$wizard.Save((Join-Path $brandingDir 'wizard_image.bmp'),[System.Drawing.Imaging.ImageFormat]::Bmp)
$wizard.Dispose()
$small = Draw-LunoraIcon 64
$small.Save((Join-Path $brandingDir 'tray_icon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose()
