//
//  ScannerScreen.swift
//  Lensir
//
//  The one screen. The camera fills it; four brackets wait in the middle.
//  When a code turns up they snap onto it and a white pill names what it
//  is. Nothing opens by itself: tap the pill and a drawer slides up from
//  the bottom edge with the whole thing, and you choose. Make, between the
//  photo and History buttons, raises the same drawer to make a code.
//

import PhotosUI
import SwiftData
import SwiftUI

struct ScannerScreen: View {
    var settings: AppSettings
    /// lensir://scan, from the widget, the control, the Action Button or Siri.
    var inbox: LinkInbox

    @State private var model = ScannerModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showingHistory = LaunchOptions.openHistory
    @State private var pendingHistoryRecord: (raw: String, symbology: String, date: Date)?
    @State private var pillSize = CGSize(width: 160, height: 44)
    @State private var drawer = DrawerState(slowdown: LaunchOptions.drawerSlowdown)
    /// What's typed in Make. Kept while the app runs, so closing the drawer
    /// by accident loses nothing.
    @State private var makeDraft = CodeDraft()
    /// Make was tapped in History; it opens once History has gone.
    @State private var pendingMake = false
    /// How much of the screen the keyboard covers. Only Make has fields.
    @State private var keyboardHeight: CGFloat = 0
    /// Where the demo camera's code sits, for the drawer tour.
    @State private var demoFrame: CGRect?
    /// The opening animation: once per cold launch, since this screen lives
    /// as long as the process.
    @State private var splashStart: Date?
    @State private var splashDone = LaunchOptions.skipSplash
    @State private var splashLocked = false
    @State private var splashStarting = false
    /// Opened straight to the scanner on a cold launch: the short version.
    @State private var quickSplash = false
    private var splashTimeline: SplashLogic.Timeline {
        (quickSplash ? .quick : SplashLogic.Timeline()).slowed(by: LaunchOptions.splashSlowdown)
    }
    private var stillTimeline: SplashLogic.StillTimeline {
        quickSplash ? .quick : SplashLogic.StillTimeline()
    }
    /// A code picked from a photo's list, opened once the list has gone.
    @State private var pendingPhotoCode: PhotoCode?
    @AccessibilityFocusState private var focus: ScannerFocus?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// The text size before this screen caps it. The camera controls stop
    /// at AX1; Make's form goes all the way.
    @Environment(\.dynamicTypeSize) private var systemTypeSize

    var body: some View {
        // The clock only runs during the opening animation.
        TimelineView(.animation(paused: splashDone || splashStart == nil)) { context in
            GeometryReader { proxy in
                let safe = proxy.safeAreaInsets
                let size = CGSize(width: proxy.size.width + safe.leading + safe.trailing,
                                  height: proxy.size.height + safe.top + safe.bottom)
                let splash = splashFrame(at: context.date, screen: size)
                ZStack(alignment: .topLeading) {
                    Palette.canvas
                    // The page: everything under the drawer. It sinks back a
                    // little as the drawer expands, like Vaul's background scale.
                    ZStack(alignment: .topLeading) {
                        camera(size: size)
                            .opacity(splash?.scene ?? 1)
                        overlay(size: size, splash: splash)
                        if let splash { SplashMarks(splash: splash) }
                        controls(safe: safe)
                            .opacity(splash?.scene ?? 1)
                        pill(size: size)
                    }
                    .frame(width: size.width, height: size.height)
                    .modifier(DrawerSink(drawer: drawer, active: model.drawerOpen))
                    if let splash {
                        SplashCredit(opacity: splash.credit, bottomInset: safe.bottom)
                            .frame(width: size.width, height: size.height)
                        // Tap anywhere to skip.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(perform: skipSplash)
                            .accessibilityHidden(true)
                    }
                    drawerLayer(size: size, safe: safe)
                }
                .frame(width: size.width, height: size.height)
                .coordinateSpace(.named("screen"))
                .ignoresSafeArea()
            }
            // The keyboard is handled by hand (keyboardHeight), so the
            // screen's own insets never jump when it comes up.
            .ignoresSafeArea(.keyboard)
        }
        .background(Palette.canvas)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .task { await start() }
        .onChange(of: reduceMotion, initial: true) {
            model.reduceMotion = reduceMotion
            drawer.reduceMotion = reduceMotion
        }
        .onChange(of: model.result?.id) {
            guard model.result != nil else {
                // The drawer's gone: VoiceOver lands back on the scanner.
                focus = ScannerFocusLogic.afterDrawerCloses(hint: hintText)
                return
            }
            let expands = LaunchOptions.demo?.expandsDrawer ?? false
            drawer.present(expands ? .expanded : .compact, animated: !(LaunchOptions.demo?.opensSheet ?? false))
            saveToHistory()
        }
        .onChange(of: model.making) {
            // Back to Make, the button that opened it.
            if !model.making { focus = ScannerFocusLogic.afterClosing(.make, hint: hintText) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboardChanged(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(Self.keyboardMotion) { keyboardHeight = 0 }
        }
        .onChange(of: photoItem) { readPhoto() }
        .onChange(of: inbox.latest, initial: true) {
            if let request = inbox.latest { open(request.link) }
        }
        .onChange(of: scenePhase, initial: true) {
            // The clock starts once the app is actually drawing (FirstFrames),
            // not when this view is built: on a slow launch it would be over
            // before iOS showed it.
            if scenePhase == .active { startSplash() }
            if scenePhase != .active, model.torchOn {
                model.torchOn = false
                CameraAccess.setTorch(false)
            }
        }
        .sensoryFeedback(trigger: model.lastFound) { _, found in
            HapticLogic.feedback(for: .detected(risky: found.risky), hapticsOn: settings.haptics)
        }
        .sensoryFeedback(trigger: splashLocked) { _, locked in settings.haptics && locked ? .impact(weight: .light) : nil }
        .sheet(isPresented: $showingHistory, onDismiss: openPendingRecord) {
            HistoryView(settings: settings) { record in
                pendingHistoryRecord = (record.raw, record.symbology, record.date)
                showingHistory = false
            } onMake: {
                pendingMake = true
                showingHistory = false
            }
        }
        .sheet(isPresented: Binding(get: { !model.photoCodes.isEmpty }, set: { if !$0 { model.photoCodes = [] } }),
               onDismiss: openPendingPhotoCode) {
            PhotoCodesSheet(codes: model.photoCodes) { code in
                pendingPhotoCode = code
                model.photoCodes = []
            }
        }
    }

    // MARK: - Layers

    @ViewBuilder private func camera(size: CGSize) -> some View {
        let scanning = !model.drawerOpen && scenePhase == .active
        Group {
            switch model.camera {
            case .dataScanner:
                DataScannerView(isScanning: scanning, onFound: model.found, onLost: model.lost)
            case .capture:
                CaptureScannerView(isScanning: scanning, onFound: model.found, onLost: model.lost)
            case .demo:
                DemoCameraView(payload: LaunchOptions.demo?.payload) { frame in
                    placeDemoCode(frame)
                }
            case .denied:
                CameraMessageView(
                    title: "Lensir needs the camera",
                    message: "Allow camera access in Settings to read codes. What the camera sees never leaves your phone.",
                    action: .settings
                )
            case .unavailable:
                CameraMessageView(
                    title: "No camera here",
                    message: "This device can't use a camera, but Lensir can still read a code from a photo.",
                    action: .photo($photoItem)
                )
            case .checking:
                Palette.canvas
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var cameraIsLive: Bool {
        [.dataScanner, .capture, .demo].contains(model.camera)
    }

    /// The dim and the brackets. During the opening animation the brackets
    /// are the splash's: the same shape, driven by its clock, so they end on
    /// exactly this frame with nothing swapped.
    @ViewBuilder private func overlay(size: CGSize, splash: SplashFrame?) -> some View {
        if cameraIsLive || splash != nil {
            let frame = splash?.brackets ?? model.detection.map { ScanGeometry.foundFrame(around: $0.bounds, in: size) } ?? ScanGeometry.lookingFrame(in: size)
            let warning = model.result?.summary.isWarning ?? model.detectionSummary?.isWarning ?? false
            let base = ScanGeometry.dimOpacity(found: model.detection != nil)
            let open = model.drawerOpen
            let live = cameraIsLive
            let brackets = !(model.result != nil && model.detection == nil)
            let showsWarning = warning && (model.detection != nil || model.result != nil)
            // The dim follows the drawer's height frame by frame; only the
            // overlay redraws for it, not the screen.
            DrawerReader(drawer: drawer) { drawer in
                let dim = open ? drawer.dim(base: base) : base
                ScanOverlay(
                    frame: frame,
                    dim: live ? dim * (splash?.scene ?? 1) : 0,
                    warning: showsWarning,
                    showsBrackets: brackets,
                    stroke: splash?.stroke ?? SplashLogic.scannerStroke,
                    // No camera: the brackets fade out as the message comes in.
                    bracketOpacity: live ? (splash?.bracketOpacity ?? 1) : 1 - (splash?.scene ?? 1)
                )
            }
            .animation(Motion.fade, value: warning)
            .frame(width: size.width, height: size.height)
        }
    }

    private func controls(safe: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Lensir")
                    .font(Typeface.wordmark)
                    .tracking(-0.34)
                    .foregroundStyle(Palette.ink)
                    .shadow(color: Palette.glow, radius: 6)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if cameraIsLive && (CameraAccess.hasTorch || model.camera == .demo) {
                    Button(action: toggleTorch) {
                        CircleIcon(systemName: model.torchOn ? "flashlight.on.fill" : "flashlight.off.fill", filled: model.torchOn)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Torch")
                    .accessibilityValue(model.torchOn ? "On" : "Off")
                }
            }
            .frame(height: 44)
            .padding(.top, safe.top + 4)

            Spacer(minLength: 0)

            VStack(spacing: 18) {
                hint
                HStack {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        CircleIcon(systemName: "photo", diameter: 52)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Scan a photo")
                    .accessibilityFocused($focus, equals: .photoButton)
                    Spacer()
                    Button { startMaking() } label: {
                        Text("Make")
                            .font(Typeface.primaryButton)
                            .foregroundStyle(Palette.onInk)
                            .padding(.horizontal, 28)
                            .frame(minHeight: 48)
                            .background(Capsule().fill(Palette.ink))
                            // 48 pt to look at, 52 like its neighbours to hit.
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Make a code")
                    .accessibilityIdentifier("make-button")
                    .accessibilityFocused($focus, equals: .makeButton)
                    Spacer()
                    Button { showingHistory = true } label: {
                        CircleIcon(systemName: "clock.arrow.circlepath", diameter: 52)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("History")
                }
            }
            .padding(.bottom, bottomInset(safe))
            .opacity(model.drawerOpen ? 0 : 1)
            .allowsHitTesting(!model.drawerOpen)
            .accessibilityHidden(model.drawerOpen)
        }
        .padding(.leading, Metrics.edge + safe.leading)
        .padding(.trailing, Metrics.edge + safe.trailing)
    }

    private var hintText: String? {
        ScannerFocusLogic.hintText(notice: model.notice, cameraIsLive: cameraIsLive, codeInView: model.detection != nil)
    }

    @ViewBuilder private var hint: some View {
        let text = hintText
        Text(text ?? " ")
            .font(Typeface.hint)
            .foregroundStyle(Palette.hint)
            // Keeps it readable over a bright scene, where the dim alone doesn't.
            .shadow(color: Palette.glow, radius: 6)
            .opacity(text == nil ? 0 : 1)
            .animation(Motion.fade, value: text)
            .accessibilityHidden(text == nil)
            .accessibilityFocused($focus, equals: .hint)
    }

    @ViewBuilder private func pill(size: CGSize) -> some View {
        if let detection = model.detection, let summary = model.detectionSummary, !model.drawerOpen {
            let frame = ScanGeometry.foundFrame(around: detection.bounds, in: size).rect
            FoundPill(summary: summary) {
                model.openDetection()
            }
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { pillSize = $0 }
            .position(ScanGeometry.pillCenter(below: frame, pillSize: pillSize, in: size))
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
        }
    }

    /// The result drawer, attached to the bottom edge, and the dimmed
    /// area above it, which closes it when tapped.
    @ViewBuilder private func drawerLayer(size: CGSize, safe: EdgeInsets) -> some View {
        if let result = model.result {
            let maxHeight = size.height - safe.top - 8
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeDrawer() }
                    .accessibilityHidden(true)
                ResultDrawer(result: result, drawer: drawer, haptics: settings.haptics,
                             bottomInset: max(safe.bottom, 16), maxHeight: maxHeight) { velocity in
                    closeDrawer(velocity: velocity)
                }
                .id(result.id)
                .padding(.leading, safe.leading)
                .padding(.trailing, safe.trailing)
                // Laid out at full height and pushed down, so only the top
                // `drawer.height` points show above the edge.
                .modifier(DrawerRise(drawer: drawer))
                .offset(y: maxHeight)
            }
            .frame(width: size.width, height: size.height)
        } else if model.making {
            // Sits on the keyboard when it's up, and shrinks to fit above it.
            let lift = keyboardHeight
            let maxHeight = size.height - safe.top - 8 - lift
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeDrawer() }
                    .accessibilityHidden(true)
                MakeDrawer(draft: $makeDraft, drawer: drawer, haptics: settings.haptics,
                           bottomInset: lift > 0 ? 12 : max(safe.bottom, 16), maxHeight: maxHeight) { velocity in
                    closeDrawer(velocity: velocity)
                }
                .id("make")
                .environment(\.dynamicTypeSize, systemTypeSize)
                .padding(.leading, safe.leading)
                .padding(.trailing, safe.trailing)
                .modifier(DrawerRise(drawer: drawer))
                .offset(y: maxHeight)
                .padding(.bottom, lift)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    /// The keyboard's own curve, near enough, so the drawer rides on it.
    private static let keyboardMotion = Animation.interpolatingSpring(mass: 3, stiffness: 1000, damping: 500)

    private func keyboardChanged(_ note: Notification) {
        guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let screenHeight = (note.object as? UIScreen)?.bounds.height
            ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }.first
            ?? end.maxY
        let height = max(0, screenHeight - end.minY)
        guard abs(height - keyboardHeight) > 0.5 else { return }
        withAnimation(Self.keyboardMotion) { keyboardHeight = height }
    }

    /// The drawer is told first, so it's waiting for its size when the
    /// form lays out.
    private func startMaking(animated: Bool = true) {
        drawer.present(.compact, animated: animated)
        model.startMaking()
    }

    /// Slide the drawer away at the speed it was thrown, let the brackets
    /// go back to waiting, and start the camera again once it's gone.
    private func closeDrawer(velocity: CGFloat = 0) {
        model.releaseDetection()
        drawer.move(to: .dismissed, velocity: velocity, fromDrag: velocity != 0) {
            if drawer.snap == .dismissed { model.clearResult() }
        }
    }

    /// The bottom row sits 26 pt above the screen's edge on a phone with a
    /// home indicator, as drawn; a little higher without one.
    private func bottomInset(_ safe: EdgeInsets) -> CGFloat {
        safe.bottom > 0 ? max(safe.bottom - 8, 16) : 20
    }

    // MARK: - Actions

    private func start() async {
        model.acceptsCodes = splashDone
        model.camera = await CameraAccess.resolve()
        guard let scene = LaunchOptions.demo else { return }
        if let draft = scene.makeDraft {
            makeDraft = draft
            startMaking(animated: false)
        }
        if scene == .photos, let data = DemoContent.photoWithCodes() {
            model.photoCodes = await PhotoScanner.codes(in: data)
        }
    }

    private func placeDemoCode(_ frame: CGRect) {
        guard let scene = LaunchOptions.demo, let payload = scene.payload, frame.width > 0, model.result == nil else { return }
        if scene == .drawerTour {
            if demoFrame == nil {
                demoFrame = frame
                Task { await playDrawerTour(Detection(raw: payload, symbology: "QR", bounds: frame)) }
            }
            return
        }
        model.place(Detection(raw: payload, symbology: "QR", bounds: frame))
        if scene.opensSheet {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                model.result = ScanResult(raw: payload, symbology: "QR", source: .camera)
            }
        }
    }

    // MARK: - Opening animation

    /// Everything the opening animation sets at time `date`, or nil once it's done.
    private func splashFrame(at date: Date, screen: CGSize) -> SplashFrame? {
        guard !splashDone else { return nil }
        let t = LaunchOptions.splashFrozenAt ?? splashStart.map { date.timeIntervalSince($0) } ?? 0
        return reduceMotion
            ? SplashFrame.still(at: t, in: stillTimeline, screen: screen)
            : SplashFrame.moving(at: t, in: splashTimeline, screen: screen)
    }

    private func startSplash() {
        guard !splashDone, splashStart == nil, !splashStarting else { return }
        splashStarting = true
        Task {
            await FirstFrames.wait()
            // The display ticks a little before iOS swaps the launch screen
            // for the app. Hold the first frame, which is the launch image,
            // so the hunt starts where you can see it.
            try? await Task.sleep(for: .milliseconds(120))
            let began = Date.now
            splashStart = began
            guard LaunchOptions.splashFrozenAt == nil else { return }
            func sleep(until time: Double) async {
                try? await Task.sleep(for: .seconds(max(time - Date.now.timeIntervalSince(began), 0)))
            }
            if !reduceMotion && splashTimeline.hasLock {
                await sleep(until: splashTimeline.lockStarts)
                if !splashDone { splashLocked = true }
            }
            await sleep(until: reduceMotion ? stillTimeline.total : splashTimeline.total)
            finishSplash()
        }
    }

    /// The last frame already is the scanner, so this changes nothing on
    /// screen; it just stops the clock and lets codes in.
    private func finishSplash() {
        guard !splashDone else { return }
        splashDone = true
        model.acceptsCodes = true
    }

    /// A tap: everything settles into the scanner at once.
    private func skipSplash() {
        guard !splashDone else { return }
        withAnimation(.easeOut(duration: 0.2)) { finishSplash() }
    }

    /// lensir://scan: close whatever is open and get to the camera.
    private func open(_ link: LensirLink) {
        let plan = ScanRouting.plan(for: link, splashDone: splashDone, splashStarted: splashStart != nil,
                                    hasDrawer: model.drawerOpen, showingHistory: showingHistory,
                                    showingPhotoList: !model.photoCodes.isEmpty)
        switch plan.splash {
        case .none: break
        case .quick: quickSplash = true
        case .skip: skipSplash()
        }
        if plan.closeHistory {
            pendingHistoryRecord = nil
            pendingMake = false
            showingHistory = false
        }
        if plan.closePhotoList { model.photoCodes = [] }
        if plan.closeDrawer { closeDrawer() }
    }

    /// `-LensirDemo drawer-tour`: what a finger would do, on a timer, since
    /// the Simulator can't drag. Each step goes through the same calls a
    /// real drag or tap makes.
    private func playDrawerTour(_ detection: Detection) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        await wait(1.2)
        model.found(detection)
        await wait(1.4)
        model.openDetection()
        await wait(1.8)
        drawer.settle(to: .expanded, velocity: 900, fromDrag: true)
        await wait(2.4)
        drawer.settle(to: .compact)
        await wait(1.4)
        // A flick down: dismissed at 1,400 pt/s.
        closeDrawer(velocity: -1400)
        await wait(1.4)
        model.found(detection)
    }

    private func toggleTorch() {
        let on = !model.torchOn
        model.torchOn = model.camera == .demo ? on : CameraAccess.setTorch(on)
    }

    private func readPhoto() {
        guard let item = photoItem else { return }
        photoItem = nil
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                model.show(notice: "Couldn't open that photo")
                return
            }
            let codes = await PhotoScanner.codes(in: data)
            switch codes.count {
            case 0: model.show(notice: "No code in that photo")
            case 1: model.open(raw: codes[0].raw, symbology: codes[0].symbology, source: .photo)
            default: model.photoCodes = codes
            }
        }
    }

    private func openPendingPhotoCode() {
        guard let code = pendingPhotoCode else { return }
        pendingPhotoCode = nil
        model.open(raw: code.raw, symbology: code.symbology, source: .photo)
    }

    private func openPendingRecord() {
        if pendingMake {
            pendingMake = false
            startMaking()
            return
        }
        guard let record = pendingHistoryRecord else { return }
        pendingHistoryRecord = nil
        model.open(raw: record.raw, symbology: record.symbology, source: .history, scannedAt: record.date)
    }

    /// Opening a code saves it. Holding the camera on the same one only
    /// moves its time; reopening from History doesn't add it again.
    private func saveToHistory() {
        guard let result = model.result, result.source != .history, LaunchOptions.demo == nil else { return }
        var latest = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        latest.fetchLimit = 1
        let last = try? context.fetch(latest).first
        let now = Date.now
        if let last, HistoryLogic.isRepeat(payload: result.raw, at: now, lastPayload: last.raw, lastDate: last.date) {
            last.date = now
        } else {
            context.insert(ScanRecord(raw: result.raw, symbology: result.symbology, date: now))
        }
    }
}

/// Shown instead of the camera when there isn't one, or it's not allowed.
struct CameraMessageView: View {
    enum Action {
        case settings
        case photo(Binding<PhotosPickerItem?>)
    }

    var title: String
    var message: String
    var action: Action

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "camera")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.checkText)
                    .fixedSize(horizontal: false, vertical: true)
                button
                    .padding(.top, 16)
            }
            // On the same edge as the wordmark and the buttons.
            .padding(.horizontal, Metrics.edge)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas)
    }

    @ViewBuilder private var button: some View {
        switch action {
        case .settings:
            Button { CameraAccess.openSettings() } label: {
                Text("Open Settings").primaryButtonStyle()
            }
            .buttonStyle(PressableStyle())
        case .photo(let item):
            PhotosPicker(selection: item, matching: .images) {
                Text("Choose a photo").primaryButtonStyle()
            }
            .buttonStyle(PressableStyle())
        }
    }
}
