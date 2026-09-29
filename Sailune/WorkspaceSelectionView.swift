import SwiftUI

/// 帳號資料管理只呈現 Coordinator 的值與意圖；不直接操作檔案。
struct WorkspaceSelectionView: View {
    @Bindable var coordinator: WorkspaceCoordinator
    let auth: SailuneAccountAuthService
    let onAddAccount: () -> Void
    let onDismiss: () -> Void
    @State private var choosingTransferDestination = false
    @State private var transferAccount: WorkspaceAccount?
    @State private var deletingAccount: WorkspaceAccount?

    var body: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea().contentShape(Rectangle())
                .onTapGesture { if !coordinator.isWorking { onDismiss() } }
            VStack(alignment: .leading, spacing: SailuneLayout.spacingL) {
                HStack {
                    Text(panelTitle).font(.headline)
                    Spacer()
                    Button { onDismiss() } label: { Image(systemName: SailuneSymbol.close.systemName) }
                        .buttonStyle(.plain).accessibilityLabel("關閉資料空間")
                }
                if let account = transferAccount {
                    Text("目的帳號：\(account.penName.isEmpty ? account.email : account.penName + "／" + account.email)")
                    Text("將移入全部作品與相關本機資料。完成後切換至此帳號，未登入空間會清空。網站登入身分不變；不會發布至網站。移入前會自動建立安全備份。")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Button(SailuneActionCopy.cancel) { transferAccount = nil }
                        Button("確認移入") {
                            Task { await coordinator.transferGuest(to: account.id) }
                        }
                    }
                } else if choosingTransferDestination {
                    ForEach(coordinator.accounts) { account in
                        let eligibility = coordinator.transferDestinations.first { $0.id == account.id }
                        VStack(alignment: .leading, spacing: SailuneLayout.spacingXS) {
                            Button(account.penName.isEmpty ? account.email : account.penName + "／" + account.email) { transferAccount = account }
                                .disabled(eligibility?.canTransfer != true)
                            if let reason = eligibility?.reason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if coordinator.accounts.isEmpty { Text("請先新增帳號。") }
                    Button(SailuneActionCopy.cancel) { choosingTransferDestination = false }
                } else if let account = deletingAccount {
                    Text(account.email).textSelection(.enabled)
                    Text("將刪除這個帳號在此裝置的全部作品、作者資料、設定、資產、對話及 App 管理的備份。此操作無法復原。網站會員、已發布作品及自行匯出的備份保留。")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: SailuneLayout.spacingM) {
                        Button("先備份") {
                            do { try coordinator.backupAccount(account.id) }
                            catch { coordinator.errorMessage = error.localizedDescription }
                        }
                        .disabled(account.isDeleting)
                        Spacer()
                        Button(SailuneActionCopy.cancel) { deletingAccount = nil }
                        Button("刪除此裝置資料", role: .destructive) {
                            Task {
                                await coordinator.deleteAccount(account.id, auth: auth)
                                if !coordinator.accounts.contains(where: { $0.id == account.id }) { deletingAccount = nil }
                            }
                        }
                    }
                } else {
                    row(title: "未登入", detail: "本機資料", id: "guest", account: nil)
                    Button("移入帳號") { choosingTransferDestination = true; coordinator.refreshTransferEligibility() }
                        .disabled(coordinator.accounts.isEmpty || coordinator.transferSourceReason != nil)
                    if coordinator.accounts.isEmpty || coordinator.transferSourceReason != nil {
                        Text(coordinator.accounts.isEmpty ? "請先新增帳號。" : coordinator.transferSourceReason ?? "未登入空間沒有可移入的資料。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(coordinator.accounts) { account in
                        row(title: account.penName.isEmpty ? account.email : account.penName,
                            detail: account.isDeleting ? "清理未完成" : account.email, id: account.id, account: account)
                    }
                    ForEach(coordinator.accounts.count..<2, id: \.self) { _ in
                        Button("新增帳號", systemImage: SailuneSymbol.add.systemName, action: onAddAccount)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if coordinator.accounts.count == 2 {
                        Text("最多保留兩個帳號；新增前請先移除一個。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if coordinator.hasPendingTransfer {
                    Button("重試") { coordinator.retryPendingTransfer() }
                }
                if let error = coordinator.errorMessage {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                if coordinator.isWorking { ProgressView("處理中…") }
            }
            .padding(SailuneLayout.spacingXL)
            .frame(maxWidth: 540)
            .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12))
            .padding(SailuneLayout.spacingXL)
            .disabled(coordinator.isWorking)
        }
        .task { coordinator.refreshTransferEligibility() }
    }

    private var panelTitle: String {
        if transferAccount != nil { return "將未登入資料移入帳號" }
        if choosingTransferDestination { return "選擇目的帳號" }
        return deletingAccount == nil ? "資料空間" : "刪除此裝置上的帳號與資料"
    }

    private func row(title: String, detail: String, id: String, account: WorkspaceAccount?) -> some View {
        HStack(spacing: SailuneLayout.spacingM) {
            VStack(alignment: .leading, spacing: SailuneLayout.spacingXS) {
                Text(title).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if coordinator.selectedID == id { Text("使用中").foregroundStyle(.secondary) }
            else {
                Button("切換") {
                    coordinator.switchTo(id)
                    if coordinator.selectedID == id { onDismiss() }
                }.disabled(account?.isDeleting == true)
            }
            if let account {
                Button(account.isDeleting ? "重試刪除" : "刪除此裝置資料", role: .destructive) {
                    deletingAccount = account
                }
            }
        }
    }
}
