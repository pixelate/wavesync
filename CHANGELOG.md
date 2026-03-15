# Changelog

## 1.0.0.alpha2 - 2026-03-15

- Add `rake release:publish` task ([#21](https://github.com/pixelate/wavesync/pull/21))
- Refactor CLI commands into separate classes with metadata ([#20](https://github.com/pixelate/wavesync/pull/20))
- Add `wavesync help` command ([#19](https://github.com/pixelate/wavesync/pull/19))
- Interactive device selection prompt when multiple devices are configured ([#18](https://github.com/pixelate/wavesync/pull/18))
- Add CLAUDE.md with project instructions ([#17](https://github.com/pixelate/wavesync/pull/17))
- Add test GitHub Actions CI workflow ([#16](https://github.com/pixelate/wavesync/pull/16))
- Add RuboCop GitHub Actions CI workflow ([#15](https://github.com/pixelate/wavesync/pull/15))
- Confirm writing BPM data to library files ([#14](https://github.com/pixelate/wavesync/pull/14))
- Add documentation URI to gemspec ([#13](https://github.com/pixelate/wavesync/pull/13))

## 1.0.0.alpha1 - 2026-03-14

- Error handling for invalid or missing YAML config ([#11](https://github.com/pixelate/wavesync/pull/11))
- Bar-aligned silence padding for Octatrack tracks on sync ([#10](https://github.com/pixelate/wavesync/pull/10))
- Introduce AudioFormat value object to reduce parameter counts ([#8](https://github.com/pixelate/wavesync/pull/8))
- Skip conversion when a converted file already exists in the source library ([#6](https://github.com/pixelate/wavesync/pull/6))
- Audio sets: create, edit, and list named track collections with an interactive editor ([#5](https://github.com/pixelate/wavesync/pull/5))
- Add audio fixtures and tests for Audio and AcidChunk ([#4](https://github.com/pixelate/wavesync/pull/4))
- Analyze library files for BPM and write results to file metadata ([#3](https://github.com/pixelate/wavesync/pull/3))
- Sync music library to hardware devices (TP-7, Octatrack) with automatic format conversion ([#1](https://github.com/pixelate/wavesync/pull/1))
