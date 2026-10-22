param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$enc1251 = [Text.Encoding]::GetEncoding(1251)
$utf8strict = New-Object Text.UTF8Encoding($false, $true)
$utf8out = New-Object Text.UTF8Encoding($false)

$files = Get-ChildItem -Path $root -Recurse -File -Include *.m, *.h, *.js, *.html
foreach ($f in $files) {
    if ($f.FullName -match '\\artifacts\\') { continue }
    $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $script:converted = 0
    $result = [regex]::Replace($text, '[\u0080-\uFFFF]+', {
        param($m)
        $s = $m.Value
        try {
            $bytes = $enc1251.GetBytes($s)
            $round = $enc1251.GetString($bytes)
            if ($round -ne $s) { return $s }
            $decoded = $utf8strict.GetString($bytes)
            if ($decoded -and $decoded -ne $s -and $decoded.IndexOf([char]0xFFFD) -lt 0) {
                $script:converted++
                return $decoded
            }
        } catch { }
        return $s
    })
    if ($result -ne $text) {
        $rel = $f.FullName.Substring($root.Length + 1)
        $sample = ''
        $line = ($result -split "`n" | Where-Object { $_ -match '[\u0400-\u04FF]' } | Select-Object -First 1)
        if ($line) { $sample = $line.Trim() }
        Write-Output ("{0}: {1} runs changed | {2}" -f $rel, $script:converted, $sample)
        if ($Apply) {
            [IO.File]::WriteAllText($f.FullName, $result, $utf8out)
        }
    }
}
