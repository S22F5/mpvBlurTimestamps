#!/bin/bash
blurSigma="20"
blurSteps="1"

commandString="mpv --lavfi-complex=\"[vid1]"

while getopts v:b:f flag; do
  case ${flag} in
  v) videoFile=$OPTARG ;;
  b) blurFile=$OPTARG ;;
  f) force=1 ;;
  ?) echo "default" ;;
  esac
done

if [[ -z "$videoFile" ]]; then
  videoFile="$1"
fi
if [[ -z "$blurFile" ]]; then
  blurFile="*.blurs"
fi

videoPlaytime=$(mpv --no-video --frames=0 --log-file=/dev/stdout "$videoFile" | grep -i "+ duration:" | awk '{print $6}')
IFS='x' read -r videoWidth videoHeight <<<"$(mpv --no-video --frames=0 --log-file=/dev/stdout "$videoFile" | grep -i "Video.*x.*fps) " | sed -E 's/.* ([0-9]+x[0-9]+) .*/\1/')"
videoAspectR=$(echo "$videoWidth / $videoHeight" | bc -l)

timeToSeconds() {
  IFS=: read -r h m s <<<"$1"
  if [[ -z "$h" || -z "$m" || -z "$s" ]]; then
    return 1
  fi
  printf "%d" "$((10#$h * 3600 + 10#$m * 60 + 10#$s))"
}

# parse timestamp file
{
  read -r timestampFileInfo
  read -r expectedPlaytime
  IFS='x' read -r expectedWidth expectedHeight
  expectedAspectR=$(echo "$expectedWidth / $expectedHeight" | bc -l)
  scaleMult=$(echo "$videoWidth / $expectedWidth" | bc -l)
  if [[ "$force" -ne 1 ]]; then
    if [[ "$expectedPlaytime" != "$videoPlaytime" ]]; then
      printf "\n[ERROR] Playtime does not match\n"
      printf "[INFO] %s != %s\n" "$expectedPlaytime" "$videoPlaytime"
      exit 1
    fi
    if [[ "$expectedAspectR" != "$videoAspectR" ]]; then
      printf "\n[ERROR] Aspect Ratio does not match\n"
      printf "[INFO] %s != %.2f\n" "$expectedAspectR" "$videoAspectR"
      exit 1
    fi
  fi
  firstFilter=true
  while IFS=' |.' read -r bStartTime bStartTimeMs bEndTime bEndTimeMs bSizeX bSizeY bOffsetX bOffsetY; do
    bStartSeconds=$(timeToSeconds "$bStartTime")
    bEndSeconds=$(timeToSeconds "$bEndTime")
    if [[ -z "$bStartSeconds" || -z "$bEndSeconds" ]]; then
      continue
    fi
    if [[ "$bSizeX" -ne 0 ]]; then
      #areaBlur
      bSSizeX=$(echo "$bSizeX * $scaleMult" | bc -l)
      bSSizeY=$(echo "$bSizeY * $scaleMult" | bc -l)
      bSOffsetX=$(echo "$bOffsetX * $scaleMult" | bc -l)
      bSOffsetY=$(echo "$bOffsetY * $scaleMult" | bc -l)
    else
      #fullscreenBlur
      bSSizeX=$videoWidth
      bSSizeY=$videoHeight
      bSOffsetX=0
      bSOffsetY=0
    fi

    if [ "$firstFilter" = true ]; then
      blur=1
      filterString+="[$blur]crop=$bSSizeX:$bSSizeY:$bSOffsetX:$bSOffsetY,gblur=sigma=$blurSigma:steps=${blurSteps}:enable='between(t,$bStartSeconds.$bStartTimeMs,$bEndSeconds.$bEndTimeMs)'[b$blur];[m][b$blur]overlay=$bSOffsetX:$bSOffsetY:enable='between(t,$bStartSeconds.$bStartTimeMs,$bEndSeconds.$bEndTimeMs)'[bo$blur];"
      firstFilter=false
    else
      ((blur = blur + 1))
      filterString+="[$blur]crop=$bSSizeX:$bSSizeY:$bSOffsetX:$bSOffsetY,gblur=sigma=$blurSigma:steps=${blurSteps}:enable='between(t,$bStartSeconds.$bStartTimeMs,$bEndSeconds.$bEndTimeMs)'[b$blur];[bo$((blur - 1))][b$blur]overlay=$bSOffsetX:$bSOffsetY:enable='between(t,$bStartSeconds.$bStartTimeMs,$bEndSeconds.$bEndTimeMs)'[bo$blur];"
    fi
  done

} <$blurFile

filterString=${filterString%[*}
filterString+="[vo]"
outputsString=$(printf '[%d]' $(seq 1 "$blur"))
((blur = blur + 1))
commandString="mpv --lavfi-complex=\"[vid1]split=outputs=${blur}[m]$outputsString;$filterString"
commandString+="\" --osd-playing-msg='$timestampFileInfo' '$videoFile'"

# print command
printf "[INFO] Command: %s\n\n" "$commandString"
# run mpv
eval "$commandString"
