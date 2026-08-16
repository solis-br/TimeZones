Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$ConfigFile = Join-Path $HOME "TimeZones.json"

# IANA -> Windows timezone mapping
$TimeZoneMap = @{
    "Pacific/Honolulu"     = "Hawaiian Standard Time"
    "America/Adak"         = "Aleutian Standard Time"
    "America/Anchorage"    = "Alaskan Standard Time"
    "America/Los_Angeles"  = "Pacific Standard Time"
    "America/Phoenix"     = "US Mountain Standard Time"
    "America/Denver"       = "Mountain Standard Time"
    "America/Chicago"      = "Central Standard Time"
    "America/New_York"     = "Eastern Standard Time"
    "America/Halifax"      = "Atlantic Standard Time"
    "Etc/UTC"              = "UTC"
    "Europe/London"        = "GMT Standard Time"
    "Australia/Brisbane"   = "E. Australia Standard Time"
}

# ------------------------------------------------------------
# Default configuration
# ------------------------------------------------------------

function Get-DefaultConfig {
    return @{
        zones = @(
            @{ label = "Hawaii";     zone = "Pacific/Honolulu" }
            @{ label = "Aleutian";   zone = "America/Adak" }
            @{ label = "Alaska";     zone = "America/Anchorage" }
            @{ label = "Pacific";    zone = "America/Los_Angeles" }
            @{ label = "Arizona";    zone = "America/Phoenix" }
            @{ label = "Mountain";   zone = "America/Denver" }
            @{ label = "Central";    zone = "America/Chicago" }
            @{ label = "Eastern";    zone = "America/New_York" }
            @{ label = "Atlantic";    zone = "America/Halifax" }
            @{ label = "UTC";        zone = "Etc/UTC" }
            @{ label = "London";     zone = "Europe/London" }
            @{ label = "Queensland"; zone = "Australia/Brisbane" }
        )
    }
}

# ------------------------------------------------------------
# Load configuration
# ------------------------------------------------------------

function Get-Config {

    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content $ConfigFile -Raw | ConvertFrom-Json

            return $json
        }
        catch {
            Write-Warning "Unable to read $ConfigFile"
            Write-Warning $_.Exception.Message
        }
    }

    $config = Get-DefaultConfig

    $config | ConvertTo-Json -Depth 10 |
        Set-Content -Path $ConfigFile -Encoding UTF8

    return ($config | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
}

# ------------------------------------------------------------
# Get Windows timezone ID
# ------------------------------------------------------------

function Get-WindowsTimeZoneId {
    param (
        [string]$IanaZone
    )

    if ($TimeZoneMap.ContainsKey($IanaZone)) {
        return $TimeZoneMap[$IanaZone]
    }

    # Allow Windows timezone IDs directly in the JSON
    try {
        [TimeZoneInfo]::FindSystemTimeZoneById($IanaZone) | Out-Null
        return $IanaZone
    }
    catch {
        return $null
    }
}

# ------------------------------------------------------------
# Get current time for a timezone
# ------------------------------------------------------------

function Get-ZoneDateTime {
    param (
        [string]$IanaZone
    )

    $windowsZone = Get-WindowsTimeZoneId $IanaZone

    if (-not $windowsZone) {
        Write-Warning "Unknown timezone: $IanaZone"
        return $null
    }

    try {
        $tz = [TimeZoneInfo]::FindSystemTimeZoneById($windowsZone)

        return [TimeZoneInfo]::ConvertTimeFromUtc(
            [DateTime]::UtcNow,
            $tz
        )
    }
    catch {
        Write-Warning "Unable to convert timezone: $IanaZone"
        return $null
    }
}

# ------------------------------------------------------------
# Determine local timezone
# ------------------------------------------------------------

$LocalWindowsTimeZone = [TimeZoneInfo]::Local.Id

Write-Host "Local Windows timezone: $LocalWindowsTimeZone"

# ------------------------------------------------------------
# Command line arguments
# ------------------------------------------------------------

$Horizontal = $false

foreach ($arg in $args) {

    switch ($arg.ToLower()) {

        "-h" {
            $Horizontal = $true
        }

        "--horizontal" {
            $Horizontal = $true
        }

        "-horizontal" {
            $Horizontal = $true
        }

        default {
            Write-Warning "Unknown argument: $arg"
        }
    }
}

# ------------------------------------------------------------
# Load configuration
# ------------------------------------------------------------

$Config = Get-Config

# ------------------------------------------------------------
# Create WPF Window
# ------------------------------------------------------------

$Window = New-Object System.Windows.Window

$Window.Title = "Time Zones"
$Window.SizeToContent = "WidthAndHeight"
$Window.WindowStartupLocation = "CenterScreen"
$Window.Background = "White"

# ------------------------------------------------------------
# Main layout
# ------------------------------------------------------------

$MainPanel = New-Object System.Windows.Controls.StackPanel

$MainPanel.Margin = New-Object System.Windows.Thickness(10)

if ($Horizontal) {
    $MainPanel.Orientation = "Horizontal"
}
else {
    $MainPanel.Orientation = "Vertical"
}

$Window.Content = $MainPanel

# ------------------------------------------------------------
# Refresh function
# ------------------------------------------------------------

function Update-Clocks {

    $MainPanel.Children.Clear()

    foreach ($entry in $Config.zones) {

        $label = $entry.label
        $ianaZone = $entry.zone

        $dt = Get-ZoneDateTime $ianaZone

        if ($null -eq $dt) {
            continue
        }

        $windowsZone = Get-WindowsTimeZoneId $ianaZone

        # Determine whether this is the local timezone
        $isLocal = ($windowsZone -eq $LocalWindowsTimeZone)

        # ----------------------------------------------------
        # Clock panel
        # ----------------------------------------------------

        $Border = New-Object System.Windows.Controls.Border

        $Border.Margin = New-Object System.Windows.Thickness(5)
        $Border.Padding = New-Object System.Windows.Thickness(10)
        $Border.CornerRadius = New-Object System.Windows.CornerRadius(6)

        if ($isLocal) {

            $Border.Background = "Goldenrod"
            $Border.BorderBrush = "#B8860B"
            $Border.BorderThickness = New-Object System.Windows.Thickness(2)

        }
        else {

            $Border.BorderBrush = "Gray"
            $Border.BorderThickness = New-Object System.Windows.Thickness(1)

        }

        # ----------------------------------------------------
        # Clock text
        # ----------------------------------------------------

        $Text = New-Object System.Windows.Controls.TextBlock

        $Text.TextAlignment = "Center"

        if ($isLocal) {
            $Text.FontSize = 25
        }
        else {
            $Text.FontSize = 20
        }

        $Text.Foreground = "Black"

        # Match Python formatting:
        #
        # Wednesday
        # August 16, 2026
        # 10:45 AM
        #

        $title = $label

        if ($isLocal) {
            $title += " (Local)"
        }

        $Text.Inlines.Add(
            (New-Object System.Windows.Documents.Run(
                $title
            ))
        )

        $Text.Inlines[0].FontWeight = "Bold"

        $Text.Inlines.Add(
            (New-Object System.Windows.Documents.LineBreak)
        )

        $Text.Inlines.Add(
            $dt.ToString("dddd")
        )

        $Text.Inlines.Add(
            (New-Object System.Windows.Documents.LineBreak)
        )

        $Text.Inlines.Add(
            $dt.ToString("MMMM dd, yyyy")
        )

        $Text.Inlines.Add(
            (New-Object System.Windows.Documents.LineBreak)
        )

        $Text.Inlines.Add(
            $dt.ToString("hh:mm tt")
        )

        $Border.Child = $Text

        $MainPanel.Children.Add($Border)
    }
}

# ------------------------------------------------------------
# Initial display
# ------------------------------------------------------------

Update-Clocks

# ------------------------------------------------------------
# Timer
# ------------------------------------------------------------

$Timer = New-Object System.Windows.Threading.DispatcherTimer

$Timer.Interval = New-TimeSpan -Seconds 30

$Timer.Add_Tick({
    Update-Clocks
})

$Timer.Start()

# ------------------------------------------------------------
# Show window
# ------------------------------------------------------------

$Window.ShowDialog() | Out-Null
