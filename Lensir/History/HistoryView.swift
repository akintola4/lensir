//
//  HistoryView.swift
//  Lensir
//
//  My codes at the top, the codes you made and kept, then every code
//  you've opened, newest first and grouped by day. Swipe to delete one,
//  or clear the scans. It all stays on this phone.
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    var settings: AppSettings
    var onOpen: (ScanRecord) -> Void
    /// Make a code: History closes and the Make drawer rises.
    var onMake: () -> Void

    @Query(sort: \ScanRecord.date, order: .reverse) private var records: [ScanRecord]
    @Query(sort: \MadeCode.date, order: .reverse) private var codes: [MadeCode]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false
    @State private var shown: MadeCode?
    @State private var renaming: MadeCode?
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            list
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
        .fullScreenCover(item: $shown) { code in
            FullScreenCode(raw: code.raw, name: code.name)
        }
        .alert("Rename code", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let renaming { renaming.name = MyCodesLogic.renamed(current: renaming.name, to: newName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only you see this name. The code stays the same.")
        }
    }

    private var list: some View {
        List {
            Section {
                if codes.isEmpty {
                    MyCodesEmpty(onMake: onMake)
                        .listRowBackground(Palette.sheet)
                } else {
                    ForEach(codes) { code in
                        Button { shown = code } label: { MadeCodeRow(code: code) }
                            .buttonStyle(PressableStyle())
                            .listRowBackground(Palette.sheet)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { context.delete(code) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { startRenaming(code) } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                            }
                            .contextMenu {
                                Button { startRenaming(code) } label: { Label("Rename", systemImage: "pencil") }
                                Button(role: .destructive) { context.delete(code) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            } header: {
                Text("My codes")
            }

            if records.isEmpty {
                Section("Scanned") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No scans yet")
                            .font(Typeface.title)
                            .foregroundStyle(.white)
                        Text("Codes you open show up here. They stay on this phone.")
                            .font(Typeface.body)
                            .foregroundStyle(Palette.checkText)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Palette.sheet)
                }
            } else {
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
        }
        .scrollContentBackground(.hidden)
        .confirmationDialog("Clear all history?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) {
                try? context.delete(model: ScanRecord.self)
            }
        } message: {
            Text("Every scan is removed from this phone. My codes stay. This can't be undone.")
        }
    }

    private func startRenaming(_ code: MadeCode) {
        newName = code.name
        renaming = code
    }
}

/// A kept code: a small copy of it, its name, its kind and when you made it.
struct MadeCodeRow: View {
    var code: MadeCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 36 pt at the default size, as drawn; grows with the text.
    @ScaledMetric(relativeTo: .subheadline) private var thumbnail: CGFloat = 36

    var body: some View {
        let display = CodeMaker.display(raw: code.raw)
        // At the accessibility sizes the code goes above the name, so the
        // name gets the whole width instead of breaking mid-word.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            ZStack {
                RoundedRectangle(cornerRadius: min(thumbnail, 72) * 0.22, style: .continuous).fill(.white)
                if let image = CodeImageCache.modules(for: code.raw) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .padding(min(thumbnail, 72) * 0.04)
                }
            }
            .frame(width: min(thumbnail, 72), height: min(thumbnail, 72))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // The breaks are for the eye; VoiceOver gets the plain name.
                Text(display.monospaced ? AddressText.breakingAtDots(code.name) : code.name)
                    .accessibilityLabel(code.name)
                    .font(display.monospaced ? Typeface.monoTitle : Typeface.title)
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .truncationMode(.middle)
                    .typesettingLanguage(AddressText.noHyphens)
                Text(MyCodesLogic.subtitle(raw: code.raw, date: code.date))
                    .font(Typeface.kindLabel)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the code full screen")
    }
}

/// My codes before there are any: what it's for, and the way in.
struct MyCodesEmpty: View {
    var onMake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keep the codes you show often")
                .font(Typeface.title)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text("Your Wi-Fi for guests, your shop's link, your number, one tap away.")
                .font(Typeface.body)
                .foregroundStyle(Palette.checkText)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onMake) {
                Text("Make a code").primaryButtonStyle()
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 12)
            .accessibilityIdentifier("my-codes-make")
        }
        .padding(.vertical, 10)
    }
}

struct HistoryRow: View {
    var record: ScanRecord
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 28 pt at the default size; grows with the text.
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 28

    var body: some View {
        let summary = ResultLogic.summary(for: PayloadParser.parse(record.raw), raw: record.raw, symbology: record.symbology, canJoinWiFi: WiFiJoiner.isAvailable)
        HStack(spacing: 12) {
            Image(systemName: HistoryLogic.symbol(for: summary, symbology: record.symbology))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summary.isWarning ? Palette.warning : Palette.secondaryText)
                .frame(width: iconWidth)
                .accessibilityLabel("Warning")
                .accessibilityHidden(!summary.isWarning)
            VStack(alignment: .leading, spacing: 2) {
                // One line, cut in the middle; at the accessibility sizes the
                // whole title, so a lookalike letter is never cut away.
                ResultDrawer.title(summary)
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .truncationMode(.middle)
                    .typesettingLanguage(AddressText.noHyphens)
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
}

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Haptics", isOn: $settings.haptics)
            } footer: {
                Text("Taps when a code is found, warns on a risky one, and ticks as the drawer settles, or when something is copied or kept.")
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
