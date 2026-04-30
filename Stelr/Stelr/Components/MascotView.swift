import SwiftUI

enum MascotMood { case idle, happy, meh, sad, excited }

struct MascotView: View {
    var mood: MascotMood = .idle
    var size: CGFloat = 44

    @State private var bounceScale: CGFloat = 1.0
    @State private var bounceRotation: Double = 0

    private var color: Color {
        switch mood {
        case .idle:    return Color(hex: "a8907a")   // neutral warm
        case .happy:   return Color(hex: "D6B84A")   // yellow — flaring
        case .meh:     return Color(hex: "E5604A")   // orange — kindling
        case .sad:     return Color(hex: "8B1A1A")   // dark red — dark star
        case .excited: return Color(hex: "FFFFFF")   // white — supernova
        }
    }

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)
            let col = GraphicsContext.Shading.color(color)
            // circle bg
            ctx.fill(Path(ellipseIn: CGRect(x: s*0.04, y: s*0.04, width: s*0.92, height: s*0.92)),
                     with: .color(color.opacity(0.13)))
            ctx.stroke(Path(ellipseIn: CGRect(x: s*0.04, y: s*0.04, width: s*0.92, height: s*0.92)),
                       with: .color(color.opacity(0.38)), lineWidth: 1.5)
            // eyes
            let eyeY: CGFloat = mood == .sad ? s*0.44 : s*0.42
            let eyeR: CGFloat = s*0.055
            ctx.fill(Path(ellipseIn: CGRect(x: s*0.36-eyeR, y: eyeY-eyeR, width: eyeR*2, height: eyeR*2)), with: col)
            ctx.fill(Path(ellipseIn: CGRect(x: s*0.64-eyeR, y: eyeY-eyeR, width: eyeR*2, height: eyeR*2)), with: col)
            // mouth
            var mouth = Path()
            switch mood {
            case .idle:
                mouth.move(to: CGPoint(x: s*0.34, y: s*0.62))
                mouth.addQuadCurve(to: CGPoint(x: s*0.66, y: s*0.62), control: CGPoint(x: s*0.5, y: s*0.68))
            case .happy:
                mouth.move(to: CGPoint(x: s*0.30, y: s*0.58))
                mouth.addQuadCurve(to: CGPoint(x: s*0.70, y: s*0.58), control: CGPoint(x: s*0.5, y: s*0.74))
            case .meh:
                mouth.move(to: CGPoint(x: s*0.34, y: s*0.64))
                mouth.addLine(to: CGPoint(x: s*0.66, y: s*0.64))
            case .sad:
                mouth.move(to: CGPoint(x: s*0.30, y: s*0.68))
                mouth.addQuadCurve(to: CGPoint(x: s*0.70, y: s*0.68), control: CGPoint(x: s*0.5, y: s*0.58))
            case .excited:
                mouth.move(to: CGPoint(x: s*0.28, y: s*0.56))
                mouth.addQuadCurve(to: CGPoint(x: s*0.72, y: s*0.56), control: CGPoint(x: s*0.5, y: s*0.78))
            }
            ctx.stroke(mouth, with: col, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: size, height: size)
        .scaleEffect(bounceScale)
        .rotationEffect(.degrees(bounceRotation))
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: color)
        .onChange(of: mood) { _, newMood in
            guard newMood != .idle else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    bounceScale = 1.0; bounceRotation = 0
                }
                return
            }
            // step 1 – squash up and tilt
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                bounceScale = 1.15; bounceRotation = -4
            }
            // step 2 – overshoot the other way
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
                    bounceScale = 0.95; bounceRotation = 3
                }
            }
            // step 3 – settle back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                    bounceScale = 1.0; bounceRotation = 0
                }
            }
        }
    }
}
