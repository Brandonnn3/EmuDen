import SwiftUI
import UniformTypeIdentifiers
import GameController
import DeclaredAgeRange

struct LibraryView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var menuInput = ConsoleMenuInput()
    @State private var importing = false
    @State private var artworkGame: Game?
    @State private var settingsGame: Game?
    @State private var pendingWidgetGameID: UUID?
    @State private var pendingHomebrew = false
    @State private var showingSystem = false
    @State private var showingMii = false
    @State private var showingLayout = false
    @State private var launch: Launch?
    @State private var search = ""
    @State private var searching = false
    @State private var collection = false
    @State private var system: ConsoleSystem = .threeDS
    @State private var launchPending = false
    @State private var selectedID: UUID?
    @State private var shelfPosition: UUID?
    @State private var handledLaunchArguments = false
    @State private var hoverTask: Task<Void, Never>?
    @AppStorage("onlineArtworkEnabled") private var onlineArtwork = false
    @AppStorage("hasArtworkChoice") private var hasArtworkChoice = false
    @State private var showingArtworkConsent = false
    @AppStorage("importedGameAccess") private var importedGameAccess = "undecided"
    @State private var ageCheckedLaunch: Launch?
    @FocusState private var searchFocused: Bool
    @Namespace private var dockNamespace
    @Namespace private var searchNamespace

    private var filtered: [Game] { library.sortedGames.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    private var selected: Game? { filtered.first { $0.id == selectedID } ?? filtered.first }
    private var menuActive: Bool { launch == nil && !launchPending && !showingSystem && !showingLayout && !showingMii && !importing && artworkGame == nil && settingsGame == nil && !library.busy && scenePhase == .active }
    private var menuAudioActive: Bool { launch == nil && scenePhase == .active }

    private var artworkNetworkActive: Bool { onlineArtwork && hasArtworkChoice && launch == nil && !launchPending && scenePhase == .active }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ConsoleBackdrop(moving: false)
                if let division = foldDivision(in: geometry), !showingSystem {
                    let layout = DuoLayout(size: geometry.size, division: division, controls: false, immersive: true)
                    spotlight(size: layout.topPanel.size)
                        .frame(width: layout.topPanel.width, height: layout.topPanel.height).clipped()
                        .position(x: layout.topPanel.midX, y: layout.topPanel.midY)
                        .accessibilityElement(children: .contain).accessibilityIdentifier("consoleSpotlightPanel")
                    VStack(spacing: 4) {
                        browser(folded: true)
                        if !searching { footer(compact: layout.bottomPanel.width < 260).transition(.opacity) }
                    }.frame(width: layout.bottomPanel.width, height: layout.bottomPanel.height).clipped()
                        .position(x: layout.bottomPanel.midX, y: layout.bottomPanel.midY)
                        .accessibilityElement(children: .contain).accessibilityIdentifier("consoleBrowsePanel")
                } else {
                    CinematicScene(game: system.available ? selected : nil, system: system, subdued: showingSystem || collection || searching).ignoresSafeArea()
                    VStack(spacing: 0) {
                        header
                        if showingSystem { SystemSetupView(testCore: launchHomebrew, testControls: launchControls, embedded: true) }
                        else { browser() }
                        if !searching { footer(width: geometry.size.width, wide: geometry.size.width > geometry.size.height).transition(.opacity) }
                    }.padding(.top, geometry.size.height * 0.027)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .foregroundStyle(.white).tint(.white).statusBarHidden(true)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await library.importGames(urls) }
            case .failure(let error): library.error = error.localizedDescription
            }
        }
        .fullScreenCover(item: $artworkGame) { ArtworkEditorView(game: $0) }
        .sheet(item: $settingsGame) { PlayerSettingsView(game: $0) }
        .fullScreenCover(isPresented: $showingLayout) { DuoLayoutSettingsView() }
        .sheet(isPresented: $showingMii) { MiiSetupView() }
        .sheet(isPresented: $showingArtworkConsent) {
            OnlineArtworkChoiceView { enabled in
                onlineArtwork = enabled; hasArtworkChoice = true; showingArtworkConsent = false
            }
        }
        .sheet(item: $ageCheckedLaunch) { item in
            ImportedGameAgeView { adult in
                importedGameAccess = adult ? "adult" : "under18"; ageCheckedLaunch = nil
                if adult { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { beginLaunch(item) } }
            }
        }
        .fullScreenCover(item: $launch, onDismiss: openPendingWidgetGame) { item in
            PlayerView(launch: item, saves: library.storage.savesDirectory, onPreview: { image in
                if let game = library.games.first(where: { library.storage.gameURL($0) == item.url }) { library.rememberScene(image, for: game) }
            }) {
                if let game = library.games.first(where: { library.storage.gameURL($0) == item.url }) { library.played(game) }
            }
        }
        .alert("Something needs attention", isPresented: Binding(get: { library.error != nil && !showingSystem && !showingMii && artworkGame == nil }, set: { if !$0 { library.error = nil } })) {
            Button("OK") { library.error = nil }
            if !library.coreReady { Button("Try again") { Task { await library.prepareEmulationData() } } }
        } message: { Text(library.error ?? "") }
        .overlay {
            if library.busy { ProgressView(library.activity).padding(28).cinematicGlass().transition(.opacity.combined(with: .scale(scale: 0.96))) }
            if launchPending {
                ZStack { ConsoleTheme.ink.opacity(0.65).ignoresSafeArea(); ProgressView("Starting your game…").padding(26).cinematicGlass() }
                    .transition(.opacity)
            }
        }
        .animation(ConsoleMotion.scene(reduceMotion), value: launchPending)
        .disabled(library.busy || launchPending)
        .onAppear { repairSelection(); configureInput(); menuAudio.setActive(menuAudioActive); library.setArtworkFetchingEnabled(artworkNetworkActive) }
        .onChange(of: artworkNetworkActive) { _, active in library.setArtworkFetchingEnabled(active) }
        .task {
            await library.prepareEmulationData()
            await library.refreshArtworkCatalog()
            library.refreshWidgets()
        }
        .onChange(of: library.coreReady, initial: true) { _, ready in if ready { handleStartup(); openPendingWidgetGame(); offerArtworkChoice() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active, library.coreReady { handleStartup(); openPendingWidgetGame(); library.refreshWidgets() } }
        .onChange(of: library.games) { _, _ in library.refreshWidgets(); offerArtworkChoice() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EmuDenArtworkUpdated"))) { _ in library.refreshWidgets() }
        .onOpenURL(perform: openLink)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in if let url = activity.webpageURL { openLink(url) } }
        .task(id: searching) {
            guard searching else { searchFocused = false; return }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 180))
            if !Task.isCancelled { searchFocused = true }
        }
        .onDisappear { hoverTask?.cancel(); menuInput.stop(); if launch != nil || scenePhase != .active { menuAudio.setActive(false) } }
        .onChange(of: filtered.map(\.id)) { _, _ in repairSelection() }
        .onChange(of: selectedID) { old, new in
            Task { @MainActor in if library.featuredGameID != new { library.featuredGameID = new } }
            if old != nil, new != nil, menuActive, !searching, system.available { menuAudio.play(.focus) }
        }
        .onChange(of: menuAudioActive) { _, active in menuAudio.setActive(active) }
        .onChange(of: menuActive) { _, active in if !active { hoverTask?.cancel() }; configureInput(); offerArtworkChoice() }
        .onChange(of: searching) { _, _ in configureInput() }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in configureInput() }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in configureInput() }
        .focusable().focusEffectDisabled()
        .onKeyPress(.leftArrow) { guard !searching else { return .ignored }; moveSelection(-1); return .handled }
        .onKeyPress(.rightArrow) { guard !searching else { return .ignored }; moveSelection(1); return .handled }
        .onKeyPress(.return) { guard !searching else { return .ignored }; confirmSelection(); return .handled }
        .onKeyPress(.escape) { back(); return .handled }
    }

    private var header: some View {
      GeometryReader { area in
        CinematicGlassGroup {
            HStack(spacing: 10) {
                if !searching {
                  if area.size.width >= 230 {
                    Text("EmuDen").font(.system(size: area.size.width > 600 ? 24 : 19, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        .accessibilityLabel("EMUDEN").transition(.opacity)
                  } else {
                    Image(systemName: "gamecontroller.fill").font(.system(size: 22, weight: .medium)).accessibilityLabel("EMUDEN")
                  }
                    Spacer(minLength: 8)
                }
                if !searching, area.size.width < 600, area.size.width >= 230 { controllerButton }
                searchControl(compact: area.size.width < 230)
                if !searching, area.size.width >= 600 { controllerButton }
            }.frame(width: area.size.width, height: 48)
        }
      }.frame(height: 48).padding(.horizontal, 28)
            .animation(ConsoleMotion.response(reduceMotion), value: searching)
    }

    private var controllerButton: some View {
        Button { menuAudio.play(.open); showingLayout = true } label: {
            Image(systemName: "gamecontroller").font(.system(size: 22, weight: .medium)).frame(width: 48, height: 48).cinematicGlass(radius: 24, interactive: true)
        }.buttonStyle(ConsolePressStyle()).accessibilityLabel("Controller layout")
    }

    @ViewBuilder private func searchControl(compact: Bool) -> some View {
        if #available(iOS 26.0, *) {
            searchContent(compact: compact).cinematicGlass(radius: 28, interactive: true)
                .glassEffectID("search", in: searchNamespace)
                .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
        } else { searchContent(compact: compact).cinematicGlass(radius: 28, interactive: true) }
    }

    @ViewBuilder private func searchContent(compact: Bool) -> some View {
        if searching {
            HStack(spacing: 12) {
                if !compact { Image(systemName: "magnifyingglass").foregroundStyle(ConsoleTheme.quiet) }
                TextField("Search games", text: $search).focused($searchFocused).submitLabel(.search)
                    .onSubmit { searchFocused = false }.accessibilityLabel("Search your library")
                if !search.isEmpty, !compact {
                    Button { menuAudio.play(.focus); search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 28, height: 44) }.accessibilityLabel("Clear search")
                }
                Button { toggleSearch() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 44, height: 48) }
                    .accessibilityLabel("Close search")
            }.padding(.leading, 18).frame(height: 48).transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
        } else {
            Button { toggleSearch() } label: { Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .medium)).frame(width: 48, height: 48) }
                .accessibilityLabel("Search games").buttonStyle(ConsolePressStyle()).transition(.opacity)
        }
    }

    private func libraryFilters(wide: Bool) -> some View {
        HStack(spacing: wide ? 16 : 12) {
            consolePicker
            librarySearch(compact: !wide)
            if wide && ConsoleSystem.visibleSystems.contains(where: { !$0.available }) { plannedPicker }
        }
    }

    private var consolePicker: some View {
        Menu {
            ForEach(ConsoleSystem.visibleSystems) { item in
                Button { selectSystem(item) } label: {
                    Label(item.available ? item.name : "\(item.name) · Coming soon", systemImage: item.symbol)
                }.accessibilityIdentifier("system-\(item.rawValue)")
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "rectangle.split.1x2").font(.system(size: 13))
                Text("Nintendo 3DS").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }.foregroundStyle(ConsoleTheme.ink).padding(.horizontal, 14).frame(height: 40).background(.white, in: Capsule())
        }.fixedSize(horizontal: true, vertical: false).frame(minHeight: 44).accessibilityIdentifier("consoleFilter").accessibilityLabel("Choose console")
    }

    private func librarySearch(compact: Bool) -> some View {
        Button { if !searching { toggleSearch() } else { searchFocused = true } } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                Text(search.isEmpty ? (compact ? "Search" : "Search games") : search).lineLimit(1)
                Spacer(minLength: 8)
            }.font(.subheadline).padding(.horizontal, 17).frame(minWidth: 130).frame(height: 40).cinematicGlass(radius: 24, interactive: true)
        }.accessibilityLabel("Filter library")
    }

    private var plannedPicker: some View {
        Menu {
            ForEach(ConsoleSystem.allCases.filter { !$0.available }) { item in
                Button { selectSystem(item) } label: { Label(item.name, systemImage: item.symbol) }
                    .accessibilityIdentifier("system-\(item.rawValue)")
            }
        } label: {
            Label("Coming soon", systemImage: "gamecontroller").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 18).frame(height: 40).cinematicGlass(radius: 24, interactive: true)
        }.accessibilityLabel("Coming soon consoles")
    }

    private func browser(folded: Bool = false) -> some View {
        GeometryReader { area in
            if !system.available { plannedSystem(size: area.size) }
            else if library.games.isEmpty { emptyLibrary.frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if filtered.isEmpty { ContentUnavailableView.search(text: search) }
            else if collection || searching { collectionGrid }
            else if folded {
                let height = min(230, max(56, min(area.size.height - 80, (area.size.width - 48) / 0.92)))
                VStack(spacing: 8) { carousel(cardHeight: height); playButton() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let wide = area.size.width > 600
                let gap: CGFloat = wide ? 14 : 6
                let cardWidth = max(60, (area.size.width - (wide ? 48 : 28) - gap * 3) / 4)
                let cardHeight = min(235, cardWidth / (wide ? 1.31 : 0.71))
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 14) { selectedInfo(wide: wide); playButton(wide: wide) }
                            .padding(.horizontal, wide ? 32 : 22).padding(.bottom, 8).frame(maxWidth: .infinity, minHeight: max(145, area.size.height - cardHeight - 70), alignment: .bottomLeading)
                            .cinematicEntrance()
                        Text("Your games").font(.system(size: wide ? 25 : 18, weight: .bold)).padding(.horizontal, wide ? 30 : 22)
                        carousel(cardHeight: cardHeight, wide: wide).cinematicEntrance(delay: 0.06)
                    }.padding(.bottom, 4).frame(minHeight: area.size.height, alignment: .bottom)
                }.scrollIndicators(.hidden)
            }
        }
    }

    private func selectedInfo(compact: Bool = false, wide: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Menu {
                ForEach(ConsoleSystem.visibleSystems) { console in
                    Button { selectSystem(console) } label: { Label(console.available ? console.name : "\(console.name) · Coming soon", systemImage: console.symbol) }
                        .accessibilityIdentifier("system-\(console.rawValue)")
                }
            } label: {
                if wide {
                    Label("Nintendo 3DS", systemImage: "rectangle.split.1x2").font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 15).frame(height: 30).cinematicGlass(radius: 20, interactive: true)
                } else {
                    Text("NINTENDO 3DS").font(.system(size: 11, weight: .semibold)).tracking(0.8).frame(minHeight: 30)
                }
            }.accessibilityLabel("Choose console").accessibilityIdentifier("consoleFilter")
            Text(selected.map { displayTitle($0.title).replacingOccurrences(of: " - ", with: "\n") } ?? "Your next adventure")
                .font(.system(size: compact ? 25 : (wide ? 40 : 30), weight: .bold)).lineLimit(3).minimumScaleFactor(0.65)
                .contentTransition(.opacity).accessibilityIdentifier("selectedGameTitle")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playButton(wide: Bool = false) -> some View {
        Button(action: startSelected) {
            HStack(spacing: wide ? 12 : 8) {
                Image(systemName: "play.fill").font(.system(size: wide ? 18 : 16, weight: .semibold))
                Text(launchPending ? "Starting…" : (wide ? "Play" : "Play game")).font(.system(size: wide ? 22 : 17, weight: .semibold)).lineLimit(1)
            }.foregroundStyle(ConsoleTheme.ink).padding(.horizontal, wide ? 26 : 18).frame(minWidth: wide ? 174 : 0, minHeight: wide ? 50 : 40)
                .background(.white, in: Capsule()).shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                .frame(minHeight: 44).contentShape(Capsule())
        }.buttonStyle(ConsolePressStyle()).disabled(selected == nil)
            .accessibilityIdentifier("startSelectedGame").accessibilityLabel(selected.map { "Play \(displayTitle($0.title))" } ?? "Start game")
    }

    private func carousel(cardHeight: CGFloat, wide: Bool = false) -> some View {
      ScrollViewReader { reader in
        ScrollView(.horizontal) {
            LazyHStack(spacing: wide ? 14 : 6) {
                ForEach(filtered) { game in
                    Button { selectGame(game) } label: { gameTile(game, height: cardHeight, wide: wide) }
                        .buttonStyle(ConsolePressStyle()).contextMenu { gameActions(game) }
                        .accessibilityLabel("Select \(displayTitle(game.title))")
                        .accessibilityIdentifier(selected?.id == game.id ? "selectedGameTile" : "gameTile-\(game.id)")
                        .accessibilityValue(selected?.id == game.id ? "Selected" : "")
                        .onHover { hover(game, inside: $0) }.id(game.id)
                }
            }.scrollTargetLayout().padding(.horizontal, wide ? 24 : 14).padding(.vertical, 8)
        }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $shelfPosition, anchor: .leading)
            .onAppear { reader.scrollTo(selected?.id, anchor: .leading) }
            .frame(height: cardHeight + 16).accessibilityIdentifier("gameCarousel")
            .accessibilityAdjustableAction { direction in
                switch direction { case .increment: moveSelection(1); case .decrement: moveSelection(-1); @unknown default: break }
            }
      }
    }

    private func gameTile(_ game: Game, height: CGFloat, wide: Bool = false) -> some View {
        let focused = selected?.id == game.id
        return GameArtwork(game: game, wide: wide).frame(width: height * (wide ? 1.31 : 0.71), height: height)
            .contentShape(RoundedRectangle(cornerRadius: 15))
            .background(.black.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(focused ? 0.95 : 0.15), lineWidth: focused ? 2 : 0.75) }
            .shadow(color: .black.opacity(focused ? 0.4 : 0.15), radius: focused ? 14 : 6, y: 6)
            .scaleEffect(focused || reduceMotion ? 1 : 0.96).opacity(focused ? 1 : 0.88)
            .animation(ConsoleMotion.response(reduceMotion), value: focused)
    }

    private var collectionGrid: some View {
      GeometryReader { area in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(searching ? "Search games" : "Library").font(.system(.title).weight(.bold))
                libraryFilters(wide: area.size.width > 600)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: area.size.width > 600 ? 4 : (area.size.width > 280 ? 2 : 1)), alignment: .leading, spacing: 24) {
                    ForEach(filtered) { game in
                        Button {
                            selectGame(game)
                            withAnimation(ConsoleMotion.response(reduceMotion)) { collection = false; searching = false; search = "" }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                GameArtwork(game: game).aspectRatio(0.71, contentMode: .fit).background(.black.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 15))
                                    .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(selected?.id == game.id ? 0.9 : 0.1), lineWidth: 1) }
                                Text(displayTitle(game.title)).font(.system(.subheadline, design: .default).weight(.medium)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.buttonStyle(ConsolePressStyle()).accessibilityLabel("Select \(displayTitle(game.title))")
                            .contextMenu { gameActions(game) }.onHover { hover(game, inside: $0) }
                    }
                }
            }.padding(24).cinematicEntrance()
        }.scrollIndicators(.hidden).accessibilityIdentifier("gameCollection")
      }
    }

    @ViewBuilder private func gameActions(_ game: Game) -> some View {
        Text("Age rating: Unrated · Adult access required")
        Button("Play game", systemImage: "play.fill") { selectedID = game.id; startSelected() }
        Button("Change artwork", systemImage: "photo.stack") { menuAudio.play(.open); artworkGame = game }.accessibilityIdentifier("changeArtwork")
        Button("Game settings", systemImage: "slider.horizontal.3") { settingsGame = game }
        ShareLink(item: EmuDenLink.game(game.id)) { Label("Share game link", systemImage: "link") }
        if CinematicArt.match(game.artworkName) == nil {
            Button("Find game artwork", systemImage: "photo") { Task { await library.refreshArtwork(game) } }
        }
    }

    private func footer(width: CGFloat = 0, compact: Bool = false, wide: Bool = false) -> some View {
        let layout = compact ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2))
        return layout {
            dockItem("Home", icon: "house", active: !collection && !showingSystem, compact: compact, wide: wide) { menuAudio.play(.confirm); backToHome() }.accessibilityIdentifier("consoleHome")
            dockItem("Library", icon: "book", active: collection && !showingSystem, compact: compact, wide: wide) {
                menuAudio.play(.open); system = .threeDS; showingSystem = false
                withAnimation(ConsoleMotion.response(reduceMotion)) { collection = true; searching = false; search = "" }
            }.accessibilityIdentifier("consoleCollection")
            dockItem("Add", icon: "plus", active: false, compact: compact, wide: wide) { menuAudio.play(.open); showingSystem = false; collection = true; system = .threeDS; importing = true }
                .accessibilityLabel("Add games").accessibilityIdentifier("addGames")
            dockItem("Settings", icon: "gearshape", active: showingSystem, compact: compact, wide: wide) { menuAudio.play(.open); withAnimation(ConsoleMotion.response(reduceMotion)) { showingSystem = true; searching = false; search = "" } }.accessibilityLabel("System setup")
        }.padding(wide ? 8 : 6).cinematicGlass(radius: compact ? 26 : 60)
            .frame(maxWidth: compact ? 240 : (width > 0 ? width * (wide ? 0.54 : 0.82) : 540)).padding(.horizontal, 12).padding(.bottom, wide ? 18 : 12)
            .cinematicEntrance(delay: 0.1).accessibilityElement(children: .contain).accessibilityIdentifier("liquidGlassDock")
    }

    private func dockItem(_ title: String, icon: String, active: Bool, compact: Bool, wide: Bool = false, action: @escaping () -> Void) -> some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 4))
        return Button(action: action) {
            layout {
                Image(systemName: icon).font(.system(size: wide ? 23 : 19, weight: .medium)).frame(width: 28, height: wide ? 30 : 24)
                Text(title).font(.system(size: compact ? 12 : (wide ? 13 : 11), weight: active ? .semibold : .medium)).lineLimit(1)
            }.frame(minWidth: 44, maxWidth: .infinity, minHeight: compact ? 44 : (wide ? 64 : 52), alignment: compact ? .leading : .center)
                .padding(.horizontal, compact ? 14 : 6)
                .background {
                    if active { Capsule().fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay { Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.8) }.shadow(color: .white.opacity(0.1), radius: 8).matchedGeometryEffect(id: "dockSelection", in: dockNamespace) }
                }.contentShape(Capsule())
        }.buttonStyle(ConsolePressStyle()).accessibilityAddTraits(active ? .isSelected : [])
    }

    private func spotlight(size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                header
                Spacer(minLength: 12)
                if system.available, !searching { selectedInfo(compact: size.width < 300).padding(.horizontal, 24).padding(.bottom, 16) }
            }.padding(.top, 10).frame(width: size.width).frame(minHeight: size.height)
        }.scrollIndicators(.hidden).background { CinematicScene(game: system.available ? selected : nil, system: system, subdued: searching) }
    }

    private func plannedSystem(size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                ConsoleEmblem(system: system).scaleEffect(0.7).frame(height: min(130, size.height * 0.3))
                Text("COMING SOON").font(.system(size: 10, weight: .semibold)).tracking(2.5).foregroundStyle(ConsoleTheme.quiet)
                Text(system.name).font(.system(.title, design: .default).weight(.bold))
                Text("More eras. One home for your games.").font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                Text("Emulation for this system is planned.\nIt isn’t playable in this build.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                Button { selectSystem(.threeDS) } label: { Label("Back to 3DS library", systemImage: "arrow.left").font(.subheadline.weight(.semibold)).padding(.horizontal, 22).frame(height: 48).cinematicGlass(interactive: true) }
                    .buttonStyle(ConsolePressStyle()).accessibilityIdentifier("backToPlayableLibrary")
            }.multilineTextAlignment(.center).padding(24).frame(maxWidth: .infinity).frame(minHeight: size.height).cinematicEntrance()
        }.scrollIndicators(.hidden).accessibilityIdentifier("comingSoonPanel")
    }

    private var emptyLibrary: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller.fill").font(.system(size: 48, weight: .light)).foregroundStyle(.white.opacity(0.85))
            Text("Your next adventure starts here.").font(.system(.title, design: .default).weight(.bold))
            Text("Add your games and make yourself at home.").font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
            Button { menuAudio.play(.open); importing = true } label: {
                Label("Add your first game", systemImage: "plus").font(.headline).padding(.horizontal, 24).frame(height: 50).foregroundStyle(ConsoleTheme.ink).background(.white, in: Capsule())
            }.buttonStyle(ConsolePressStyle())
            Button("Launch 3DS test", action: launchHomebrew).font(.caption.weight(.medium)).frame(minHeight: 44).accessibilityIdentifier("launchHomebrew")
        }.multilineTextAlignment(.center).padding(24).cinematicEntrance()
    }

    private func foldDivision(in geometry: GeometryProxy) -> CGRect? {
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--avatar-import-test"), let path = ProcessInfo.processInfo.environment["EMUDEN_TEST_AVATAR_PATH"] {
            Task { await library.importAvatar(URL(fileURLWithPath: path)) }
        }
        if ProcessInfo.processInfo.arguments.contains("--library-tabletop-preview") { return CGRect(x: 0, y: geometry.size.height / 2 - 10, width: geometry.size.width, height: 20) }
        if ProcessInfo.processInfo.arguments.contains("--library-book-preview") { return CGRect(x: geometry.size.width / 2 - 10, y: 0, width: 20, height: geometry.size.height) }
#endif
        if #available(iOS 27.1, *), let region = geometry.reservedRegions(kind: .division, options: [], layoutDirectionBehavior: .fixed).first {
            return region.frame.inset(by: UIEdgeInsets(top: -region.margins.top, left: -region.margins.leading, bottom: -region.margins.bottom, right: -region.margins.trailing))
        }
        return nil
    }
    private func repairSelection() { if !filtered.contains(where: { $0.id == selectedID }) { selectedID = filtered.first?.id } }
    private func selectGame(_ game: Game) { withAnimation(ConsoleMotion.scene(reduceMotion)) { selectedID = game.id } }
    private func hover(_ game: Game, inside: Bool) {
        hoverTask?.cancel()
        guard inside, menuActive, selectedID != game.id else { return }
        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled, menuActive else { return }; selectGame(game)
        }
    }
    private func moveSelection(_ offset: Int) {
        guard system.available else { moveSystem(offset); return }; guard !filtered.isEmpty else { return }
        let index = filtered.firstIndex { $0.id == selected?.id } ?? 0
        withAnimation(ConsoleMotion.response(reduceMotion)) { selectedID = filtered[(index + offset + filtered.count) % filtered.count].id; shelfPosition = selectedID }
    }
    private func toggleSearch() {
        menuAudio.play(searching ? .back : .search)
        if showingSystem { showingSystem = false; collection = true }
        if !system.available { system = .threeDS }
        withAnimation(ConsoleMotion.response(reduceMotion)) { searching.toggle(); if !searching { search = "" } }
    }
    private func backToHome() { withAnimation(ConsoleMotion.response(reduceMotion)) { showingSystem = false; system = .threeDS; collection = false; searching = false; search = "" } }
    private func startSelected() {
        guard system.available, let game = selected else { return }; searchFocused = false
        beginLaunch(Launch(title: game.title, url: library.storage.gameURL(game)))
    }
    private func beginLaunch(_ item: Launch) {
        guard library.coreReady, !launchPending, launch == nil else { return }
        if let url = item.url, url != Bundle.main.url(forResource: "boot", withExtension: "3dsx"),
           !ImportedGameAccess.stored(importedGameAccess).allowsImportedGames {
            if ImportedGameAccess.stored(importedGameAccess) == .under18 {
                library.error = "Imported software is unrated and restricted to adults. The bundled homebrew demo is available. You can review your declared age group in Settings."
            } else { ageCheckedLaunch = item }
            return
        }
        launchPending = true
        Task { @MainActor in
            defer { launchPending = false }
            if let url = item.url, url != Bundle.main.url(forResource: "boot", withExtension: "3dsx"),
               !(await regionalAdultAccessAllowed()) { return }
            guard UIApplication.shared.applicationState == .active else { return }
            let duration = max(reduceMotion ? 0 : 0.22, menuAudio.play(.launch))
            if duration > 0 { try? await Task.sleep(for: .seconds(duration)) }
            if UIApplication.shared.applicationState == .active { launch = item }
        }
    }
    @MainActor private func regionalAdultAccessAllowed() async -> Bool {
        // The OS determines whether regional age assurance applies. Never infer it
        // from the storefront, a location permission or the user's local choice.
        guard #available(iOS 26.2, *) else { return true }
        do {
            guard try await AgeRangeService.shared.isEligibleForAgeFeatures else { return true }
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow),
                  var presenter = window.rootViewController else {
                library.error = "Age confirmation couldn’t open. Please try again."; return false
            }
            while let presented = presenter.presentedViewController { presenter = presented }
            let response = try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: presenter)
            if case .sharing(let range) = response,
               ImportedGameAccess.isAdultAgeBand(lowerBound: range.lowerBound, upperBound: range.upperBound) { return true }
            library.error = "Apple hasn’t confirmed an adult age range for imported software. The included homebrew demo is still available."
        } catch {
            library.error = "Apple’s regional age check is unavailable. Please try again before opening imported software. The included homebrew demo is still available."
        }
        return false
    }
    private func openPendingWidgetGame() {
        guard launch == nil, !launchPending, library.coreReady, scenePhase == .active else { return }
        if pendingHomebrew { pendingHomebrew = false; launchHomebrew(); return }
        guard let id = pendingWidgetGameID else { return }
        pendingWidgetGameID = nil
        guard let game = library.games.first(where: { $0.id == id }) else { library.error = "This game is no longer in your library."; return }
        guard FileManager.default.fileExists(atPath: library.storage.gameURL(game).path) else { library.error = "This game's file is missing. Import it again to play."; return }
        showingSystem = false; showingMii = false; showingLayout = false; artworkGame = nil; settingsGame = nil
        searching = false; searchFocused = false; system = .threeDS; selectedID = game.id
        beginLaunch(Launch(title: game.title, url: library.storage.gameURL(game)))
    }
    private func openLink(_ url: URL) {
        guard let destination = EmuDenLink.destination(url) else { return }
        switch destination {
        case .library:
            if launch == nil { backToHome(); collection = true }
            return
        case .homebrew:
            if let launch, launch.url == Bundle.main.url(forResource: "boot", withExtension: "3dsx") { return }
            pendingHomebrew = true; pendingWidgetGameID = nil
        case .game(let id):
            if let game = library.games.first(where: { $0.id == id }), launch?.url == library.storage.gameURL(game) { return }
            pendingWidgetGameID = id; pendingHomebrew = false
        }
        if launch != nil { NotificationCenter.default.post(name: Notification.Name("EmuDenWidgetSwitchGame"), object: nil) }
        else { openPendingWidgetGame() }
    }
    private func handleStartup() {
        guard library.coreReady, scenePhase == .active, !handledLaunchArguments else { return }; handledLaunchArguments = true
        if ProcessInfo.processInfo.arguments.contains("--input-test") { launch = Launch(title: "Input & display test", url: nil) }
        if ProcessInfo.processInfo.arguments.contains("--boot-homebrew"), launch == nil { launchHomebrew() }
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--boot-test-game"), launch == nil {
            let url = ProcessInfo.processInfo.environment["EMULATOR_TEST_ROM_PATH"].map { URL(fileURLWithPath: $0) }
                ?? library.storage.root.appendingPathComponent("TestGames/MarioGolf.3ds")
            if FileManager.default.fileExists(atPath: url.path) { launch = Launch(title: url.deletingPathExtension().lastPathComponent, url: url) }
        }
#endif
        configureInput()
    }
    private func confirmSelection() { if system.available { startSelected() } else { selectSystem(.threeDS) } }
    private func selectSystem(_ value: ConsoleSystem) {
        guard value != system else { return }; menuAudio.play(value.available ? .confirm : .planned)
        withAnimation(ConsoleMotion.response(reduceMotion)) { search = ""; searching = false; collection = false; system = value }
    }
    private func moveSystem(_ offset: Int) { let list = ConsoleSystem.visibleSystems; let index = list.firstIndex(of: system) ?? 0; selectSystem(list[(index + offset + list.count) % list.count]) }
    private func back() { if searching { toggleSearch() } else { menuAudio.play(.back); backToHome() } }
    private func configureInput() {
        guard menuActive, !searching else { menuInput.stop(); return }
        menuInput.start { command in
            switch command {
            case .left: moveSelection(-1)
            case .right: moveSelection(1)
            case .confirm: confirmSelection()
            case .back: back()
            case .settings: menuAudio.play(.open); showingSystem = true
            case .previousSystem: moveSystem(-1)
            case .nextSystem: moveSystem(1)
            }
        }
    }
    private func displayTitle(_ title: String) -> String {
        title.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^(.+), The( - |$)"#, with: "The $1$2", options: .regularExpression)
    }
    private func launchControls() { showingSystem = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { beginLaunch(Launch(title: "Input & display test", url: nil)) } }
    private func offerArtworkChoice() {
        let arguments = ProcessInfo.processInfo.arguments
        guard menuActive, library.coreReady, !library.games.isEmpty, !hasArtworkChoice,
              !arguments.contains("--boot-homebrew"), !arguments.contains("--boot-test-game") else { return }
        showingArtworkConsent = true
    }
    private func launchHomebrew() {
        guard library.coreReady else { return }; showingSystem = false
        guard let url = Bundle.main.url(forResource: "boot", withExtension: "3dsx") else { library.error = "The bundled homebrew test is missing from this build."; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { beginLaunch(Launch(title: "3DS Homebrew Menu", url: url)) }
    }
}

struct GameArtwork: View {
    @EnvironmentObject private var library: GameLibrary
    let game: Game
    var wide = false
    @State private var image: UIImage?
    @State private var custom = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image, custom {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                } else if let art = CinematicArt.match(game.artworkName) { ApprovedCoverArt(art: art, wide: wide) }
                else if let image {
                    let width = image.cgImage?.width ?? Int(image.size.width)
                    let height = image.cgImage?.height ?? Int(image.size.height)
                    ArtworkRegion(image: image, sourceSize: CGSize(width: CGFloat(width), height: CGFloat(height)),
                                  region: CGRect(x: 0, y: 0, width: CGFloat(ArtworkCoverPolicy.frontWidth(width: width, height: height)), height: CGFloat(height)), alignment: .top)
                } else { ConsoleArtwork(title: game.title) }
            }.clipped()
        }
        .contentShape(Rectangle())
        .accessibilityHidden(true)
        .task(id: "\(game.id)-\(game.artworkName)-\(library.artworkRevision)-\(library.artworkFetchingEnabled)") {
            let chosen = await library.artwork.preferredImage(for: game)
            guard !Task.isCancelled else { return }
            custom = chosen != nil; image = chosen
            if custom || CinematicArt.match(game.artworkName) != nil { return }
            let found = await library.artwork.image(for: game)
            if !Task.isCancelled { image = found }
        }
    }
}

// Original illustrations remain available while a cover downloads or when no match exists.
private struct ConsoleArtwork: View {
    let title: String
    private var theme: Int {
        let name = title.lowercased()
        if name.contains("golf") { return 0 }
        if name.contains("zelda") || name.contains("ocarina") { return 1 }
        return 2 + title.utf8.reduce(0) { ($0 + Int($1)) % 3 }
    }
    private var colors: [Color] {
        switch theme {
        case 0: return [Color(red: 0.06, green: 0.61, blue: 0.58), Color(red: 0.05, green: 0.20, blue: 0.30)]
        case 1: return [Color(red: 0.27, green: 0.25, blue: 0.65), Color(red: 0.04, green: 0.15, blue: 0.30)]
        case 2: return [Color(red: 0.87, green: 0.32, blue: 0.25), Color(red: 0.37, green: 0.08, blue: 0.37)]
        case 3: return [Color(red: 0.27, green: 0.35, blue: 0.91), Color(red: 0.12, green: 0.07, blue: 0.33)]
        default: return [Color(red: 0.66, green: 0.28, blue: 0.87), Color(red: 0.16, green: 0.08, blue: 0.32)]
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color(red: 1, green: 0.83, blue: 0.46))
                    .frame(width: min(w, h) * 0.48).position(x: w * 0.75, y: h * 0.28)
                    .shadow(color: .yellow.opacity(0.2), radius: 30)
                Canvas { context, size in
                    for i in 0..<22 {
                        let x = CGFloat((i * 83 + 19) % 337) / 337 * size.width
                        let y = CGFloat((i * 47 + 13) % 251) / 251 * size.height * 0.7
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: i % 3 == 0 ? 3 : 1.5, height: i % 3 == 0 ? 3 : 1.5)), with: .color(.white.opacity(0.4)))
                    }
                    var mountain = Path()
                    mountain.move(to: CGPoint(x: -size.width * 0.2, y: size.height))
                    mountain.addLine(to: CGPoint(x: size.width * 0.35, y: size.height * 0.32))
                    mountain.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.8))
                    mountain.addLine(to: CGPoint(x: size.width * 1.1, y: size.height * 0.45))
                    mountain.addLine(to: CGPoint(x: size.width * 1.2, y: size.height))
                    mountain.closeSubpath()
                    context.fill(mountain, with: .color(.white.opacity(0.12)))
                    var horizon = Path()
                    horizon.move(to: CGPoint(x: 0, y: size.height * 0.75))
                    horizon.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.62), control: CGPoint(x: size.width * 0.45, y: size.height * 0.38))
                    horizon.addLine(to: CGPoint(x: size.width, y: size.height)); horizon.addLine(to: CGPoint(x: 0, y: size.height)); horizon.closeSubpath()
                    context.fill(horizon, with: .color(.black.opacity(0.20)))
                }
                if theme == 0 {
                    Image(systemName: "flag.checkered").font(.system(size: min(w, h) * 0.31, weight: .bold))
                        .foregroundStyle(.white).rotationEffect(.degrees(-14)).position(x: w * 0.66, y: h * 0.46)
                    Circle().fill(.white).frame(width: min(w, h) * 0.13).shadow(color: .black.opacity(0.2), radius: 3, y: 6)
                        .position(x: w * 0.38, y: h * 0.69)
                } else if theme == 1 {
                    Image(systemName: "sparkles").font(.system(size: min(w, h) * 0.42, weight: .light))
                        .foregroundStyle(Color(red: 1, green: 0.89, blue: 0.58)).rotationEffect(.degrees(-12)).position(x: w * 0.68, y: h * 0.47)
                } else {
                    RoundedRectangle(cornerRadius: 28).fill(.white.opacity(0.12))
                        .frame(width: min(w, h) * 0.58, height: min(w, h) * 0.58)
                        .rotationEffect(.degrees(26)).position(x: w * 0.62, y: h * 0.43)
                    Image(systemName: theme == 2 ? "bolt.fill" : theme == 3 ? "gamecontroller.fill" : "moon.stars.fill")
                        .font(.system(size: min(w, h) * 0.35, weight: .bold)).foregroundStyle(.white)
                        .rotationEffect(.degrees(-15)).shadow(color: .black.opacity(0.2), radius: 10, y: 10)
                        .position(x: w * 0.64, y: h * 0.42)
                }
            }.clipped()
        }.accessibilityHidden(true)
    }
}

