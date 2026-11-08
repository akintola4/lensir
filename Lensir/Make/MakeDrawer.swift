//
//  MakeDrawer.swift
//  Lensir
//
//  Make a code, in the same drawer a scan opens in. The header is laid out
//  like a scan's: the name on the left, the code on the right, redrawing
//  as you type. Under it: a chip for each kind, the form
//  for that kind, and two buttons, Show code (full screen, bright, to
//  share or save) and Keep (into My codes). A link you make goes through
//  the same checks as a link you scan, and a risky one asks before it's
//  shown or kept.
//

import SwiftData
import SwiftUI

struct MakeDrawer: View {
    @Binding var draft: CodeDraft
    var drawer: DrawerState
    var haptics: Bool
    var bottomInset: CGFloat
    var maxHeight: CGFloat
    var onClose: (_ velocity: CGFloat) -> Void

    @Environment(\.modelContext) private var context
    @Query private var kept: [MadeCode]
    @State private var code: CGImage?
    /// The checks under a link, shown once typing pauses so they don't
    /// flicker through "Not secure" on the way to "https".
    @State private var shownReport: SafetyReport?
    @State private var reportTask: Task<Void, Never>?
    @State private var showing: ShownCode?
    @State private var confirming: RiskyAction?
    /// Goes up on every keep, for its tick.
    @State private var keepCount = 0
    @AccessibilityFocusState private var previewFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var made: Result<String, CodeProblem> { CodeMaker.make(draft) }
    private var payload: String? { try? made.get() }
    private var problem: CodeProblem? {
        if case .failure(let problem) = made { problem } else { nil }
    }
    private var isKept: Bool {
        guard let payload else { return false }
        return kept.contains { $0.raw == payload }
    }

    var body: some View {
        DrawerSurface(drawer: drawer, haptics: haptics, bottomInset: bottomInset, maxHeight: maxHeight,
                      expands: false, onClose: onClose) {
            // Laid out like a scan's drawer: what it is on the left, the
            // code where the scan's Share button sits.
            // At the accessibility sizes the code goes above the name, so the
            // name gets the whole width, as in My codes.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                if dynamicTypeSize.isAccessibilitySize {
                    CodePreview(image: code, label: previewLabel)
                        .accessibilityFocused($previewFocused)
                }
                VStack(alignment: .leading, spacing: 1) {
                    headerTitle
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(draft.kind.title)
                        .font(Typeface.kindLabel)
                        .foregroundStyle(Palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The code's own label says all of this.
                .accessibilityHidden(true)
                if !dynamicTypeSize.isAccessibilitySize {
                    CodePreview(image: code, label: previewLabel)
                        .accessibilityFocused($previewFocused)
                }
            }
        } content: {
            MakeForm(draft: $draft, problem: problem, report: shownReport, canMake: code != nil, isKept: isKept,
                     onShow: { attempt(.show) }, onKeep: { attempt(.keep) })
        } details: {
            EmptyView()
        }
        .onAppear {
            // VoiceOver starts on the code; the keyboard waits for a tap.
            previewFocused = true
            if LaunchOptions.demo == .makeShow { attempt(.show) }
        }
        .onChange(of: payload, initial: true) { _, payload in
            code = payload.flatMap(CodeImage.modules(for:))
            updateReport(immediately: shownReport == nil && payload != nil && LaunchOptions.demo != nil)
        }
        .sensoryFeedback(trigger: keepCount) { _, _ in HapticLogic.feedback(for: .kept, hapticsOn: haptics) }
        .fullScreenCover(item: $showing) { shown in
            FullScreenCode(raw: shown.raw, name: shown.name)
        }
        .alert("This link looks risky", isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
               presenting: confirming) { action in
            Button(action == .show ? "Show anyway" : "Keep anyway") { perform(action) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(CodeMaker.safety(for: draft)?.findings.first?.message ?? "")
        }
    }

    /// What the code will be called once it's kept, as it's typed.
    private var headerTitle: Text {
        guard let payload, code != nil else { return Text("New code").font(Typeface.title) }
        // A link's site, with any lookalike letter underlined in red, as a
        // scanned one's title is.
        if let report = shownReport, let title = AddressText.title(report) {
            return Text(title).font(Typeface.monoTitle).typesettingLanguage(AddressText.noHyphens)
        }
        let name = CodeMaker.defaultName(for: draft)
        return CodeMaker.display(raw: payload).monospaced
            ? Text(AddressText.breakingAtDots(name)).font(Typeface.monoTitle).typesettingLanguage(AddressText.noHyphens)
            : Text(name).font(Typeface.title)
    }

    private var previewLabel: String {
        guard let payload, code != nil else { return "Make a code. Fill in the form and the code appears here." }
        return CodeMaker.display(raw: payload).accessibilityLabel
    }

    private func updateReport(immediately: Bool) {
        reportTask?.cancel()
        guard draft.kind == .link, payload != nil else {
            withAnimation(Motion.fade) { shownReport = nil }
            return
        }
        if immediately {
            shownReport = CodeMaker.safety(for: draft)
            return
        }
        reportTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) { shownReport = CodeMaker.safety(for: draft) }
        }
    }

    // MARK: - Actions

    enum RiskyAction: Equatable { case show, keep }

    /// A risky link asks first; anything else goes straight ahead.
    private func attempt(_ action: RiskyAction) {
        guard payload != nil else { return }
        if let report = CodeMaker.safety(for: draft), !report.isSafe {
            confirming = action
        } else {
            perform(action)
        }
    }

    private func perform(_ action: RiskyAction) {
        guard let payload else { return }
        switch action {
        case .show:
            showing = ShownCode(raw: payload, name: CodeMaker.defaultName(for: draft))
        case .keep:
            let plan = MyCodesLogic.keep(raw: payload, name: CodeMaker.defaultName(for: draft), keptPayloads: kept.map(\.raw))
            guard case .insert(let name) = plan else { return }
            // The tick lands with the button turning to "Kept".
            withAnimation(Motion.fade) {
                context.insert(MadeCode(raw: payload, name: name))
                try? context.save()
            }
            keepCount += 1
            AccessibilityNotification.Announcement("Kept in My codes").post()
        }
    }
}

/// A code on its way to the full screen.
struct ShownCode: Identifiable, Equatable {
    var raw: String
    var name: String
    var id: String { raw }
}

// MARK: - The code at the top

/// The live code: white with the code on it, or a quiet placeholder until
/// there's enough to make one.
struct CodePreview: View {
    var image: CGImage?
    var label: String
    var side: CGFloat = 76
    @ScaledMetric(relativeTo: .title) private var placeholderIcon: CGFloat = 34

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack {
            // The code itself is always black on white, in either appearance.
            shape.fill(image == nil ? Palette.raised : Palette.paper)
            if let image {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .clipShape(shape)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: min(placeholderIcon, 52), weight: .regular))
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .overlay(image == nil ? nil : shape.strokeBorder(Palette.tileEdge, lineWidth: 1))
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(image == nil ? .isHeader : [.isImage, .isHeader])
        .accessibilityIdentifier("make-preview")
    }
}

// MARK: - The form

enum MakeField: String, Hashable {
    case link, ssid, password, phone, contactName, contactPhone, contactEmail, text
}

/// Inside the drawer, so its buttons and focus see the drawer's environment.
private struct MakeForm: View {
    @Binding var draft: CodeDraft
    var problem: CodeProblem?
    var report: SafetyReport?
    var canMake: Bool
    var isKept: Bool
    var onShow: () -> Void
    var onKeep: () -> Void

    @FocusState private var focus: MakeField?
    @State private var showsPassword = false
    @Environment(\.drawerScroller) private var scroller
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .subheadline) private var menuIcon: CGFloat = 12

    private static let securities: [WiFi.Security] = [.wpa, .wpa3, .wep, .open]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chips
            VStack(alignment: .leading, spacing: 12) {
                fields
            }
            status
            buttons
        }
        .padding(.horizontal, Metrics.sheetPadding)
        .onChange(of: focus) { _, field in
            guard let field else { return }
            // Once the keyboard is up and the drawer has made room for it.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                scroller?.scrollTo(field.rawValue)
            }
        }
    }

    // MARK: Kinds

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(CodeKind.allCases, id: \.self) { kind in
                    let selected = draft.kind == kind
                    DrawerButton {
                        focus = nil
                        draft.kind = kind
                    } label: {
                        Text(kind.title)
                            .font(Typeface.secondaryButton)
                            .foregroundStyle(selected ? Palette.onInk : Palette.ink)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(selected ? Palette.ink : Palette.chip))
                            .overlay(contrast == .increased && !selected ? Capsule().stroke(Palette.grabber) : nil)
                            // 36 pt to look at, 44 pt to hit.
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("make-kind-\(kind.rawValue)")
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Metrics.sheetPadding, for: .scrollContent)
        .padding(.horizontal, -Metrics.sheetPadding)
    }

    // MARK: Fields

    @ViewBuilder private var fields: some View {
        switch draft.kind {
        case .wifi:
            row("Network", .ssid) {
                TextField("Network", text: $draft.ssid, prompt: prompt("Kola-Home-5G"))
                    .focused($focus, equals: .ssid)
                    .font(Typeface.monoBody)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focus = draft.security == .open ? nil : .password }
            }
            if draft.security != .open { passwordRow }
            securityRow
        case .link:
            row("Link", .link) {
                TextField("Link", text: $draft.link, prompt: prompt("kolalogistics.test"))
                    .focused($focus, equals: .link)
                    .font(Typeface.monoBody)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }
        case .phone:
            row("Phone number", .phone) {
                TextField("Phone number", text: $draft.phone, prompt: prompt("+234 806 000 0000"))
                    .focused($focus, equals: .phone)
                    .font(Typeface.monoBody)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        case .contact:
            row("Name", .contactName) {
                TextField("Name", text: $draft.contactName, prompt: prompt("Kola Logistics"))
                    .focused($focus, equals: .contactName)
                    .font(Typeface.body)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit { focus = .contactPhone }
            }
            row("Phone", .contactPhone) {
                TextField("Phone", text: $draft.contactPhone, prompt: prompt("+234 806 000 0000"))
                    .focused($focus, equals: .contactPhone)
                    .font(Typeface.monoBody)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            row("Email", .contactEmail) {
                TextField("Email", text: $draft.contactEmail, prompt: prompt("hello@kolalogistics.test"))
                    .focused($focus, equals: .contactEmail)
                    .font(Typeface.monoBody)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }
        case .text:
            row("Text", .text, multiline: true) {
                TextField("Text", text: $draft.text, prompt: prompt("Gate code 4417. Ring twice."), axis: .vertical)
                    .focused($focus, equals: .text)
                    .font(Typeface.body)
                    .lineLimit(3...8)
            }
        }
    }

    private var passwordRow: some View {
        row("Password", .password) {
            HStack(spacing: 8) {
                Group {
                    if showsPassword {
                        TextField("Password", text: $draft.password, prompt: prompt("At least 8 characters"))
                    } else {
                        SecureField("Password", text: $draft.password, prompt: prompt("At least 8 characters"))
                    }
                }
                .font(Typeface.monoBody)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focus, equals: .password)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button {
                    let typing = focus == .password
                    showsPassword.toggle()
                    if typing { focus = .password }
                } label: {
                    Text(showsPassword ? "Hide" : "Show")
                        .font(Typeface.check)
                        .foregroundStyle(Palette.secondaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .padding(.trailing, -8)
                .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
            }
        }
    }

    private var securityRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Security").accessibilityHidden(true)
            Menu {
                Picker("Security", selection: $draft.security) {
                    ForEach(Self.securities, id: \.self) { security in
                        Text(security.label).tag(security)
                    }
                }
            } label: {
                HStack {
                    Text(draft.security.label)
                        .font(Typeface.body)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: menuIcon, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(fieldBackground)
                .contentShape(Self.fieldShape)
            }
            .accessibilityLabel("Security")
            .accessibilityValue(draft.security.label)
        }
    }

    private static let fieldShape = RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)

    private var fieldBackground: some View {
        Self.fieldShape
            .fill(Palette.raised)
            .overlay(contrast == .increased ? Self.fieldShape.stroke(Palette.grabber) : nil)
    }

    /// A grey label over a field. The field carries its own name for
    /// VoiceOver, so the label is only for the eye.
    private func row<Input: View>(_ label: String, _ field: MakeField, multiline: Bool = false,
                                  @ViewBuilder input: () -> Input) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(label).accessibilityHidden(true)
            input()
                .foregroundStyle(Palette.ink)
                .tint(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.vertical, multiline ? 10 : 0)
                .padding(.horizontal, 12)
                .background(fieldBackground)
                .accessibilityIdentifier("make-field-\(field.rawValue)")
        }
        .id(field.rawValue)
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Palette.secondaryText)
    }

    // MARK: Status

    @ViewBuilder private var status: some View {
        if let report {
            if report.isSafe {
                CheckLine(systemName: "checkmark", color: Palette.safe, text: report.safeSummary, textColor: Palette.checkText)
            } else {
                // The header above shows the site with the swapped letters
                // underlined, so "the underlined а" points at something.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(report.findings.enumerated()), id: \.offset) { _, finding in
                        CheckLine(systemName: "exclamationmark.triangle", color: Palette.warning, text: finding.message,
                                  textColor: Palette.warningText)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Warning. " + report.findings.map(\.message).joined(separator: " "))
            }
        } else if let message = problem?.message {
            CheckLine(systemName: problem == .tooLong ? "exclamationmark.triangle" : "info.circle",
                      color: problem == .tooLong ? Palette.warning : Palette.secondaryText,
                      text: message, textColor: Palette.checkText)
        }
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(spacing: 6) {
            DrawerButton(action: onShow) {
                Text("Show code")
                    .primaryButtonStyle(enabled: canMake)
            }
            .buttonStyle(PressableStyle())
            .disabled(!canMake)

            DrawerButton(action: onKeep) {
                Group {
                    if isKept {
                        Label("Kept in My codes", systemImage: "checkmark")
                    } else {
                        Text("Keep in My codes")
                    }
                }
                .contentTransition(.opacity)
                .font(Typeface.secondaryButton)
                .foregroundStyle(!canMake ? Palette.secondaryText : isKept ? Palette.checkText : Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(!canMake || isKept)
            .accessibilityIdentifier("make-keep")
        }
    }
}
