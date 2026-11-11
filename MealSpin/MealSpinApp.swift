import SwiftUI

@main struct MealSpinApp: App {
    @State private var store: MealStore
    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing") {
            let file = URL.documentsDirectory.appending(path: "ui-tests.json")
            let backups = URL.documentsDirectory.appending(path: "UITest Recovery", directoryHint: .isDirectory)
            if args.contains("--reset-test-data") {
                try? FileManager.default.removeItem(at: file)
                try? FileManager.default.removeItem(at: backups)
                UserDefaults.standard.removeObject(forKey: "selectedFoodList")
            }
            if args.contains("--corrupt-test-data") { try? Data("invalid test data".utf8).write(to: file) }
            _store = State(initialValue: MealStore(file: file, backupDirectory: backups))
        } else {
            _store = State(initialValue: MealStore())
        }
    }
    private var testMaximumType: Bool { ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--maximum-type") }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Theme.orange)
                .onAppear {
                    if testMaximumType {
                        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                            scene.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
                        }
                    }
                }
                .alert("資料儲存提醒", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("知道了") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}

enum Theme {
    static let orange = dynamic(0xC23D19, 0xFFAF8B)
    static let action = Color(red: 0.76, green: 0.24, blue: 0.10)
    static let cream = dynamic(0xFAF8F3, 0x171918)
    static let card = dynamic(0xFFFFFF, 0x232624)
    static let ink = dynamic(0x263E37, 0xF1F3ED)
    static let muted = dynamic(0x69716B, 0xADB5AF)
    static let line = dynamic(0xE8E9E0, 0x383E39)
    static let orangeWash = dynamic(0xFAEDE2, 0x432E25)
    static let green = dynamic(0x32654F, 0xADD8BB)
    static let greenWash = dynamic(0xEAF2E8, 0x293D30)
    static let wheelInk = Color(red: 0.16, green: 0.23, blue: 0.19)
    static let colors: [Color] = [0xEDBFA6, 0xF0D99E, 0xBDCEB0, 0xABCBCD, 0xD1BDCE, 0xE4CAB4].map { Color(uiColor: uiColor($0)) }
    private static func uiColor(_ hex: Int) -> UIColor {
        UIColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
    }
    private static func dynamic(_ light: Int, _ dark: Int) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }
}

struct PressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(!enabled ? 0.5 : configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RoundButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.labelStyle(.iconOnly).font(.system(size: 18, weight: .medium))
            .foregroundStyle(Theme.ink).frame(width: 44, height: 44)
            .background(configuration.isPressed ? Theme.line : Theme.card, in: Circle())
            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            .opacity(enabled ? 1 : 0.45)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 4)
            .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.action.opacity(enabled ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 19))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
