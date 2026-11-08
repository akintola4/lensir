//
//  HistoryView.swift
//  Lensir
//
//  Every code you've opened, newest first and grouped by day. Swipe to
//  delete one, or clear the lot. It all stays on this phone.
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    var settings: AppSettings
    var onOpen: (ScanRecord) -> Void

    @Query(sort: \ScanRecord.date, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView {
                        Label("No scans yet", systemImage: "clock")
                    } description: {
                        Text("Codes you open show up here. They stay on this phone.")
                    }
                } else {
                    list
                }
            }
            .background(Color.black)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView(settings: settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(HistoryLogic.sections(records, date: \.date)) { section in
                Section(section.title) {
                    ForEach(section.items) { record in
                        Button { onOpen(record) } label: { HistoryRow(record: record) }
                            .buttonStyle(PressableStyle())
                            .listRowBackground(Palette.sheet)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(section.items[index]) }
                    }
                }
            }
            Section {
                Button("Clear history", role: .destructive) { confirmingClear = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .listRowBackground(Palette.sheet)
            }
        }
        .scrollContentBackground(.hidden)
        .confirmationDialog("Clear all history?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) {
                try? context.delete(model: ScanRecord.self)
            }
        } message: {
            Text("Every scan is removed from this phone. This can't be undone.")
        }
    }
}

struct HistoryRow: View {
    var record: ScanRecord

    var body: some View {
        let summary = ResultLogic.summary(for: PayloadParser.parse(record.raw), raw: record.raw, symbology: record.symbology, canJoinWiFi: WiFiJoiner.isAvailable)
        HStack(spacing: 12) {
            Image(systemName: summary.isWarning ? "exclamationmark.triangle" : symbol(summary.pillIcon))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(summary.isWarning ? Palette.warning : Palette.secondaryText)
                .frame(width: 28)
                .accessibilityLabel(summary.isWarning ? "Warning" : "")
            VStack(alignment: .leading, spacing: 2) {
                ResultDrawer.title(summary)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(summary.kindLabel) · \(record.date.formatted(date: .omitted, time: .shortened))")
                    .font(Typeface.kindLabel)
                    .foregroundStyle(Palette.secondaryText)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func symbol(_ icon: ResultSummary.PillIcon) -> String {
        switch icon {
        case .lock: "lock"
        case .wifi: "wifi"
        case .person: "person"
        case .phone: "phone"
        case .message: "message"
        case .envelope: "envelope"
        case .pin: "mappin"
        case .text: "text.alignleft"
        case .warning: "exclamationmark.triangle"
        case .none: "link"
        }
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Haptics", isOn: $settings.haptics)
            } footer: {
                Text("A light tap when a code is found and when something is copied.")
            }
            Section("Privacy") {
                Text("Lensir has no network code. Codes, photos and history never leave this phone, and links only open when you tap Open.")
                    .font(Typeface.body)
                    .foregroundStyle(Palette.checkText)
            }
            Section {
                Link(destination: URL(string: "https://devakintola.com")!) {
                    HStack {
                        Text("Made by DevAkintola")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
