import AppIntents
import SwiftUI
import WidgetKit

struct ClueTimelineEntry: TimelineEntry {
  let date: Date
  let totalCount: Int
  /// The first row also holds the "All" chip, which isn't listed here.
  let chipRows: [[WidgetCategory]]
  let activeFilter: String?
  let items: [WidgetItem]
  let columns: Int
}

struct ClueTimelineProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ClueTimelineEntry {
    previewEntry(in: context)
  }

  func snapshot(
    for configuration: ClueWidgetConfigurationIntent,
    in context: Context
  ) async -> ClueTimelineEntry {
    context.isPreview ? previewEntry(in: context) : currentEntry(for: configuration, in: context)
  }

  func timeline(
    for configuration: ClueWidgetConfigurationIntent,
    in context: Context
  ) async -> Timeline<ClueTimelineEntry> {
    let entry = currentEntry(for: configuration, in: context)
    let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    return Timeline(entries: [entry], policy: .after(next))
  }

  private func currentEntry(
    for configuration: ClueWidgetConfigurationIntent,
    in context: Context
  ) -> ClueTimelineEntry {
    let snapshot = WidgetDataStore.loadSnapshot()
    let layout = WidgetLayout(family: context.family, size: context.displaySize)
    let activeFilter = WidgetDataStore.activeFilter(in: snapshot)
    let chipRows = layout.chipRows(
      for: WidgetDataStore.chipCategories(from: snapshot, preferred: configuration.preferredIcons),
      keeping: snapshot.categories.first(where: { $0.icon == activeFilter })
    )
    let matching = WidgetDataStore.matchingItems(from: snapshot)
    return ClueTimelineEntry(
      date: Date(),
      totalCount: snapshot.items.count,
      chipRows: chipRows,
      activeFilter: activeFilter,
      items: Array(matching.prefix(layout.itemCapacity(chipRows: chipRows.count))),
      columns: layout.columns
    )
  }

  private func previewEntry(in context: Context) -> ClueTimelineEntry {
    let items = [
      WidgetItem(
        id: "1",
        title: "Hotel Room Number",
        content: "412",
        icon: "bed",
        isPinned: false,
        hasTitle: true,
        displayTitle: "Hotel Room Number"
      ),
      WidgetItem(
        id: "2",
        title: "Address",
        content: "12 Pine Street",
        icon: "pin",
        isPinned: true,
        hasTitle: true,
        displayTitle: "Address"
      ),
      WidgetItem(
        id: "3",
        title: "ID Number",
        content: "A18422",
        icon: "person-square",
        isPinned: false,
        hasTitle: true,
        displayTitle: "ID Number"
      ),
      WidgetItem(
        id: "4",
        title: "",
        content: "040323624",
        icon: "phone",
        isPinned: false,
        hasTitle: false,
        displayTitle: "040323624"
      ),
    ]
    let categories = items.map { WidgetCategory(icon: $0.icon, count: 1) }
    let layout = WidgetLayout(family: context.family, size: context.displaySize)
    let chipRows = layout.chipRows(for: categories, keeping: nil)
    return ClueTimelineEntry(
      date: Date(),
      totalCount: items.count,
      chipRows: chipRows,
      activeFilter: nil,
      items: items.filter(\.isPinned) + items.filter { !$0.isPinned },
      columns: layout.columns
    )
  }
}

/// Fixed metrics shared by the timeline (to decide what fits) and the view.
struct WidgetLayout {
  static let padding: CGFloat = 16
  static let headerHeight: CGFloat = 32
  static let chipHeight: CGFloat = 28
  static let chipWidth: CGFloat = 48
  static let allChipWidth: CGFloat = 64
  static let chipSpacing: CGFloat = 6
  static let sectionSpacing: CGFloat = 12
  static let rowHeight: CGFloat = 36
  static let rowSpacing: CGFloat = 6

  let family: WidgetFamily
  let size: CGSize

  var columns: Int { family == .systemExtraLarge ? 2 : 1 }

  private var contentWidth: CGFloat { size.width - Self.padding * 2 }

  private var chipsBesideAll: Int {
    max(0, Int((contentWidth - Self.allChipWidth) / (Self.chipWidth + Self.chipSpacing)))
  }

  private var chipsPerFullRow: Int {
    max(1, Int((contentWidth + Self.chipSpacing) / (Self.chipWidth + Self.chipSpacing)))
  }

  /// One row when everything fits beside "All", otherwise two. `selected` replaces the
  /// last visible chip when it would otherwise be cut off.
  func chipRows(for categories: [WidgetCategory], keeping selected: WidgetCategory?) -> [[WidgetCategory]] {
    let firstRow = chipsBesideAll
    let limit = categories.count <= firstRow ? firstRow : firstRow + chipsPerFullRow
    var visible = Array(categories.prefix(limit))
    if let selected, !visible.contains(selected) {
      if visible.count < limit {
        visible.append(selected)
      } else if !visible.isEmpty {
        visible[visible.count - 1] = selected
      }
    }
    let second = Array(visible.dropFirst(firstRow))
    return second.isEmpty ? [Array(visible.prefix(firstRow))] : [Array(visible.prefix(firstRow)), second]
  }

  func itemCapacity(chipRows: Int) -> Int {
    let chipBlock = CGFloat(chipRows) * Self.chipHeight + CGFloat(max(0, chipRows - 1)) * Self.chipSpacing
    let available = size.height
      - Self.padding * 2
      - Self.headerHeight
      - chipBlock
      - Self.sectionSpacing * 2
    let rows = Int((available + Self.rowSpacing) / (Self.rowHeight + Self.rowSpacing))
    return max(1, rows) * columns
  }
}

struct ClueWidget: Widget {
  static let kind = "ClueWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: Self.kind,
      intent: ClueWidgetConfigurationIntent.self,
      provider: ClueTimelineProvider()
    ) { entry in
      ClueWidgetView(entry: entry)
        .modifier(WidgetCardBackground())
    }
    .configurationDisplayName("Clue")
    .description("Forgotten things — copy at a glance.")
    .supportedFamilies([.systemLarge, .systemExtraLarge])
    .contentMarginsDisabled()
  }
}

struct ClueWidgetView: View {
  let entry: ClueTimelineEntry
  @Environment(\.colorScheme) private var colorScheme

  private var isDark: Bool { colorScheme == .dark }
  private var accent: Color { Color(uiColor: WidgetPalette.ocean300) }
  private var primaryText: Color { isDark ? .white : Color(uiColor: WidgetPalette.ocean900) }

  var body: some View {
    VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
      header
      if entry.totalCount > 0 {
        chipBlock
      }
      itemList
    }
    .padding(WidgetLayout.padding)
  }

  private var header: some View {
    HStack(spacing: 8) {
      openClueLink {
        Group {
          if let logo = WidgetDataStore.logoImage() {
            Image(uiImage: logo)
              .resizable()
              .scaledToFit()
              .frame(height: WidgetLayout.headerHeight)
          } else {
            Text("Clue")
              .font(.system(size: 22, weight: .bold, design: .rounded))
              .foregroundStyle(accent)
          }
        }
      }
      .accessibilityLabel("Open Clue")

      Spacer(minLength: 0)
    }
    .frame(height: WidgetLayout.headerHeight)
  }

  // MARK: Chips

  private var chipBlock: some View {
    VStack(alignment: .leading, spacing: WidgetLayout.chipSpacing) {
      ForEach(Array(entry.chipRows.enumerated()), id: \.offset) { index, row in
        HStack(spacing: WidgetLayout.chipSpacing) {
          if index == 0 {
            chip(icon: nil, count: entry.totalCount)
          }
          ForEach(row, id: \.icon) { category in
            chip(icon: category.icon, count: category.count)
          }
          Spacer(minLength: 0)
        }
        .frame(height: WidgetLayout.chipHeight)
      }
    }
  }

  private func chip(icon: String?, count: Int) -> some View {
    let isSelected = entry.activeFilter == icon
    let foreground = isSelected ? Color.white : primaryText
    return Button(intent: FilterCategoryIntent(icon: icon ?? "")) {
      HStack(spacing: 4) {
        if let icon {
          categoryIcon(icon, size: 14)
            .foregroundStyle(isSelected ? Color.white : accent)
        } else {
          Text("All")
            .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        Text("\(count)")
          .font(.system(size: 13, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .minimumScaleFactor(0.7)
      }
      .foregroundStyle(foreground)
      .lineLimit(1)
      .padding(.horizontal, 6)
      .frame(
        width: icon == nil ? WidgetLayout.allChipWidth : WidgetLayout.chipWidth,
        height: WidgetLayout.chipHeight
      )
      .background(
        Capsule().fill(isSelected ? accent : Color.clear)
      )
      .overlay(
        Capsule().stroke(
          isSelected ? Color.clear : (isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)),
          lineWidth: 1
        )
      )
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      icon.map { "Show \(count) \(WidgetDataStore.displayName(for: $0)) items" }
        ?? "Show all \(count) items"
    )
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: Items

  @ViewBuilder
  private var itemList: some View {
    if entry.items.isEmpty {
      Text("No forgotten things yet.")
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundStyle(Color(uiColor: WidgetPalette.charcoal500))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    } else {
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), spacing: 12),
          count: entry.columns
        ),
        spacing: WidgetLayout.rowSpacing
      ) {
        ForEach(entry.items) { item in
          itemRow(item)
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
  }

  private func copyURL(for item: WidgetItem) -> URL {
    var components = URLComponents()
    components.scheme = "forgotten-things"
    components.host = "copy"
    components.queryItems = [URLQueryItem(name: "id", value: item.id)]
    return components.url ?? URL(string: "forgotten-things://copy")!
  }

  private func itemRow(_ item: WidgetItem) -> some View {
    // Widget extensions can't write the pasteboard, so the tap opens Clue to copy.
    Link(destination: copyURL(for: item)) {
      HStack(spacing: 10) {
        categoryIcon(item.icon, size: 18)
          .foregroundStyle(accent)
        Text(item.displayTitle)
          .font(.system(size: 15, weight: item.hasTitle ? .bold : .regular, design: .rounded))
          .foregroundStyle(primaryText)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        copyGlyph
      }
      .padding(.horizontal, 12)
      .frame(height: WidgetLayout.rowHeight)
      .background(rowBackground)
      .overlay(rowBorder)
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .accessibilityLabel("Copy \(item.displayTitle)")
  }

  private func openClueLink<Label: View>(@ViewBuilder label: () -> Label) -> some View {
    Link(destination: URL(string: "forgotten-things://open")!) {
      label()
    }
  }

  @ViewBuilder
  private func categoryIcon(_ icon: String, size: CGFloat) -> some View {
    if let image = WidgetDataStore.iconImage(named: icon) {
      Image(uiImage: image)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    } else {
      Image(systemName: "note.text")
        .font(.system(size: size - 3, weight: .medium))
        .frame(width: size, height: size)
    }
  }

  private var copyGlyph: some View {
    Group {
      if let copy = WidgetDataStore.copyImage() {
        Image(uiImage: copy)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "square.on.square")
          .font(.system(size: 14, weight: .regular))
      }
    }
    .frame(width: 18, height: 18)
    .foregroundStyle(isDark ? Color.white.opacity(0.55) : Color(uiColor: WidgetPalette.charcoal500))
  }

  private var rowBackground: some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(isDark ? Color.white.opacity(0.06) : Color(uiColor: WidgetPalette.charcoal50))
  }

  private var rowBorder: some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .stroke(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.12), lineWidth: 1)
  }
}

private struct WidgetCardBackground: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content.containerBackground(for: .widget) {
      colorScheme == .dark ? Color(uiColor: WidgetPalette.charcoal900) : Color.white
    }
  }
}

@main
struct ClueWidgetBundle: WidgetBundle {
  var body: some Widget {
    ClueWidget()
  }
}
