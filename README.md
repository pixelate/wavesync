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

1. Install dependencies

```bash
brew install ffmpeg    # required for all commands
brew install taglib    # required for all commands
brew install bpm-tools # required for analyze command
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
    model: TP-7
    path: ~/Library/Containers/engineering.teenage.fieldkit/Data/Documents/TP-7 MTP Device-F1ELN21A/library
  - name: Octatrack
    model: Octatrack
    path: /Volumes/OCTATRACK/LIBRARY/AUDIO
```

- `library`: path to your source music library
- `devices`: list of devices to sync to, each with:
  - `name`: a label for this device, used with the `-d` command-line option
  - `model`: device model (`TP-7` or `Octatrack`)
  - `path`: path to the device's library directory

Wavesync will exit with an error if a device model in the config is not supported.

## Usage

```bash
# Sync library to all devices (uses default config at ~/wavesync.yml)
wavesync sync

# Use a config at a specific path
wavesync sync -c /path/to/wavesync.yml

# Sync to a specific device only (by name as defined in config)
wavesync sync -d Octatrack

# Analyze library files for BPM and write results to file metadata
# Files that already have BPM set are skipped
wavesync analyze

# Overwrite existing BPM values
wavesync analyze --force

# Analyze with a specific config path
wavesync analyze -c /path/to/wavesync.yml
```

## Sets

A set is a named, ordered selection of tracks from your library. Sets are stored as YAML files inside a `.sets` folder within the library directory.

```bash
# Create a new set and open the interactive editor
wavesync set create <name>

# Edit an existing set
wavesync set edit <name>

# List all sets
wavesync set list
```

The set editor is a keyboard-driven interactive UI:

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate tracks |
| `space` | Play / pause selected track |
| `a` | Add track after selection |
| `u` | Move selected track up |
| `d` | Move selected track down |
| `r` | Remove selected track |
| `s` | Save and exit |
| `c` | Cancel without saving |

The playing track is indicated by `▶` (playing) or `⏸` (paused) before the track number. When a track finishes, the next track plays automatically. Changes are only written to disk when you press `s`.

## Sample Rate Selection

When a source file's sample rate isn't supported by the target device, Wavesync selects the closest supported rate. For files with equal distance to two rates, it chooses the higher rate to minimize quality loss.

Example: If a 96kHz file is synced to an Octatrack (which only supports 44.1kHz), it will be downsampled to 44.1kHz.

## Development

### Running Tests

```bash
rake test
```
