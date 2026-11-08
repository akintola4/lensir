//
//  PhotoScanner.swift
//  Lensir
//
//  Finds every code in a photo with Vision. The photo is read, scaled down
//  and turned upright on a background thread, and never leaves the phone.
//

import ImageIO
import SwiftUI
import Vision

nonisolated struct PhotoCode: Identifiable, Equatable, @unchecked Sendable {
    let id = UUID()
    var raw: String
    var symbology: String
    /// A crop of the photo around the code, for telling several apart.
    var thumbnail: CGImage?

    static func == (lhs: PhotoCode, rhs: PhotoCode) -> Bool { lhs.id == rhs.id }
}

nonisolated enum PhotoScanner {
    @concurrent
    static func codes(in data: Data) async -> [PhotoCode] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [] }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return [] }
        return codes(in: image)
    }

    static func codes(in image: CGImage) -> [PhotoCode] {
        let request = VNDetectBarcodesRequest()
        #if targetEnvironment(simulator)
        // The Simulator can't run the current barcode model ("Could not
        // create inference context", or no results on the CPU). Revision 1
        // still works there, which keeps the photo flow testable. Phones use
        // the current revision.
        request.revision = 1  // VNDetectBarcodesRequestRevision1
        #endif
        let supported = Set((try? request.supportedSymbologies()) ?? Symbology.all)
        request.symbologies = Symbology.all.filter(supported.contains)
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        var seen: Set<String> = []
        var codes: [PhotoCode] = []
        // Top to bottom, then left to right, the way you'd read the photo.
        let observations = (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.05 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        for observation in observations {
            guard let raw = observation.payloadStringValue, !raw.isEmpty, seen.insert(raw).inserted else { continue }
            codes.append(PhotoCode(raw: raw, symbology: Symbology.name(observation.symbology), thumbnail: crop(image, to: observation.boundingBox)))
        }
        return codes
    }

    /// Vision's boxes are normalised with the origin at the bottom left.
    private static func crop(_ image: CGImage, to box: CGRect) -> CGImage? {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let rect = CGRect(x: box.minX * width, y: (1 - box.maxY) * height, width: box.width * width, height: box.height * height)
            .insetBy(dx: -box.width * width * 0.12, dy: -box.height * height * 0.12)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        return image.cropping(to: rect.integral)
    }
}

/// Several codes in one photo: pick the one you meant.
struct PhotoCodesSheet: View {
    var codes: [PhotoCode]
    var onPick: (PhotoCode) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List(codes) { code in
                let summary = ResultLogic.summary(for: PayloadParser.parse(code.raw), raw: code.raw, symbology: code.symbology, canJoinWiFi: WiFiJoiner.isAvailable)
                Button {
                    onPick(code)
                } label: {
                    HStack(spacing: 12) {
                        thumbnail(code.thumbnail)
                        VStack(alignment: .leading, spacing: 2) {
                            // The whole title at the accessibility sizes, so two
                            // lookalike sites never cut down to the same "pay…com".
                            ResultDrawer.title(summary)
                                .foregroundStyle(.white)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                .truncationMode(.middle)
                            HStack(spacing: 4) {
                                if summary.isWarning {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Palette.warning)
                                        .accessibilityLabel("Warning")
                                }
                                Text(summary.kindLabel)
                            }
                            .font(Typeface.kindLabel)
                            .foregroundStyle(Palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .listRowBackground(Palette.sheet)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("\(codes.count) codes in this photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private func thumbnail(_ image: CGImage?) -> some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
            } else {
                Palette.raised
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
