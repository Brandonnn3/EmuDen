import SwiftUI
import WidgetKit

struct EmuDenWidgetEntry: TimelineEntry {
    let date: Date
    let library: WidgetLibrary
    let directory: URL?
}
struct EmuDenWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmuDenWidgetEntry { current() }
    func getSnapshot(in context: Context, completion: @escaping (EmuDenWidgetEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EmuDenWidgetEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(1800))))
    }
    private func current() -> EmuDenWidgetEntry {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetLibrary.groupID)?.appendingPathComponent(WidgetLibrary.directoryName, isDirectory: true)
        return EmuDenWidgetEntry(date: Date(), library: directory.flatMap { WidgetLibrary.read(from: $0) } ?? .empty, directory: directory)
    }
}
struct EmuDenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var rendering
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let entry: EmuDenWidgetEntry
    var recent = false
    var body: some View {
        EmuDenWidgetContent(library: entry.library, directory: entry.directory, recent: recent, compact: family == .systemSmall, fullColor: rendering == .fullColor && showsBackground)
            .containerBackground(for: .widget) { Color(red: 0.025, green: 0.045, blue: 0.09) }
            .widgetURL(recent ? URL(string: "emuden://library") : entry.library.games.first?.link ?? URL(string: "emuden://library"))
    }
}
struct ContinuePlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetLibrary.continueKind, provider: EmuDenWidgetProvider()) { EmuDenWidgetView(entry: $0) }
            .configurationDisplayName("Continue Playing")
            .description("Your next session, one tap away.")
            .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}
struct RecentGamesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetLibrary.recentKind, provider: EmuDenWidgetProvider()) { EmuDenWidgetView(entry: $0, recent: true) }
            .configurationDisplayName("Recent Games")
            .description("A cinematic shelf for your recent games.")
            .supportedFamilies([.systemMedium, .systemLarge]).contentMarginsDisabled()
    }
}
@main struct EmuDenWidgets: WidgetBundle {
    var body: some Widget { ContinuePlayingWidget(); RecentGamesWidget() }
}
