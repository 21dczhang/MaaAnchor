# PowerShell script to download and extract the latest version of MaaAnchor

# Set variables
$DownloadPath = "$env:TEMP\MaaAnchorLatest.zip"
$ExtractPath = "C:\Users\Aurora\Desktop"
$TargetFolderName = "MaaAnchor"
$RepoUrl = "https://api.github.com/repos/21dczhang/MaaAnchor/releases/latest"

Write-Host "Getting latest MaaAnchor release info..."

try {
    # Get latest release information
    $ReleaseInfo = Invoke-RestMethod -Uri $RepoUrl -Method Get

    # Find asset matching Windows x86_64 pattern (e.g., MaaAnchor-win-x86_64-*.zip)
    $Asset = $ReleaseInfo.assets | Where-Object {
        $_.name -like "MaaAnchor-win-x86_64-*.zip"
    } | Select-Object -First 1

    if ($null -eq $Asset) {
        Write-Error "No Windows x86_64 asset found for MaaAnchor. Available assets:"
        foreach ($availableAsset in $ReleaseInfo.assets) {
            Write-Host "  - $($availableAsset.name)"
        }
        exit 1
    }

    $DownloadUrl = $Asset.browser_download_url
    $FileName = $Asset.name

    Write-Host "Found latest version: $FileName"
    Write-Host "Starting download..."

    # Download file using .NET WebClient
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($DownloadUrl, $DownloadPath)
    $WebClient.Dispose()

    Write-Host "Download completed, saved to: $DownloadPath"

    # Load ZIP assembly
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    }
    catch {
        Write-Error "Failed to load System.IO.Compression.FileSystem assembly: $($_.Exception.Message)"
        exit 1
    }

    # Verify ZIP integrity
    try {
        $ZipArchive = [System.IO.Compression.ZipFile]::OpenRead($DownloadPath)
        $ZipArchive.Dispose()
    }
    catch {
        Write-Error "Downloaded file is not a valid ZIP archive: $($_.Exception.Message)"
        Remove-Item $DownloadPath -ErrorAction SilentlyContinue
        exit 1
    }

    # Ensure extraction path exists
    if (!(Test-Path $ExtractPath)) {
        New-Item -ItemType Directory -Path $ExtractPath -Force
    }

    # Final destination
    $DestinationPath = Join-Path $ExtractPath $TargetFolderName

    # Remove existing folder
    if (Test-Path $DestinationPath) {
        Write-Host "Removing existing $TargetFolderName folder..."
        Remove-Item -Path $DestinationPath -Recurse -Force
    }

    # Temporary extraction path
    $TempExtractPath = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $TempExtractPath -Force

    # Extract to temp location
    [System.IO.Compression.ZipFile]::ExtractToDirectory($DownloadPath, $TempExtractPath)

    # Handle possible top-level folder inside ZIP
    $ExtractedItems = Get-ChildItem -Path $TempExtractPath
    if ($ExtractedItems.Count -eq 1 -and $ExtractedItems[0].PSIsContainer) {
        $ActualContentPath = $ExtractedItems[0].FullName
    }
    else {
        $ActualContentPath = $TempExtractPath
    }

    # Move to final destination with name "MaaAnchor"
    Move-Item -Path $ActualContentPath -Destination $DestinationPath -Force

    # Cleanup
    if (Test-Path $TempExtractPath) {
        Remove-Item -Path $TempExtractPath -Recurse -Force
    }
    Remove-Item $DownloadPath -Force

    Write-Host "Extraction completed! Files saved to: $DestinationPath"
    Write-Host "Operation completed successfully!"
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    # Cleanup on error
    if (Test-Path $DownloadPath) {
        Remove-Item $DownloadPath -ErrorAction SilentlyContinue
    }
}