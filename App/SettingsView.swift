import SwiftUI
import UniformTypeIdentifiers
import StoreKit

struct SystemSetupView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @State private var playerSettings = false
    @State private var miiSetup = false
    @State private var duoLayout = false
    @State private var importingAvatar = false
    @State private var showingWidgets = false
    @State private var soundOptions = false
    @State private var showingNotices = false
    @State private var showingArtworkCatalog = false
    @AppStorage("buttonHaptics") private var haptics = true
        @AppStorage("favoriteConsole") private var favoriteConsole = "3ds"
    @StateObject private var tips = TipJarStore()
    let testCore: () -> Void
    let testControls: () -> Void
    var embedded = false
    var system: ConsoleSystem = .threeDS

    var body: some View {
        Group {
            if embedded { content }
            else {
                NavigationStack {
                    content.background { CinematicScene(game: library.featuredGame.flatMap { $0.console.rawValue == system.rawValue ? $0 : nil }, system: system, subdued: true).ignoresSafeArea() }
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { menuAudio.play(.back); dismiss() }.accessibilityIdentifier("settingsDone") } }
                }
            }
        }.tint(.green).foregroundStyle(.white).buttonStyle(ConsolePressStyle())
            .sheet(isPresented: $playerSettings) { PlayerSettingsView(initialSystem: system) }
            .sheet(isPresented: $showingWidgets) { WidgetShowcaseView() }
            .sheet(isPresented: $miiSetup) { MiiSetupView() }
            .sheet(isPresented: $showingNotices) { OpenSourceNoticesView() }
            .sheet(isPresented: $showingArtworkCatalog) { ArtworkCatalogView() }
            .task { await tips.load() }
            .fullScreenCover(isPresented: $duoLayout) { DuoLayoutSettingsView(system: system) }
            .fileImporter(isPresented: $importingAvatar, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url): Task { await library.importAvatar(url) }
                case .failure(let error): library.error = error.localizedDescription
                }
            }
            .alert("Couldn’t import system data", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
                Button("OK") { library.error = nil }
            } message: { Text(library.error ?? "") }
    }

    private var content: some View {
        GeometryReader { area in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings").font(.system(size: 32, weight: .bold)).cinematicEntrance()
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Your Home console", systemImage: "house").font(.headline)
                        Picker("Favorite console", selection: $favoriteConsole) {
                            ForEach(ConsoleSystem.visibleSystems) { Text($0.name).tag($0.rawValue) }
                        }.accessibilityIdentifier("favoriteConsole")
                        Text("Home opens this console, including when you launch EmuDen. Use the console button at the top to browse another console anytime.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.cinematicCard()
                    let layout = area.size.width >= 650 ? AnyLayout(HStackLayout(alignment: .top, spacing: 22)) : AnyLayout(VStackLayout(spacing: 18))
                    layout {
                        VStack(spacing: 18) { performanceCard; layoutCard }.frame(maxWidth: .infinity)
                        VStack(spacing: 18) { appearanceCard; systemCard }.frame(maxWidth: .infinity)
                    }.cinematicEntrance(delay: 0.04)
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Library & artwork", systemImage: "photo.on.rectangle.angled").font(.headline)
                        Button { showingArtworkCatalog = true; menuAudio.play(.open) } label: {
                            CinematicSettingRow(title: "Artwork catalogs", detail: library.artworkSourceURL == nil && library.boxArtSourceURL == nil ? "Automatic covers & backgrounds" : "Connected · Manage artwork", symbol: "photo.stack")
                        }.accessibilityIdentifier("openArtworkCatalog")
                        Text("Connect an original box-art collection for automatic covers and a separate catalog for backgrounds. You can also choose images from Files. Saved images work offline; no service is enabled by default.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet).accessibilityIdentifier("localArtworkPolicy")
                    }.cinematicCard()
                    if !tips.products.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Support EmuDen", systemImage: "heart.fill").font(.headline)
                            Text("EmuDen is free. If you’d like to support development, you can leave an optional tip. Every feature stays available to everyone.")
                                .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                            ForEach(tips.products) { product in
                                Button { Task { await tips.purchase(product) } } label: {
                                    HStack { Text(product.displayName); Spacer(); Text(product.displayPrice).fontWeight(.semibold) }.frame(minHeight: 44)
                                }.accessibilityIdentifier(product.id)
                            }.disabled(tips.purchasing)
                            if tips.purchasing { ProgressView("Waiting for Apple…") }
                            Text("Optional, repeatable purchases handled by Apple. Tips do not unlock content or features.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        }.cinematicCard()
                            .alert("EmuDen support", isPresented: Binding(get: { tips.message != nil }, set: { if !$0 { tips.message = nil } })) { Button("OK") { tips.message = nil } } message: { Text(tips.message ?? "") }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("About EmuDen", systemImage: "info.circle").font(.headline)
                        Link("Privacy policy", destination: URL(string: "https://emuden-support.headyopossum2.chatgpt.site/privacy.html")!).frame(minHeight: 44).accessibilityIdentifier("privacyPolicyLink")
                        Link("Support", destination: URL(string: "https://emuden-support.headyopossum2.chatgpt.site/support.html")!).frame(minHeight: 44).accessibilityIdentifier("supportLink")
                        Link("Source code & rebuilding", destination: URL(string: "https://emuden-support.headyopossum2.chatgpt.site/source.html")!).frame(minHeight: 44).accessibilityIdentifier("correspondingSourceLink")
                        Link("Bundled software", destination: URL(string: "https://emuden-support.headyopossum2.chatgpt.site/software.html")!).frame(minHeight: 44)
                        Button("Open-source notices", systemImage: "doc.text") {
                            showingNotices = true
                        }.frame(minHeight: 44).accessibilityIdentifier("openSourceNotices")
                    }.frame(maxWidth: .infinity, alignment: .leading).cinematicCard()
                    DisclosureGroup("Help, tests & open-source notices") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button("Launch 3DS test", systemImage: "play.rectangle", action: testCore).frame(minHeight: 44)
                            Button("Test controls", systemImage: "gamecontroller", action: testControls).frame(minHeight: 44)
                            let log = library.storage.savesDirectory.appendingPathComponent("azahar-session.log")
                            if FileManager.default.fileExists(atPath: log.path) {
                                ShareLink(item: log) { Label("Share emulator log", systemImage: "square.and.arrow.up") }.frame(minHeight: 44)
                                Text("Includes device/core settings and game-session messages. You can review it before sharing.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }
                            Text("EmuDen 0.1.0 · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                            Text("Azahar 2127.0-rc1 · GPL-3.0-or-later\n3DS Homebrew Menu 2.4.4 · bundled notice\nMoltenVK 1.4.2 · Apache-2.0").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Text(ConsoleSystem.gameCubeAvailable ? "Play compatible Nintendo 3DS, PlayStation and GameCube software. No commercial games or proprietary system resources are bundled." : "Nintendo 3DS and PlayStation are playable. No commercial games or proprietary system resources are bundled.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Link("Azahar source & release notes", destination: URL(string: "https://github.com/azahar-emu/azahar/releases/tag/2127.0-rc1")!)
                        }.padding(.top, 12)
                    }.font(.caption).foregroundStyle(ConsoleTheme.quiet)
                }.padding(.horizontal, 30).padding(.top, 16).padding(.bottom, 18).frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Graphics & display", systemImage: "sparkles.tv").font(.headline)
            Text("Choose resolution, textures and picture sizing for each console.").font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
            Button { menuAudio.play(.open); playerSettings = true } label: {
                CinematicSettingRow(title: "Graphics settings", detail: system.name + " · App defaults & game overrides", symbol: "slider.horizontal.3")
            }.accessibilityIdentifier("advancedPlayerSettings")
        }.cinematicCard()
    }
    private var systemCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Console setup", systemImage: "externaldrive").font(.headline)
            Button { menuAudio.play(.open); miiSetup = true } label: {
                CinematicSettingRow(title: "3DS system & Miis", detail: library.mii.archiveFound ? "Original face resources ready" : "Import resources or choose a profile picture", symbol: "person.crop.circle")
            }.accessibilityIdentifier("openMiiSetup")
            Button { menuAudio.play(.open); importingAvatar = true } label: {
                HStack(spacing: 12) {
                    Group {
                        if let image = library.miiAvatar { Image(uiImage: image).resizable().scaledToFill().accessibilityIdentifier("customMiiAvatar") }
                        else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit() }
                    }.frame(width: 38, height: 38).clipShape(Circle())
                    Text("Profile picture").font(.subheadline)
                    Spacer(); Image(systemName: "photo")
                }.frame(minHeight: 44)
            }.accessibilityIdentifier("miiAvatar").accessibilityLabel("Choose Mii profile picture")
                .accessibilityValue(library.miiAvatar == nil ? "Default portrait" : "Custom portrait")
                .contextMenu { if library.miiAvatar != nil { Button("Reset profile picture", role: .destructive) { library.resetAvatar() } } }
            Text("PlayStation BIOS and save options are in Graphics settings → Saves & system.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
        }.cinematicCard()
    }
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Appearance", systemImage: "paintpalette").font(.headline)
            Toggle("Menu sounds", isOn: $menuAudio.enabled).accessibilityIdentifier("menuSoundsEnabled").font(.subheadline)
                .onChange(of: menuAudio.enabled) { _, enabled in if enabled { menuAudio.play(.confirm) } }
            Button { menuAudio.play(.open); showingWidgets = true } label: {
                CinematicSettingRow(title: "Home Screen widgets", detail: "Continue playing and your recent shelf", symbol: "rectangle.grid.1x2")
            }.accessibilityIdentifier("widgetShowcase")
            Toggle("Haptics", isOn: $haptics).font(.subheadline).onChange(of: haptics) { _, _ in menuAudio.play(.focus) }
            DisclosureGroup("Sound options", isExpanded: $soundOptions) {
                VStack(alignment: .leading, spacing: 12) {
                    Slider(value: $menuAudio.volume, in: 0...1, onEditingChanged: { editing in if !editing { menuAudio.play(.confirm) } }).accessibilityLabel("Menu sound volume").disabled(!menuAudio.enabled)
                    Button { menuAudio.play(.confirm) } label: { Label("Preview chime", systemImage: "play.circle") }.accessibilityIdentifier("previewMenuSound").disabled(!menuAudio.enabled || menuAudio.volume == 0)
                    Text("Original glass tones. Follows Silent Mode and pauses during gameplay.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                }.padding(.top, 10)
            }.font(.caption)
        }.cinematicCard()
    }
    private var layoutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Controls & Duo", systemImage: "gamecontroller").font(.headline)
            Button { menuAudio.play(.open); duoLayout = true } label: {
                CinematicSettingRow(title: "Duo layout", detail: system.name + " · Skin and controller display", symbol: "rectangle.split.1x2")
            }.accessibilityIdentifier("openDuoLayout")
            Text("To move touch buttons and sticks, open a game, then Game menu → More → Customize controls. Layouts are saved separately for each console and orientation.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
        }.cinematicCard()
    }

}

private struct OpenSourceNoticesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var introduction = ""
    private struct Notice: Decodable { let source: String; let text: String }
    private struct Document: Decodable { let introduction: String; let notices: [Notice] }
    @State private var sections = [Notice]()
    var body: some View {
        NavigationStack {
            List {
                if !introduction.isEmpty { Text(introduction).font(.footnote).textSelection(.enabled) }
                Text("\(sections.count) license and notice files").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("noticeFileCount")
                ForEach(sections, id: \.source) { section in
                    NavigationLink {
                        NoticeTextView(text: section.text)
                            .navigationTitle((section.source as NSString).lastPathComponent).navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((section.source as NSString).lastPathComponent).font(.headline)
                            Text(section.source).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }.accessibilityIdentifier("notice-" + section.source)
                }
            }.navigationTitle("Open-source notices").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .overlay { if introduction.isEmpty { ProgressView("Loading notices…") } }
        }.task {
            guard introduction.isEmpty else { return }
            let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "json")
            let document = try? await Task.detached {
                guard let url else { throw CocoaError(.fileNoSuchFile) }
                return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
            }.value
            guard let document else { introduction = "The bundled notices could not be opened. Use Source code & rebuilding in Settings for another copy."; return }
            introduction = document.introduction
            sections = document.notices
        }
    }
}

private struct NoticeTextView: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false; view.isSelectable = true; view.alwaysBounceVertical = true
        view.font = .preferredFont(forTextStyle: .footnote); view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear; view.textColor = .label
        view.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 24, right: 20)
        view.accessibilityIdentifier = "openSourceNoticeText"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
    }
}

struct MiiSetupView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @State private var importingMii = false
    @State private var importingFolder = false
    @State private var imported = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CinematicPageHeading(title: "Mii faces", subtitle: "", symbol: "person.crop.circle", onClose: { menuAudio.play(.back); dismiss() }, closeID: "miiSetupDone")
                        .cinematicEntrance()
                    VStack(alignment: .leading, spacing: 20) {
                    Label(library.mii.title, systemImage: library.mii.archiveFound ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(library.mii.archiveFound ? ConsoleTheme.blue : .white)
                    Button {
                        imported = false; menuAudio.play(.open); importingMii = true
                    } label: {
                        Label(library.mii.archiveFound ? "Replace Mii file" : "Import Mii file", systemImage: "square.and.arrow.down")
                            .font(.headline).frame(maxWidth: .infinity).padding(17)
                            .foregroundStyle(ConsoleTheme.ink).background(.white, in: Capsule())
                    }.buttonStyle(ConsolePressStyle()).accessibilityLabel("Mii resource archive")
                    Text("Choose a decrypted Mii resource archive you have the right to use. Files are imported locally; no system data is downloaded.")
                        .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                    if imported {
                        Label("Imported. Open your game normally to use the new faces; in-game saves are kept.", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(ConsoleTheme.blue).accessibilityIdentifier("miiImportComplete")
                    }
                    Text(library.mii.detail).font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.cinematicCard().cinematicEntrance(delay: 0.05)
                    DisclosureGroup("I have a NAND folder") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Select your console’s nand folder, or a folder containing nand and/or sysdata. Existing system data is merged and SD-card game saves are kept.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Button("Import system folder", systemImage: "folder.badge.plus") { menuAudio.play(.open); importingFolder = true }.frame(minHeight: 44)
                            Text("Raw archive location: nand/title/0004009b/00010202/content.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        }.padding(.top, 12)
                    }.font(.subheadline).cinematicCard().cinematicEntrance(delay: 0.09)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Models and personal Miis are different.").font(.subheadline.weight(.semibold))
                        Text("This setup installs the faces and hairstyles games use. Choosing a personal Mii is done inside the game and may require your console’s saved Mii database.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        Label(library.mii.databaseFound ? "Personal Mii database detected" : "Personal Mii database not imported (optional)", systemImage: library.mii.databaseFound ? "checkmark.circle" : "info.circle")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.cinematicCard().cinematicEntrance(delay: 0.12)
                }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden).background { CinematicScene(game: library.featuredGame, subdued: true).ignoresSafeArea() }.navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
        }.tint(ConsoleTheme.blue).buttonStyle(ConsolePressStyle()).statusBarHidden(true)
            .fileImporter(isPresented: $importingMii, allowedContentTypes: [.item]) { result in importFile(result, archive: true) }
            .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder]) { result in importFile(result, archive: false) }
            .overlay { if library.busy { ProgressView(library.activity).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
            .disabled(library.busy)
            .alert("Couldn’t import Mii data", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
                Button("OK") { library.error = nil }
            } message: { Text(library.error ?? "") }
    }

    private func importFile(_ result: Result<URL, Error>, archive: Bool) {
        switch result {
        case .success(let url): Task {
            await library.importSystem(url, miiArchive: archive)
            withAnimation(ConsoleMotion.response(reduceMotion)) { imported = library.error == nil && library.mii.archiveFound }
            if imported { menuAudio.play(.save) }
        }
        case .failure(let error): library.error = error.localizedDescription
        }
    }
}

struct WidgetShowcaseView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot = WidgetLibrary.empty
    @State private var directory: URL?
    var body: some View {
        NavigationStack {
            GeometryReader { area in
                let width = min(360, max(240, area.size.width - 48))
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        CinematicPageHeading(title: "Your next session.", subtitle: "Add EmuDen from your Home Screen’s widget gallery. Tap a game to open it in the app.", symbol: "rectangle.grid.1x2", onClose: { menuAudio.play(.back); dismiss() }, closeID: "widgetShowcaseDone")
                        Text("Continue Playing").font(.headline)
                        HStack(spacing: 14) {
                            EmuDenWidgetContent(library: snapshot, directory: directory, compact: true).frame(width: (width - 14) / 2, height: (width - 14) / 2)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            EmuDenWidgetContent(library: snapshot, directory: directory, compact: true, fullColor: false).frame(width: (width - 14) / 2, height: (width - 14) / 2)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        }.accessibilityIdentifier("smallWidgetPreviews")
                        EmuDenWidgetContent(library: snapshot, directory: directory).frame(width: width, height: 170).clipShape(RoundedRectangle(cornerRadius: 26)).accessibilityIdentifier("continueWidgetPreview")
                        Text("Recent Games").font(.headline)
                        EmuDenWidgetContent(library: snapshot, directory: directory, recent: true).frame(width: width, height: 170).clipShape(RoundedRectangle(cornerRadius: 26)).accessibilityIdentifier("recentWidgetPreview")
                        EmuDenWidgetContent(library: snapshot, directory: directory, recent: true).frame(width: width, height: 350).clipShape(RoundedRectangle(cornerRadius: 28))
                        Text("Artwork stays on your device. Widgets use cached thumbnails and recent titles; your game files, saves and system resources stay in EmuDen.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        Text("Preview. Your Home Screen adapts the glass and tint to your chosen appearance.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.frame(width: width).padding(24).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }.background { CinematicScene(game: library.featuredGame, subdued: true).ignoresSafeArea() }.toolbar(.hidden, for: .navigationBar)
        }.foregroundStyle(.white).statusBarHidden(true)
            .task {
                library.refreshWidgets()
                snapshot = WidgetLibrary(games: Array(library.sortedGames.prefix(4)).map { WidgetGame(id: $0.id, title: $0.customTitle ?? $0.artworkName) }, updated: Date())
                directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetLibrary.groupID)?.appendingPathComponent(WidgetLibrary.directoryName, isDirectory: true)
                try? await Task.sleep(for: .seconds(3))
                if let directory, let saved = WidgetLibrary.read(from: directory) { snapshot = saved }
            }
    }
}

@MainActor
final class TipJarStore: ObservableObject {
    static let identifiers = ["com.brandonaleman.Emulator.tip.small", "com.brandonaleman.Emulator.tip.medium", "com.brandonaleman.Emulator.tip.large"]
    @Published private(set) var products = [Product]()
    @Published private(set) var purchasing = false
    @Published var message: String?
    private var updates: Task<Void, Never>?
    init() {
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard self != nil else { return }
                if case .verified(let transaction) = result,
                   Self.identifiers.contains(transaction.productID), transaction.productType == .consumable {
                    await transaction.finish()
                }
            }
        }
    }
    deinit { updates?.cancel() }
    func load() async {
        do {
            products = try await Product.products(for: Self.identifiers)
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }
        } catch { products = [] }
    }
    func purchase(_ product: Product) async {
        guard !purchasing, Self.identifiers.contains(product.id), product.type == .consumable else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result,
                      transaction.productID == product.id, transaction.productType == .consumable else {
                    message = "Apple couldn’t verify this transaction. Please check your purchase history with Apple."; return
                }
                await transaction.finish()
                message = "Thank you for supporting EmuDen! Every feature remains free for everyone."
            case .pending: message = "Your tip is waiting for Apple’s approval. You can keep using EmuDen."
            case .userCancelled: break
            @unknown default: message = "The purchase couldn’t be completed. Please try again later."
            }
        } catch { message = error.localizedDescription }
    }
}
