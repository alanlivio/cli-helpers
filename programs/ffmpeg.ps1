function ffmpeg_cut_mp4 {
    param([string]$video, [string]$beginTime, [string]$endTime)
    if ($PSBoundParameters.Keys.Count -le 3) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video> <begin_time_in_format_00:00:00> <end_time_in_format_00:00:00>"; return }
    $fname_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($video)
    $extension = [System.IO.Path]::GetExtension($video)
    ffmpeg.exe -i "$video" -vcodec copy -acodec copy -ss "$beginTime" -t "$endTime" -f mp4 "$fname_no_ext (cuted)$extension"
}

function ffmpeg_convert_to_mp4_960x540 {
    param([string]$video)
    if (-not $PSBoundParameters.Keys.Count) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video>"; return }
    $fname_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($video)
    ffmpeg.exe -i "$video" -vf "scale=960:540" -c:v libx264 -c:a aac "$fname_no_ext (converted).mp4"
}

function ffmpeg_convert_to_mp4_960x540_cutted_until {
    param([string]$video, [string]$cutUntilTime)
    if ($PSBoundParameters.Keys.Count -le 3) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video> <XX:YY:ZZ>"; return }
    $fname_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($video)
    ffmpeg.exe -i "$video" -ss 00:00:00 -t "$cutUntilTime" -vf "scale=960:540" -c:v libx264 -c:a aac "$fname_no_ext (converted).mp4"
}

function ffmpeg_extract_audio_m4a {
    param([string]$video)
    if (-not $PSBoundParameters.Keys.Count) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video>"; return }
    $fname_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($video)
    ffmpeg.exe -i "$video" -vn -acodec copy "$fname_no_ext (audio only).m4a"
}

function ffmpeg_extract_video_mp4 {
    param([string]$video)
    if (-not $PSBoundParameters.Keys.Count) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video>"; return }
    $fname_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($video)
    ffmpeg.exe -i "$video" -c:v copy -an "$fname_no_ext (video only).mp4"
}

function ffmpeg_show_motion_vectors {
    param([string]$video)
    if (-not $PSBoundParameters.Keys.Count) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video>"; return }
    ffplay.exe -flags2 +export_mvs -vf codecview=mv=pf+bf+bb "$video"
}

function ffmpeg_extract_key_frames {
    param([string]$video)
    if (-not $PSBoundParameters.Keys.Count) { log_error "Usage: $($MyInvocation.MyCommand.Name) <video>"; return }
    $fname_no_ext = [System.IO.Path]::GetFileNameWithoutExtension($video)
    ffmpeg.exe -skip_frame nokey -i "$video" -vsync vfr -frame_pts true "${fname_no_ext}-key-frame-%02d.jpeg"
}

function ffmpeg_mp4_files_merge {
    param([string[]]$files)
    if (-not $PSBoundParameters.Keys.Count) { throw "Usage: $($MyInvocation.MyCommand.Name) <file1> ..."; return }
    $fileList = $files | ForEach-Object { "file '$((Resolve-Path $_).Path)'" }
    $tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
    $fileList | Set-Content $tempFile
    ffmpeg.exe -f concat -safe 0 -i "$tempFile" -c copy merged.mp4
    Remove-Item $tempFile
}