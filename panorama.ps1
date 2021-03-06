Param (
  [Parameter(Mandatory=$true)][string]$panoOriginal,
  [switch]$fixPitch,
  [switch]$expandTop
)

$imagemagick_convert = "$PSScriptRoot\convert.exe"
$nona = "C:\Program Files\Hugin\bin\nona.exe"

$workingDir = $(Get-Location)

# Get path details
Try {
  $panoFile = (get-item $panoOriginal -ErrorAction Stop)
  $panoPath = $panoFile.fullname
  $panoFileName = $panoFile.Name
  $panoBaseName = $panoFile.Basename
  $panoDir = $panoFile.Directory
}
Catch {
  write-host -ForegroundColor red "File $panoOriginal not Found"
  break;
}

# get image dimensions
add-type -AssemblyName System.Drawing
$fs = New-Object System.IO.FileStream ("$panoPath", [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$img = [System.Drawing.Image]::FromStream($fs)
$fs.Dispose()

$width = $img.Size.Width
$height = $img.Size.Height

# print informations
write-host "Path: $($panoPath)"
write-host "Wordking Dir: $($workingDir)"
write-host "Image Dimensions: $($width)x$($height)"

$newHeight = $width / 2

write-host "New Image Dimensions: $($width)x$($newHeight)"

Try {
  $test = 1/$width
  $test = 1/$height
}
Catch {
  write-host -ForegroundColor red "size error"
  break;
}

# copy original to working dir
if(-not (Test-Path "$($panoFileName)")) {
	Write-Host "copy pano to Workdir"
	Copy-Item "$panoPath" "$($panoFileName)"
}

# if specified, fix pitch of equirectangular pano using nona
if($fixPitch -and ($height/$width) -eq 0.5) {
	$ptoTPL = (Get-Content "$($PSScriptRoot)/pano_fix_pitch_tpl.pto").replace("{{panofilename}}", "$workingDir/$panoFileName")
	$ptoTPL = $ptoTPL.replace("{{panowidth}}", "$width").replace("{{panoheight}}", "$newHeight")
	$ptoTPL | Set-Content "$($PSScriptRoot)/pano_fix_pitch.pto"

	write-host "fix pitch of pano with nona.exe"
	& $nona -o pano "$($PSScriptRoot)/pano_fix_pitch.pto"
	
	write-host "compress fixed pano"
	& $imagemagick_convert -quality 85% "pano.jpg" "$panoFileName"
	Remove-Item "pano.jpg"
}elseif($fixPitch -and ($height/$width) -ne 0.5) {
  write-host -ForegroundColor red "Parameter -fixPitch is given but the image aspect ratio isn't 2:1. I think it has to be, though."
  break;
}

# generate 1000px wide preview
if(-not (Test-Path "pano_preview.jpg")) {
	write-host "generating poster 1000x500 pano_preview.jpg"
	& $imagemagick_convert "$panoFileName" -resize 1000x "pano_preview.jpg"
}

# if needed, expand panorama to 2:1 aspect ratio with black
# should run after preview and only when pitch wasn't changed
if(-not($fixPitch)) {
	if(($height/$width) -ne 0.5) {
		write-host "expand pano to ratio 2:1 ($($width)x$($newHeight))"
		& $imagemagick_convert "$panoFileName" -background black -gravity south -extent "$($width)x$($newHeight)" "$panoFileName"
	}
}

# create mobile browser version (4096px wide equirectangular)
if(-not (Test-Path "pano_mobile.jpg")) {
	write-host "create mobile browser version pano_mobile.jpg"
	& $imagemagick_convert "$panoFileName" -resize 4096x "pano_mobile.jpg"
}

# create cube faces from equirectangular pano using nona
if(-not (Test-Path "pano0000.jpg")) {
	# Generate pto from template with filename
	$ptoTPL = (Get-Content "$($PSScriptRoot)/pano_tpl.pto").replace("{{panofilename}}", "$workingDir/$panoFileName")
	$ptoTPL = $ptoTPL.replace("{{panowidth}}", "$width").replace("{{panoheight}}", "$newHeight")
	$ptoTPL | Set-Content "$($PSScriptRoot)/pano.pto"

	write-host "creating cube faces with nona.exe"
	& $nona -o pano "$($PSScriptRoot)/pano.pto"
}
