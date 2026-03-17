# FFmpegKit SPM

This is a Swift Package Manager compatible version of [FFmpegKit](https://github.com/thebytearray/ffmpeg-kit).
It distributes and bundles the ffmpeg-kit full-gpl version for iOS, macOS and tvOS as XCFrameworks.

### Installation
Add this repo as a Swift Package dependency to your project
```
https://github.com/thebytearray/ffmpeg-kit-spm
```

If using this in a Swift package, add this repo as a dependency.
```
.package(url: "https://github.com/thebytearray/ffmpeg-kit-spm/", .upToNextMajor(from: "5.1.0"))
```

### Usage

To get started, import this library: `import ffmpegkit` \
_If you are wanting to use the FFmpeg libav c libraries directly: `import FFmpeg`_

See the [FFmpegKit wiki](https://github.com/arthenica/ffmpeg-kit/tree/main/apple#3-using) for more info on integration and usage for FFmpeg. \
_For using FFmpeg directly, see the [FFmpeg documentation](https://trac.ffmpeg.org/wiki/Using%20libav*) here_

### Building
Run the `build.sh` script on a macOS machine, or use the [GitHub Actions workflow](.github/workflows/build-spm-release.yml): Actions → "Build and Publish SPM Release" → Run workflow → enter a tag (e.g. `full-gpl.v6.0.0`). 
