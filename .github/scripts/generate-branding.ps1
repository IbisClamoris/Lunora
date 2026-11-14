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
  $g.FillEllipse($moonBrush, [single](55*$scale),[single](42*$scale),[single](150*$scale),[single](170*$scale))
  $cut = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,26,29,54))
  $g.FillEllipse($cut,[single](99*$scale),[single](25*$scale),[single](142*$scale),[single](165*$scale))
  $star = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,239,190))
  $points = @()
  for($i=0;$i -lt 10;$i++){ $a=(-90+$i*36)*[Math]::PI/180; $r=if($i%2 -eq 0){20}else{8}; $points += [System.Drawing.PointF]::new([single](185*$scale+$r*$scale*[Math]::Cos($a)),[single](64*$scale+$r*$scale*[Math]::Sin($a))) }
  $g.FillPolygon($star,$points)
  $g.Dispose(); $bg.Dispose(); $path.Dispose(); $moonBrush.Dispose(); $cut.Dispose(); $star.Dispose()
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
$large.Dispose()
$small = Draw-LunoraIcon 64
$small.Save((Join-Path $brandingDir 'tray_icon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose()
