import SwiftUI

/// GitHub's monochrome mark, drawn locally so the footer has no network dependency.
struct GitHubIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 12, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: 12), control1: CGPoint(x: 5.37, y: 0), control2: CGPoint(x: 0, y: 5.37))
        path.addCurve(to: CGPoint(x: 8.205, y: 23.385), control1: CGPoint(x: 0, y: 17.31), control2: CGPoint(x: 3.435, y: 21.795))
        path.addCurve(to: CGPoint(x: 9.025, y: 22.81), control1: CGPoint(x: 8.805, y: 23.49), control2: CGPoint(x: 9.025, y: 23.125))
        path.addLine(to: CGPoint(x: 9.01, y: 20.77))
        path.addCurve(to: CGPoint(x: 5.675, y: 19.285), control1: CGPoint(x: 5.672, y: 21.495), control2: CGPoint(x: 4.968, y: 19.16))
        path.addCurve(to: CGPoint(x: 4.345, y: 17.53), control1: CGPoint(x: 5.402, y: 18.593), control2: CGPoint(x: 5.009, y: 17.92))
        path.addCurve(to: CGPoint(x: 4.45, y: 16.85), control1: CGPoint(x: 3.257, y: 16.786), control2: CGPoint(x: 4.263, y: 16.802))
        path.addCurve(to: CGPoint(x: 6.29, y: 18.086), control1: CGPoint(x: 5.65, y: 16.934), control2: CGPoint(x: 6.083, y: 18.084))
        path.addCurve(to: CGPoint(x: 9.04, y: 19.171), control1: CGPoint(x: 7.357, y: 19.913), control2: CGPoint(x: 8.437, y: 19.377))
        path.addCurve(to: CGPoint(x: 9.8, y: 17.566), control1: CGPoint(x: 9.148, y: 18.39), control2: CGPoint(x: 9.458, y: 18.02))
        path.addCurve(to: CGPoint(x: 4.34, y: 11.635), control1: CGPoint(x: 7.133, y: 17.263), control2: CGPoint(x: 4.34, y: 16.232))
        path.addCurve(to: CGPoint(x: 5.575, y: 8.415), control1: CGPoint(x: 4.34, y: 10.325), control2: CGPoint(x: 4.809, y: 9.255))
        path.addCurve(to: CGPoint(x: 5.695, y: 5.24), control1: CGPoint(x: 5.453, y: 8.112), control2: CGPoint(x: 5.038, y: 6.891))
        path.addCurve(to: CGPoint(x: 8.995, y: 6.47), control1: CGPoint(x: 5.695, y: 5.24), control2: CGPoint(x: 6.703, y: 4.918))
        path.addCurve(to: CGPoint(x: 15.005, y: 6.47), control1: CGPoint(x: 10.913, y: 5.936), control2: CGPoint(x: 13.087, y: 5.936))
        path.addCurve(to: CGPoint(x: 18.305, y: 5.24), control1: CGPoint(x: 17.297, y: 4.918), control2: CGPoint(x: 18.305, y: 5.24))
        path.addCurve(to: CGPoint(x: 18.425, y: 8.415), control1: CGPoint(x: 18.962, y: 6.891), control2: CGPoint(x: 18.547, y: 8.112))
        path.addCurve(to: CGPoint(x: 19.66, y: 11.635), control1: CGPoint(x: 19.191, y: 9.255), control2: CGPoint(x: 19.66, y: 10.325))
        path.addCurve(to: CGPoint(x: 14.18, y: 17.56), control1: CGPoint(x: 19.66, y: 16.245), control2: CGPoint(x: 16.86, y: 17.258))
        path.addCurve(to: CGPoint(x: 14.99, y: 19.78), control1: CGPoint(x: 14.61, y: 17.932), control2: CGPoint(x: 14.99, y: 18.662))
        path.addLine(to: CGPoint(x: 14.975, y: 22.81))
        path.addCurve(to: CGPoint(x: 15.795, y: 23.385), control1: CGPoint(x: 14.975, y: 23.125), control2: CGPoint(x: 15.195, y: 23.49))
        path.addCurve(to: CGPoint(x: 24, y: 12), control1: CGPoint(x: 20.565, y: 21.795), control2: CGPoint(x: 24, y: 17.31))
        path.addCurve(to: CGPoint(x: 12, y: 0), control1: CGPoint(x: 24, y: 5.37), control2: CGPoint(x: 18.63, y: 0))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
