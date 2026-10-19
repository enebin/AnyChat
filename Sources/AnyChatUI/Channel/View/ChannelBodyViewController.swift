import AnyChatCore
import SwiftUI
import UIKit

/// Holds the message list and the composer.
///
/// The composer is pinned to `keyboardLayoutGuide`, which follows the keyboard while the user
/// drags the list to dismiss it; SwiftUI's keyboard safe area is not updated during that drag.
final class ChannelBodyViewController: UIViewController {
    let messages = MessageCollectionViewController()

    private static let keyboardTransitionDistance: CGFloat = 60
    private static let jumpToLatestSpacing: CGFloat = 8

    private let composerPresentation = ComposerPresentation()
    private lazy var composer = UIHostingController(rootView: ComposerRoot(
        presentation: composerPresentation,
        onHeightChange: { [weak self] height in self?.updateComposerHeight(height) }
    ))
    private var composerHeightConstraint: NSLayoutConstraint?
    private let emptyStatePresentation = EmptyStatePresentation()
    /// Shown below the list's top inset while the channel has no messages. It lives in the list's
    /// background view: a view inside the list still takes its own taps, while a drag anywhere on
    /// it reaches the list's pan, which dismisses the keyboard interactively.
    private lazy var emptyState = UIHostingController(rootView: ChannelEmptyState(
        presentation: emptyStatePresentation,
        composer: composerPresentation
    ))
    /// Paints the composer's background from its top down to the screen edge, behind the home
    /// indicator. The composer paints none itself: a translucent color drawn by both would be
    /// darker over the composer and show a seam at its bottom edge.
    private let composerBackdrop = UIView()
    private lazy var composerBackground = UIHostingController(rootView: ComposerBackground(presentation: composerPresentation))
    private let jumpToLatestPresentation = JumpToLatestPresentation()
    private lazy var jumpToLatest = UIHostingController(rootView: JumpToLatestButton(presentation: jumpToLatestPresentation))
    private var onSend: (String) -> Void = { _ in }
    private var onAttach: ([AttachmentSource]) -> Void = { _ in }
    private var onAttachFailure: () -> Void = {}

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(messages)
        messages.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messages.view)
        messages.didMove(toParent: self)

        // Its content already stops at the composer; the keyboard must not shrink it again.
        emptyState.safeAreaRegions = []
        emptyState.view.backgroundColor = .clear
        emptyState.view.isHidden = true
        messages.setBackground(emptyState)

        composerBackdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composerBackdrop)

        // The host view must fill the backdrop under the home indicator and not shrink for the keyboard.
        composerBackground.safeAreaRegions = []
        composerBackground.view.backgroundColor = .clear
        composerBackground.view.isHidden = true
        composerBackground.view.isUserInteractionEnabled = false
        addChild(composerBackground)
        composerBackground.view.translatesAutoresizingMaskIntoConstraints = false
        composerBackdrop.addSubview(composerBackground.view)
        composerBackground.didMove(toParent: self)

        addChild(composer)
        composer.sizingOptions = .intrinsicContentSize
        composer.view.backgroundColor = .clear
        composer.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composer.view)
        composer.didMove(toParent: self)
        composerHeightConstraint = composer.view.heightAnchor.constraint(equalToConstant: 0)

        addChild(jumpToLatest)
        jumpToLatest.sizingOptions = .intrinsicContentSize
        jumpToLatest.safeAreaRegions = []
        jumpToLatest.view.backgroundColor = .clear
        jumpToLatest.view.isUserInteractionEnabled = false
        jumpToLatest.view.accessibilityElementsHidden = true
        jumpToLatest.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(jumpToLatest.view)
        jumpToLatest.didMove(toParent: self)

        NSLayoutConstraint.activate([
            messages.view.topAnchor.constraint(equalTo: view.topAnchor),
            messages.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messages.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messages.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            composer.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            composerBackdrop.topAnchor.constraint(equalTo: composer.view.topAnchor),
            composerBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            composerBackground.view.topAnchor.constraint(equalTo: composerBackdrop.topAnchor),
            composerBackground.view.leadingAnchor.constraint(equalTo: composerBackdrop.leadingAnchor),
            composerBackground.view.trailingAnchor.constraint(equalTo: composerBackdrop.trailingAnchor),
            composerBackground.view.bottomAnchor.constraint(equalTo: composerBackdrop.bottomAnchor),

            jumpToLatest.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            jumpToLatest.view.bottomAnchor.constraint(equalTo: composer.view.topAnchor, constant: -Self.jumpToLatestSpacing)
        ])

        composerPresentation.onSend = { [weak self] text in
            self?.messages.didSend()
            self?.onSend(text)
        }
        composerPresentation.onAttach = { [weak self] sources in
            self?.messages.didSend()
            self?.onAttach(sources)
        }
        composerPresentation.onAttachFailure = { [weak self] in
            self?.onAttachFailure()
        }
        jumpToLatestPresentation.onJump = { [weak self] in
            self?.messages.scrollToLatest()
        }
        messages.onAwayFromBottomChange = { [weak self] isAway in
            guard let self else { return }
            jumpToLatestPresentation.isVisible = isAway
            jumpToLatest.view.isUserInteractionEnabled = isAway
            // The hosted view's own `accessibilityHidden` still left it in the accessibility tree.
            jumpToLatest.view.accessibilityElementsHidden = !isAway
        }
    }

    /// The navigation bar cannot find a list hosted in a representable, so on iOS 26 it drew no
    /// edge blur under itself. Before iOS 26 the bar is left alone: once it finds a scrolled list
    /// it turns opaque and hides the header avatar that reaches up into it.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard #available(iOS 26, *) else { return }
        var screen: UIViewController = self
        while let parent = screen.parent, !(parent is UINavigationController) {
            screen = parent
        }
        screen.setContentScrollView(messages.collectionView, for: .top)
    }

    private func updateComposerHeight(_ height: CGFloat) {
        guard let constraint = composerHeightConstraint, constraint.constant != height else { return }
        constraint.constant = height
        constraint.isActive = true
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The list keeps its automatic inset adjustment, which already adds the device's bottom
        // safe area; only the part of the composer above that edge is added here.
        let safeBottom = view.bounds.height - view.safeAreaInsets.bottom
        // Graded rather than on or off, so the composer's padding follows an interactive dismissal
        // instead of jumping when the keyboard reaches the bottom.
        let keyboardRise = safeBottom - view.keyboardLayoutGuide.layoutFrame.minY
        let keyboardProgress = min(1, max(0, keyboardRise / Self.keyboardTransitionDistance))
        if composerPresentation.keyboardProgress != keyboardProgress {
            composerPresentation.keyboardProgress = keyboardProgress
        }
        let inset = max(0, safeBottom - composer.view.frame.minY)
        if messages.additionalSafeAreaInsets.bottom != inset {
            messages.additionalSafeAreaInsets.bottom = inset
        }
        if !emptyState.view.isHidden {
            layOutEmptyState(animated: true)
        }
    }

    /// A frame rather than constraints: constraints between this view and the composer kept the
    /// composer from rising with the keyboard. The list's background view fills the list, which
    /// fills this view, so both share one coordinate space.
    private func layOutEmptyState(animated: Bool) {
        let listTop = messages.view.safeAreaInsets.top
        let frame = CGRect(x: 0, y: listTop, width: view.bounds.width, height: max(0, view.bounds.height - listTop))
        if emptyState.view.frame != frame {
            emptyState.view.frame = frame
        }
        let inset = max(0, view.bounds.height - composer.view.frame.minY)
        if emptyStatePresentation.bottomInset != inset {
            emptyStatePresentation.animatesInset = animated
            emptyStatePresentation.bottomInset = inset
        }
    }

    func update(
        content: MessageListContent,
        slots: ChannelSlots,
        signals: MessageSignals,
        environment: EnvironmentValues,
        isEmpty: Bool,
        canSend: Bool,
        isUnavailable: Bool,
        replyingTo: ChatMessage?,
        replyBarText: ReplyBarText?,
        topInset: CGFloat,
        onReachTop: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onFailedMessageSelected: @escaping (ChatMessage) -> Void,
        onSend: @escaping (String) -> Void,
        onAttach: @escaping ([AttachmentSource]) -> Void,
        onAttachFailure: @escaping () -> Void,
        onCancelReply: @escaping () -> Void,
        liftedMessageID: String?,
        onLiftedFrameChange: @escaping (CGRect?) -> Void
    ) {
        loadViewIfNeeded()
        messages.update(
            content: content,
            slots: slots,
            signals: signals,
            environment: environment,
            onReachTop: onReachTop,
            onRetry: onRetry,
            onFailedMessageSelected: onFailedMessageSelected,
            liftedMessageID: liftedMessageID,
            onLiftedFrameChange: onLiftedFrameChange
        )
        if isEmpty {
            emptyStatePresentation.slot = slots.emptyState
            emptyStatePresentation.theme = environment.channelTheme
            emptyStatePresentation.environment = environment
            if emptyState.view.isHidden {
                layOutEmptyState(animated: false)
                emptyState.view.isHidden = false
            }
        } else {
            emptyState.view.isHidden = true
        }
        composerPresentation.theme = environment.channelTheme
        composerPresentation.isEnabled = canSend
        composerPresentation.isUnavailable = isUnavailable
        composerPresentation.replyingTo = replyingTo
        composerPresentation.replyBarText = replyBarText
        composerPresentation.replyBar = slots.composerReplyBar
        composerPresentation.onCancelReply = onCancelReply
        composerPresentation.placeholder = slots.composerPlaceholder
        composerPresentation.environment = environment
        composerPresentation.leadingItems = slots.composerLeadingItems
        composerPresentation.trailingItems = slots.composerTrailingItems
        composerPresentation.itemsInsideField = slots.composerItemsInsideField
        composerPresentation.sendButtonLabel = slots.composerSendButtonLabel
        composerPresentation.isResponding = slots.composerStopButton?.isResponding ?? false
        composerPresentation.onStop = slots.composerStopButton?.action ?? {}
        composerPresentation.composer = slots.composer
        composerPresentation.background = slots.composerBackground
        jumpToLatestPresentation.slot = slots.jumpToLatestButton
        jumpToLatestPresentation.theme = environment.channelTheme
        jumpToLatestPresentation.environment = environment
        if messages.additionalSafeAreaInsets.top != topInset {
            messages.additionalSafeAreaInsets.top = topInset
            view.setNeedsLayout()
        }
        composerBackground.view.isHidden = slots.composerBackground == nil
        composerBackdrop.backgroundColor = slots.composerBackground == nil
            ? UIColor(environment.channelTheme.composerBackground)
            : .clear
        self.onSend = onSend
        self.onAttach = onAttach
        self.onAttachFailure = onAttachFailure
    }

    func stop() {
        messages.stop()
        jumpToLatestPresentation.onJump = {}
        onSend = { _ in }
        onAttach = { _ in }
        onAttachFailure = {}
    }
}
