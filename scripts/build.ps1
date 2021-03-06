﻿param(
    [Parameter(Position = 0)]
    [ValidateSet('major', 'minor', 'patch')]
    [System.String]$versionIncrement = "patch"
)

$standaloneList = "BetterArray.cls"
$withTestsList = 
"BetterArray.cls",
"ArrayGenerator.cls",
"ExcelProvider.cls",
"IValuesList.cls",
"TestUtils.bas",
"TestModule_ArrayGenerator.bas",
"TestModule_BetterArray.bas",
"TestModule_ExcelProvider.bas",
"ValuesList_Booleans.cls",
"ValuesList_Bytes.cls", 
"ValuesList_Doubles.cls", 
"ValuesList_Longs.cls", 
"ValuesList_Objects.cls",
"ValuesList_Strings.cls",
"ValuesList_Variants.cls"

$projectRoot = (Get-Item $PSScriptRoot).Parent
$src = Get-Item (Join-Path -Path $projectRoot.FullName -ChildPath "src")
$releases = Get-Item (Join-Path -Path $projectRoot.FullName -ChildPath "releases")
$latest = Get-Item (Join-Path -Path $releases.FullName -ChildPath "latest")
$temp = New-Item -ItemType Directory -Force -Path (Join-Path -Path $releases.FullName -ChildPath "temp")
Set-Location $projectRoot.FullName
$lastTag = git describe --tags --abbrev=0
if ($lastTag) {
    $currentVersion = [regex]::Match($lastTag, "(\d+.\d+.\d+)").captures.groups[1].value
}
else {
    $currentVersion = "0.0.0"
}
$versionArray = $currentVersion.Split(".") 
switch ($versionIncrement) {
    "major" {
        $versionArray[-1] = 0
        $versionArray[-2] = 0
        $versionArray[-3] = [int]$versionArray[-3] + 1
    }
    "minor" {
        $versionArray[-1] = 0
        $versionArray[-2] = [int]$versionArray[-2] + 1
    }
    "patch" {
        $versionArray[-1] = [int]$versionArray[-1] + 1
    }
}
$currentVersion = "v$($versionArray -join ".")" 
$currentFooter = "'" + $currentVersion
Write-Host $temp
$standaloneList = $standaloneList.ForEach( { "$temp\$_" })
$withTestsList = $withTestsList.ForEach( {
        # Add version number to bottom of all files - standalone is also in this array
        $content = Get-Content "$src\$_"
        if ($content[-1] -ne $currentFooter) {
            if ($content[-1] -Match "^v\d+.\d+.\d+$") {
                $content[-1] = $currentFooter
                $content | Set-Content "$temp\$_"
            }
            else {
                ($content) + ($currentFooter)  | Set-Content "$temp\$_"
            }
        }
        "$temp\$_"
    })
$outputPath = New-Item -ItemType Directory -Force -Path (Join-Path -Path $releases.FullName -ChildPath $currentVersion)
$standalonePath = "$($outputPath.FullName)\Standalone.Zip"
$withTestsPath = "$($outputPath.FullName)\WithTests.Zip"

# Delete current files in latest
Get-ChildItem -Path $latest.FullName | Remove-Item -Recurse

# Create .zip files
Compress-Archive -Path $standaloneList -CompressionLevel Optimal -DestinationPath $standalonePath -Force
Compress-Archive -Path $withTestsList -CompressionLevel Optimal -DestinationPath $withTestsPath -Force

# Delete temp folder now archives created
Remove-Item $temp.FullName -Recurse

# Create change-log
if ($lastTag) {
    # get commits since last tag
    $log = git log $lastTag`..HEAD --oneline # escape period with backtick
}
else {
    # get commits unpushed commits
    $log = git log origin/master`..master --oneline
}

$changeLog = New-Item -ItemType File -Force -Path "$($outputPath.FullName)\changelog.txt"
Set-Content $changeLog $log

# Copy new files to latest
Copy-Item -Path $standalonePath -Destination $latest.FullName
Copy-Item -Path $withTestsPath -Destination $latest.FullName
Copy-Item -Path $changeLog -Destination $latest.FullName

git add --all
git commit --message $currentVersion
git tag $currentVersion
git push
git push --tags
return $currentVersion
Exit