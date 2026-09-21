Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

if (-not ([System.Management.Automation.PSTypeName]'DwmHelper').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DwmHelper {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@
}

$xaml_code = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="cli-helpers GUI runner"
        Height="720"
        Width="580"
        MinHeight="600"
        MinWidth="480"
        WindowStartupLocation="CenterScreen"
        Background="Transparent"
        FontFamily="Segoe UI Variable Text, Segoe UI, sans-serif">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#0067C0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Padding" Value="14,0,14,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#198AE3"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#005FB8"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#25FFFFFF"/>
                    <Setter Property="Foreground" Value="#55FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="BorderBrush" Value="#3D3D3D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="5"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#383838"/>
                    <Setter Property="BorderBrush" Value="#4A4A4A"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#222222"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#202020"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="CaretBrush" Value="#0078D4"/>
            <Setter Property="BorderBrush" Value="#383838"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Padding" Value="10,4,10,4"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="5">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsFocused" Value="True">
                    <Setter Property="BorderBrush" Value="#0078D4"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="LogTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#00FF66"/>
            <Setter Property="CaretBrush" Value="#00FF66"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontFamily" Value="Cascadia Code, Consolas, monospace"/>
            <Setter Property="VerticalContentAlignment" Value="Top"/>
            <Setter Property="AcceptsReturn" Value="True"/>
            <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="HorizontalScrollBarVisibility" Value="Auto"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <ScrollViewer x:Name="PART_ContentHost"
                                      VerticalScrollBarVisibility="Auto"
                                      HorizontalScrollBarVisibility="Auto"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <ControlTemplate x:Key="ComboBoxToggleButton" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition />
                    <ColumnDefinition Width="28" />
                </Grid.ColumnDefinitions>
                <Border x:Name="Border"
                        Grid.ColumnSpan="2"
                        CornerRadius="5"
                        Background="#202020"
                        BorderBrush="#383838"
                        BorderThickness="1" />
                <Path x:Name="Arrow"
                      Grid.Column="1"
                      Fill="#A0A0A0"
                      HorizontalAlignment="Center"
                      VerticalAlignment="Center"
                      Data="M 0 0 L 4 4 L 8 0 Z"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Border" Property="Background" Value="#2A2A2A" />
                    <Setter TargetName="Border" Property="BorderBrush" Value="#484848" />
                    <Setter TargetName="Arrow" Property="Fill" Value="#FFFFFF" />
                </Trigger>
                <Trigger Property="IsChecked" Value="True">
                    <Setter TargetName="Border" Property="Background" Value="#222222" />
                    <Setter TargetName="Border" Property="BorderBrush" Value="#0078D4" />
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <Style TargetType="ComboBox">
            <Setter Property="Height" Value="32"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Name="ToggleButton"
                                          Template="{StaticResource ComboBoxToggleButton}"
                                          Focusable="False"
                                          IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}"
                                          ClickMode="Press"/>
                            <ContentPresenter Name="ContentSite"
                                              IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                              Margin="10,3,30,3"
                                              VerticalAlignment="Center"
                                              HorizontalAlignment="Left" />
                            <Popup Name="Popup"
                                   Placement="Bottom"
                                   IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   PopupAnimation="Slide">
                                <Grid Name="DropDown"
                                      SnapsToDevicePixels="True"
                                      MinWidth="{TemplateBinding ActualWidth}"
                                      MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border x:Name="DropDownBorder"
                                            Background="#1E1E1E"
                                            BorderThickness="1"
                                            BorderBrush="#383838"
                                            CornerRadius="6"/>
                                    <ScrollViewer Margin="3,4,3,4" SnapsToDevicePixels="True">
                                        <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                                    </ScrollViewer>
                                </Grid>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Padding" Value="10,6,10,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="ItemBorder"
                                Background="{TemplateBinding Background}"
                                BorderThickness="0"
                                CornerRadius="4"
                                Margin="2,1,2,1"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#333333"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#0078D4"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,16">
            <TextBlock Text="cli-helpers GUI runner" FontSize="20" FontWeight="SemiBold" Foreground="#FFFFFF" FontFamily="Segoe UI Variable Display, Segoe UI"/>
        </StackPanel>

        <Border Grid.Row="1" Background="#12FFFFFF" BorderBrush="#25FFFFFF" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,14">
            <StackPanel>
                <TextBlock Text="Git &amp; setup" FontSize="14" FontWeight="SemiBold" Foreground="#D0D0D0" Margin="0,0,0,12"/>
                
                <Grid Margin="0,0,0,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="Git:" Width="120" FontSize="12" Foreground="#A0A0A0"/>
                        <Border Background="#1AFFFFFF" CornerRadius="4" Padding="8,2,8,2">
                            <TextBlock x:Name="git_status_text" Text="Checking..." FontSize="12" FontWeight="SemiBold" Foreground="#FFA500"/>
                        </Border>
                    </StackPanel>
                    <Button x:Name="btn_install_git" Grid.Column="1" Content="Install Git" Width="130"/>
                </Grid>

                <Grid Margin="0,0,0,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="cli-helpers:" Width="120" FontSize="12" Foreground="#A0A0A0"/>
                        <Border Background="#1AFFFFFF" CornerRadius="4" Padding="8,2,8,2">
                            <TextBlock x:Name="helpers_status_text" Text="Checking..." FontSize="12" FontWeight="SemiBold" Foreground="#FFA500"/>
                        </Border>
                    </StackPanel>
                    <Button x:Name="btn_install_helpers" Grid.Column="1" Content="Install helpers" Width="130" Style="{StaticResource SecondaryButton}"/>
                </Grid>

                <Grid Margin="0,0,0,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="User dotfiles:" Width="120" FontSize="12" Foreground="#A0A0A0"/>
                        <Border Background="#1AFFFFFF" CornerRadius="4" Padding="8,2,8,2">
                            <TextBlock x:Name="dotfiles_status_text" Text="Checking..." FontSize="12" FontWeight="SemiBold" Foreground="#FFA500"/>
                        </Border>
                    </StackPanel>
                </Grid>

                <TextBlock Text="GitHub Username for dotfiles:" FontSize="12" Foreground="#A0A0A0" Margin="16,0,0,4"/>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="tb_username" Margin="16,0,10,0" Text=""/>
                    <Button x:Name="btn_clone_dotfiles" Grid.Column="1" Content="Download dotfiles" Width="130"/>
                </Grid>
            </StackPanel>
        </Border>

        <Border Grid.Row="2" Background="#12FFFFFF" BorderBrush="#25FFFFFF" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row="0" Text="Run Helper" FontSize="14" FontWeight="SemiBold" Foreground="#D0D0D0" Margin="0,0,0,10"/>
                
                <Grid Grid.Row="1" Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <ComboBox x:Name="task_selector" Margin="0,0,10,0"/>
                    <Button x:Name="btn_refresh_tasks" Grid.Column="1" Content="Refresh" Width="80" Style="{StaticResource SecondaryButton}"/>
                </Grid>
                
                <Button Grid.Row="2" x:Name="execute_button" Content="Run Selected Script" Height="36" Margin="0,0,0,12"/>

                <Border Grid.Row="3" Background="#14000000" BorderBrush="#20FFFFFF" BorderThickness="1" CornerRadius="8" Padding="10">
                    <TextBox x:Name="output_box"
                             Style="{StaticResource LogTextBox}"
                             IsReadOnly="True"
                             TextWrapping="NoWrap"/>
                </Border>
            </Grid>
        </Border>

        <TextBlock Grid.Row="3" x:Name="status_label" Text="Ready" FontSize="12" Foreground="#AAAAAA" Margin="4,0,0,0"/>
    </Grid>
</Window>
'@

$string_reader = [System.IO.StringReader]::new($xaml_code)
$xml_reader = [System.Xml.XmlReader]::Create($string_reader)
$window = [System.Windows.Markup.XamlReader]::Load($xml_reader)

$window.Add_SourceInitialized({
    try {
        $hwnd = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
        $dark_mode = 1
        [DwmHelper]::DwmSetWindowAttribute($hwnd, 20, [ref]$dark_mode, [System.Runtime.InteropServices.Marshal]::SizeOf([type][int])) | Out-Null
        $backdrop_mica = 2
        [DwmHelper]::DwmSetWindowAttribute($hwnd, 38, [ref]$backdrop_mica, [System.Runtime.InteropServices.Marshal]::SizeOf([type][int])) | Out-Null
    } catch {
    }
})

$git_status_text = $window.FindName("git_status_text")
$btn_install_git = $window.FindName("btn_install_git")
$helpers_status_text = $window.FindName("helpers_status_text")
$btn_install_helpers = $window.FindName("btn_install_helpers")
$dotfiles_status_text = $window.FindName("dotfiles_status_text")
$tb_username = $window.FindName("tb_username")
$btn_clone_dotfiles = $window.FindName("btn_clone_dotfiles")
$task_selector = $window.FindName("task_selector")
$btn_refresh_tasks = $window.FindName("btn_refresh_tasks")
$execute_button = $window.FindName("execute_button")
$output_box = $window.FindName("output_box")
$status_label = $window.FindName("status_label")

function Invoke-DoEvents() {
    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [System.Action[System.Windows.Threading.DispatcherFrame]]{ param($f) $f.Continue = $false },
        $frame
    ) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

function Add-Output([string]$message) {
    if ([string]::IsNullOrWhiteSpace($message)) { return }
    $lines = $message -split "`r?`n"
    foreach ($line in $lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $output_box.AppendText("$line`r`n")
        }
    }
    $output_box.ScrollToEnd()
    Invoke-DoEvents
}

function Get-CliHelpersPath() {
    $candidates = @(
        (Join-Path $env:USERPROFILE "src\cli-helpers"),
        (Join-Path $env:USERPROFILE "src\dotfiles\cli-helpers")
    )
    if ($PSScriptRoot) {
        $candidates += (Split-Path -Parent $PSScriptRoot)
    }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path (Join-Path $path "init.ps1"))) {
            return $path
        }
    }
    return $null
}

function Get-DotfilesPath() {
    $candidates = @(
        (Join-Path $env:USERPROFILE "src\dotfiles")
    )
    if ($PSScriptRoot) {
        $candidates += (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path (Join-Path $path "init.ps1"))) {
            return $path
        }
    }
    return $null
}

function Get-DotfilesUser() {
    $dotfilesPath = Get-DotfilesPath
    if (-not $dotfilesPath) { return $null }

    $repoConfigFile = Join-Path $dotfilesPath ".git\config"
    if (Test-Path $repoConfigFile) {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            $remoteUrl = (git -C $dotfilesPath config --get remote.origin.url 2>&1).ToString().Trim()
            if ($remoteUrl -match 'github\.com[:/]([^/]+)') {
                return $matches[1].Trim()
            }
        }

        $repoContent = Get-Content $repoConfigFile -Raw -ErrorAction SilentlyContinue
        if ($repoContent -match 'github\.com[:/]([^/\s\r\n]+)') {
            return $matches[1].Trim()
        }
    }

    $gitconfigFile = Join-Path $dotfilesPath ".gitconfig"
    if (Test-Path $gitconfigFile) {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            $user = (git config --file $gitconfigFile --get github.user 2>&1).ToString().Trim()
            if (-not [string]::IsNullOrWhiteSpace($user) -and $user -notmatch 'error:') {
                return $user
            }
            $user = (git config --file $gitconfigFile --get user.username 2>&1).ToString().Trim()
            if (-not [string]::IsNullOrWhiteSpace($user) -and $user -notmatch 'error:') {
                return $user
            }
        }
        $content = Get-Content $gitconfigFile -Raw -ErrorAction SilentlyContinue
        if ($content -match '(?ms)\[github\].*?^\s*user\s*=\s*([^\r\n]+)') {
            return $matches[1].Trim()
        }
        if ($content -match '(?ms)\[user\].*?^\s*username\s*=\s*([^\r\n]+)') {
            return $matches[1].Trim()
        }
    }

    return $null
}

function Update-SetupStatus() {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $rawGitVersion = (git --version 2>&1) -replace '^git version\s*', 'v'
        $git_status_text.Text = "Installed ($rawGitVersion)"
        $git_status_text.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $btn_install_git.IsEnabled = $false
    } else {
        $git_status_text.Text = "Not installed"
        $git_status_text.Foreground = [System.Windows.Media.Brushes]::Coral
        $btn_install_git.IsEnabled = $true
    }

    $helpersPath = Get-CliHelpersPath
    if ($helpersPath) {
        $helpers_status_text.Text = "Installed"
        $helpers_status_text.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $btn_install_helpers.Content = "Update helpers"
    } else {
        $helpers_status_text.Text = "Not installed"
        $helpers_status_text.Foreground = [System.Windows.Media.Brushes]::Coral
        $btn_install_helpers.Content = "Install helpers"
    }

    $dotfilesPath = Get-DotfilesPath
    if ($dotfilesPath) {
        $dotfiles_status_text.Text = "Installed"
        $dotfiles_status_text.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $btn_clone_dotfiles.Content = "Update dotfiles"

        $dotfilesUser = Get-DotfilesUser
        if ($dotfilesUser) {
            $tb_username.Text = $dotfilesUser
        }
    } else {
        $dotfiles_status_text.Text = "Not installed"
        $dotfiles_status_text.Foreground = [System.Windows.Media.Brushes]::Coral
        $btn_clone_dotfiles.Content = "Download dotfiles"
    }
}

function Initialize-Tasks() {
    $helpersPath = Get-CliHelpersPath
    if ($helpersPath) {
        $initPs1 = Join-Path $helpersPath "init.ps1"
        if (Test-Path $initPs1) {
            . $initPs1
        }
    }

    $dotfilesPath = Get-DotfilesPath
    if ($dotfilesPath) {
        $initDotfiles = Join-Path $dotfilesPath "init.ps1"
        if (Test-Path $initDotfiles) {
            . $initDotfiles
        }
    }

    $allCommands = Get-Command -CommandType Function, Alias |
        Where-Object { $_.Name -match '^(win_|ubu_|my_)' } |
        Select-Object -ExpandProperty Name |
        Sort-Object -Unique

    $task_selector.Items.Clear()
    foreach ($cmd in $allCommands) {
        $task_selector.Items.Add($cmd) | Out-Null
    }
    if ($task_selector.Items.Count -gt 0) {
        $task_selector.SelectedIndex = 0
    }
    Add-Output "Loaded $($allCommands.Count) profile tasks."
}

Update-SetupStatus
Initialize-Tasks

$btn_refresh_tasks.Add_Click({
    Initialize-Tasks
    Update-SetupStatus
    $status_label.Text = "Tasks and status refreshed."
})

$btn_install_git.Add_Click({
    $status_label.Text = "Installing Git..."
    Add-Output "Starting Git installation via winget..."
    $btn_install_git.IsEnabled = $false
    try {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements *>&1 | ForEach-Object {
            Add-Output ([string]$_)
        }
        Update-SetupStatus
        Add-Output "Git installation completed."
        $status_label.Text = "Git installed."
    } catch {
        Add-Output "Git install failed: $_"
        $status_label.Text = "Git install error."
        $btn_install_git.IsEnabled = $true
    }
})

$btn_install_helpers.Add_Click({
    $helpersPath = Get-CliHelpersPath
    if ($helpersPath) {
        $status_label.Text = "Updating cli-helpers..."
        Add-Output "Pulling latest cli-helpers at $helpersPath..."
        git -C $helpersPath pull origin main *>&1 | ForEach-Object { Add-Output ([string]$_) }
        $status_label.Text = "cli-helpers updated."
    } else {
        $targetDir = "$env:USERPROFILE\src\cli-helpers"
        $status_label.Text = "Installing cli-helpers..."
        Add-Output "Cloning cli-helpers into $targetDir..."
        if (-not (Test-Path "$env:USERPROFILE\src")) {
            New-Item -ItemType Directory -Path "$env:USERPROFILE\src" -Force | Out-Null
        }
        git clone https://github.com/alanlivio/cli-helpers.git $targetDir *>&1 | ForEach-Object { Add-Output ([string]$_) }
        $status_label.Text = "cli-helpers installed."
    }
    Update-SetupStatus
    Initialize-Tasks
})

$btn_clone_dotfiles.Add_Click({
    $username = $tb_username.Text.Trim()
    $dotfilesPath = Get-DotfilesPath

    if (-not $dotfilesPath -and [string]::IsNullOrWhiteSpace($username)) {
        [System.Windows.MessageBox]::Show("Please enter a GitHub username to download dotfiles.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $btn_clone_dotfiles.IsEnabled = $false
    try {
        if ($dotfilesPath) {
            $status_label.Text = "Updating dotfiles..."
            Add-Output "Updating existing dotfiles at $dotfilesPath..."
            git -C $dotfilesPath pull origin main *>&1 | ForEach-Object { Add-Output ([string]$_) }
            $status_label.Text = "dotfiles updated."
        } else {
            $targetDir = "$env:USERPROFILE\src\dotfiles"
            $status_label.Text = "Downloading $username/dotfiles..."
            Add-Output "Downloading $username/dotfiles to $targetDir..."
            if (-not (Test-Path "$env:USERPROFILE\src")) {
                New-Item -ItemType Directory -Path "$env:USERPROFILE\src" -Force | Out-Null
            }
            git clone "https://github.com/$username/dotfiles.git" $targetDir *>&1 | ForEach-Object { Add-Output ([string]$_) }
            $status_label.Text = "dotfiles installed at $targetDir"
        }
        Update-SetupStatus
        Initialize-Tasks
    } catch {
        Add-Output "Error with dotfiles: $_"
        $status_label.Text = "dotfiles action failed."
    } finally {
        $btn_clone_dotfiles.IsEnabled = $true
    }
})

$execute_button.Add_Click({
    $selectedTask = [string]$task_selector.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedTask)) {
        return
    }

    $status_label.Text = "Executing: $selectedTask..."
    Add-Output ">>> Running $selectedTask..."
    $execute_button.IsEnabled = $false

    try {
        & $selectedTask *>&1 | ForEach-Object {
            Add-Output ([string]$_)
        }
        $status_label.Text = "Finished: $selectedTask"
        Add-Output ">>> Completed $selectedTask"
    } catch {
        Add-Output "Error: $_"
        $status_label.Text = "Failed: $selectedTask"
    } finally {
        $execute_button.IsEnabled = $true
    }
})

$window.ShowDialog() | Out-Null
