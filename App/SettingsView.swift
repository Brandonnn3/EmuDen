import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import StoreKit

struct SystemSetupView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @State private var playerSettings = false
    @State private var miiSetup = false
    @State private var duoLayout = false
    @State private var importingMii = false
    @State private var importingFolder = false
    @State private var importingAvatar = false
    @State private var showingWidgets = false
    @State private var soundOptions = false
    @State private var noticeURL: URL?
    @AppStorage("buttonHaptics") private var haptics = true
    @AppStorage("asyncShaderCompilation") private var asyncShaders = true
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("onlineArtworkEnabled") private var onlineArtwork = false
    @AppStorage("hasArtworkChoice") private var hasArtworkChoice = false
    @AppStorage("importedGameAccess") private var importedGameAccess = "undecided"
    @State private var showingAgeChoice = false
    @StateObject private var tips = TipJarStore()
    let testCore: () -> Void
    let testControls: () -> Void
    var embedded = false

    var body: some View {
        Group {
            if embedded { content }
            else {
                NavigationStack {
                    content.background { CinematicScene(game: library.featuredGame, subdued: true).ignoresSafeArea() }
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { menuAudio.play(.back); dismiss() }.accessibilityIdentifier("settingsDone") } }
                }
            }
        }.tint(.green).foregroundStyle(.white).buttonStyle(ConsolePressStyle())
            .sheet(isPresented: $playerSettings) { PlayerSettingsView() }
            .sheet(isPresented: $showingWidgets) { WidgetShowcaseView() }
            .sheet(isPresented: $miiSetup) { MiiSetupView() }
            .sheet(isPresented: $showingAgeChoice) { ImportedGameAgeView { adult in importedGameAccess = adult ? "adult" : "under18"; showingAgeChoice = false } }
            .quickLookPreview($noticeURL)
            .task { await tips.load() }
            .fullScreenCover(isPresented: $duoLayout) { DuoLayoutSettingsView() }
            .fileImporter(isPresented: $importingMii, allowedContentTypes: [.item]) { importFile($0, archive: true) }
            .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder]) { importFile($0, archive: false) }
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
                    let layout = area.size.width >= 650 ? AnyLayout(HStackLayout(alignment: .top, spacing: 22)) : AnyLayout(VStackLayout(spacing: 18))
                    layout {
                        VStack(spacing: 18) { performanceCard; appearanceCard }.frame(maxWidth: .infinity)
                        VStack(spacing: 18) { miiCard; layoutCard }.frame(maxWidth: .infinity)
                    }.cinematicEntrance(delay: 0.04)
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Artwork & privacy", systemImage: "photo.on.rectangle.angled").font(.headline)
                        Toggle("Online artwork", isOn: $onlineArtwork).accessibilityIdentifier("onlineArtwork")
                            .onChange(of: onlineArtwork) { _, _ in hasArtworkChoice = true; menuAudio.play(.focus) }
                        Text("Find covers and cinematic backgrounds for your games. Artwork hosts receive image requests and connection information. Your game files and saves stay on this device. Turn this off to use bundled, cached or chosen pictures.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        Divider()
                        Button { showingAgeChoice = true } label: { CinematicSettingRow(title: "Imported game access", detail: importedGameAccess == "adult" ? "Adult access confirmed" : "Unrated imports require adult confirmation", symbol: "person.crop.circle.badge.checkmark") }
                            .accessibilityIdentifier("importedGameAccess")
                        Text("Imported software is unrated by EmuDen. Play is restricted to users who declare they are 18 or older. The bundled homebrew demo stays available. Only your choice is stored locally; no birth date or identity document is requested.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
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
                            noticeURL = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt")
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
                            Text("No Nintendo games or system resources are bundled. Only Nintendo 3DS is currently playable.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Link("Azahar source & release notes", destination: URL(string: "https://github.com/azahar-emu/azahar/releases/tag/2127.0-rc1")!)
                        }.padding(.top, 12)
                    }.font(.caption).foregroundStyle(ConsoleTheme.quiet)
                }.padding(.horizontal, 30).padding(.top, 16).padding(.bottom, 18).frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("3DS performance", systemImage: "rectangle.split.1x2").font(.headline)
            Toggle("Reduce shader pauses", isOn: $asyncShaders).font(.subheadline)
                .onChange(of: asyncShaders) { _, _ in menuAudio.play(.focus) }
            Divider()
            ResolutionSetting()
            Toggle("Show FPS", isOn: $showFPS).font(.subheadline).accessibilityIdentifier("showFPS")
                .onChange(of: showFPS) { _, _ in menuAudio.play(.focus) }
            Button { menuAudio.play(.open); playerSettings = true } label: {
                CinematicSettingRow(title: "Graphics & performance", detail: "Defaults, shader cache and frame graph", symbol: "slider.horizontal.3")
            }.accessibilityIdentifier("advancedPlayerSettings")
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
    private var miiCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Mii faces", systemImage: "person.crop.circle").font(.headline)
            HStack(spacing: 14) {
                Button { menuAudio.play(.open); importingAvatar = true } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = library.miiAvatar { Image(uiImage: image).resizable().scaledToFill().accessibilityIdentifier("customMiiAvatar") }
                            else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(ConsoleTheme.blue) }
                        }.frame(width: 54, height: 54).clipShape(Circle())
                        Image(systemName: library.mii.archiveFound ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 17)).foregroundStyle(library.mii.archiveFound ? .green : .white).background(.black, in: Circle()).offset(x: 3, y: 3)
                    }
                }.accessibilityLabel("Choose Mii profile picture").accessibilityIdentifier("miiAvatar")
                    .accessibilityValue(library.miiAvatar == nil ? "Default portrait" : "Custom portrait")
                    .contextMenu { if library.miiAvatar != nil { Button("Reset profile picture", role: .destructive) { library.resetAvatar() } } }
                Text(library.mii.archiveFound ? "Original faces ready" : "Using guest face").font(.subheadline.weight(.medium))
            }
            Button { menuAudio.play(.open); importingMii = true } label: { CinematicActionLabel(title: "Import Mii file", symbol: "square.and.arrow.down", primary: true) }
            Button { menuAudio.play(.open); importingFolder = true } label: {
                CinematicActionLabel(title: "Import system folder", symbol: "folder")
            }.cinematicGlass(radius: 28, interactive: true)
            Text("Face archives supply shared models, not a personal avatar. Tap the portrait to choose a Mii picture or another image.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
        }.cinematicCard()
    }
    private var layoutCard: some View {
        VStack(spacing: 0) {
            Button { menuAudio.play(.open); duoLayout = true } label: { CinematicSettingRow(title: "Duo layout", detail: "Console skin and expanded screens", symbol: "rectangle.split.1x2") }.accessibilityIdentifier("openDuoLayout")
            Divider()
            Button { menuAudio.play(.open); playerSettings = true } label: { CinematicSettingRow(title: "Player settings", detail: "Performance and controls", symbol: "slider.horizontal.3") }.accessibilityLabel("Player settings")
            Divider()
            Button { menuAudio.play(.open); miiSetup = true } label: { CinematicSettingRow(title: "Mii setup details", detail: "Compatibility and personal Miis", symbol: "person.crop.circle") }.accessibilityIdentifier("openMiiSetup")
        }.cinematicCard()
    }
    private func importFile(_ result: Result<URL, Error>, archive: Bool) {
        switch result {
        case .success(let url): Task { await library.importSystem(url, miiArchive: archive); if library.error == nil { menuAudio.play(.save) } }
        case .failure(let error): library.error = error.localizedDescription
        }
    }
}

struct OnlineArtworkChoiceView: View {
    let choose: (Bool) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "photo.stack.fill").font(.system(size: 42)).foregroundStyle(ConsoleTheme.blue)
            Text("Bring your library to life.").font(.system(size: 32, weight: .bold))
            Text("Online artwork finds covers and cinematic backgrounds for your games. Artwork hosts receive image requests and connection information. Your game files and saves stay on this device.")
                .font(.body).foregroundStyle(ConsoleTheme.quiet)
            Link("Read the privacy policy", destination: URL(string: "https://emuden-support.headyopossum2.chatgpt.site/privacy.html")!)
            Spacer(minLength: 10)
            Button { choose(true) } label: { CinematicActionLabel(title: "Use online artwork", symbol: "sparkles", primary: true) }.accessibilityIdentifier("allowOnlineArtwork")
            Button { choose(false) } label: { CinematicActionLabel(title: "Use offline artwork", symbol: "photo", disclosure: false) }.accessibilityIdentifier("declineOnlineArtwork")
        }.padding(30).frame(maxWidth: 660).frame(maxWidth: .infinity)
            .background(ConsoleTheme.ink.ignoresSafeArea()).foregroundStyle(.white).tint(ConsoleTheme.blue)
            .buttonStyle(ConsolePressStyle()).presentationDetents([.large]).interactiveDismissDisabled()
    }
}

struct ImportedGameAgeView: View {
    let choose: (Bool) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 42)).foregroundStyle(ConsoleTheme.blue)
            Text("Your games. Your age group.").font(.system(size: 32, weight: .bold))
            Text("Imported games and homebrew are unrated by EmuDen and may contain mature content. You must be 18 or older to enable imported software. The bundled homebrew demo remains available.")
                .foregroundStyle(ConsoleTheme.quiet)
            Text("Your choice stays on this device. No date of birth or identity document is collected.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
            Spacer(minLength: 12)
            Button { choose(true) } label: { CinematicActionLabel(title: "I’m 18 or older", symbol: "checkmark", primary: true) }.accessibilityIdentifier("confirmAdultAccess")
            Button { choose(false) } label: { CinematicActionLabel(title: "I’m under 18", symbol: "arrow.uturn.backward", disclosure: false) }.accessibilityIdentifier("restrictImportedAccess")
        }.padding(30).frame(maxWidth: 660).frame(maxWidth: .infinity)
            .foregroundStyle(.white).background(ConsoleTheme.ink.ignoresSafeArea()).tint(ConsoleTheme.blue)
            .buttonStyle(ConsolePressStyle()).presentationDetents([.large])
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
                snapshot = WidgetLibrary(games: Array(library.sortedGames.prefix(4)).map { WidgetGame(id: $0.id, title: $0.artworkName) }, updated: Date())
                directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetLibrary.groupID)?.appendingPathComponent("WidgetLibrary", isDirectory: true)
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
