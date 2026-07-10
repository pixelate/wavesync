# Changelog

## 1.0.0.beta2 - 2026-07-10

- Read and write the iTunes tmpo atom for M4A BPM ([#74](https://github.com/pixelate/wavesync/pull/74))
- Rescue all SystemCallError in safe copy paths ([#73](https://github.com/pixelate/wavesync/pull/73))
- Connect unused RhythmDescriptors sources in EssentiaBpmDetector ([#72](https://github.com/pixelate/wavesync/pull/72))
- Transliterate umlauts in TP-7 paths ([#71](https://github.com/pixelate/wavesync/pull/71))
- Allow analyze to target a single file or folder ([#70](https://github.com/pixelate/wavesync/pull/70))
- Read TP-7 loop markers from device and show in setlist player ([#69](https://github.com/pixelate/wavesync/pull/69))
- Log per-bucket timing breakdown after each sync ([#68](https://github.com/pixelate/wavesync/pull/68))
- Simplify install instructions and move TP-7 sync notes ([#67](https://github.com/pixelate/wavesync/pull/67))
- Remove taglib install step from README ([#66](https://github.com/pixelate/wavesync/pull/66))

## 1.0.0.beta1 - 2026-05-14

- Uppercase folder and file names when syncing to TP-7 ([#64](https://github.com/pixelate/wavesync/pull/64))
- Extract cue-point pull into its own `pull` command ([#63](https://github.com/pixelate/wavesync/pull/63))
- Add per-device `mp3_bitrate` config and copy MP3 files as-is ([#62](https://github.com/pixelate/wavesync/pull/62))
- Sync to TP-7 over MTP via libmtp instead of fieldkit container path ([#61](https://github.com/pixelate/wavesync/pull/61))
- Sort audio library files alphabetically (case-insensitive) ([#60](https://github.com/pixelate/wavesync/pull/60))
- Rename `Wavesync::Set` to `Wavesync::Setlist` ([#59](https://github.com/pixelate/wavesync/pull/59))
- Log sync and analyze command invocations in the log ([#58](https://github.com/pixelate/wavesync/pull/58))
- Strip curly apostrophe, colon, and question mark for Octatrack ([#57](https://github.com/pixelate/wavesync/pull/57))
- Verify target file exists after sync writes ([#56](https://github.com/pixelate/wavesync/pull/56))
- Log total run time at end of analyze and sync commands ([#55](https://github.com/pixelate/wavesync/pull/55))
- Replace taglib-ruby with ffmpeg for metadata operations ([#54](https://github.com/pixelate/wavesync/pull/54))
- Encode mp3 transcodes at 192 kbps and display source bitrate ([#53](https://github.com/pixelate/wavesync/pull/53))

## 1.0.0.alpha4 - 2026-04-19

- Replace extended characters with ASCII equivalents in Playdate metadata tags ([#51](https://github.com/pixelate/wavesync/pull/51))
- Add Playdate (Kicooya) as a supported device ([#50](https://github.com/pixelate/wavesync/pull/50))
- Fix re-conversion on FAT/exFAT caused by unicode path mismatch ([#49](https://github.com/pixelate/wavesync/pull/49))
- Strip double-quote characters from filenames when syncing to FAT devices ([#47](https://github.com/pixelate/wavesync/pull/47))
- Add error logging to all rescue sites ([#45](https://github.com/pixelate/wavesync/pull/45))
- Pad to power-of-2 bar multiples to keep slice counts valid ([#44](https://github.com/pixelate/wavesync/pull/44))
- Add `unsupported_characters` to devices and strip them from target paths ([#42](https://github.com/pixelate/wavesync/pull/42))
- Replace streamio-ffmpeg with a custom FFMPEG wrapper class ([#41](https://github.com/pixelate/wavesync/pull/41))
- Add integration tests for device sync ([#40](https://github.com/pixelate/wavesync/pull/40))
- Write BPM and cue data in-place to save disk space on source device ([#39](https://github.com/pixelate/wavesync/pull/39))
- Fix crash when writing BPM/cue data to MTP devices ([#37](https://github.com/pixelate/wavesync/pull/37), [#38](https://github.com/pixelate/wavesync/pull/38))

## 1.0.0.alpha3 - 2026-03-23

- Flush filesystem buffers after sync completion ([#34](https://github.com/pixelate/wavesync/pull/34))
- Update audio test fixtures with rake generation task ([#33](https://github.com/pixelate/wavesync/pull/33))
- Replace bpm-tools with Essentia + Percival BPM detection ([#32](https://github.com/pixelate/wavesync/pull/32))
- Replace instance_variable_get with public accessors in set editor tests ([#31](https://github.com/pixelate/wavesync/pull/31))
- Enhance set editor with duration display, playback bar, and inline folder layout ([#30](https://github.com/pixelate/wavesync/pull/30))
- Add support for TP-7 cue points ([#29](https://github.com/pixelate/wavesync/pull/29))
- Update Rubocop to 1.85 ([#28](https://github.com/pixelate/wavesync/pull/28))
- Run rubocop, steep check, and tests with rake ([#27](https://github.com/pixelate/wavesync/pull/27))
- Add Ruby installation step to README ([#26](https://github.com/pixelate/wavesync/pull/26))
- Add typechecking with rbs-inline and Steep ([#25](https://github.com/pixelate/wavesync/pull/25))
- Display BPM and pitch shift semitones when editing sets ([#24](https://github.com/pixelate/wavesync/pull/24))
- Update README with improved docs ([#23](https://github.com/pixelate/wavesync/pull/23))

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
