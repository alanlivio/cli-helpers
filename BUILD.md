# Building and Running

## Development

Install dependencies and run the application locally:

```powershell
make deps
make run-gui
```

Run tests:

```powershell
make test
```

## Packaging

Build the standalone executable and WinGet package:

```powershell
make gui
make winget-pkg
```

## Release

Publish the GUI executable to GitHub and submit the WinGet package:

```powershell
make publish-gui
make winget-pkg-submit
```
