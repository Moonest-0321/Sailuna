import AppKit
import SwiftUI

struct PublicationPreviewView: View {
    let coordinator: PublicationCoordinator
    let isSignedIn: Bool
    let onLogin: () -> Void
    let onSend: () -> Void

    var body: some View {
        if let package = coordinator.package {
            ZStack {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { coordinator.dismiss() }
                VStack(alignment: .leading, spacing: SailuneLayout.spacingL) {
                    Text(title).font(.headline)
                    HStack(alignment: .top, spacing: SailuneLayout.spacingL) {
                        if let bytes = coordinator.coverPreviewData, let image = NSImage(data: bytes) {
                            Image(nsImage: image).resizable().scaledToFit().frame(width: 72, height: 108)
                                .accessibilityLabel("作品封面")
                        }
                        VStack(alignment: .leading, spacing: SailuneLayout.spacingS) {
                            Text(package.manifest.book.title).font(.title3)
                            Text(package.manifest.book.author).foregroundStyle(.secondary)
                            Text(package.manifest.book.tags.joined(separator: "、")).foregroundStyle(.secondary)
                            Text("\(package.manifest.volumes.count) 卷・\(package.manifest.volumes.flatMap(\.sections).count) 節・共 \(package.manifest.book.wordCount) 字")
                                .font(.callout)
                        }
                    }
                    if coordinator.phase == .preview {
                        Text("這次會更新整本作品；封包中缺少的既有節會在拾頁下架。")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if !isSignedIn { Text("請先登入，再確認傳送。登入後會返回這份預覽。") .font(.callout) }
                    }
                    if coordinator.phase == .uploading {
                        ProgressView(value: coordinator.progress).accessibilityLabel("作品傳送進度")
                        Text("正在傳送：\(Int(coordinator.progress * 100))%") .font(.callout)
                    }
                    if coordinator.phase == .committing {
                        HStack { ProgressView().controlSize(.small); Text("正在確認拾頁發布結果，請稍候。") }
                    }
                    if let message = coordinator.message {
                        Text(message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if coordinator.phase == .success, let result = coordinator.result {
                        Text("新增 \(result.createdChapters) 節・更新 \(result.updatedChapters) 節・未變更 \(result.unchangedChapters) 節・下架 \(result.hiddenChapters) 節")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: SailuneLayout.spacingS) {
                        Spacer()
                        if coordinator.phase == .success {
                            Button("完成") { coordinator.dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.cancelAction)
                        } else {
                            Button(coordinator.isWorking ? "取消" : "關閉") { coordinator.dismiss() }
                                .buttonStyle(.bordered).keyboardShortcut(.cancelAction).disabled(!coordinator.canCancel)
                            if !coordinator.isWorking {
                                if !isSignedIn {
                                    Button("登入", action: onLogin).buttonStyle(.borderedProminent)
                                } else {
                                    Button(coordinator.phase == .failure ? "重試" : "傳送", action: onSend).buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }
                }
                .padding(SailuneLayout.spacingXL)
                .frame(width: 460)
                .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8)
            }
            .onExitCommand { coordinator.dismiss() }
        }
    }
    private var title: String {
        switch coordinator.phase {
        case .preview: "傳送至拾頁"
        case .uploading, .committing: "傳送中"
        case .success: "傳送完成"
        case .failure: "傳送結果"
        }
    }
}
