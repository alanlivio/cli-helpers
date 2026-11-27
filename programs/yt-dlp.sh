yt_dlp_sub_en_url() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url to video>"
        return 1
    fi
    local url="${1%%&*}"
    local args_all=(--no-warnings --windows-filenames --output "%(title)s [%(id)s].%(ext)s")
    yt-dlp "${args_all[@]}" --skip-download --write-sub --write-auto-sub --convert-subs srt --sub-lang en "$url"
}

yt_dlp_audio_from_url_or_list_url() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url to audio or list>"
        return 1
    fi
    local args_all=(--no-warnings --windows-filenames --output "%(title)s [%(id)s].%(ext)s")
    yt-dlp "${args_all[@]}" --extract-audio --audio-format m4a "$1"
}

yt_dlp_audio_from_urls_at_txt() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <txt_file>"
        return 1
    fi
    local args_all=(--no-warnings --windows-filenames --output "%(title)s [%(id)s].%(ext)s")
    local args_batch=(--download-archive .downloaded.txt --no-playlist --sleep-requests 1.5)
    yt-dlp "${args_all[@]}" "${args_batch[@]}" --extract-audio --audio-format m4a --batch-file "$1"
}

yt_dlp_video_from_urls_at_txt() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <txt_file>"
        return 1
    fi
    local args_all=(--no-warnings --windows-filenames --output "%(title)s [%(id)s].%(ext)s")
    local args_batch=(--download-archive .downloaded.txt --no-playlist --sleep-requests 1.5)
    yt-dlp "${args_all[@]}" "${args_batch[@]}" --recode-video mp4 --batch-file "$1"
}

yt_dlp_video_480_from_url_or_list_url() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url to video or list>"
        return 1
    fi
    local args_all=(--no-warnings --windows-filenames --output "%(title)s [%(id)s].%(ext)s")
    yt-dlp "${args_all[@]}" -S "res:480" --recode-video mp4 "$1"
}

yt_dlp_video_480_from_urls_at_txt() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <txt_file>"
        return 1
    fi
    local args_all=(--no-warnings --windows-filenames --output "%(title)s [%(id)s].%(ext)s")
    local args_batch=(--download-archive .downloaded.txt --no-playlist --sleep-requests 1.5)
    yt-dlp "${args_all[@]}" "${args_batch[@]}" -S "res:480" --recode-video mp4 --batch-file "$1"
}
