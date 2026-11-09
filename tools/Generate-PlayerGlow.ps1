# Deterministic white alpha masks; the addon supplies the buff color at runtime.
$ErrorActionPreference = 'Stop'
$assetDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'AggeHealBot\Media'
New-Item -ItemType Directory -Path $assetDirectory -Force | Out-Null

function Write-GlowTexture($Name, $Width, $Height, $Distance) {
    $pixels = New-Object byte[] (18 + $Width * $Height * 4)
    $pixels[2] = 2 # Uncompressed true-color TGA, BGRA, top-left origin.
    $pixels[12] = $Width -band 255
    $pixels[13] = $Width -shr 8
    $pixels[14] = $Height -band 255
    $pixels[15] = $Height -shr 8
    $pixels[16] = 32
    $pixels[17] = 40
    for ($y = 0; $y -lt $Height; $y++) {
        for ($x = 0; $x -lt $Width; $x++) {
            $d = & $Distance (($x + 0.5) / $Width) (($y + 0.5) / $Height)
            # A translucent core and broad Gaussian falloffs give a blurred
            # halo instead of an opaque stroke. Never saturate the center.
            $alpha = 0.30 * [Math]::Exp(-0.5 * ($d / 0.9) * ($d / 0.9)) + 0.35 * [Math]::Exp(-0.5 * ($d / 2.4) * ($d / 2.4)) + 0.25 * [Math]::Exp(-0.5 * ($d / 4.2) * ($d / 4.2))
            $offset = 18 + ($y * $Width + $x) * 4
            $pixels[$offset] = 255
            $pixels[$offset + 1] = 255
            $pixels[$offset + 2] = 255
            $pixels[$offset + 3] = [byte][Math]::Round(255 * $alpha)
        }
    }
    [IO.File]::WriteAllBytes((Join-Path $assetDirectory "$Name.tga"), $pixels)
}

Write-GlowTexture 'PlayerGlowArc' 256 256 {
    param($u, $v)
    # Padding surrounds the whole silhouette so the broad fade is not clipped.
    $x = $u * 128 - 16
    $y = $v * 144 - 8
    # Keep the established top/left fit; lift the lower portrait contour.
    $portraitY = ($y - 54.5) * 50 / 48.5
    $circle = [Math]::Sqrt(($x - 56) * ($x - 56) + $portraitY * $portraitY) - 50
    $level = [Math]::Sqrt(($x - 26) * ($x - 26) + ($y - 90.5) * ($y - 90.5)) - 23
    # Smooth unions keep a consistent exterior stroke without internal rings
    # where the level badge overlaps the portrait or the portrait meets bars.
    $panel = [Math]::Max(56 - $x, [Math]::Max(22 - $y, $y - 96))
    $join = [Math]::Max(2 - [Math]::Abs($circle - $level), 0)
    $portrait = [Math]::Min($circle, $level) - $join * $join / 8
    $join = [Math]::Max(2 - [Math]::Abs($portrait - $panel), 0)
    [Math]::Abs([Math]::Min($portrait, $panel) - $join * $join / 8)
}
Write-GlowTexture 'PlayerGlowHorizontal' 8 256 {
    param($u, $v)
    $y = $v * 128 - 8
    [Math]::Min([Math]::Abs($y - 22), [Math]::Abs($y - 96))
}
Write-GlowTexture 'PlayerGlowVertical' 64 256 {
    param($u, $v)
    # Four-unit rounded corners on the panel's right end, at x=8.
    $qx = ($u * 32 - 8) - 4
    $qy = [Math]::Abs(($v * 128 - 8) - 59) - 33
    $outsideX = [Math]::Max($qx, 0)
    $outsideY = [Math]::Max($qy, 0)
    [Math]::Abs([Math]::Sqrt($outsideX * $outsideX + $outsideY * $outsideY) + [Math]::Min([Math]::Max($qx, $qy), 0) - 4)
}
