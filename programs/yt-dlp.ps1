function yt_dlp__base_args {
    @(
        "--no-warnings"
        "--windows-filenames"
        "--output"
        "%(title)s.%(ext)s"
    )
}

function yt_dlp__batch_args {
    @(
        "--download-archive"
        ".downloaded.txt"
        "--no-playlist"
    )
}

function yt_dlp_sub_en_url {
    param([string]$url)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <url to video>"; return }
    $cleanUrl = $url.Split('&')[0]
    $yt_dlt_args = @(
        (yt_dlp__base_args)
        "--skip-download"
        "--write-sub"
        "--write-auto-sub"
        "--convert-subs"
        "srt"
        "--sub-lang"
        "en"
        $cleanUrl
    )
    yt-dlp @yt_dlt_args
}

function yt_dlp_audio_from_url_or_list_url {
    param([string]$url)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <url to audio or list>"; return }
    $yt_dlt_args = @(
        (yt_dlp__base_args)
        "--extract-audio"
        "--audio-format"
        "m4a"
        $url
    )
    yt-dlp @yt_dlt_args
}

function yt_dlp_audio_from_urls_at_txt {
    param([string]$file)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <url to audio or list>"; return }
    $yt_dlt_args = @(
        (yt_dlp__base_args)
        (yt_dlp__batch_args)
        "--extract-audio"
        "--audio-format"
        "m4a"
        "--batch-file"
        $file
    )
    yt-dlp @yt_dlt_args
}

function yt_dlp_video_from_urls_at_txt {
    param([string]$file)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <url to audio or list>"; return }
    $yt_dlt_args = @(
        (yt_dlp__base_args)
        (yt_dlp__batch_args)
        "--recode-video"
        "mp4"
        "--batch-file"
        $file
    )
    yt-dlp @yt_dlt_args
}

function yt_dlp_video_480_from_url_or_list_url {
    param([string]$url)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <url to video or list>"; return }
    $yt_dlt_args = @(
        (yt_dlp__base_args)
        "-f"
        "best[height<=480]"
        "--recode-video"
        "mp4"
        $url
    )
    yt-dlp @yt_dlt_args
}

function yt_dlp_video_480_from_urls_at_txt {
    param([string]$file)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <txt_file>"; return }
    $yt_dlt_args = @(
        (yt_dlp__base_args)
        (yt_dlp__batch_args)
        "-f"
        "best[height<=480]"
        "--recode-video"
        "mp4"
        "--batch-file"
        $file
    )
    yt-dlp @yt_dlt_args
}
