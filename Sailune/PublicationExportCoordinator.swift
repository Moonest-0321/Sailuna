import Foundation
import Observation

/// 協調遠端提交、本機 sidecar 與重試；遠端成功才更新本機發布狀態。
@MainActor @Observable
final class PublicationCoordinator {
    enum Phase { case preview, uploading, committing, success, failure }
    private(set) var coverPreviewData: Data?
    private(set) var package: BookJSONExporter.Package?
    private(set) var phase = Phase.preview
    private(set) var progress = 0.0
    private(set) var message: String?
    private(set) var result: PublicationResult?
    @ObservationIgnored private var attempt: PublicationAttempt?
    @ObservationIgnored private var task: Task<Void, Never>?

    var isPresented: Bool { package != nil }
    var isWorking: Bool { phase == .uploading || phase == .committing }
    var canCancel: Bool { phase != .committing }

    func prepare(book: Book, tags: [String], status: BookStatus, sectionUnit: BookTextSectionMarker) throws {
        guard !isWorking else { return }
        let package = try BookJSONExporter.makePackage(book: book, categories: tags,
            status: status == .draft ? .ongoing : status, sectionUnit: sectionUnit)
        self.package = package
        coverPreviewData = BookCoverStore.displayedCoverPNGData(for: book)
        attempt = PublicationAttempt(bookID: book.id, tags: package.manifest.book.tags, data: package.data)
        result = nil; message = nil; progress = 0; phase = .preview
    }
    func dismiss() {
        guard canCancel else { return }
        if isWorking { task?.cancel(); return }
        package = nil; coverPreviewData = nil; attempt = nil; task = nil; result = nil; message = nil
    }
    func waitForCompletion() async { await task?.value }

    func send(auth: SailuneAccountAuthService, store: BookPublicationStore, workspace: WorkspaceCoordinator) {
        guard !isWorking else { return }
        let account: WorkspaceAccount
        do { account = try workspace.requirePublicationAccount(auth: auth) }
        catch { phase = .failure; message = error.localizedDescription; return }
        send(store: store) { attempt, progress, commit in
            let credentials = try await auth.publicationCredentials(for: attempt.bookID, expectedUserID: account.userID)
            try Task.checkCancellation()
            do { return try await PublicationClient().publish(attempt, credentials: credentials, onProgress: progress, onCommit: commit) }
            catch PublicationFailure.login { auth.requirePublicationLogin(); throw PublicationFailure.login }
        }
    }
    func send(store: BookPublicationStore,
              operation: @escaping @MainActor (PublicationAttempt, @escaping @MainActor @Sendable (Double) -> Void, @escaping @MainActor () -> Void) async throws -> PublicationResult) {
        guard let attempt, !isWorking else { return }
        message = nil; phase = attempt.hasStartedCommit ? .committing : .uploading
        task = Task { [self] in
            do {
                if result == nil {
                    result = try await operation(attempt,
                        { [weak self] progress in
                            guard let self, self.attempt?.id == attempt.id, self.phase == .uploading else { return }
                            self.progress = progress
                        },
                        { [weak self] in self?.phase = .committing })
                }
                do { try store.publish(attempt.bookID, tags: attempt.tags) }
                catch { throw PublicationFailure.localSave }
                phase = .success
            } catch is CancellationError {
                phase = .failure; message = "已取消傳送，尚未提交作品；可重試。"
            } catch {
                phase = .failure
                if Task.isCancelled && !attempt.hasStartedCommit {
                    message = "已取消傳送，尚未提交作品；可重試。"
                } else {
                    message = (error as? WorkspaceError)?.errorDescription ?? (error as? PublicationFailure)?.errorDescription ?? (error is URLError ? "連線中斷，請使用相同傳送重試。" : "無法傳送作品，請重試。")
                }
            }
            task = nil
        }
    }
}
