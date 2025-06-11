# Show a popup with OK button
function Show-Popup {
    param (
        [string]$message,
        [string]$title = "Notice"
    )

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($message, $title, 'OK', 'Information') | Out-Null
}

try {
    $found = $false
    $success = $false
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    # Check if Brave is installed
    foreach ($path in $regPaths) {
        $subkeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $subkeys) {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -and $props.DisplayName -like "*Brave*") {
                $found = $true
                break
            }
        }
        if ($found) { break }
    }

    if (-not $found) {
        # Show message if Brave not found and exit
        Show-Popup -message "Cannot find Brave Browser" -title "Notice"
        exit
    }

    # Uninstall Brave
    foreach ($path in $regPaths) {
        $subkeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $subkeys) {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -and $props.DisplayName -like "*Brave*") {
                $uninstallString = $props.UninstallString
                if (-not $uninstallString) { continue }

                if ($uninstallString -match "msiexec.exe") {
                    if ($uninstallString -match "/x\s*({[^}]+})") {
                        $productCode = $matches[1]
                        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x",$productCode,"/quiet","/norestart" -Wait
                        $success = $true
                        break
                    }
                } else {
                    if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                        $exePath = $matches[1]
                        $args = $matches[2]
                    } else {
                        $split = $uninstallString.Split(' ', 2)
                        $exePath = $split[0]
                        $args = if ($split.Length -gt 1) { $split[1] } else { "" }
                    }

                    $args += " --uninstall --force-uninstall --system-level"

                    if (Test-Path $exePath) {
                        Start-Process -FilePath $exePath -ArgumentList $args -Wait
                        $success = $true
                        break
                    }
                }
            }
        }
        if ($success) { break }
    }

    if ($success) {
        # Clean up files
        $pathsToDelete = @(
            "$env:ProgramFiles\BraveSoftware",
            "$env:ProgramFiles(x86)\BraveSoftware",
            "$env:LOCALAPPDATA\BraveSoftware",
            "$env:APPDATA\BraveSoftware"
        )

        foreach ($path in $pathsToDelete) {
            if (Test-Path $path) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Show success message and exit immediately after user clicks OK
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("Successfully deleted Brave Browser", "Uninstall Complete", 'OK', 'Information') | Out-Null
        exit
    } else {
        Show-Popup "Uninstallation process did not complete successfully." "Error"
    }
}
catch {
    Show-Popup "An error occurred: $_" "Script Error"
}
