import AppKit
import SwiftUI

@main
struct Render {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/previews", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            for (name, layout, size) in [("small", BatteryLayout.small, CGSize(width: 158, height: 158)),
                                        ("medium", .medium, CGSize(width: 338, height: 158)),
                                        ("large", .large, CGSize(width: 338, height: 354))] {
                let view = BatteryContent(snapshot: .sample, layout: layout)
                    .padding(16).frame(width: size.width, height: size.height)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 23))
                    .environment(\.colorScheme, dark ? .dark : .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw UsageError.invalidResponse
                }
                try png.write(to: output.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
            }
        }
        print("Rendered six sample-data previews: \(output.path)")
    }
}
