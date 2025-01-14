#!/bin/bash

blurSigma="20"
blurSteps="5"
videoFile="*.mkv"

command_string="mpv --lavfi-complex=\"[vid1]"
video_length=$(mpv --no-video --frames=0 --log-file=/dev/stdout $videoFile | grep -i "+ duration:" | awk '{print $6}')

time_to_seconds() {
  IFS=: read -r h m s <<<"$1"
  printf "%d" "$((10#$h * 3600 + 10#$m * 60 + 10#$s))"
}

# read timestamps from file
{
  read -r timestampfilename
  read -r expected_playtime
  if [[ "$expected_playtime" != "$video_length" ]]; then
    printf "\n[ERROR] Playtime does not match\n"
    printf "[INFO] %s != %s\n" "$expected_playtime" "$video_length"
    exit 1
  fi
  while read -r start_time end_time; do
    start_seconds=$(time_to_seconds "$start_time")
    end_seconds=$(time_to_seconds "$end_time")

    if [ "$command_string" == "mpv --lavfi-complex=\"[vid1]" ]; then
      command_string+="gblur=sigma=$blurSigma:steps=$blurSteps:enable='between(t,$start_seconds,$end_seconds)'"
    else
      command_string+=",gblur=sigma=$blurSigma:steps=$blurSteps:enable='between(t,$start_seconds,$end_seconds)'"
    fi
  done
} <timestamps.txt

command_string+="[vo]\" --osd-playing-msg='$timestampfilename' $videoFile"

# run mpv
eval "$command_string"
