//
//  ScannerScreen.swift
//  Lensir
//
//  The one screen. The camera fills it; four brackets wait in the middle.
//  When a code turns up they snap onto it and a white pill names what it
//  is. Nothing opens by itself: tap the pill and it grows into the sheet,
//  where you see the whole thing and choose.
//

import PhotosUI
import SwiftData
import SwiftUI

struct ScannerScreen: View {
    var settings: AppSettings

    @State private var model = ScannerModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showingHistory = LaunchOptions.openHistory
    @State private var pendingHistoryRecord: (raw: String, symbology: String)?
    @State private var pillSize = CGSize(width: 160, height: 44)
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let safe = proxy.safeAreaInsets
            let size = CGSize(width: proxy.size.width + safe.leading + safe.trailing,
                              height: proxy.size.height + safe.top + safe.bottom)
            ZStack(alignment: .topLeading) {
                camera(size: size)
                overlay(size: size)
                controls(safe: safe)
                pill(size: size)
                sheet(safe: safe)
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(.named("screen"))
            .ignoresSafeArea()
        }
        .background(Color.black)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .task { await start() }
        .onChange(of: reduceMotion, initial: true) { model.reduceMotion = reduceMotion }
        .onChange(of: model.result?.id) { saveToHistory() }
        .onChange(of: photoItem) { readPhoto() }
        .onChange(of: scenePhase) {
            if scenePhase != .active, model.torchOn {
                model.torchOn = false
                CameraAccess.setTorch(false)
            }
        }
        .sensoryFeedback(trigger: model.foundCount) { _, _ in settings.haptics ? .impact(weight: .medium) : nil }
        .sheet(isPresented: $showingHistory, onDismiss: openPendingRecord) {
            HistoryView(settings: settings) { record in
                pendingHistoryRecord = (record.raw, record.symbology)
                showingHistory = false
            }
        }
        .sheet(isPresented: Binding(get: { !model.photoCodes.isEmpty }, set: { if !$0 { model.photoCodes = [] } })) {
            PhotoCodesSheet(codes: model.photoCodes) { code in
                model.photoCodes = []
                Task {
                    // Let the list slide away before the result grows in.
                    try? await Task.sleep(for: .milliseconds(350))
                    model.open(raw: code.raw, symbology: code.symbology, source: .photo)
                }
            }
        }
    }

    // MARK: - Layers

    @ViewBuilder private func camera(size: CGSize) -> some View {
        let scanning = model.result == nil && scenePhase == .active
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
                Color.black
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var cameraIsLive: Bool {
        [.dataScanner, .capture, .demo].contains(model.camera)
    }

    @ViewBuilder private func overlay(size: CGSize) -> some View {
        if cameraIsLive {
            let frame = model.detection.map { ScanGeometry.foundFrame(around: $0.bounds, in: size) } ?? ScanGeometry.lookingFrame(in: size)
            let warning = model.result?.summary.isWarning ?? model.detectionSummary?.isWarning ?? false
            ScanOverlay(
                frame: frame,
                dim: ScanGeometry.dimOpacity(found: model.detection != nil, sheetOpen: model.result != nil),
                warning: warning && (model.detection != nil || model.result != nil),
                showsBrackets: !(model.result != nil && model.detection == nil)
            )
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
                    .foregroundStyle(.white)
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
                    Spacer()
                    Button { showingHistory = true } label: {
                        CircleIcon(systemName: "clock.arrow.circlepath", diameter: 52)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("History")
                }
            }
            .padding(.bottom, bottomInset(safe))
            .opacity(model.result == nil ? 1 : 0)
            .allowsHitTesting(model.result == nil)
        }
        .padding(.leading, Metrics.edge + safe.leading)
        .padding(.trailing, Metrics.edge + safe.trailing)
    }

    @ViewBuilder private var hint: some View {
        let text = model.notice ?? (cameraIsLive && model.detection == nil ? "Point at a QR code" : nil)
        Text(text ?? " ")
            .font(Typeface.hint)
            .foregroundStyle(Palette.hint)
            .opacity(text == nil ? 0 : 1)
            .animation(Motion.fade, value: text)
            .accessibilityHidden(text == nil)
    }

    @ViewBuilder private func pill(size: CGSize) -> some View {
        if let detection = model.detection, let summary = model.detectionSummary, model.result == nil {
            let frame = ScanGeometry.foundFrame(around: detection.bounds, in: size).rect
            FoundPill(summary: summary, namespace: namespace, morphs: !reduceMotion) {
                model.openDetection()
            }
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { pillSize = $0 }
            .position(ScanGeometry.pillCenter(below: frame, pillSize: pillSize, in: size))
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
        }
    }

    @ViewBuilder private func sheet(safe: EdgeInsets) -> some View {
        if let result = model.result {
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeResult() }
                    .accessibilityHidden(true)
                ResultSheet(result: result, haptics: settings.haptics, namespace: namespace,
                            morphs: !reduceMotion && result.source == .camera) {
                    model.closeResult()
                }
                .id(result.id)
                .padding(.leading, Metrics.edge + safe.leading)
                .padding(.trailing, Metrics.edge + safe.trailing)
                .padding(.bottom, bottomInset(safe))
                .transition(sheetTransition(result))
            }
        }
    }

    private func sheetTransition(_ result: ScanResult) -> AnyTransition {
        if reduceMotion { return .opacity }
        if result.source == .camera { return .opacity }
        return .opacity.combined(with: .offset(y: 24))
    }

    /// The bottom row sits 26 pt above the screen's edge on a phone with a
    /// home indicator, as drawn; a little higher without one.
    private func bottomInset(_ safe: EdgeInsets) -> CGFloat {
        safe.bottom > 0 ? max(safe.bottom - 8, 16) : 20
    }

    // MARK: - Actions

    private func start() async {
        model.camera = await CameraAccess.resolve()
        guard let scene = LaunchOptions.demo else { return }
        if scene == .photos, let data = DemoContent.photoWithCodes() {
            model.photoCodes = await PhotoScanner.codes(in: data)
        }
    }

    private func placeDemoCode(_ frame: CGRect) {
        guard let scene = LaunchOptions.demo, let payload = scene.payload, frame.width > 0, model.result == nil else { return }
        model.place(Detection(raw: payload, symbology: "QR", bounds: frame))
        if scene.opensSheet {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                model.result = ScanResult(raw: payload, symbology: "QR", source: .camera)
            }
        }
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

    private func openPendingRecord() {
        guard let record = pendingHistoryRecord else { return }
        pendingHistoryRecord = nil
        model.open(raw: record.raw, symbology: record.symbology, source: .history)
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
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.checkText)
                    .fixedSize(horizontal: false, vertical: true)
                button
                    .padding(.top, 16)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
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
