$blurSigma = 20
$blurSteps = 5
$videoFile = '*.mkv'

$tempLogFile = [System.IO.Path]::GetTempFileName()
mpv --no-video --frames=0 --log-file=$tempLogFile $videoFile
$video_length = & { Get-Content -Path $tempLogFile | Select-String -Pattern '\+ duration:' | ForEach-Object { $_.Line.Split(':')[-1].Trim() } }
Remove-Item -Path $tempLogFile
$filter_string = ''

function time_to_seconds {
	param (
		[string]$time
	)
	$parts = $time.Split(":")
	if ($parts.Count -eq 3) {
		return [int]$parts[0] * 3600 + [int]$parts[1] * 60 + [int]$parts[2]
	} elseif ($parts.Count -eq 2) {
		return [int]$parts[0] * 60 + [int]$parts[1]
	} else {
		throw "invalid $time"
	}
}

$timestamps = Get-Content 'timestamps.txt'
$timestampfilename = $timestamps[0]
$expected_playtime = $timestamps[1]

if ($expected_playtime -ne $video_length) {
	Write-Error "[ERROR] Playtime does not match"
	exit 1
}

for ($i = 2; $i -lt $timestamps.Count; $i++) {
	$time_range = $timestamps[$i].Split(" ")
	$start_time = $time_range[0]
	$end_time = $time_range[1]
	$start_seconds = time_to_seconds -time $start_time
	$end_seconds = time_to_seconds -time $end_time
	Write-Output $start_time

	if ($filter_string -eq '') {
		$filter_string = "gblur=sigma=$blurSigma`:steps=$blurSteps`:enable='between(t,$start_seconds,$end_seconds)'"
	} else {
		$filter_string += ",gblur=sigma=$blurSigma`:steps=$blurSteps`:enable='between(t,$start_seconds,$end_seconds)'"
	}
}

$command_string = ' --lavfi-complex="[vid1]' + $filter_string + '[vo]" --osd-playing-msg="' + $timestampfilename + '" ' + $videoFile

# run mpv
Start-Process -FilePath "mpv" -ArgumentList $command_string