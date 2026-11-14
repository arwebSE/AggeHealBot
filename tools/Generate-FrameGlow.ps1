# Matching rounded corners and straight edges for the stock rectangular frames.
$ErrorActionPreference = 'Stop'
$assetDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'AggeHealBot\Media'
function Write-Mask($name, $width, $height, $corner) {
    $pixels = [byte[]]::new(18 + $width * $height * 4)
    $pixels[2] = 2; $pixels[12] = $width; $pixels[14] = $height
    $pixels[16] = 32; $pixels[17] = 40
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $vertical = ($y + 0.5) / $height * 16 - 8
            if ($corner) {
                $horizontal = ($x + 0.5) / $width * 16 - 8
                $qx = 3 - $horizontal; $qy = 3 - $vertical
                $outsideX = [Math]::Max($qx, 0); $outsideY = [Math]::Max($qy, 0)
                $distance = [Math]::Abs([Math]::Sqrt($outsideX * $outsideX + $outsideY * $outsideY) + [Math]::Min([Math]::Max($qx, $qy), 0) - 3)
            } else { $distance = [Math]::Abs($vertical) }
            $alpha = 0.40 * [Math]::Exp(-0.5 * [Math]::Pow($distance / 0.8, 2)) + 0.32 * [Math]::Exp(-0.5 * [Math]::Pow($distance / 2, 2)) + 0.18 * [Math]::Exp(-0.5 * [Math]::Pow($distance / 3, 2))
            $offset = 18 + ($y * $width + $x) * 4
            $pixels[$offset] = 255; $pixels[$offset + 1] = 255; $pixels[$offset + 2] = 255
            $pixels[$offset + 3] = [byte][Math]::Round(255 * $alpha)
        }
    }
    [IO.File]::WriteAllBytes((Join-Path $assetDirectory "$name.tga"), $pixels)
}
Write-Mask 'FrameGlowCorner' 64 64 $true
Write-Mask 'FrameGlowEdge' 8 64 $false
