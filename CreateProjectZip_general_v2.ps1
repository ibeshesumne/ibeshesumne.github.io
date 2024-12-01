# Get the current working directory (where the script is being executed)
$rootDir = Get-Location

# Determine the project name from the directory name
$projectName = Split-Path -Leaf $rootDir.Path

# Generate the output zip file name using the project name and timestamp
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$outputZip = Join-Path -Path $rootDir.Path -ChildPath "$projectName_$timestamp.zip"

# Exclusion patterns (e.g., files and folders to exclude)
$exclusionPatterns = @(".env*", "node_modules", "dist")

# Collect files in the root directory (non-recursively)
$rootFiles = Get-ChildItem -Path $rootDir -File |
    Where-Object { 
        foreach ($pattern in $exclusionPatterns) { 
            if ($_.Name -like $pattern) { return $false } 
        } 
        return $true 
    }

# Collect files in the /src folder and its subdirectories
$srcPath = Join-Path -Path $rootDir -ChildPath "src"
$srcFiles = if (Test-Path -Path $srcPath) {
    Get-ChildItem -Path $srcPath -Recurse -File |
        Where-Object { 
            foreach ($pattern in $exclusionPatterns) { 
                if ($_.Name -like $pattern) { return $false } 
            } 
            return $true 
        }
} else {
    @() # If the src folder doesn't exist, return an empty array
}

# Combine files from the root directory and /src folder
$keyFiles = $rootFiles + $srcFiles

# Check if there are files to zip
if ($keyFiles.Count -eq 0) {
    Write-Output "No files found to zip. Check your exclusion patterns or directory contents."
    exit
}

# Create a temporary folder to stage the files with their structure
$tempFolder = Join-Path -Path $rootDir.Path -ChildPath "tempZipFolder"
if (Test-Path -Path $tempFolder) {
    Remove-Item -Path $tempFolder -Recurse -Force
}
New-Item -Path $tempFolder -ItemType Directory | Out-Null

# Copy files into the temporary folder, preserving structure
foreach ($file in $keyFiles) {
    $relativePath = $file.FullName.Substring($rootDir.Path.Length + 1)
    $destinationPath = Join-Path -Path $tempFolder -ChildPath $relativePath
    $destinationFolder = Split-Path -Path $destinationPath -Parent
    if (!(Test-Path -Path $destinationFolder)) {
        New-Item -Path $destinationFolder -ItemType Directory | Out-Null
    }
    Copy-Item -Path $file.FullName -Destination $destinationPath
}

# Zip the staged folder
Compress-Archive -Path "$tempFolder\*" -DestinationPath $outputZip -Force

# Clean up temporary folder
Remove-Item -Path $tempFolder -Recurse -Force

# Output the path of the created zip file
Write-Output "Zip file created at: $outputZip"
