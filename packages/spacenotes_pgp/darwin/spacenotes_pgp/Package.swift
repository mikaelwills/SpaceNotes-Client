// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "spacenotes-pgp",
  platforms: [.iOS("13.0"), .macOS("10.15")],
  products: [
    .library(name: "spacenotes-pgp", targets: ["spacenotes_pgp"])
  ],
  targets: [
    .binaryTarget(
      name: "SpaceNotesPGP",
      path: "Frameworks/SpaceNotesPGP.xcframework"
    ),
    .target(
      name: "spacenotes_pgp",
      dependencies: ["SpaceNotesPGP"]
    ),
  ]
)
