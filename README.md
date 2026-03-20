# Wavesync

Wavesync is a Ruby-based CLI tool that scans your music library and automatically converts audio files to match the specifications of the [teenage engineering TP-7](https://teenage.engineering/products/tp-7) and the [Elektron Octatrack MKII](https://www.elektron.se/explore/octatrack-mkii), adjusting sample rate, bit depth and file format as needed while preserving your original library structure and only converting files that don't already meet the device requirements.

It can also analyse the BPM of the tracks in your library and store the information as metadata in your files, as well as convert the metadata so that the target device can read the BPM. When syncing to the Octatrack, you can choose to add padding to each track, so that it's dead-simple to auto-slice your tracks to a multiple of full bars which allows precise looping, and seamlessly jumping to different parts of a track with Octatrack's sequencer.

![Wavesync syncing to Octatrack](assets/screenshot.png)

## Supported file types

Wavesync supports the following file types in your source library:

- M4A
- MP3
- WAV
- AIF

Unsupported file types will be ignored when syncing.

## Installation

1. Install Ruby

   https://www.ruby-lang.org/en/documentation/installation/

2. Install dependencies

```bash
brew install ffmpeg
brew install taglib
brew install bpm-tools
```

3. Install Wavesync

```bash
gem install wavesync --pre
```

4. Install field kit (only required for syncing to TP-7)

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

## Usage

### Help

```bash
# List all available commands
wavesync help
```

### Analyze

```bash
# Analyze library files for BPM and write results to file metadata
# Files that already have BPM set are skipped
wavesync analyze

# Overwrite existing BPM values
wavesync analyze -f
```

### Sync

```bash
# Sync library
# If multiple devices are configured, you will be prompted to select one
wavesync sync

# Sync to a specific device (by name as defined in config)
wavesync sync -d Octatrack

# Pad each track with silence so its total length aligns to a multiple of 64 bars
# (Octatrack only — requires BPM metadata on each track)
wavesync sync -p
```

When a source file's sample rate isn't supported by the target device, Wavesync selects the closest supported rate. Example: If a 96kHz file is synced to an Octatrack (which only supports 44.1kHz), it will be downsampled to 44.1kHz.

### Sets (experimental)

A set is a named, ordered selection of tracks from your library. Sets are stored as YAML files inside a `.sets` folder within the library directory. Syncing sets to devices is not yet implemented.

```bash
# Create a new set and open the interactive editor
wavesync set create NAME

# Edit an existing set
wavesync set edit NAME

# List all sets
wavesync set list
```

## Development

### Running Tests, RuboCop, and Type Checks

```bash
rake
```

This runs RuboCop (with auto-fix), Steep type checks, and the test suite in sequence.

### Releasing

```bash
rake release:publish
```

This tags the current version, pushes the tag to origin, builds the gem, and publishes it to RubyGems.
