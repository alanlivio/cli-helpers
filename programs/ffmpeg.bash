function ffmpeg_cut_mp4() {
    : ${3?"Usage: ${FUNCNAME[0]} <video> <begin_time_in_format_00:00:00> <end_time_in_format_00:00:00>"}
    local fname_no_ext="${1%.*}"
    local extension=${1##*.}
    ffmpeg -i "$1" -vcodec copy -acodec copy -ss "$2" -t "$3" -f mp4 "$fname_no_ext (cuted).$extension"
}

function ffmpeg_convert_to_mp4_960x540() {
    : ${1?"Usage: ${FUNCNAME[0]} <video>"}
    local fname_no_ext="${1%.*}"
    ffmpeg -i "$1" -vf "scale=960:540" -c:v libx264 -c:a aac "$fname_no_ext (converted).mp4"
}

function ffmpeg_convert_to_mp4_960x540_cutted_until() {
    : ${2?"Usage: ${FUNCNAME[0]} <video> <XX:YY:ZZ>"}
    local fname_no_ext="${1%.*}"
    ffmpeg -i "$1" -ss 00:00:00 -t "$2" -vf "scale=960:540" -c:v libx264 -c:a aac "$fname_no_ext (converted).mp4"
}

function ffmpeg_extract_audio_m4a() {
    : ${1?"Usage: ${FUNCNAME[0]} <video>"}
    local fname_no_ext="${1%.*}"
    ffmpeg -i "$1" -vn -acodec copy "$fname_no_ext (audio only).m4a"
}

function ffmpeg_extract_video_mp4() {
    : ${1?"Usage: ${FUNCNAME[0]} <video>"}
    local fname_no_ext="${1%.*}"
    ffmpeg -i "$1" -c:v copy -an "$fname_no_ext (video only).mp4"
}

function ffmpeg_show_motion_vectors() {
    : ${1?"Usage: ${FUNCNAME[0]} <video>"}
    ffplay -flags2 +export_mvs -vf codecview=mv=pf+bf+bb "$1"
}

function ffmpeg_extract_key_frames() {
    : ${1?"Usage: ${FUNCNAME[0]} <video>"}
    # https://jdhao.github.io/2021/12/25/ffmpeg-extract-key-frame-video/
    local fname_no_ext="${1%.*}"
    ffmpeg -skip_frame nokey -i "$1" -vsync vfr -frame_pts true "${fname_no_ext}-key-frame-%02d.jpeg"
}

function ffmpeg_mp4_files_merge() {
    : ${1?"Usage: ${FUNCNAME[0]} <file1> ... "}
    ffmpeg -f concat -safe 0 -i <(for f in "$@"; do echo "file '$PWD/$f'"; done) -c copy merged.mp4
}
