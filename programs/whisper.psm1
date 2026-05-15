function whisper_transcribe {
    param(
        [string[]]$video,
        [string]$model = "turbo",
        [string]$language
    )

    if ($PSBoundParameters.Keys.Count -lt 1) {
        log_error "Usage: $($MyInvocation.MyCommand.Name) <video.mp4|*> [model] [language]"
        return
    }

    $videos = @()
    foreach ($item in $video) {
        if ($item -eq "*") {
            $videos += Get-ChildItem -File -Filter *.mp4 | Select-Object -ExpandProperty FullName
            continue
        }

        if (Test-Path $item -PathType Leaf) {
            $videos += (Resolve-Path $item).Path
            continue
        }

        $matched_files = Get-ChildItem -File -Path $item -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        if ($matched_files) {
            $videos += $matched_files
            continue
        }

        log_error "$item not exists"
    }

    $videos = $videos | Select-Object -Unique
    if (-not $videos) {
        return
    }

    foreach ($resolved_video in $videos) {
        $output_dir = Split-Path -Parent $resolved_video
        $base_name = [System.IO.Path]::GetFileNameWithoutExtension($resolved_video)
        $expected_output_file = Join-Path $output_dir "$base_name.txt"

        $whisper_args = @(
            "--model"
            $model
            "--task"
            "transcribe"
            "--output_format"
            "txt"
            "--output_dir"
            $output_dir
        )

        if ($PSBoundParameters.ContainsKey("language") -and $language) {
            $whisper_args += @("--language", $language)
        }

        $whisper_args += $resolved_video

        whisper.exe @whisper_args

        $generated_output_file = Join-Path $output_dir "$base_name.txt"
        if (($generated_output_file -ne $expected_output_file) -and (Test-Path $generated_output_file)) {
            Move-Item -Force $generated_output_file $expected_output_file
        }

        if (Test-Path $expected_output_file) {
            Write-Host $expected_output_file
        }
    }
}

Export-ModuleMember -Function *
