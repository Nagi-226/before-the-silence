# Generate procedural BMP textures for missing wall/floor/ceiling files
$imagesDir = "$PSScriptRoot\..\assets\images"
New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null

function New-BMP($filepath, $width, $height, $pixelFunc) {
    $rowSize = ($width * 3 + 3) -band -bnot 3
    $imageSize = $rowSize * $height
    $fileSize = 54 + $imageSize
    $bytes = New-Object byte[] $fileSize

    # BMP header
    $bytes[0] = 0x42; $bytes[1] = 0x4D           # 'BM'
    [BitConverter]::GetBytes($fileSize).CopyTo($bytes, 2)
    [BitConverter]::GetBytes(54).CopyTo($bytes, 10) # data offset
    [BitConverter]::GetBytes(40).CopyTo($bytes, 14) # header size
    [BitConverter]::GetBytes($width).CopyTo($bytes, 18)
    [BitConverter]::GetBytes($height).CopyTo($bytes, 22)
    $bytes[26] = 1; $bytes[27] = 0                 # planes
    $bytes[28] = 24; $bytes[29] = 0                # bpp

    # Pixel data (bottom-up)
    for ($y = $height - 1; $y -ge 0; $y--) {
        $rowOffset = 54 + ($height - 1 - $y) * $rowSize
        for ($x = 0; $x -lt $width; $x++) {
            $rgb = & $pixelFunc $x $y
            $bytes[$rowOffset + $x * 3 + 0] = $rgb[2]  # B
            $bytes[$rowOffset + $x * 3 + 1] = $rgb[1]  # G
            $bytes[$rowOffset + $x * 3 + 2] = $rgb[0]  # R
        }
        # padding bytes already zero
    }

    [IO.File]::WriteAllBytes($filepath, $bytes)
    Write-Host "  $filepath ($width`x$height)"
}

# Texture generators
function Brick($x,$y) {
    $row = [int]($y / 8); $offset = ($row -band 1) * 4
    $bx = [int]((($x + $offset) % 16) / 4)
    $by = [int](($y % 16) / 4)
    if ($bx -ge 1 -and $bx -le 2 -and $by -in @(0,3)) { return @(75,35,35) }
    if ($bx -in @(0,3) -or $by -in @(0,3))            { return @(90,50,40) }
    return @(110,65,45)
}
function Metal($x,$y) {
    $v = 120 + ((($x -shr 3) + ($y -shr 3)) -band 1) * 15
    if ($x % 16 -eq 0 -or $y % 16 -eq 0) { $v -= 20 }
    if ($x % 4 -eq 0 -or $y % 4 -eq 0)   { $v += 5 }
    return @($v, $v, [Math]::Min($v+10, 255))
}
function Stone($x,$y) {
    $v = 80
    $a = ($x * 7 + $y * 13) % 23
    $b = ($x * 3 + $y * 17) % 19
    if ($a -lt 3)  { $v = 70 }
    if ($b -lt 2)  { $v = 90 }
    if ($x % 16 -lt 2 -or $y % 16 -lt 2) { $v = 65 }
    return @($v, $v, $v)
}
function Grate($x,$y) {
    if (($x % 12 -lt 2) -or ($y % 12 -lt 2)) { return @(140,150,160) }
    return @(20,25,35)
}
function Floor($x,$y) {
    $v = 70
    if ((($x -shr 4) + ($y -shr 4)) -band 1) { $v = 55 }
    if ($x % 16 -eq 0 -or $y % 16 -eq 0)   { $v = 45 }
    return @($v, [Math]::Max($v-5,0), [Math]::Max($v-15,0))
}
function Ceiling($x,$y) {
    $v = 50 + ((($x -shr 3) + ($y -shr 3)) -band 1) * 8
    return @([Math]::Max($v-5,0), $v, [Math]::Min($v+10,255))
}
function Cloud($x,$y) {
    $r=0; $g=0; $b=0
    foreach($p in @(@(0,3,80),@(30,8,60),@(60,5,70),@(120,12,50),@(160,7,65))) {
        $dx=$x-$p[0]; $dy=$y-$p[1]; $w=$p[2]
        $d2=$dx*$dx+$dy*$dy*4
        if ($d2 -lt $w*$w) {
            $a=[Math]::Min($d2/($w*$w)*0.6, 0.6)
            $r=[Math]::Min($r+200*$a,255)
            $g=[Math]::Min($g+220*$a,255)
            $b=[Math]::Min($b+255*$a,255)
        }
    }
    return @($r,$g,$b)
}
function Weapon($x,$y) {
    if ($y -lt 5)                { return @(40,35,30) }
    if ($x -lt 4 -or $x -ge 28)  { return @(60,55,50) }
    if ($x -ge 10 -and $x -le 20 -and $y -ge 20 -and $y -le 40) { return @(50,40,30) }
    return @(45,40,35)
}

Write-Host "Generating procedural textures..."
New-BMP "$imagesDir\Wall Brick.bmp" 64 64 ${function:Brick}
New-BMP "$imagesDir\Wall Metal.bmp" 64 64 ${function:Metal}
New-BMP "$imagesDir\Wall Stone.bmp" 64 64 ${function:Stone}
New-BMP "$imagesDir\Wall Grate.bmp" 64 64 ${function:Grate}
New-BMP "$imagesDir\Floor Tile.bmp" 64 64 ${function:Floor}
New-BMP "$imagesDir\Ceiling.bmp" 64 64 ${function:Ceiling}
New-BMP "$imagesDir\Cloud.bmp" 200 32 ${function:Cloud}
New-BMP "$imagesDir\Weapon.bmp" 32 60 ${function:Weapon}
Write-Host "Done!"
