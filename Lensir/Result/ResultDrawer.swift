//
//  ResultDrawer.swift
//  Lensir
//
//  What's inside a code, before anything opens, in a drawer attached to the
//  bottom edge like shadcn/ui's Drawer. Compact, it shows what the approved
//  sheet showed: the title in SF Mono with Share beside it, a small label,
//  the address, one line of checks, one white main button and one plain
//  one. A risky link swaps them: Copy becomes the main button and Open
//  anyway turns red. Drag it up, or tap the grabber, and Details appear
//  underneath: every check, every field, the raw text and when it was
//  scanned.
//
//  The drawer's height and physics live in DrawerState and DrawerLogic;
//  this view only draws the content and reports drags and sizes.
//

import SwiftUI

struct ResultDrawer: View {
    var result: ScanResult
    var drawer: DrawerState
    var haptics: Bool
    /// Room for the home indicator under the buttons.
    var bottomInset: CGFloat
    /// The tallest the drawer may get: the screen less the status bar.
    var maxHeight: CGFloat
    var onClose: (_ velocity: CGFloat) -> Void

    @Environment(\.openURL) private var openURL
    @State private var copied: ResultAction?
    @State private var copiedTask: Task<Void, Never>?
    @State private var savingContact = false
    @State private var wifiStatus: WiFiStatus?
    /// Grabber plus header: always a drag handle, pinned above the scroll.
    @State private var handleHeight: CGFloat = 0
    @State private var handleFrame: CGRect = .zero
    @State private var compactBodyHeight: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var dragState = DrawerDrag()
    @State private var dragStartsInHandle = false
    /// Set while, and just after, the drawer follows a finger. The drawer
    /// moves with the finger, so a drag that starts on a button also ends
    /// on it; this keeps that release from counting as a tap.
    @State private var suppressTaps = false

    private var summary: ResultSummary { result.summary }
    private var compactHeight: CGFloat { handleHeight + compactBodyHeight }
    private var fullHeight: CGFloat { handleHeight + scrollContentHeight }
    private var expandedHeight: CGFloat { min(fullHeight, maxHeight) }
    /// Taller than the screen allows: once expanded, Details scroll.
    private var overflows: Bool { fullHeight > maxHeight + 0.5 }
    private var canScroll: Bool { overflows && drawer.snap == .expanded }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                grabber
                header
                    .allowsHitTesting(!suppressTaps)
                    .padding(.horizontal, Metrics.sheetPadding)
                    .padding(.top, 2)
                    .padding(.bottom, 14)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                handleFrame = $0
                handleHeight = $0.height
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    compactBody
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { compactBodyHeight = $0 }
                    expandedDetails
                        .opacity(drawer.expansion)
                        .accessibilityHidden(drawer.snap != .expanded)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scrollContentHeight = $0 }
            }
            .allowsHitTesting(!suppressTaps)
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                scrollOffset = offset
            }
            // Only scrolls while expanded and taller than the screen, and
            // never while the drawer itself has the finger.
            .scrollDisabled(!canScroll || dragState.owner == .drawer)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .frame(height: maxHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Runs on below the screen, so the rubber band never shows a gap.
            UnevenRoundedRectangle(topLeadingRadius: Metrics.drawerRadius, topTrailingRadius: Metrics.drawerRadius, style: .continuous)
                .fill(Palette.sheet)
                .padding(.bottom, -400)
        }
        // Alongside the scroll view and the buttons, not instead of them:
        // DrawerLogic.track decides, per drag, which one the finger means.
        .simultaneousGesture(drag)
        .onChange(of: compactHeight) { report() }
        .onChange(of: fullHeight) { report() }
        .onChange(of: maxHeight) { report() }
        .onChange(of: drawer.snap) {
            // Back to the top of Details whenever it's no longer expanded.
            if drawer.snap != .expanded { scrollPosition.scrollTo(edge: .top) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) { onClose(0) }
        .accessibilityAction(named: "Close") { onClose(0) }
        .sensoryFeedback(trigger: copied) { _, new in haptics && new != nil ? .success : nil }
        .sheet(isPresented: $savingContact) {
            if case .contact(let contact) = result.payload {
                ContactSaveView(contact: contact) { savingContact = false }
                    .ignoresSafeArea()
            }
        }
    }

    private func report() {
        drawer.measured(compact: compactHeight + bottomInset, expanded: expandedHeight)
    }

    // MARK: - Grabber and dragging

    static let grabberHeight: CGFloat = 24

    /// 36 × 5 to look at, 160 × 44 to hit. Tapping it moves between the
    /// two heights.
    private var grabber: some View {
        Capsule()
            .fill(Palette.grabber)
            .frame(width: 36, height: 5)
            .frame(width: 160, height: Self.grabberHeight)
            .contentShape(Rectangle().inset(by: -10))
            .onTapGesture { drawer.toggle() }
            .accessibilityElement()
            .accessibilityIdentifier("drawer-grabber")
            .accessibilityLabel(drawer.snap == .expanded ? "Collapse details" : "Expand details")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { drawer.toggle() }
    }

    /// One gesture over the whole drawer. Under 8 pt it's nothing, so taps
    /// on buttons still land; past that, DrawerLogic.track says whether
    /// the finger is moving the drawer, scrolling Details, or going sideways.
    private var drag: some Gesture {
        DragGesture(minimumDistance: DrawerLogic.dragThreshold, coordinateSpace: .global)
            .onChanged { value in
                if dragState.owner == nil {
                    dragStartsInHandle = handleFrame.contains(value.startLocation)
                }
                let before = dragState.owner
                dragState = DrawerLogic.track(dragState, translation: value.translation, startsInHandle: dragStartsInHandle,
                                              scrollOffset: scrollOffset, canScroll: canScroll)
                if dragState.owner == .drawer {
                    suppressTaps = true
                    if before == .scroll { scrollPosition.scrollTo(edge: .top) }
                    drawer.dragChanged(dragState.drawerTranslation(value.translation.height))
                }
            }
            .onEnded { value in
                defer { dragState = DrawerDrag() }
                guard dragState.owner == .drawer else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    suppressTaps = false
                }
                let velocity = value.velocity.height
                switch drawer.dragEnded(velocity: velocity) {
                case .dismissed: onClose(-velocity)
                case let snap: drawer.move(to: snap, velocity: -velocity)
                }
            }
    }

    // MARK: - Compact

    /// Everything in compact under the header: the details line or two,
    /// the checks and the buttons.
    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            details
            buttons
        }
        .padding(.horizontal, Metrics.sheetPadding)
        .padding(.bottom, summary.secondary == nil ? Metrics.sheetPadding : 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                titleText
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                Text(summary.kindLabel)
                    .font(Typeface.kindLabel)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            ShareLink(item: summary.shareText) {
                CircleIcon(systemName: "square.and.arrow.up", background: Palette.raised)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Share")
        }
    }

    private var titleText: Text { Self.title(summary) }

    /// The title, with lookalike letters underlined in red wherever it's
    /// shown: the sheet, the photo list and History.
    static func title(_ summary: ResultSummary) -> Text {
        if let report = summary.safety, let title = AddressText.title(report) {
            return Text(title).font(Typeface.monoTitle)
        }
        return Text(summary.title).font(summary.titleIsMonospaced ? Typeface.monoTitle : Typeface.title)
    }

    // MARK: - Details

    @ViewBuilder private var details: some View {
        switch result.payload {
        case .link(let link):
            if let report = summary.safety {
                Text(AddressText.full(link, report: report))
                    .font(Typeface.address)
                    .lineSpacing(4)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Address: \(link)")
                checks(report)
            }
        case .wifi(let wifi):
            DetailRow(label: "Password", value: wifi.password ?? "None needed", monospaced: wifi.password != nil)
            DetailRow(label: "Security", value: wifi.security.label)
            if let wifiStatus { wifiStatusLine(wifiStatus, ssid: wifi.ssid) }
        case .contact(let contact):
            ForEach(Array(contact.phones.prefix(2).enumerated()), id: \.offset) { _, phone in
                DetailRow(label: "Phone", value: phone, monospaced: true)
            }
            ForEach(Array(contact.emails.prefix(2).enumerated()), id: \.offset) { _, email in
                DetailRow(label: "Email", value: email, monospaced: true)
            }
            let work = [contact.jobTitle, contact.organization].filter { !$0.isEmpty }.joined(separator: ", ")
            if !work.isEmpty, work != contact.displayName { DetailRow(label: "Work", value: work) }
            if !contact.address.isEmpty { DetailRow(label: "Address", value: contact.address) }
        case .phone:
            EmptyView()
        case .sms(_, let body):
            if !body.isEmpty { DetailRow(label: "Message", value: body) }
        case .email(_, let subject, let body):
            if !subject.isEmpty { DetailRow(label: "Subject", value: subject) }
            if !body.isEmpty { DetailRow(label: "Message", value: body) }
        case .location(let location):
            if location.query != nil { DetailRow(label: "Coordinates", value: location.coordinates, monospaced: true) }
        case .text(let text):
            if text != summary.title {
                ScrollView {
                    Text(text)
                        .font(summary.titleIsMonospaced ? Typeface.monoBody : Typeface.body)
                        .foregroundStyle(Palette.warningText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func checks(_ report: SafetyReport) -> some View {
        if report.isSafe {
            CheckLine(systemName: "checkmark", color: Palette.safe, text: report.safeSummary, textColor: Palette.checkText)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(report.findings.enumerated()), id: \.offset) { _, finding in
                    CheckLine(systemName: "exclamationmark.triangle", color: Palette.warning, text: finding.message, textColor: Palette.warningText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Warning. " + report.findings.map(\.message).joined(separator: " "))
        }
    }

    @ViewBuilder private func wifiStatusLine(_ status: WiFiStatus, ssid: String) -> some View {
        switch status {
        case .joining:
            HStack(spacing: 7) {
                ProgressView().controlSize(.small).tint(.white)
                Text("Joining…").font(Typeface.check).foregroundStyle(Palette.checkText)
            }
        case .joined:
            CheckLine(systemName: "checkmark", color: .white, text: "Joined \(ssid)", textColor: Palette.checkText)
        case .failed(let message):
            CheckLine(systemName: "exclamationmark.triangle", color: Palette.warning, text: message, textColor: Palette.warningText)
        }
    }

    // MARK: - Expanded

    /// Below the buttons, out of sight until the drawer is pulled up, and
    /// faded in as it rises so nothing peeks out under the home indicator.
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            Rectangle()
                .fill(Palette.raised)
                .frame(height: 1)
            Text("Details")
                .font(Typeface.sectionHeader)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            if case .link(let link) = result.payload, let report = summary.safety {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Full address")
                    Text(AddressText.full(link, report: report))
                        .font(Typeface.address)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel("Checks")
                    ForEach(Array(ResultDetails.checks(for: report).enumerated()), id: \.offset) { _, check in
                        CheckRow(check: check)
                    }
                }
            } else {
                ForEach(Array(ResultDetails.fields(for: result.payload).enumerated()), id: \.offset) { _, field in
                    DetailRow(label: field.label, value: field.value, monospaced: field.monospaced)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    FieldLabel("Scanned text")
                    Spacer()
                    Button { copy(result.raw, for: nil) } label: {
                        Image(systemName: copiedRaw ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.vertical, -12)
                    .padding(.trailing, -12)
                    .accessibilityLabel(copiedRaw ? "Copied" : "Copy scanned text")
                }
                Text(result.raw)
                    .font(Typeface.address)
                    .foregroundStyle(Palette.checkText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.raised))
            }

            DetailRow(label: "Scanned", value: scannedLine)

            Button { onClose(0) } label: {
                Label("Scan again", systemImage: "viewfinder")
                    .font(Typeface.secondaryButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(Palette.raised))
                    .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, Metrics.sheetPadding)
        .padding(.top, 8)
        .padding(.bottom, bottomInset + 8)
    }

    private var scannedLine: String {
        let when = result.scannedAt.formatted(date: .abbreviated, time: .shortened)
        let source = switch result.source {
        case .camera: "with the camera"
        case .photo: "from a photo"
        case .history: "opened from History"
        }
        return "\(when), \(source)"
    }

    @State private var copiedRaw = false

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 6) {
            Button { perform(summary.primary) } label: {
                buttonLabel(summary.primary)
                    .primaryButtonStyle()
            }
            .buttonStyle(PressableStyle())
            .disabled(summary.primary == .joinWiFi && wifiStatus == .joining)

            if let secondary = summary.secondary {
                Button { perform(secondary) } label: {
                    buttonLabel(secondary)
                        .font(Typeface.secondaryButton)
                        .foregroundStyle(secondary == .openAnyway ? Palette.warning : .white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    @ViewBuilder private func buttonLabel(_ action: ResultAction) -> some View {
        if copied == action {
            Label("Copied", systemImage: "checkmark")
                .contentTransition(.opacity)
        } else {
            Text(action.title)
        }
    }

    // MARK: - Actions

    private func perform(_ action: ResultAction) {
        guard !suppressTaps else { return }
        switch (action, result.payload) {
        case (.openLink, .link(let link)), (.openAnyway, .link(let link)):
            if let url = ResultLinks.web(link) { openURL(url) }
        case (.copyLink, .link(let link)):
            copy(link, for: action)
        case (.joinWiFi, .wifi(let wifi)):
            join(wifi)
        case (.copyPassword, .wifi(let wifi)):
            copy(wifi.password ?? "", for: action)
        case (.copyNetworkName, .wifi(let wifi)):
            copy(wifi.ssid, for: action)
        case (.saveContact, .contact):
            savingContact = true
        case (.copyContact, .contact(let contact)):
            copy(ResultLogic.contactText(contact), for: action)
        case (.call, .phone(let number)):
            if let url = ResultLinks.call(number) { openURL(url) }
        case (.copyNumber, .phone(let number)), (.copyNumber, .sms(let number, _)):
            copy(number, for: action)
        case (.sendMessage, .sms(let number, let body)):
            if let url = ResultLinks.message(to: number, body: body) { openURL(url) }
        case (.copyMessage, .sms(_, let body)):
            copy(body, for: action)
        case (.email, .email(let address, let subject, let body)):
            if let url = ResultLinks.email(to: address, subject: subject, body: body) { openURL(url) }
        case (.copyEmailAddress, .email(let address, _, _)):
            copy(address, for: action)
        case (.openMaps, .location(let location)):
            if let url = ResultLinks.maps(location) { openURL(url) }
        case (.copyCoordinates, .location(let location)):
            copy(location.coordinates, for: action)
        case (.copyText, .text(let text)):
            copy(text, for: action)
        default:
            break
        }
    }

    /// Copies and shows "Copied" on the button that did it for 1.5 s. A nil
    /// action is the raw-text button under Details.
    private func copy(_ text: String, for action: ResultAction?) {
        UIPasteboard.general.string = text
        copiedTask?.cancel()
        withAnimation(Motion.fade) {
            copied = action
            copiedRaw = action == nil
        }
        copiedTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) {
                copied = nil
                copiedRaw = false
            }
        }
    }

    private func join(_ wifi: WiFi) {
        withAnimation(Motion.fade) { wifiStatus = .joining }
        Task {
            let outcome = await WiFiJoiner.join(wifi)
            withAnimation(Motion.fade) {
                switch outcome {
                case .joined: wifiStatus = .joined
                case .cancelled: wifiStatus = nil
                case .failed(let message): wifiStatus = .failed(message)
                }
            }
        }
    }
}

enum WiFiStatus: Equatable {
    case joining
    case joined
    case failed(String)
}

/// One line of the checks: an icon and a sentence.
struct CheckLine: View {
    var systemName: String
    var color: Color
    var text: String
    var textColor: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .font(Typeface.check)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One check under Details: a green tick when it passed, a red cross when
/// it didn't.
struct CheckRow: View {
    var check: CheckItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: check.passed ? "checkmark" : "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(check.passed ? Palette.safe : Palette.warning)
                .frame(width: 16)
            Text(check.title)
                .font(Typeface.check)
                .foregroundStyle(check.passed ? Palette.checkText : Palette.warningText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(check.title): \(check.passed ? "passed" : "failed")")
    }
}

struct FieldLabel: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Typeface.kindLabel)
            .foregroundStyle(Palette.secondaryText)
    }
}

/// A small grey label over its value.
struct DetailRow: View {
    var label: String
    var value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typeface.kindLabel)
                .foregroundStyle(Palette.secondaryText)
            Text(value)
                .font(monospaced ? Typeface.monoBody : Typeface.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}
