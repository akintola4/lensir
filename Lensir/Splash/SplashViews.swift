//
//  SplashViews.swift
//  Lensir
//
//  What the opening animation draws besides the brackets (which are the
//  scanner overlay's own): the lens dot, its one ring, and the credit.
//  Every value comes from a SplashFrame; these only draw.
//

import SwiftUI

struct SplashMarks: View {
    var splash: SplashFrame

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let mark = splash.stillMark {
                BracketsShape(frame: mark)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: SplashLogic.Mark.stroke, lineCap: .round, lineJoin: .round))
                    .opacity(splash.stillMarkOpacity)
            }
            Circle()
                .stroke(Palette.ink, lineWidth: 1.5)
                .frame(width: splash.ringRadius * 2, height: splash.ringRadius * 2)
                .position(splash.dotCentre)
                .opacity(splash.ringOpacity)
            Circle()
                .fill(Palette.ink)
                .frame(width: splash.dotRadius * 2, height: splash.dotRadius * 2)
                .position(splash.dotCentre)
                .opacity(splash.dotOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "Made by" and the DEVAKINTOLA wordmark, in ink, above the home indicator,
/// as on Pocket's and Tape's opening. The launch screen can only hold one
/// centred image, so this fades in with the first motion rather than
/// popping on.
struct SplashCredit: View {
    var opacity: Double
    var bottomInset: CGFloat

    var body: some View {
        VStack {
            Spacer()
            // 8 pt between the inks, measured: the y's side bearing and the
            // wordmark's own margin add the last point. Centred, the
            // wordmark's middle lands on the middle of the capitals.
            HStack(alignment: .center, spacing: 7) {
                Text("Made by")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.credit)
                Image("DevAkintola")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .foregroundStyle(Palette.ink)
            }
            // The M's side bearing sits the inks right of centre; measured
            // on a 3× screen, this centres them to the pixel.
            .offset(x: -0.5)
            .padding(.bottom, bottomInset + 12)
        }
        .frame(maxWidth: .infinity)
        // The wordmark is a fixed image, so "Made by" stays its size too.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Made by DevAkintola")
    }
}
