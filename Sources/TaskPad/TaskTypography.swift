import AppKit
import SwiftUI

@MainActor
enum TaskTypography {
    private static let heights: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 32
        return cache
    }()

    static func lineHeight(for font: NSFont) -> CGFloat {
        let key = "\(font.fontName):\(font.pointSize)" as NSString
        if let height = heights.object(forKey: key) { return CGFloat(height.doubleValue) }
        // SwiftUI and TextKit round font metrics differently. Measure the
        // resting renderer once per font instead of guessing its line pitch.
        let view = NSHostingView(rootView: Text("Ag").font(Font(font)).fixedSize())
        let height = view.fittingSize.height
        heights.setObject(NSNumber(value: Double(height)), forKey: key)
        return height
    }
}
