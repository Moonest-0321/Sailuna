import SwiftUI
import SwiftData
import UniformTypeIdentifiers // 用於處理檔案類型

// MARK: - 作者設定頁 (V1.4)
// 這是一個彈出視窗 (Sheet) 或獨立視窗，用來管理全局作者帳號。
struct AuthorSettingsView: View {
    
    // 取得資料庫操作權限
    @Environment(\.modelContext) private var modelContext
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(StoryPlanningStore.self) private var planningStore
    // 查詢所有的 AuthorProfile (根據 PRD，我們只會有唯一一筆資料)
    @Query private var profiles: [AuthorProfile]
    // 用來關閉當前視窗
    @Environment(\.dismiss) private var dismiss
    
    // 狀態變數：用來暫存預覽的頭像圖片
    @State private var avatarImage: NSImage?
    @State private var dataOperationMessage: String?
    @State private var dataOperationFailed = false
    
    // 取得唯一的作者資料。如果資料庫裡還沒有，我們就建立一個。
    private var profile: AuthorProfile {
        if let existingProfile = profiles.first {
            return existingProfile
        } else {
            // 如果沒有，建立一個預設的並加入資料庫
            let newProfile = AuthorProfile(penName: "我的筆名")
            modelContext.insert(newProfile)
            return newProfile
        }
    }
    
    var body: some View {
        // 使用 @Bindable 讓 profile 的屬性可以直接綁定到 UI 元件上
        // 這樣使用者輸入文字時，SwiftData 會自動在背景儲存，無需手動按「儲存」
        @Bindable var bindableProfile = profile
        
        VStack(spacing: 24) {
            
            // 1. 頭像區域
            avatarSection
            
            // 2. 筆名輸入
            VStack(alignment: .leading, spacing: 8) {
                Text("筆名")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("請輸入您的筆名", text: $bindableProfile.penName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            }

            GroupBox("資料備份") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("備份包含全部六個資料庫與書籍封面。還原會先驗證檔案並排程於下次啟動執行。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("建立完整備份", systemImage: "externaldrive.badge.plus") { createBackup() }
                        Button("從備份還原", systemImage: "arrow.counterclockwise") { scheduleRestore() }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 3. 簡介輸入
            VStack(alignment: .leading, spacing: 8) {
                Text("個人簡介")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: Binding(
                    get: { bindableProfile.bio ?? "" },
                    set: { bindableProfile.bio = $0 }
                ))
                    .font(.body)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                // 找到這段程式碼：
                .overlay(alignment: .topLeading) {
                    if bindableProfile.bio?.isEmpty != false {
                        Text("一句話介紹自己... (選填)")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
            }
            
            Spacer()
            
            // 4. 底部按鈕
            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction) // 支援按 Enter 鍵關閉
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 460, height: 640)
        .onAppear {
            // 畫面出現時，如果已有頭像資料，載入顯示
            loadAvatarImage()
        }
        .alert(dataOperationFailed ? "資料作業失敗" : "資料作業完成", isPresented: Binding(
            get: { dataOperationMessage != nil },
            set: { if !$0 { dataOperationMessage = nil } }
        )) {
            Button("好") { dataOperationMessage = nil }
        } message: {
            Text(dataOperationMessage ?? "")
        }
    }
    
    // MARK: - 子視圖：頭像區域
    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // 如果有頭像顯示頭像，沒有則顯示筆名首字
                if let image = avatarImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Text(String(profile.penName.prefix(1)).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.accentColor.gradient) // 使用系統強調色
                }
                
                // 點擊更換的提示遮罩
                Color.black.opacity(0.01) // 讓整個區域可點擊
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
            .shadow(radius: 5)
            .onTapGesture {
                selectAvatar()
            }
            
            Text("點擊頭像更換圖片")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 功能方法
    
    // 從 Data 載入圖片到 NSImage
    private func loadAvatarImage() {
        if let data = profile.avatarData, let image = NSImage(data: data) {
            avatarImage = image
        } else {
            avatarImage = nil
        }
    }
    
    // 打開 macOS 檔案選擇器
    private func selectAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image] // 只允許圖片
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "選擇您的頭像"
        
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                // 將圖片轉換為 Data 存入 SwiftData
                // 這裡使用 PNG 格式以支援透明背景
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    
                    profile.avatarData = pngData // 存入資料庫
                    avatarImage = image          // 更新 UI 預覽
                }
            }
        }
    }

    @MainActor
    private func createBackup() {
        guard let destination = SailuneBackupService.chooseBackupDestination() else { return }
        do {
            try commitAllStores()
            try SailuneBackupService.createBackup(at: destination)
            dataOperationFailed = false
            dataOperationMessage = "已建立備份：\(destination.lastPathComponent)"
            NSWorkspace.shared.selectFile(destination.path, inFileViewerRootedAtPath: destination.deletingLastPathComponent().path)
        } catch {
            dataOperationFailed = true
            dataOperationMessage = error.localizedDescription
        }
    }

    @MainActor
    private func scheduleRestore() {
        guard let source = SailuneBackupService.chooseRestoreSource() else { return }
        do {
            try SailuneBackupService.scheduleRestore(from: source)
            dataOperationFailed = false
            dataOperationMessage = "備份已通過完整性與 schema 驗證。請完全退出並重新開啟 Sailune；下次啟動會先備份目前資料，再進行還原。"
        } catch {
            dataOperationFailed = true
            dataOperationMessage = error.localizedDescription
        }
    }

    @MainActor
    private func commitAllStores() throws {
        if modelContext.hasChanges { try modelContext.save() }
        guard settingsStore.saveAndReport() else {
            throw NSError(domain: "SailuneBackup", code: 1, userInfo: [NSLocalizedDescriptionKey: settingsStore.persistenceErrorMessage ?? "設定集無法儲存。"])
        }
        copyStore.save()
        if let message = copyStore.persistenceErrorMessage {
            throw NSError(domain: "SailuneBackup", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        abilityStore.save()
        if let message = abilityStore.persistenceErrorMessage {
            throw NSError(domain: "SailuneBackup", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }
        try planningStore.saveChanges()
    }
}
