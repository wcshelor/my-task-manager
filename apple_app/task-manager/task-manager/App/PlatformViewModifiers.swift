import SwiftUI

extension View {
    @ViewBuilder
    func macSheetFrame(
        minWidth: CGFloat,
        minHeight: CGFloat
    ) -> some View {
        #if os(macOS)
        frame(minWidth: minWidth, minHeight: minHeight)
        #else
        self
        #endif
    }
}
