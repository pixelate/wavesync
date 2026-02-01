# Wavesync

Wavesync is a Ruby-based CLI tool that scans your music library and automatically converts audio files to match the specifications of specific hardware music devices like the teenage engineering TP-7 and Elektron Octatrack, adjusting sample rate, bit depth and file format as needed while preserving your original library structure and only converting files that don't already meet the device requirements.

## Supported devices

Out of the box, Wavesync supports:

- teenage engineering TP-7
- Elektron Octatrack MKII

Custom devices can be added via a YAML configuration file.

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

## Usage

### Command-line options

- `-s, --source PATH`: Path to your source music library
- `-t, --target PATH`: Path to the target sync directory
- `-d, --device DEVICE_MODEL`: Target device model (TP-7 or Octatrack)
- `-c, --config PATH`: Path to custom device configuration YAML file (optional)

### Examples

Sync to TP-7:
```bash
./bin/wavesync -s ~/Music/Library -t /Users/username/Library/Containers/engineering.teenage.fieldkit/Data/Documents/TP-7\ MTP\ Device-F1ELN21A/library -d TP-7
```

Sync to Octatrack:
```bash
./bin/wavesync -s ~/Music/Library -t /Volumes/OCTATRACK/LIBRARY/AUDIO -d Octatrack
```

## Custom device configuration

Create a YAML file to define custom devices:

```yaml
devices:
  - name: MyCustomDevice
    sample_rates:
      - 44100
      - 48000
    file_types:
      - wav
      - mp3
```

Then use it with the `-c` flag:

```bash
wavesync -s ~/Music -t /Volumes/DEVICE -d MyCustomDevice -c path/to/config.yml
```
## Sample Rate Selection

When a source file's sample rate isn't supported by the target device, Wavesync selects the closest supported rate. For files with equal distance to two rates, it chooses the higher rate to minimize quality loss.

Example: If a 96kHz file is synced to an Octatrack (which only supports 44.1kHz), it will be downsampled to 44.1kHz.

## Development

### Running Tests

```bash
rake test
```