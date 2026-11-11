# Small deterministic control overlays; the mouse itself uses Blizzard atlases.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'AggeHealBot\Media'
function RoundedPath($height) {
    $p=[Drawing.Drawing2D.GraphicsPath]::new()
    $p.AddArc(5,4,22,20,180,180)
    $p.AddArc(5,($height-24),22,20,0,180)
    $p.CloseFigure()
    return ,$p
}
foreach($item in @(@('MouseSideButton.tga',64,$false),@('MouseSideGlow.tga',64,$true))) {
    $height=[int]$item[1]
    $bitmap=[Drawing.Bitmap]::new(32,$height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=[Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $path=RoundedPath $height
    try {
        if($item[2]) {
            $fill=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(180,255,255,255))
            $g.FillPath($fill,$path); $fill.Dispose()
            foreach($stroke in @(@(18,8),@(50,5),@(240,1.5))) {
                $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb($stroke[0],255,255,255),[single]$stroke[1])
                $g.DrawPath($pen,$path); $pen.Dispose()
            }
        } else {
            $fill=[Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Point]::new(5,0),[Drawing.Point]::new(27,$height),[Drawing.Color]::FromArgb(255,110,116,124),[Drawing.Color]::FromArgb(255,30,34,42))
            $g.FillPath($fill,$path); $fill.Dispose()
            $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(255,18,20,24),2)
            $g.DrawPath($pen,$path); $pen.Dispose()
        }
        $data=$bitmap.LockBits([Drawing.Rectangle]::new(0,0,32,$height),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $pixels=[byte[]]::new(32*$height*4)
            if($data.Stride -ne 128) { throw 'Unexpected stride' }
            [Runtime.InteropServices.Marshal]::Copy($data.Scan0,$pixels,0,$pixels.Length)
        } finally { $bitmap.UnlockBits($data) }
        $header=[byte[]]::new(18)
        $header[2]=2; $header[12]=32; $header[14]=$height; $header[16]=32; $header[17]=40
        [IO.File]::WriteAllBytes((Join-Path $assetDirectory $item[0]),[byte[]]($header+$pixels))
    } finally { $g.Dispose(); $path.Dispose(); $bitmap.Dispose() }
}
