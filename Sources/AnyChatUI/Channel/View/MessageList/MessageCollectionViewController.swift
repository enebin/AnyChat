import SwiftUI
import UIKit

final class MessageCollectionViewController: UICollectionViewController {
    private static let preloadScreens: CGFloat = 2

    private let presentation = MessageListCellPresentation()
    private var messageDataSource: MessageListDataSource?
    private var scrollController: MessageListScrollController?
    private var swipeController: MessageSwipeController?
    /// Attached only while the host declares the long-press overlay.
    private var longPressController: MessageLongPressController?
    private var liftedMessageID: String?
    /// `.none` until the first report for the lifted message, so a first `nil` is reported too.
    private var reportedLiftedFrame: CGRect??
    private var liftedFrameReport: Task<Void, Never>?
    private var onLiftedFrameChange: (CGRect?) -> Void = { _ in }
    private var content = MessageListContent()
    private var onReachTop: () -> Void = {}
    private var requestedFirstRowID: String?
    private var pageRequest: Task<Void, Never>?
    var onAwayFromBottomChange: (Bool) -> Void = { _ in }

    init() {
        super.init(collectionViewLayout: Self.makeLayout())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    // Explicitly nonisolated: the implied main-actor deinit crashes on iOS 18 (ARCHITECTURE.md section 3).
    nonisolated deinit {}

    override func loadView() {
        let collectionView = MessageCollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        self.collectionView = collectionView
        view = collectionView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .interactive
        let dataSource = MessageListDataSource(collectionView: collectionView, presentation: presentation)
        messageDataSource = dataSource
        let scrollController = MessageListScrollController(collectionView: collectionView, dataSource: dataSource)
        scrollController.onAwayFromBottomChange = { [weak self] in self?.onAwayFromBottomChange($0) }
        self.scrollController = scrollController
        swipeController = MessageSwipeController(collectionView: collectionView, dataSource: dataSource)
        (collectionView as? MessageCollectionView)?.onLayout = { [weak self] in
            self?.didLayoutCollectionView()
        }
        presentation.onBubbleFrameChange = { [weak self] id, frame in
            guard let self else { return }
            longPressController?.setBubbleFrame(frame, for: id)
            if id == liftedMessageID {
                scheduleLiftedFrameReport()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        swipeController?.yield(to: navigationController?.interactivePopGestureRecognizer)
        scrollController?.didLayout()
        requestPreviousPageIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pageRequest?.cancel()
        pageRequest = nil
    }

    func update(
        content: MessageListContent,
        slots: ChannelSlots,
        signals: MessageSignals,
        environment: EnvironmentValues,
        onReachTop: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onFailedMessageSelected: @escaping (ChatMessage) -> Void,
        liftedMessageID: String?,
        onLiftedFrameChange: @escaping (CGRect?) -> Void
    ) {
        loadViewIfNeeded()
        self.content = content
        self.onReachTop = onReachTop
        self.onLiftedFrameChange = onLiftedFrameChange
        updateLongPress(signals: signals)
        presentation.slots = slots
        presentation.signals = signals
        presentation.environment = environment
        presentation.onRetry = onRetry
        presentation.onFailedMessageSelected = onFailedMessageSelected
        swipeController?.canReply = signals.canReply
        swipeController?.onReply = signals.reply
        swipeController?.setColors(
            icon: UIColor(environment.channelTheme.senderNameText),
            background: UIColor(environment.channelTheme.replyBarCloseBackground)
        )

        guard let messageDataSource, let scrollController else { return }
        scrollController.scrollBehavior = slots.scrollBehavior
        let repliesChanged = messageDataSource.content.repliesEnabled != content.repliesEnabled
        if repliesChanged || messageDataSource.content.rows != content.rows || messageDataSource.content.topStatus != content.topStatus {
            // A row's Reply action depends on whether replying is possible, not only on its message.
            let changedRowIDs = repliesChanged ? Set(content.rows.map(\.id)) : messageDataSource.changedRowIDs(in: content)
            let sentRowID = scrollController.awaitsSentRow ? content.sentRowID(after: messageDataSource.content) : nil
            swipeController?.cancel()
            scrollController.beginUpdate(changedRowIDs: changedRowIDs)
            messageDataSource.apply(content, changedRowIDs: changedRowIDs)
            scrollController.endUpdate(sentRowID: sentRowID)
        }
        requestPreviousPageIfNeeded()
        setLiftedMessageID(liftedMessageID)
    }

    /// Shows `controller`'s view behind the rows as this controller's child. The child must belong to
    /// the controller whose view holds its view; a hosting view checks this as it enters a window.
    func setBackground(_ controller: UIViewController) {
        loadViewIfNeeded()
        addChild(controller)
        let background = UIView()
        background.addSubview(controller.view)
        collectionView.backgroundView = background
        controller.didMove(toParent: self)
    }

    func didSend() {
        scrollController?.didSend()
    }

    func scrollToLatest() {
        scrollController?.scrollToBottomAnimated()
    }

    func stop() {
        pageRequest?.cancel()
        pageRequest = nil
        onReachTop = {}
        onAwayFromBottomChange = { _ in }
        presentation.onRetry = {}
        presentation.onFailedMessageSelected = { _ in }
        presentation.signals = MessageSignals()
        swipeController?.canReply = { _ in false }
        swipeController?.onReply = { _ in }
        longPressController?.detach()
        longPressController = nil
        liftedFrameReport?.cancel()
        liftedFrameReport = nil
        onLiftedFrameChange = { _ in }
        presentation.onBubbleFrameChange = { _, _ in }
        (collectionView as? MessageCollectionView)?.onLayout = nil
        collectionView.delegate = nil
    }

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollController?.willBeginDragging()
    }

    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scrollController?.didEndDragging(willDecelerate: decelerate)
        requestPreviousPageIfNeeded()
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollController?.didEndDecelerating()
        requestPreviousPageIfNeeded()
    }

    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollController?.didEndScrollingAnimation()
        requestPreviousPageIfNeeded()
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollController?.didScroll()
        requestPreviousPageIfNeeded()
        scheduleLiftedFrameReport()
    }

    private func didLayoutCollectionView() {
        scrollController?.didLayout()
        requestPreviousPageIfNeeded()
        scheduleLiftedFrameReport()
    }

    // MARK: - Long-press overlay

    private func updateLongPress(signals: MessageSignals) {
        if signals.overlay == nil {
            longPressController?.detach()
            longPressController = nil
        } else if longPressController == nil, let messageDataSource {
            longPressController = MessageLongPressController(
                collectionView: collectionView,
                dataSource: messageDataSource,
                swipeController: swipeController
            )
        }
        longPressController?.onOpen = signals.openOverlay
    }

    private func setLiftedMessageID(_ id: String?) {
        guard id != liftedMessageID else {
            scheduleLiftedFrameReport()
            return
        }
        liftedMessageID = id
        reportedLiftedFrame = nil
        if id == nil {
            presentation.liftedMessageID = nil
        }
        scheduleLiftedFrameReport()
    }

    /// Reports the lifted bubble's frame in the container's space, which is the overlay's, only
    /// when it changed, and `nil` once its cell leaves the screen. Layout runs inside
    /// `updateUIViewController` too, where changing SwiftUI state is not allowed, so it waits for
    /// the next main-actor turn like the page request.
    private func scheduleLiftedFrameReport() {
        guard liftedMessageID != nil, liftedFrameReport == nil else { return }
        liftedFrameReport = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            liftedFrameReport = nil
            guard let id = liftedMessageID, let container = collectionView.superview else { return }
            let frame = longPressController?.bubbleFrame(for: id, in: container)
            guard reportedLiftedFrame != .some(frame) else { return }
            reportedLiftedFrame = frame
            onLiftedFrameChange(frame)
            if frame != nil {
                presentation.liftedMessageID = id
            }
        }
    }

    private func requestPreviousPageIfNeeded() {
        guard let scrollController, !scrollController.isAdjusting,
              collectionView.window != nil, content.canLoadPreviousPage,
              scrollController.viewportHeight > 0,
              scrollController.distanceToTop < scrollController.viewportHeight * Self.preloadScreens,
              let firstRowID = messageDataSource?.firstRowID,
              firstRowID != requestedFirstRowID, pageRequest == nil else { return }

        // Sending a Store input inside updateUIViewController would mutate SwiftUI mid-update.
        pageRequest = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            pageRequest = nil
            guard !scrollController.isAdjusting,
                  collectionView.window != nil, content.canLoadPreviousPage,
                  scrollController.distanceToTop < scrollController.viewportHeight * Self.preloadScreens,
                  messageDataSource?.firstRowID == firstRowID else { return }
            requestedFirstRowID = firstRowID
            onReachTop()
        }
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        return UICollectionViewCompositionalLayout(section: section)
    }
}
