//
//  ResultSheet.swift
//  Lensir
//
//  What's inside a code, before anything opens. Every kind of code gets the
//  same sheet: the title in SF Mono with Share beside it, a small label,
//  the details, one line of checks for links, one white main button and
//  one plain one. A risky link swaps them: Copy becomes the main button and
//  Open anyway turns red.
//

import SwiftUI

struct ResultSheet: View {
    var result: ScanResult
    var haptics: Bool
    var namespace: Namespace.ID
    var morphs: Bool
    var onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied: ResultAction?
    @State private var copiedTask: Task<Void, Never>?
    @State private var savingContact = false
    @State private var wifiStatus: WiFiStatus?
    @State private var dragOffset: CGFloat = 0

    private var summary: ResultSummary { result.summary }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            details
            buttons
        }
        .padding(.horizontal, Metrics.sheetPadding)
        .padding(.top, Metrics.sheetPadding)
        .padding(.bottom, summary.secondary == nil ? Metrics.sheetPadding : 12)
        .background {
            RoundedRectangle(cornerRadius: Metrics.sheetRadius, style: .continuous)
                .fill(Palette.sheet)
                .morph(morphs, in: namespace)
        }
        .offset(y: dragOffset)
        .gesture(dismissDrag)
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onClose)
        .sensoryFeedback(trigger: copied) { _, new in haptics && new != nil ? .success : nil }
        .sheet(isPresented: $savingContact) {
            if case .contact(let contact) = result.payload {
                ContactSaveView(contact: contact) { savingContact = false }
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                titleText
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .textSelection(.enabled)
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
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityLabel("Full address: \(link)")
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

    private func copy(_ text: String, for action: ResultAction) {
        UIPasteboard.general.string = text
        copiedTask?.cancel()
        withAnimation(Motion.fade) { copied = action }
        copiedTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) { copied = nil }
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

    // MARK: - Dismissing

    /// Pull down to put it away; pulling up gives a little and springs back.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let y = value.translation.height
                dragOffset = y > 0 ? y : y / 6
            }
            .onEnded { value in
                if value.translation.height > 110 || value.predictedEndTranslation.height > 260 {
                    onClose()
                } else {
                    withAnimation(reduceMotion ? Motion.fade : .spring(duration: 0.3, bounce: 0)) { dragOffset = 0 }
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
