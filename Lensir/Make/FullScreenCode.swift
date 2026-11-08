//
//  FullScreenCode.swift
//  Lensir
//
//  A code made to be scanned: big, on white, with the screen turned all the
//  way up while it's open and put back after. The phone won't lock while
//  it's showing, so a guest has time to point their camera. Share sends the
//  picture; Save to Photos only asks to add, never to read your library.
//

import Photos
import SwiftUI

struct FullScreenCode: View {
    var raw: String
    var name: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var brightness = BrightnessLock()
    @State private var saveState: SaveState?
    @State private var saveTask: Task<Void, Never>?
    @AccessibilityFocusState private var codeFocused: Bool
    @ScaledMetric(relativeTo: .body) private var closeIcon: CGFloat = 15

    private var display: CodeDisplay { CodeMaker.display(raw: raw) }
    /// Sharp at any size it's shared or printed at.
    private var shareImage: UIImage? { CodeImage.image(for: raw, atLeast: 1200) }

    /// #6E6E73 as drawn: it holds 4.6:1 on white, so it reads at small sizes.
    private static let quiet = Color(red: 0x6E / 255, green: 0x6E / 255, blue: 0x73 / 255)
    private static let saveFill = Color(red: 0xE5 / 255, green: 0xE5 / 255, blue: 0xEA / 255)

    enum SaveState: Equatable { case saving, saved, denied, failed }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    closeButton
                    Spacer(minLength: 16)
                    code(width: proxy.size.width)
                    Spacer(minLength: 24)
                    actions
                }
                .padding(.horizontal, Metrics.sheetPadding)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.white.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .onAppear {
            codeFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
            raiseBrightness()
        }
        .onDisappear {
            restoreBrightness()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app puts your brightness back; coming back turns it up again.
            if phase == .active { raiseBrightness() } else { restoreBrightness() }
        }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: closeIcon, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: max(44, closeIcon * 2.9), height: max(44, closeIcon * 2.9))
                    .background(Circle().fill(Self.saveFill))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Close")
            .accessibilityIdentifier("code-close")
        }
        .padding(.top, 8)
    }

    private func code(width: CGFloat) -> some View {
        let side = min(width * 0.73, 360)
        return VStack(spacing: 0) {
            Text(display.caption)
                .font(Typeface.check)
                .foregroundStyle(Self.quiet)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            if let image = CodeImageCache.modules(for: raw) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: side, height: side)
                    .accessibilityElement()
                    .accessibilityLabel(display.accessibilityLabel)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityFocused($codeFocused)
                    .accessibilityIdentifier("code-image")
            }
            Text(name)
                .font(display.monospaced ? .system(.title3, design: .monospaced).weight(.bold)
                                         : .system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .accessibilityAddTraits(.isHeader)
            Text(display.detail)
                .font(display.kind == .link ? Typeface.address : Typeface.body)
                .foregroundStyle(Self.quiet)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .truncationMode(.middle)
                .padding(.top, 6)
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Text(saveMessage ?? "Brightness turned up while this is open")
                .font(Typeface.kindLabel)
                .foregroundStyle(Self.quiet)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                if let shareImage {
                    let picture = Image(uiImage: shareImage)
                    ShareLink(item: picture, preview: SharePreview(name, image: picture)) {
                        Text("Share")
                            .font(Typeface.primaryButton)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(.black))
                            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
                Button(action: save) {
                    Group {
                        if saveState == .saved {
                            Label("Saved", systemImage: "checkmark")
                        } else {
                            Text("Save to Photos")
                        }
                    }
                    .contentTransition(.opacity)
                    .font(Typeface.primaryButton)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(Self.saveFill))
                    .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .disabled(saveState == .saving)
            }
        }
    }

    private var saveMessage: String? {
        switch saveState {
        case .denied: "Lensir can't add to Photos. Allow it in Settings › Lensir › Photos."
        case .failed: "Couldn't save the picture. Try again."
        case .saved, .saving, nil: nil
        }
    }

    // MARK: - Brightness

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }

    private func raiseBrightness() {
        guard let screen, let target = brightness.raise(from: screen.brightness) else { return }
        screen.brightness = target
    }

    private func restoreBrightness() {
        guard let screen, let original = brightness.restore() else { return }
        screen.brightness = original
    }

    // MARK: - Saving

    private func save() {
        guard let image = shareImage else { return }
        saveTask?.cancel()
        saveState = .saving
        saveTask = Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                withAnimation(Motion.fade) { saveState = .denied }
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                withAnimation(Motion.fade) { saveState = .saved }
                AccessibilityNotification.Announcement("Saved to Photos").post()
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(Motion.fade) { if saveState == .saved { saveState = nil } }
            } catch {
                withAnimation(Motion.fade) { saveState = .failed }
            }
        }
    }
}
