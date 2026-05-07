import SwiftUI

// MARK: - AppTab (used by ContentView)

enum AppTab: Int, CaseIterable, Identifiable {
    case universe = 0
    case search   = 1
    case activity = 2
    case ranking  = 3
    case profile  = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .universe: return "Stelr"
        case .search:   return "Search"
        case .activity: return "Activity"
        case .ranking:  return "Rankings"
        case .profile:  return "Me"
        }
    }

    var icon: String {
        switch self {
        case .universe: return "sparkles"
        case .search:   return "magnifyingglass"
        case .activity: return "waveform.path.ecg"
        case .ranking:  return "chart.bar.fill"
        case .profile:  return "person.fill"
        }
    }
}

// MARK: - FloatingTabBar (original design, AppTab-based)

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var onSelect: ((AppTab) -> Void)? = nil

    @Namespace private var bubbleNamespace
    private let mainTabs: [AppTab] = [.universe, .activity, .ranking, .profile]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(mainTabs) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.18), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .fill(Color.white.opacity(0.030))
                    .allowsHitTesting(false)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.075), lineWidth: 0.6)
                    .allowsHitTesting(false)
            )
            .contentShape(Capsule())
            .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 9)

            searchIsland
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .animation(.easeInOut(duration: 0.28), value: selection)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = tab == selection

        return Button {
            select(tab)
        } label: {
            HStack(spacing: isSelected ? 5 : 0) {
                tabIcon(tab, isSelected: isSelected)

                if isSelected {
                    Text(tab.label)
                        .font(StelrTypography.tabLabel)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)),
                                removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading))
                            )
                        )
                }
            }
            .foregroundColor(isSelected ? .white.opacity(0.96) : Color.stelrMuted.opacity(0.58))
            .padding(.horizontal, isSelected ? 12 : 8)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(Color.stelrAccent.opacity(0.88))
                            .background(.thinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.6))
                            .matchedGeometryEffect(id: "bubble", in: bubbleNamespace)
                    }
                }
            )
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.stelrPress)
    }

    @ViewBuilder
    private func tabIcon(_ tab: AppTab, isSelected: Bool) -> some View {
        if tab == .universe {
            StelrFourPointStar(variant: .twinkle)
                .fill(isSelected ? Color.white : Color.stelrMuted.opacity(0.55))
                .frame(width: 15, height: 15)
                .shadow(color: isSelected ? Color.white.opacity(0.10) : .clear, radius: 4)
                .frame(width: 17, height: 17)
        } else {
            Image(systemName: tab.icon)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 17)
        }
    }

    private var searchIsland: some View {
        let isSelected = selection == .search

        return Button {
            select(.search)
        } label: {
            Image(systemName: AppTab.search.icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(isSelected ? .white.opacity(0.96) : Color.stelrMuted.opacity(0.68))
                .frame(width: 50, height: 50)
                .background(
                    Group {
                        if isSelected {
                            Circle()
                                .fill(Color.stelrAccent.opacity(0.88))
                                .background(.thinMaterial, in: Circle())
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.18))
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().fill(Color.white.opacity(0.030)))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 0.10 : 0.075), lineWidth: 0.6)
                        .allowsHitTesting(false)
                )
                .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 9)
                .contentShape(Circle())
        }
        .buttonStyle(.stelrPress)
        .accessibilityLabel(AppTab.search.label)
    }

    private func select(_ tab: AppTab) {
        StelrHaptics.selection()
        if let onSelect {
            onSelect(tab)
        } else {
            selection = tab
        }
    }
}

// MARK: - BottomTabBar (Int-based wrapper for legacy call sites)

struct BottomTabBar: View {
    @Binding var selectedTab: Int
    var onSelect: ((Int) -> Void)? = nil

    private var selectionBinding: Binding<AppTab> {
        Binding {
            AppTab(rawValue: selectedTab) ?? .universe
        } set: {
            selectedTab = $0.rawValue
        }
    }

    var body: some View {
        FloatingTabBar(selection: selectionBinding) { tab in
            if let onSelect { onSelect(tab.rawValue) } else { selectedTab = tab.rawValue }
        }
    }
}
