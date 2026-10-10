ARGS_ALL="--no-warnings --windows-filenames --output '%(title)s [%(id)s].%(ext)s'"
ARGS_BATCH="--download-archive .downloaded.txt --no-playlist --sleep-requests 1.5"

function yt_dlp_sub_en_url() {
    : ${1?"Usage: ${FUNCNAME[0]} <url to video>"}
    local url=${1%%&*}
    yt-dlp $ARGS_ALL --skip-download --write-sub --write-auto-sub --convert-subs srt --sub-lang en "$url"
}

function yt_dlp_audio_from_url_or_list_url() {
    : ${1?"Usage: ${FUNCNAME[0]} <url to audio or list>"}
    yt-dlp $ARGS_ALL --extract-audio --audio-format m4a "$1"
}

function yt_dlp_audio_from_urls_at_txt() {
    : ${1?"Usage: ${FUNCNAME[0]} <txt_file>"}
    yt-dlp $ARGS_ALL $ARGS_BATCH --extract-audio --audio-format m4a --batch-file "$1"
}

function yt_dlp_video_from_urls_at_txt() {
    : ${1?"Usage: ${FUNCNAME[0]} <txt_file>"}
    yt-dlp $ARGS_ALL $ARGS_BATCH --recode-video mp4 --batch-file "$1"
}

function yt_dlp_video_480_from_url_or_list_url() {
    : ${1?"Usage: ${FUNCNAME[0]} <url to video or list>"}
    yt-dlp $ARGS_ALL -S "res:480" --recode-video mp4 "$1"
}

function yt_dlp_video_480_from_urls_at_txt() {
    : ${1?"Usage: ${FUNCNAME[0]} <txt_file>"}
    yt-dlp $ARGS_ALL $ARGS_BATCH -S "res:480" --recode-video mp4 --batch-file "$1"
}
