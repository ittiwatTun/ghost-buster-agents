<#
The last measured wall time of each test suite, so a wait is budgeted from what the suite took
rather than from a fixed ceiling. Stored in MCP/test-durations.json, keyed by a caller-chosen name.
#>

$script:DurationsFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-durations.json'

function Get-TestDuration([string]$Key) {
    if (-not (Test-Path $script:DurationsFile)) {
        return $null
    }
    $all = Get-Content $script:DurationsFile -Raw | ConvertFrom-Json
    $entry = $all.PSObject.Properties[$Key]
    if ($null -eq $entry) {
        return $null
    }
    return [double]$entry.Value.seconds
}

function Set-TestDuration([string]$Key, [double]$Seconds) {
    $all = [ordered]@{}
    if (Test-Path $script:DurationsFile) {
        $existing = Get-Content $script:DurationsFile -Raw | ConvertFrom-Json
        foreach ($property in $existing.PSObject.Properties) {
            $all[$property.Name] = $property.Value
        }
    }
    $all[$Key] = [ordered]@{ seconds = [math]::Round($Seconds, 1); at = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    $sorted = [ordered]@{}
    foreach ($name in ($all.Keys | Sort-Object)) {
        $sorted[$name] = $all[$name]
    }
    $sorted | ConvertTo-Json -Depth 3 | Set-Content -Path $script:DurationsFile -Encoding ASCII
}

# Twice the last run plus a minute; a suite never measured gets the caller's fallback.
function Get-TestBudget([string]$Key, [int]$FallbackSeconds) {
    $last = Get-TestDuration $Key
    if ($null -eq $last) {
        return $FallbackSeconds
    }
    return [int][math]::Max(120, 2 * $last + 60)
}

Export-ModuleMember -Function Get-TestDuration, Set-TestDuration, Get-TestBudget
