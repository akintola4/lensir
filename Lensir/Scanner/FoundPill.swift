//
//  FoundPill.swift
//  Lensir
//
//  The white pill under a found code: an icon, what the code is, a chevron.
//  Tapping it slides the result drawer up from the bottom edge.
//

import SwiftUI

struct FoundPill: View {
    var summary: ResultSummary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                Text(ResultLogic.pillText(summary))
                    .font(summary.titleIsMonospaced ? Typeface.pill : Typeface.check)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(Palette.onInk)
            .padding(.leading, summary.pillIcon == .none ? 16 : 13)
            .padding(.trailing, 12)
            .frame(height: 34)
            .background(Capsule().fill(Palette.ink))
            // 34 pt to look at, 44 pt to hit.
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows what's inside before anything opens")
        .accessibilityIdentifier("found-pill")
    }

    @ViewBuilder private var icon: some View {
        switch summary.pillIcon {
        case .none:
            EmptyView()
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.warningOnInk)
        default:
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
        }
    }

    private var symbol: String {
        switch summary.pillIcon {
        case .lock: "lock.fill"
        case .wifi: "wifi"
        case .person: "person.fill"
        case .phone: "phone.fill"
        case .message: "message.fill"
        case .envelope: "envelope.fill"
        case .pin: "mappin"
        case .text: "text.alignleft"
        case .warning, .none: ""
        }
    }

    private var accessibilityText: String {
        var parts = [summary.kindLabel, summary.title]
        if summary.isWarning { parts.append("Warning") } else if summary.pillIcon == .lock { parts.append("Secure") }
        return parts.joined(separator: ", ")
    }
}
