import SwiftUI
import UIKit

struct WheelScreen: View {
    let list: FoodList
    let store: MealStore
    var scrollsInternally = true
    @Binding var spinning: Bool
    var edit: () -> Void
    var share: () -> Void
    @State private var rotation = 0.0
    @State private var result: String?
    @State private var activeSpin: UUID?
    @State private var showingOptions = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var reduceMotion: Bool { systemReduceMotion || (ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--reduce-motion")) }
    private var participating: [String] { store.participatingItems(in: list) }
    private var pausedCount: Int { list.items.count - participating.count }

    var body: some View {
        Group {
            if scrollsInternally {
                GeometryReader { geometry in
                    ScrollView {
                        wheelContent(diameter: wheelSize(geometry))
                            .frame(minHeight: geometry.size.height, alignment: .center)
                    }.scrollIndicators(.automatic)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
            } else {
                VStack(spacing: 0) {
                    wheelContent(diameter: 260)
                    actionBar
                }
            }
        }
        .sheet(isPresented: $showingOptions) { optionsSheet }
        .onChange(of: participating) { _, _ in
            activeSpin = nil
            spinning = false
            rotation = 0
            result = nil
        }
        .onDisappear { activeSpin = nil; spinning = false }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private func wheelContent(diameter: CGFloat) -> some View {
        VStack(spacing: 20) {
            if list.items.isEmpty {
                ContentUnavailableView("轉盤還空著呢", systemImage: "carrot", description: Text("先放進幾個想吃的，\n下一餐就不用再煩惱。"))
            } else if participating.isEmpty {
                ContentUnavailableView("沒有參與抽選的項目", systemImage: "checklist", description: Text("項目都還在清單裡。\n重新勾選幾個，就能繼續轉動。"))
                optionControls
            } else {
                wheel(diameter: diameter)
                    .frame(width: diameter, height: diameter)
                    .padding(.top, 12)
                resultCard
                optionControls
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .frame(maxWidth: 580).frame(maxWidth: .infinity)
    }

    private func wheelSize(_ geometry: GeometryProxy) -> CGFloat {
        min(geometry.size.width - 48, max(250, geometry.size.height - (typeSize.isAccessibilitySize ? 300 : 230)), 360)
    }

    private func wheel(diameter: CGFloat) -> some View {
        ZStack {
            Circle().fill(Theme.card)
                .shadow(color: Theme.wheelInk.opacity(0.08), radius: 18, x: 0, y: 12)
            GeometryReader { proxy in
                let radius = proxy.size.width / 2
                ForEach(0..<48, id: \.self) { tick in
                    Circle().fill(Theme.muted.opacity(tick % 4 == 0 ? 0.5 : 0.2))
                        .frame(width: tick % 4 == 0 ? 3 : 2, height: tick % 4 == 0 ? 3 : 2)
                        .position(x: radius + cos(Double(tick) * .pi / 24) * (radius - 7), y: radius + sin(Double(tick) * .pi / 24) * (radius - 7))
                }
            }.accessibilityHidden(true)
            WheelDisc(items: participating).rotationEffect(.degrees(rotation)).padding(16)
            Circle().fill(Theme.card).frame(width: min(64, diameter * 0.19), height: min(64, diameter * 0.19))
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                .overlay(Image(systemName: "fork.knife").font(.system(size: min(23, diameter * 0.07), weight: .semibold)).foregroundStyle(Theme.orange))
                .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
            VStack {
                Pointer().fill(Theme.ink).frame(width: 24, height: 30)
                    .overlay(Circle().fill(Theme.card).frame(width: 5, height: 5).offset(y: -7))
                    .offset(y: -4)
                Spacer()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("食物轉盤，\(participating.count) 個項目參與抽選，\(pausedCount) 個暫停")
        .accessibilityValue(spinning ? String(localized: "轉動中") : result ?? String(localized: "尚未抽選"))
    }

    private var resultCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if result != nil { Image(systemName: "checkmark.seal.fill") }
                Text(spinning ? String(localized: "正在挑選你的下一餐") : result == nil ? String(localized: "今天的美味，交給一點運氣") : String(localized: "今天就吃這個"))
            }.font(.caption.weight(.medium)).foregroundStyle(result == nil ? Theme.muted : Theme.green)
            Text(spinning ? String(localized: "讓轉盤想一下⋯") : result ?? String(localized: "準備好開動了嗎？"))
                .font(.system(result == nil ? .title3 : .title, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("spinResult")
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(result == nil ? Color.clear : Theme.greenWash, in: RoundedRectangle(cornerRadius: 22))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: result)
    }

    private var optionControls: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button { showingOptions = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text(pausedCount == 0 ? String(localized: "\(list.items.count) 個選項") : String(localized: "\(participating.count)/\(list.items.count) 項參與"))
                }.font(.subheadline).foregroundStyle(Theme.muted).frame(minHeight: 44)
            }.accessibilityLabel("選擇本次參與項目，目前\(participating.count)個參與，\(pausedCount)個暫停").accessibilityIdentifier("participationOptions").disabled(spinning)
            if !typeSize.isAccessibilitySize { Spacer() }
            Button("分享", systemImage: "square.and.arrow.up", action: share)
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.orange).frame(minHeight: 44)
                .padding(.horizontal, 8).disabled(spinning).accessibilityLabel("分享清單")
            Button("編輯", systemImage: "pencil", action: edit)
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.orange).frame(minHeight: 44)
                .disabled(spinning).accessibilityLabel("編輯選項")
        }.buttonStyle(PressButtonStyle())
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                HStack(spacing: 10) {
                    if spinning { ProgressView().tint(.white) }
                    else { Image(systemName: list.items.isEmpty ? "plus" : participating.isEmpty ? "checklist" : "arrow.2.circlepath") }
                    Text(list.items.isEmpty ? String(localized: "加入想吃的選項") : participating.isEmpty ? String(localized: "選擇參與項目") : spinning ? String(localized: "美味決定中⋯") : result == nil ? String(localized: "轉一下，決定吃什麼") : String(localized: "再轉一次"))
                        .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                }
            }.buttonStyle(PrimaryButtonStyle()).disabled(spinning).accessibilityIdentifier("spinButton")
            Text(list.items.isEmpty ? String(localized: "從餐廳、料理到小吃，都可以加入") : pausedCount > 0 ? String(localized: "本次 \(participating.count) 項參與 · \(pausedCount) 項暫停，未刪除") : String(localized: "每個選項機率相同 · 只儲存在你的手機"))
                .accessibilityIdentifier("participationStatus")
                .font(.caption2).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
        .frame(maxWidth: 580).frame(maxWidth: .infinity)
        .background { Theme.cream.ignoresSafeArea(edges: .bottom).shadow(color: Theme.wheelInk.opacity(0.04), radius: 12, y: -6) }
    }

    private func primaryAction() {
        if list.items.isEmpty { edit() }
        else if participating.isEmpty { showingOptions = true }
        else { spin() }
    }

    private var optionsSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(list.items.enumerated()), id: \.offset) { _, food in
                        let included = store.isParticipating(food, in: list)
                        Button {
                            store.setParticipation(food, in: list, enabled: !store.isParticipating(food, in: list))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24)).foregroundStyle(included ? Theme.green : Theme.muted)
                                    .frame(width: 30).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food).foregroundStyle(included ? Theme.ink : Theme.muted)
                                    Text(included ? String(localized: "參與抽選 · \((1.0 / Double(max(participating.count, 1))).formatted(.percent.precision(.fractionLength(1))))") : String(localized: "本次不參與，仍保留在清單"))
                                        .font(.caption).foregroundStyle(Theme.muted)
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).disabled(spinning)
                        .accessibilityLabel(food)
                        .accessibilityValue(included ? String(localized: "參與抽選") : String(localized: "本次暫停"))
                        .accessibilityAddTraits(included ? .isSelected : [])
                        .accessibilityIdentifier("participation-\(food)")
                        .accessibilityHint("只影響本次轉盤，不會刪除項目")
                        .padding(.vertical, 6).listRowBackground(Theme.card)
                    }
                } header: { Text("\(participating.count) 項參與 · \(pausedCount) 項暫停") }
                footer: { Text("點一下取消勾選即可暫時排除，不會刪除項目。切換清單仍保留本次設定；重開 App 會恢復全部參與。分享與編輯仍保留完整清單。") }
            }.scrollContentBackground(.hidden).background(Theme.cream)
                .navigationTitle("本次參與項目").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("全部參與") { store.includeAll(in: list) }
                            .disabled(pausedCount == 0 || spinning).accessibilityIdentifier("includeAllOptions")
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { showingOptions = false } }
                }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }

    private func spin() {
        let candidates = participating
        guard !spinning, !candidates.isEmpty else { return }
        let index = Int.random(in: candidates.indices)
        let request = UUID()
        activeSpin = request
        spinning = true
        result = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let target = WheelMath.targetRotation(current: rotation, index: index, count: candidates.count, turns: reduceMotion ? 0 : Int.random(in: 5...7))
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { rotation = target }
            finishSpin(request, food: candidates[index])
        } else {
            withAnimation(.timingCurve(0.12, 0.75, 0.12, 1, duration: 3.4), completionCriteria: .removed) {
                rotation = target
            } completion: {
                finishSpin(request, food: candidates[index])
            }
        }
    }

    private func finishSpin(_ request: UUID, food: String) {
        guard activeSpin == request else { return }
        activeSpin = nil
        result = food
        spinning = false
        store.record(food: food, list: list)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "今天吃\(food)"))
    }

}

struct WheelDisc: View {
    let items: [String]
    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let angle = Double(index) * 360 / Double(items.count)
                    let mid = angle + 180 / Double(items.count) - 90
                    Sector(start: angle - 90, end: angle + 360 / Double(items.count) - 90, fullCircle: items.count == 1)
                        .fill(Theme.colors[index % Theme.colors.count])
                        .overlay(Sector(start: angle - 90, end: angle + 360 / Double(items.count) - 90, fullCircle: items.count == 1).stroke(Theme.card.opacity(0.65), lineWidth: 1.5))
                    if items.count <= 16 {
                        Text(item).font(.system(size: items.count > 10 ? min(11, radius * 0.1) : min(15, radius * 0.12), weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.wheelInk).lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: radius * 0.68)
                            .rotationEffect(.degrees(mid + (mid > 90 && mid < 270 ? 180 : 0)))
                            .position(x: radius + cos(mid * .pi / 180) * radius * 0.62, y: radius + sin(mid * .pi / 180) * radius * 0.62)
                    }
                }
            }.clipShape(Circle())
        }
    }
}

struct Pointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 5, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: 6), control: .zero)
        path.addLine(to: CGPoint(x: rect.midX - 3, y: rect.maxY - 3))
        path.addQuadCurve(to: CGPoint(x: rect.midX + 3, y: rect.maxY - 3), control: CGPoint(x: rect.midX, y: rect.maxY + 3))
        path.addLine(to: CGPoint(x: rect.maxX, y: 6))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 5, y: 0), control: CGPoint(x: rect.maxX, y: 0))
        path.closeSubpath()
        return path
    }
}

struct Sector: Shape {
    let start: Double
    let end: Double
    let fullCircle: Bool
    func path(in rect: CGRect) -> Path {
        if fullCircle { return Path(ellipseIn: rect) }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview { ContentView(store: MealStore(file: URL.temporaryDirectory.appending(path: "meal-preview.json"))) }
