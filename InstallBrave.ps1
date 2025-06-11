$url = "https://laptop-updates.brave.com/latest/winx64"

# Get final redirected URL to extract filename
$req = [System.Net.WebRequest]::Create($url)
$req.AllowAutoRedirect = $true
$finalUrl = $req.GetResponse().ResponseUri.AbsoluteUri
$filename = [IO.Path]::GetFileName($finalUrl)
$path = Join-Path $env:USERPROFILE\Downloads $filename

$request = [Net.HttpWebRequest]::Create($finalUrl)
$response = $request.GetResponse()
$total = $response.ContentLength
$stream = $response.GetResponseStream()
$file = [IO.File]::OpenWrite($path)

$buffer = New-Object byte[] 524288
$totalRead = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function fmtSize($b) {
    if ($b -ge 1GB) { "{0:N2} GB" -f ($b / 1GB) }
    elseif ($b -ge 1MB) { "{0:N2} MB" -f ($b / 1MB) }
    elseif ($b -ge 1KB) { "{0:N2} KB" -f ($b / 1KB) }
    else { "$b Bytes" }
}

function fmtTime($seconds) {
    if ($seconds -le 0) { return "Calculating..." }
    $ts = [TimeSpan]::FromSeconds($seconds)
    if ($ts.TotalHours -ge 1) {
        "{0:D2}h:{1:D2}m:{2:D2}s" -f $ts.Hours, $ts.Minutes, $ts.Seconds
    }
    elseif ($ts.TotalMinutes -ge 1) {
        "{0:D2}m:{1:D2}s" -f $ts.Minutes, $ts.Seconds
    }
    else {
        "{0:D2}s" -f $ts.Seconds
    }
}

while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
    $file.Write($buffer, 0, $read)
    $totalRead += $read

    $elapsed = $stopwatch.Elapsed.TotalSeconds
    $speed = if ($elapsed -gt 0) { $totalRead / 1KB / $elapsed } else { 0 }

    $remainingBytes = $total - $totalRead
    $timeLeftSeconds = if ($speed -gt 0) { ($remainingBytes / 1KB) / $speed } else { -1 }

    $speedStr = if ($speed -gt 1024) { "{0:N2} MB/s" -f ($speed / 1024) } else { "{0:N2} KB/s" -f $speed }
    $timeStr = fmtTime $timeLeftSeconds
    $percent = if ($total -gt 0) { [math]::Round(($totalRead / $total) * 100, 2) } else { 0 }
    $status = "$(fmtSize $totalRead) of $(fmtSize $total) downloaded at $speedStr, ETA: $timeStr"

    Write-Progress -Activity "Downloading $filename" -Status $status -PercentComplete $percent
}

$file.Close()
$stream.Close()
$response.Close()
$stopwatch.Stop()

Write-Host "`nDownload complete: $path"

# Run installer and wait for completion
$process = Start-Process -FilePath $path -Verb RunAs -PassThru
$process.WaitForExit()

# Delete the installer file after installation finishes
Remove-Item $path -Force

# Set extension install policy
$regPath = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "1" -Value "fdpohaocaechififmbbbbbknoalclacl;https://clients2.google.com/service/update2/crx"

Write-Output "Stylus extension installation policy set. Restarting Brave..."

# Restart Brave to apply extension policy
Get-Process brave -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process "brave.exe"
