//
//  FoundPill.swift
//  Lensir
//
//  The white pill under a found code: an icon, what the code is, a chevron.
//  Tapping it grows it into the result sheet.
//

import SwiftUI

struct FoundPill: View {
    var summary: ResultSummary
    var namespace: Namespace.ID
    var morphs: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                Text(ResultLogic.pillText(summary))
                    .font(summary.titleIsMonospaced ? Typeface.pill : Typeface.check)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.leading, summary.pillIcon == .none ? 16 : 13)
            .padding(.trailing, 12)
            .frame(height: 34)
            .background {
                Capsule()
                    .fill(.white)
                    .morph(morphs, in: namespace)
            }
            // 34 pt to look at, 44 pt to hit.
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows what's inside before anything opens")
    }

    @ViewBuilder private var icon: some View {
        switch summary.pillIcon {
        case .none:
            EmptyView()
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.warning)
        default:
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
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

/// The pill's capsule and the sheet's background share one geometry, so
/// the pill grows into the sheet. Off with Reduce Motion: it fades instead.
extension View {
    @ViewBuilder func morph(_ enabled: Bool, in namespace: Namespace.ID) -> some View {
        if enabled {
            matchedGeometryEffect(id: "result-card", in: namespace)
        } else {
            self
        }
    }
}
