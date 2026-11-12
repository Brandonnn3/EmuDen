import SwiftUI

enum ConsoleSystem: String, CaseIterable, Identifiable {
    case threeDS = "3ds", psp, ps1, gamecube
    var id: String { rawValue }
    var available: Bool { self == .threeDS }
    static var visibleSystems: [ConsoleSystem] { [.threeDS] }
    var shortName: String {
        switch self { case .threeDS: "3DS"; case .psp: "PSP"; case .ps1: "PS1"; case .gamecube: "GC" }
    }
    var name: String {
        switch self { case .threeDS: "Nintendo 3DS"; case .psp: "PlayStation Portable"; case .ps1: "PlayStation"; case .gamecube: "GameCube" }
    }
    var color: Color {
        switch self { case .threeDS: ConsoleTheme.blue; case .psp: Color(red: 0.65, green: 0.63, blue: 1); case .ps1: Color(red: 1, green: 0.73, blue: 0.5); case .gamecube: Color(red: 0.78, green: 0.61, blue: 1) }
    }
    var symbol: String {
        switch self { case .threeDS: "rectangle.split.1x2"; case .psp: "gamecontroller"; case .ps1: "opticaldisc"; case .gamecube: "cube" }
    }
}

/// Original hardware-inspired silhouettes, without platform logos.
struct ConsoleEmblem: View {
    let system: ConsoleSystem
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32).fill(system.color.opacity(0.07))
                .overlay { RoundedRectangle(cornerRadius: 32).strokeBorder(system.color.opacity(0.2), lineWidth: 1) }
                .rotationEffect(.degrees(-8))
            if system == .psp {
                HStack(spacing: 13) {
                    Image(systemName: "plus").font(.system(size: 25, weight: .light))
                    RoundedRectangle(cornerRadius: 5).fill(system.color.opacity(0.2)).frame(width: 69, height: 42)
                        .overlay { Image(systemName: "sparkle").font(.system(size: 21, weight: .ultraLight)) }
                    Image(systemName: "circle.dotted").font(.system(size: 25, weight: .light))
                }.padding(14).background(system.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                    .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(system.color.opacity(0.65), lineWidth: 1) }
            } else if system == .ps1 {
                RoundedRectangle(cornerRadius: 14).fill(system.color.opacity(0.1)).frame(width: 160, height: 97)
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(system.color.opacity(0.6), lineWidth: 1) }
                    .overlay {
                        HStack(spacing: 15) {
                            Circle().fill(system.color.opacity(0.7)).frame(width: 6, height: 6)
                            Image(systemName: "opticaldisc").font(.system(size: 65, weight: .ultraLight))
                            VStack(spacing: 4) { ForEach(0..<5) { _ in Capsule().fill(system.color.opacity(0.4)).frame(width: 11, height: 2) } }
                        }
                    }.rotation3DEffect(.degrees(24), axis: (x: 1, y: 0, z: 0))
            } else {
                Image(systemName: system.symbol).font(.system(size: 112, weight: .ultraLight))
            }
        }.foregroundStyle(system.color).frame(width: 200, height: 164)
            .shadow(color: system.color.opacity(0.18), radius: 35).accessibilityHidden(true)
    }
}
