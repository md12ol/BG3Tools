#!/bin/sh
# rec.sh start NAME | stop : screen recording WITH game audio to $BG3_REC_DIR/NAME.mp4 (default: Desktop/BG3Mods/Autopilot/videos).
# Video (2026-10-06, user: "very choppy" -> 1080p 45 fps): ffmpeg gfxcapture of the BG3 window at 45 fps, scaled on the
#   GPU by gfxcapture itself (1728x1080 = 1080 lines, the 16:10 frame kept whole; scale_d3d11 failed: texture 80070057), so only
#   ~340 MB/s are read back instead of ~1 GB/s of 2560x1600 BGRA; MediaFoundation hardware H.264 (h264_mf; NVENC only
#   managed ~40 fps at full size, a34) into NAME_v.ts (MPEG-TS, so a dead recorder leaves a playable file). 2026-10-09:
#   the fragmented MP4 used until a166 broke - h264_mf now reports "stream format change" after the empty moov was
#   written, so the file had no usable SPS/PPS and 0 decodable frames (a167, a168); MPEG-TS carries them in-band.
# Audio: tools/bg3drive/loopcap.exe = WASAPI loopback of the default playback device (own helper, no install, no
#   Windows sound setting changed) -> NAME.raw. It starts when the video file appears (trigger file).
# stop: ffmpeg is stopped GRACEFULLY ("q" on its stdin pipe) at the same moment loopcap is killed, so both ends line up
#   and the last video fragment is complete. (Until a66 ffmpeg was force-killed: the truncated last fragment plus a
#   whole-second container duration put the audio 1-1.5 s ahead of the picture - user report 2026-10-06.) The offset is
#   computed from the VIDEO STREAM duration (packet timestamps), then video + audio (AAC) are muxed into NAME.mp4.
# A watchdog restarts a dead video recorder into NAME_partN.ts until "rec.sh stop".
HERE="$(cd "$(dirname "$0")" && pwd)"
F="$LOCALAPPDATA/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0.2-full_build/bin/ffmpeg.exe"
FLAG="$TEMP/bg3rec.on"
DESK="${BG3_REC_DIR:-C:/Users/micha/Desktop/BG3Mods/Autopilot/videos}"   # restructure 2026-10: helm videos live in Autopilot/videos
case "$1" in
  start)
    echo "$2" > "$FLAG"; rm -f "$TEMP/bg3rec.trig"; mkdir -p "$DESK"
    "$HERE/loopcap.exe" "$DESK/$2.raw" "$TEMP/bg3rec.trig" >> "$TEMP/bg3rec.log" 2>&1 &
    (
      n=1
      while [ -f "$FLAG" ]; do
        out="$DESK/$2_v.ts"; [ $n -gt 1 ] && out="$DESK/$2_part$n.ts"
        # stdin = a pipe that sends "q" once the flag file is gone (graceful stop, complete last fragment)
        ( while [ -f "$FLAG" ]; do sleep 0.1; done; printf q ) | \
        "$F" -hide_banner -loglevel error -y -f lavfi -i gfxcapture=window_exe=bg3_dx11.exe:max_framerate=45:capture_cursor=0:width=1728:height=1080:resize_mode=scale_aspect:scale_mode=bicubic \
          -vf hwdownload,format=bgra,format=nv12 \
          -c:v h264_mf -hw_encoding 1 -rate_control quality -quality 70 -b:v 10M -g 90 -r 45 -fps_mode cfr \
          -muxdelay 0 -muxpreload 0 -f mpegts "$out" >> "$TEMP/bg3rec.log" 2>&1
        n=$((n+1)); sleep 1
      done
    ) > /dev/null 2>&1 &
    # start the audio when the first video frame has been written (file bigger than the bare header)
    for i in $(seq 1 100); do
      [ -f "$DESK/$2_v.ts" ] && [ "$(stat -c %s "$DESK/$2_v.ts" 2>/dev/null || echo 0)" -gt 4000 ] && break; sleep 0.05
    done
    : > "$TEMP/bg3rec.trig"
    sleep 0.3; tasklist > "$TEMP/bg3rec.tl"; grep -i -q ffmpeg "$TEMP/bg3rec.tl" && grep -i -q loopcap "$TEMP/bg3rec.tl" && echo "recording (video+audio) -> $DESK/$2.mp4" || echo "recorder failed (see $TEMP/bg3rec.log)";;
  stop)
    N=$(cat "$FLAG" 2>/dev/null); rm -f "$FLAG"
    # the feeder sees the flag gone within 0.1 s and sends "q"; loopcap is killed in the same moment
    sleep 0.1; taskkill //IM loopcap.exe //F > /dev/null 2>&1
    for i in $(seq 1 100); do tasklist | grep -qi ffmpeg.exe || break; sleep 0.1; done
    tasklist | grep -qi ffmpeg.exe && { echo "ffmpeg did not stop on q - killing it"; taskkill //IM ffmpeg.exe //F > /dev/null 2>&1; sleep 1; }
    if [ -n "$N" ] && [ -f "$DESK/${N}_v.ts" ]; then
      if [ -s "$DESK/$N.raw" ]; then
        # stream duration from the last packet timestamp (the container duration came out in whole seconds)
        vd=$("${F%ffmpeg.exe}ffprobe.exe" -v error -select_streams v:0 -show_entries packet=pts_time,duration_time -of csv=p=0 "$DESK/${N}_v.ts" 2>/dev/null \
             | awk -F, '$1!="" {e=$1+$2; if(e>m)m=e; if(s==""||$1<s)s=$1} END{printf "%.3f", m-s}')
        # both recorders are killed together, so their ENDS line up: the audio starts (vd - ad) s after the video does
        # 2026-10-06: the delay is applied with adelay. ffmpeg IGNORED -itsoffset on the raw audio input, so every recording
        # up to a66 was muxed with no delay at all and the audio ran ahead by the real delay (user: "about 1.5 s ahead").
        # Verified with synctap.ps1 (HUD toggle + beep markers) + avsync.py --beep. ffmpeg keeps capturing ~0.45 s after
        # the q (measured +0.43..+0.53 s audio lag without this term), so the video end is 0.45 s later than the audio end.
        AUDIO_DELAY=$(awk -v v="$vd" -v b="$(stat -c %s "$DESK/$N.raw")" 'BEGIN{d=v-b/192000-0.45; if(d<0)d=0; if(d>9)d=0; printf "%.3f", d}')
        DMS=$(awk -v d="$AUDIO_DELAY" 'BEGIN{printf "%d", d*1000}')
        echo "rec $N: video ${vd}s, audio $(( $(stat -c %s "$DESK/$N.raw") / 192000 ))s, audio delayed ${AUDIO_DELAY}s" | tee -a "$TEMP/bg3rec.log"
        "$F" -hide_banner -loglevel error -y -i "$DESK/${N}_v.ts" -f s16le -ar 48000 -ac 2 -i "$DESK/$N.raw" \
          -map 0:v -map 1:a -af "adelay=${DMS}:all=1" -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$DESK/$N.mp4" >> "$TEMP/bg3rec.log" 2>&1 \
          && "${F%ffmpeg.exe}ffprobe.exe" -v error -show_entries stream=codec_type -of csv=p=0 "$DESK/$N.mp4" | grep -q audio \
          && awk -v v="$vd" 'BEGIN{exit !(v > 1)}' \
          && rm -f "$DESK/${N}_v.ts" "$DESK/$N.raw" || echo "MUX FAILED (video ${vd}s) - kept ${N}_v.ts and $N.raw"
      else
        "$F" -hide_banner -loglevel error -y -i "$DESK/${N}_v.ts" -c copy "$DESK/$N.mp4" && rm -f "$DESK/${N}_v.ts"; echo "no audio captured"
      fi
    fi
    echo "recording stopped";;
esac
