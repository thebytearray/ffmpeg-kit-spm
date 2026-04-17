// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let release = "v1.0.0"

// SHA-256 of each binary zip (not git SHAs). Recomputed by ./build.sh when you zip prebuilt/*.xcframework.
let frameworks = ["ffmpegkit": "f3f97ee32d86d74b80394b7823265f69126bca694614dca169317a945e329052", "libavcodec": "a79b323314b532ec8dac339321329b0769a9a4c83076b6889e5d14eae148e660", "libavdevice": "a1dc192c5c2ea072285d4ba6d7c3411015b46b45ee2aa7928e833ff69110c77a", "libavfilter": "f2b807ab868ae0e7af4650b868bfbe40beb56593a2d56e0abc1a3b359ede0344", "libavformat": "db881f73bca94631b7732c7ddaa3f77b26fb73cd4489a73fae4cb40b8fed52bf", "libavutil": "7a2c4d867f0583a73eab803809462d39ba0ce6325fecb6a464cd08d817511e2c", "libswresample": "6574f6b47f6f976397f8de4ce2fcb5216e4aff5bf51022b8b193c62af22029b5", "libswscale": "a271f84cdffdda7b0166af91f16d137c02e91d3585e3f7adddcd02d56a28276b"]

func xcframework(_ package: Dictionary<String, String>.Element) -> Target {
    let url = "https://github.com/codewithtamim/ffmpeg-kit-spm/releases/download/\(release)/\(package.key).xcframework.zip"
    return .binaryTarget(name: package.key, url: url, checksum: package.value)
}

let linkerSettings: [LinkerSetting] = [
    .linkedFramework("AudioToolbox", .when(platforms: [.macOS, .iOS, .macCatalyst, .tvOS])),
    .linkedFramework("AVFoundation", .when(platforms: [.macOS, .iOS, .macCatalyst])),
    .linkedFramework("CoreMedia", .when(platforms: [.macOS])),
    .linkedFramework("OpenGL", .when(platforms: [.macOS])),
    .linkedFramework("VideoToolbox", .when(platforms: [.macOS, .iOS, .macCatalyst, .tvOS])),
    .linkedLibrary("z"),
    .linkedLibrary("lzma"),
    .linkedLibrary("bz2"),
    .linkedLibrary("iconv")
]

let libAVFrameworks = frameworks.filter({ $0.key != "ffmpegkit" })

let package = Package(
    name: "ffmpeg-kit-spm",
    platforms: [.iOS(.v12), .macOS(.v10_15), .tvOS(.v11), .watchOS(.v7)],
    products: [
        .library(
            name: "FFmpeg-Kit",
            type: .dynamic,
            targets: ["FFmpeg-Kit", "ffmpegkit"]),
        .library(
            name: "FFmpeg",
            type: .dynamic,
            targets: ["FFmpeg"] + libAVFrameworks.map { $0.key }),
    ] + libAVFrameworks.map { .library(name: $0.key, targets: [$0.key]) },
    dependencies: [],
    targets: [
        .target(
            name: "FFmpeg-Kit",
            dependencies: frameworks.map { .byName(name: $0.key) },
            linkerSettings: linkerSettings),
        .target(
            name: "FFmpeg",
            dependencies: libAVFrameworks.map { .byName(name: $0.key) },
            linkerSettings: linkerSettings),
    ] + frameworks.map { xcframework($0) }
)
