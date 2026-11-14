$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '../..')
$outDir = Join-Path $root 'assets/branding/theme_icons'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$themes = @{
 botanical = @{ light = @('#F3F5EF','#66866C','#26352D'); dark = @('#1C241F','#A6C39F','#F0F3EC') }
 lavender = @{ light = @('#F4F1F8','#8970A8','#342B40'); dark = @('#211D29','#C1A6E0','#F3EDF8') }
 rose_garden = @{ light = @('#F8F1F0','#AD737D','#3F2D32'); dark = @('#2A2024','#D29AA5','#F7ECEE') }
 vintage_library = @{ light = @('#F2EBDD','#947447','#3D3528'); dark = @('#29251E','#D0B17A','#F5EBD8') }
 midnight = @{ light = @('#F0EDF5','#8665A5','#292333'); dark = @('#1D1925','#C3A0E5','#F5EFF9') }
 moonlight = @{ light = @('#EEF3F7','#6489A4','#273642'); dark = @('#1C252D','#A2C6DE','#F0F5F8') }
}
function To-Color([string]$hex) {
 $c=[System.Drawing.ColorTranslator]::FromHtml($hex)
 return [System.Drawing.Color]::FromArgb(255,$c.R,$c.G,$c.B)
}
function Draw-ThemeIcon([string]$theme,[string]$mode,[int]$size) {
 $palette=$themes[$theme][$mode]; $bg=To-Color $palette[0]; $accent=To-Color $palette[1]; $ink=To-Color $palette[2]; $gold=To-Color '#D7B77A'
 $bmp=New-Object System.Drawing.Bitmap($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $g.Clear([System.Drawing.Color]::Transparent)
 $s=$size/256.0; $path=New-Object System.Drawing.Drawing2D.GraphicsPath; $r=58*$s; $d=2*$r
 $path.AddArc(2,2,$d,$d,180,90); $path.AddArc($size-2-$d,2,$d,$d,270,90); $path.AddArc($size-2-$d,$size-2-$d,$d,$d,0,90); $path.AddArc(2,$size-2-$d,$d,$d,90,90); $path.CloseFigure()
 $brush=New-Object System.Drawing.SolidBrush($bg); $g.FillPath($brush,$path)
 $pen=New-Object System.Drawing.Pen($gold,[single](4*$s)); $g.DrawPath($pen,$path)
 $main=New-Object System.Drawing.SolidBrush($accent); $detail=New-Object System.Drawing.Pen($ink,[single](5*$s)); $detail.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $detail.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
 switch ($theme) {
  'botanical' {
   $g.DrawLine($detail,[single](78*$s),[single](190*$s),[single](178*$s),[single](67*$s))
   $g.FillEllipse($main,[single](70*$s),[single](90*$s),[single](72*$s),[single](42*$s)); $g.FillEllipse($main,[single](117*$s),[single](62*$s),[single](78*$s),[single](43*$s)); $g.FillEllipse($main,[single](126*$s),[single](128*$s),[single](76*$s),[single](42*$s))
   $g.DrawLine($detail,[single](105*$s),[single](111*$s),[single](126*$s),[single](126*$s)); $g.DrawLine($detail,[single](151*$s),[single](91*$s),[single](164*$s),[single](76*$s)); $g.DrawLine($detail,[single](151*$s),[single](150*$s),[single](173*$s),[single](164*$s))
  }
  'lavender' {
   foreach($x in @(88,128,168)){ $g.DrawLine($detail,[single]($x*$s),[single](193*$s),[single](($x+4)*$s),[single](75*$s)); for($i=0;$i -lt 5;$i++){ $yy=(83+$i*19)*$s; $g.FillEllipse($main,[single](($x-21)*$s),[single]$yy,[single](27*$s),[single](12*$s)); $g.FillEllipse($main,[single](($x+3)*$s),[single]($yy-7*$s),[single](27*$s),[single](12*$s)) } }
   $g.DrawLine($detail,[single](72*$s),[single](194*$s),[single](185*$s),[single](194*$s))
  }
  'rose_garden' {
   for($i=0;$i -lt 8;$i++){ $a=(-90+$i*45)*[Math]::PI/180; $x=128+43*[Math]::Cos($a); $y=119+43*[Math]::Sin($a); $g.FillEllipse($main,[single](($x-24)*$s),[single](($y-30)*$s),[single](48*$s),[single](60*$s)) }
   $center=New-Object System.Drawing.SolidBrush($gold); $g.FillEllipse($center,[single](109*$s),[single](100*$s),[single](38*$s),[single](38*$s)); $g.DrawLine($detail,[single](128*$s),[single](164*$s),[single](128*$s),[single](207*$s)); $g.DrawLine($detail,[single](128*$s),[single](187*$s),[single](95*$s),[single](169*$s)); $g.DrawLine($detail,[single](128*$s),[single](187*$s),[single](161*$s),[single](169*$s)); $center.Dispose()
  }
  'vintage_library' {
   $feather=New-Object System.Drawing.Drawing2D.GraphicsPath; $feather.AddBezier([single](82*$s),[single](190*$s),[single](57*$s),[single](100*$s),[single](139*$s),[single](44*$s),[single](184*$s),[single](60*$s)); $feather.AddBezier([single](184*$s),[single](60*$s),[single](198*$s),[single](111*$s),[single](150*$s),[single](177*$s),[single](82*$s),[single](190*$s)); $feather.CloseFigure(); $g.FillPath($main,$feather); $g.DrawLine($detail,[single](78*$s),[single](195*$s),[single](184*$s),[single](60*$s)); foreach($yy in @(104,127,150,171)){ $g.DrawLine($detail,[single](($yy-20)*$s),[single](($yy+20)*$s),[single](($yy+30)*$s),[single](($yy-12)*$s)) }; $feather.Dispose()
  }
  'midnight' {
   $nodes=@(@(73,157),@(111,91),@(163,73),@(191,139),@(139,190),@(73,157)); for($i=0;$i -lt $nodes.Count-1;$i++){ $g.DrawLine($detail,[single]($nodes[$i][0]*$s),[single]($nodes[$i][1]*$s),[single]($nodes[$i+1][0]*$s),[single]($nodes[$i+1][1]*$s)) }; foreach($node in $nodes){ $g.FillEllipse($main,[single](($node[0]-9)*$s),[single](($node[1]-9)*$s),[single](18*$s),[single](18*$s)) }; $star=New-Object System.Drawing.SolidBrush($gold); $g.FillEllipse($star,[single](101*$s),[single](81*$s),[single](20*$s),[single](20*$s)); $star.Dispose()
  }
  'moonlight' {
   $g.FillEllipse($main,[single](61*$s),[single](48*$s),[single](139*$s),[single](160*$s)); $cut=New-Object System.Drawing.SolidBrush($bg); $g.FillEllipse($cut,[single](111*$s),[single](29*$s),[single](133*$s),[single](151*$s)); $cut.Dispose()
   $pts=@(); for($i=0;$i -lt 10;$i++){ $a=(-90+$i*36)*[Math]::PI/180; $rad=if($i%2 -eq 0){22}else{9}; $pts += [System.Drawing.PointF]::new([single](183*$s+$rad*$s*[Math]::Cos($a)),[single](174*$s+$rad*$s*[Math]::Sin($a))) }; $star=New-Object System.Drawing.SolidBrush($gold); $g.FillPolygon($star,$pts); $star.Dispose()
  }
 }
 $brush.Dispose(); $main.Dispose(); $detail.Dispose(); $pen.Dispose(); $path.Dispose(); $g.Dispose(); return $bmp
}
function Save-Ico($bitmap,[string]$path) {
 $stream=New-Object System.IO.MemoryStream; $bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png); $bytes=$stream.ToArray(); $file=[System.IO.File]::Create($path); $writer=New-Object System.IO.BinaryWriter($file)
 $writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]1); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([UInt16]1); $writer.Write([UInt16]32); $writer.Write([UInt32]$bytes.Length); $writer.Write([UInt32]22); $writer.Write($bytes); $writer.Dispose(); $file.Dispose(); $stream.Dispose()
}
foreach($theme in $themes.Keys){ foreach($mode in @('light','dark')){ $icon=Draw-ThemeIcon $theme $mode 256; Save-Ico $icon (Join-Path $outDir "$($theme)_$($mode).ico"); $icon.Dispose(); $tray=Draw-ThemeIcon $theme $mode 64; $tray.Save((Join-Path $outDir "$($theme)_$($mode).png"),[System.Drawing.Imaging.ImageFormat]::Png); $tray.Dispose() } }
$default=Draw-ThemeIcon 'moonlight' 'light' 256; Save-Ico $default (Join-Path $root 'windows/runner/resources/app_icon.ico'); $default.Dispose()
Write-Host 'Generated 12 theme-aware Lunora icon variants and the default Windows app icon.'
