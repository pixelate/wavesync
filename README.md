# Wavesync

Wavesync is a Ruby-based CLI tool that scans your music library and automatically converts audio files to match the specifications of specific hardware music devices like the teenage engineering TP-7 and Elektron Octatrack, adjusting sample rate, bit depth and file format as needed while preserving your original library structure and only converting files that don't already meet the device requirements. It also reads BPM information from the original file and converts it so that the target device can read it.

## Supported devices

- teenage engineering TP-7
- Elektron Octatrack MKII

## Supported file types

Wavesync supports the following file types in your source library:

- M4A
- MP3
- WAV
- AIF

Unsupported file types will be ignored when syncing.

## Installation

1. Install ffmpeg and taglib

```bash
brew install ffmpeg
brew install taglib
```

2. Install field kit (only required for syncing to TP-7)

https://teenage.engineering/guides/fieldkit

## Configuration

Wavesync is configured via a YAML file. By default it looks for `~/wavesync.yml`. You can also pass a path explicitly with the `-c` flag.

### wavesync.yml format

```yaml
library: ~/Music/Library
devices:
  - name: TP-7
    path: ~/Library/Containers/engineering.teenage.fieldkit/Data/Documents/TP-7 MTP Device-F1ELN21A/library
  - name: Octatrack
    path: /Volumes/OCTATRACK/LIBRARY/AUDIO
```

- `library`: path to your source music library
- `devices`: list of devices to sync to, each with:
  - `name`: device model (`TP-7` or `Octatrack`)
  - `path`: path to the device's library directory

Wavesync will exit with an error if a device name in the config is not supported.

## Usage

```bash
# Use the default config at ~/wavesync.yml
wavesync

# Use a config at a specific path
wavesync -c /path/to/wavesync.yml
```

## Sample Rate Selection

When a source file's sample rate isn't supported by the target device, Wavesync selects the closest supported rate. For files with equal distance to two rates, it chooses the higher rate to minimize quality loss.

Example: If a 96kHz file is synced to an Octatrack (which only supports 44.1kHz), it will be downsampled to 44.1kHz.

## Development

### Running Tests

```bash
rake test
```
