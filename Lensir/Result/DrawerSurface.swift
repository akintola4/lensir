//
//  DrawerSurface.swift
//  Lensir
//
//  The drawer itself, whatever is in it: attached to the bottom edge with
//  rounded top corners, a grabber, a header that's always a drag handle,
//  and content under it that scrolls when there's no room. It follows the
//  finger anywhere on it, Vaul-style, and hands a drag between moving the
//  drawer and scrolling the content. The scan result and Make both use it.
//
//  A drawer that `expands` has two heights, compact and expanded, with
//  Details faded in between. One that doesn't has a single height, and its
//  content scrolls whenever it's taller than the room it has.
//
//  The drawer's height and physics live in DrawerState and DrawerLogic;
//  this view draws the frame and reports drags and sizes. Nothing here
//  reads the height: the small modifiers at the bottom do, so a frame of
//  a drag or a spring redraws only them.
//

import SwiftUI

extension EnvironmentValues {
    /// True while, and just after, the drawer follows a finger. A drag that
    /// starts on a button also ends on it; content checks this so that
    /// release doesn't count as a tap.
    @Entry var drawerSuppressesTaps = false
    /// Scrolls the drawer's content to a view by its `.id`, if it scrolls.
    @Entry var drawerScroller: DrawerScroller?
}

/// Lets content scroll its drawer, say to the field being typed in. A
/// reference, so handing it down doesn't redraw the content each pass.
final class DrawerScroller {
    fileprivate var scroll: (String) -> Void = { _ in }

    func scrollTo(_ id: String) { scroll(id) }
}

struct DrawerSurface<Header: View, Content: View, Details: View>: View {
    var drawer: DrawerState
    var haptics: Bool
    /// Room for the home indicator under the content.
    var bottomInset: CGFloat
    /// The tallest the drawer may get: the screen less the status bar (and
    /// the keyboard, when it's up).
    var maxHeight: CGFloat
    var expands: Bool
    var onClose: (_ velocity: CGFloat) -> Void
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content
    @ViewBuilder var details: Details

    /// Grabber plus header: always a drag handle, pinned above the scroll.
    @State private var handleHeight: CGFloat = 0
    /// Where the handle is on screen, to tell where a drag started. Kept in
    /// a reference rather than state: it changes on every frame the drawer
    /// moves, and nothing drawn depends on it.
    @State private var handle = HandleFrame()
    @State private var compactBodyHeight: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var dragState = DrawerDrag()
    @State private var dragStartsInHandle = false
    @State private var suppressTaps = false
    @State private var scroller = DrawerScroller()
    /// A finger is on the drawer, as far as catching it goes. Resets on
    /// lift and on cancel alike, so a held drawer is never left hanging.
    @GestureState private var touching = false
    @Environment(\.displayScale) private var displayScale

    private var compactHeight: CGFloat { handleHeight + compactBodyHeight }
    private var fullHeight: CGFloat { handleHeight + scrollContentHeight }
    private var expandedHeight: CGFloat { min(fullHeight, maxHeight) }
    /// Taller than the screen allows: the content scrolls.
    private var overflows: Bool { fullHeight > maxHeight + 0.5 }
    /// Even compact won't fit, at the largest text sizes: the drawer opens
    /// as tall as it can, Details shown, and everything scrolls.
    private var compactOverflows: Bool { expands && compactHeight + bottomInset > maxHeight + 0.5 }
    private var canScroll: Bool { overflows && (!expands || drawer.snap == .expanded || compactOverflows) }

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
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { handleHeight = $0 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { handle.frame = $0 }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { compactBodyHeight = $0 }
                    if expands {
                        details
                            .modifier(DrawerExpansionFade(drawer: drawer, shown: compactOverflows))
                            .accessibilityHidden(drawer.snap != .expanded && !compactOverflows)
                    }
                }
                // One height only: room under the content for the home
                // indicator, inside the scroll so the last row can clear it.
                .padding(.bottom, expands ? 0 : bottomInset)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scrollContentHeight = $0 }
            }
            .allowsHitTesting(!suppressTaps)
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                scrollOffset = offset
            }
            // Never while the drawer itself has the finger.
            .scrollDisabled(!canScroll || dragState.owner == .drawer)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .frame(height: maxHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Runs on below the screen, so the rubber band never shows a gap.
            let shape = UnevenRoundedRectangle(topLeadingRadius: Metrics.drawerRadius, topTrailingRadius: Metrics.drawerRadius, style: .continuous)
            shape
                .fill(Palette.sheet)
                // A one-pixel line where a white drawer meets the camera; none on dark.
                .overlay(shape.strokeBorder(Palette.drawerEdge, lineWidth: 1 / displayScale))
                .padding(.bottom, -400)
        }
        // Alongside the scroll view and the buttons, not instead of them:
        // DrawerLogic.track decides, per drag, which one the finger means.
        .simultaneousGesture(drag)
        // While a spring is moving it, a touch anywhere stops the drawer
        // under the finger, before it has moved far enough to be a drag.
        .simultaneousGesture(catchGesture, including: drawer.isCatchable ? .all : .subviews)
        .onChange(of: touching) {
            if touching {
                drawer.hold()
            } else if let snap = drawer.releaseHold(expands: expands) {
                finish(snap, velocity: 0, fromDrag: false)
            }
        }
        .environment(\.drawerSuppressesTaps, suppressTaps)
        .environment(\.drawerScroller, scroller)
        .onAppear {
            // Content that fits has nowhere to scroll to, so this is a no-op there.
            scroller.scroll = { id in
                withAnimation(.easeOut(duration: 0.25)) { scrollPosition.scrollTo(id: id, anchor: .center) }
            }
        }
        .onChange(of: compactHeight) { report() }
        .onChange(of: fullHeight) { report() }
        .onChange(of: maxHeight) { report() }
        .onChange(of: drawer.snap) {
            // Back to the top of Details whenever it's no longer expanded.
            if expands, drawer.snap != .expanded { scrollPosition.scrollTo(edge: .top) }
        }
        .accessibilityElement(children: .contain)
        // VoiceOver stays in the drawer while it's open.
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose(0) }
        .accessibilityAction(named: "Close") { onClose(0) }
        .sensoryFeedback(trigger: drawer.lastSettle) { _, settle in
            settle.flatMap { HapticLogic.feedback(for: .drawerSettled(from: $0.from, to: $0.to), hapticsOn: haptics) }
        }
    }

    private func report() {
        if compactOverflows {
            drawer.measured(compact: maxHeight, expanded: maxHeight)
        } else if expands {
            drawer.measured(compact: compactHeight + bottomInset, expanded: expandedHeight)
        } else {
            drawer.measured(compact: expandedHeight, expanded: expandedHeight)
        }
    }

    // MARK: - Grabber and dragging

    static var grabberHeight: CGFloat { 24 }

    /// 36 × 5 to look at, 160 × 44 to hit. Tapping it moves between the
    /// two heights; a drawer with one height just shows it.
    @ViewBuilder private var grabber: some View {
        let capsule = Capsule()
            .fill(Palette.grabber)
            .frame(width: 36, height: 5)
            .frame(width: 160, height: Self.grabberHeight)
        if expands {
            capsule
                .contentShape(Rectangle().inset(by: -10))
                .onTapGesture { drawer.toggle() }
                .accessibilityElement()
                .accessibilityIdentifier("drawer-grabber")
                .accessibilityLabel(drawer.snap == .expanded ? "Collapse details" : "Expand details")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { drawer.toggle() }
        } else {
            capsule.accessibilityHidden(true)
        }
    }

    /// One gesture over the whole drawer. Under 8 pt it's nothing, so taps
    /// on buttons still land; past that, DrawerLogic.track says whether
    /// the finger is moving the drawer, scrolling the content, or going sideways.
    private var drag: some Gesture {
        DragGesture(minimumDistance: DrawerLogic.dragThreshold, coordinateSpace: .global)
            .onChanged { value in
                if dragState.owner == nil {
                    dragStartsInHandle = handle.frame.contains(value.startLocation)
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
                finish(drawer.dragEnded(velocity: velocity, expands: expands), velocity: -velocity, fromDrag: true)
            }
    }

    private var catchGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($touching) { _, touching, _ in touching = true }
    }

    /// Let go: close, or spring to `snap` at the finger's speed (positive upward).
    private func finish(_ snap: DrawerSnap, velocity: CGFloat, fromDrag: Bool) {
        if snap == .dismissed {
            onClose(velocity)
        } else {
            drawer.settle(to: snap, velocity: velocity, fromDrag: fromDrag)
        }
    }
}

/// A button in a drawer that ignores the release of a drag: the drawer
/// carries the button along under the finger, so a drag that starts on it
/// also ends on it.
struct DrawerButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: Label
    @Environment(\.drawerSuppressesTaps) private var suppressTaps

    var body: some View {
        Button {
            if !suppressTaps { action() }
        } label: {
            label
        }
    }
}

/// Details fade in as the drawer expands. Read here rather than in the
/// drawer's body, so the frames of a drag redraw only this.
private struct DrawerExpansionFade: ViewModifier {
    var drawer: DrawerState
    /// The drawer has one height and scrolls: Details are simply there.
    var shown = false

    func body(content: Content) -> some View {
        content.opacity(shown ? 1 : drawer.expansion)
    }
}

/// Lifts a drawer laid out below the screen's edge by its height. The one
/// place a drawer's position is read, so each frame of a drag or a spring
/// moves it without redrawing what's in it or the screen behind.
struct DrawerRise: ViewModifier {
    var drawer: DrawerState

    func body(content: Content) -> some View {
        content.offset(y: -drawer.height)
    }
}

/// The page behind sinks back and rounds as the drawer expands.
struct DrawerSink: ViewModifier {
    var drawer: DrawerState
    var active: Bool

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: active ? drawer.backgroundRadius : 0, style: .continuous))
            .scaleEffect(active ? drawer.backgroundScale : 1)
    }
}

/// Reads the drawer for whatever it builds, so the drawer's frames redraw
/// only that and not the view it sits in.
struct DrawerReader<Content: View>: View {
    var drawer: DrawerState
    @ViewBuilder var content: (DrawerState) -> Content

    var body: some View { content(drawer) }
}

/// The drawer handle's frame on screen. A plain reference, so writing it as
/// the drawer moves doesn't redraw anything.
final class HandleFrame {
    var frame: CGRect = .zero
}
