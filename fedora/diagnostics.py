import json

DIAGNOSTICS = {
    "system_snapshot": {
        "id": "system_snapshot",
        "name": "System Snapshot",
        "description": "Collects basic system health and inventory data. Returns JSON.",
        "script": """
$ErrorActionPreference = 'Stop'

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"

    $pythonVer = try { python --version 2>&1 } catch { "Not found" }
    $gitVer = try { git --version 2>&1 } catch { "Not found" }
    
    $fgStatus = "Not found"
    try {
        $fgService = Get-Service -Name ForgeGrid -ErrorAction SilentlyContinue
        if ($fgService) {
            $fgStatus = $fgService.Status
        }
    } catch {}

    $result = @{
        hostname = $(hostname)
        currentUser = $cs.PrimaryOwnerName
        uptime = $os.LastBootUpTime
        windowsVersion = $os.Caption
        cpu = $cpu.Name
        totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
        freeDiskGB = [math]::Round($disk.FreeSpace / 1GB)
        python = "$pythonVer"
        git = "$gitVer"
        forgeGridStatus = $fgStatus
    }

    $result | ConvertTo-Json -Depth 5
} catch {
    $errorObj = @{
        error = $_.Exception.Message
    }
    $errorObj | ConvertTo-Json -Depth 5
    exit 1
}
"""
    }
}

def get_diagnostic(diag_id: str) -> dict:
    if diag_id not in DIAGNOSTICS:
        raise ValueError(f"Unknown diagnostic: {diag_id}")
    return DIAGNOSTICS[diag_id]
