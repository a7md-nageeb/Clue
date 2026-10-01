import AppIntents
import WidgetKit

struct ClueWidgetConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Clue"
  static var description: IntentDescription = "Choose which categories appear as chips."

  @Parameter(title: "Categories")
  var categories: [WidgetCategoryEntity]?

  var preferredIcons: [String] {
    categories?.map(\.id) ?? []
  }
}

struct WidgetCategoryEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
  static var defaultQuery = WidgetCategoryQuery()

  let id: String
  let count: Int

  var displayRepresentation: DisplayRepresentation {
    let image = WidgetDataStore.iconData(named: id).map {
      DisplayRepresentation.Image(data: $0, isTemplate: true)
    }
    return DisplayRepresentation(
      title: "\(WidgetDataStore.displayName(for: id))",
      subtitle: "\(count) \(count == 1 ? "item" : "items")",
      image: image
    )
  }
}

struct WidgetCategoryQuery: EntityQuery {
  func entities(for identifiers: [WidgetCategoryEntity.ID]) async throws -> [WidgetCategoryEntity] {
    let categories = WidgetDataStore.loadSnapshot().categories
    return identifiers.map { icon in
      WidgetCategoryEntity(id: icon, count: categories.first(where: { $0.icon == icon })?.count ?? 0)
    }
  }

  func suggestedEntities() async throws -> [WidgetCategoryEntity] {
    WidgetDataStore.loadSnapshot().categories.map {
      WidgetCategoryEntity(id: $0.icon, count: $0.count)
    }
  }
}

struct FilterCategoryIntent: AppIntent {
  static var title: LocalizedStringResource = "Filter Category"
  static var isDiscoverable = false
  static var openAppWhenRun = false

  @Parameter(title: "Icon")
  var icon: String

  init() {
    icon = ""
  }

  init(icon: String) {
    self.icon = icon
  }

  func perform() async throws -> some IntentResult {
    let current = WidgetDataStore.selectedFilter
    if icon.isEmpty || current == icon {
      WidgetDataStore.selectedFilter = nil
    } else {
      WidgetDataStore.selectedFilter = icon
    }
    WidgetCenter.shared.reloadTimelines(ofKind: ClueWidget.kind)
    return .result()
  }
}
