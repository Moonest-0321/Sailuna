import SwiftUI

private enum MapNameOperation: Identifiable {
    case add
    case rename(UUID)
    var id: String {
        switch self { case .add: "add"; case .rename(let id): "rename-\(id)" }
    }
}

struct MapManagementView: View {
    let bookID: UUID
    var isReadOnly: Bool = false
    @Binding var selectedLevel: MapLevel
    @Binding var selectedMapID: UUID?
    let onSelectionChanged: () -> Void

    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var nameOperation: MapNameOperation?
    @State private var nameText = ""
    @State private var mapToDelete: BookMap?
    @State private var errorMessage: String?

    private var maps: [BookMap] { settingsStore.maps(for: bookID, level: selectedLevel) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("管理地圖").font(.headline)
            Picker("層級", selection: $selectedLevel) {
                ForEach(MapLevel.allCases) { level in Text(level.title).tag(level) }
            }
            .pickerStyle(.segmented)

            List(maps, selection: $selectedMapID) { map in
                HStack {
                    Text(map.name)
                    Spacer()
                    Button(SailuneActionCopy.rename) { nameText = map.name; nameOperation = .rename(map.id) }
                        .disabled(isReadOnly)
                    Button(SailuneActionCopy.delete, role: .destructive) { mapToDelete = map }
                        .disabled(isReadOnly)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedMapID = map.id }
                .tag(Optional(map.id))
            }
            .frame(minHeight: 220)

            HStack {
                Button { nameText = ""; nameOperation = .add } label: { Label("新增地圖", systemImage: SailuneSymbol.add.systemName) }
                    .disabled(isReadOnly)
                Spacer()
                Button(SailuneActionCopy.done) { onSelectionChanged(); dismiss() }
            }
        }
        .padding(20)
        .frame(width: 560, height: 370)
        .onChange(of: selectedLevel) { _, _ in selectedMapID = maps.first?.id }
        .alert(nameOperationTitle, isPresented: Binding(get: { nameOperation != nil }, set: { if !$0 { nameOperation = nil } })) {
            TextField("地圖名稱", text: $nameText)
            Button(SailuneActionCopy.cancel, role: .cancel) { nameOperation = nil }
            Button(SailuneActionCopy.save) { performNameOperation() }
        }
        .alert("刪除地圖？", isPresented: Binding(get: { mapToDelete != nil }, set: { if !$0 { mapToDelete = nil } })) {
            Button(SailuneActionCopy.cancel, role: .cancel) { mapToDelete = nil }
            Button(SailuneActionCopy.delete, role: .destructive) { deleteSelectedMap() }
        } message: {
            Text("會刪除此地圖的所有背景版本與標記位置，但不會刪除設定集中的地點。")
        }
        .sailuneErrorAlert("無法完成操作", errorMessage: $errorMessage, acknowledgeRole: .cancel)
    }

    private var nameOperationTitle: String {
        if case .rename = nameOperation { return "重新命名地圖" }
        return "新增地圖"
    }

    private func performNameOperation() {
        guard !isReadOnly else { return }
        do {
            switch nameOperation {
            case .add:
                let (map, _) = try settingsStore.createMap(bookID: bookID, level: selectedLevel, name: nameText)
                selectedMapID = map.id
            case .rename(let mapID):
                if let map = maps.first(where: { $0.id == mapID }) { try settingsStore.renameMap(map, to: nameText) }
            case nil: break
            }
            nameOperation = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteSelectedMap() {
        guard !isReadOnly, let mapToDelete else { return }
        let deletedMapID = mapToDelete.id
        do {
            try settingsStore.deleteMap(mapToDelete)
            if selectedMapID == deletedMapID { selectedMapID = maps.first?.id }
            self.mapToDelete = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

struct MapVersionManagementView: View {
    let map: BookMap
    var isReadOnly: Bool = false
    @Binding var selectedVersionID: UUID?
    let onSelectionChanged: () -> Void

    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var nameOperation: MapNameOperation?
    @State private var nameText = ""
    @State private var versionToDelete: BookMapVersion?
    @State private var errorMessage: String?

    private var versions: [BookMapVersion] { settingsStore.versions(for: map) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("管理「\(map.name)」版本").font(.headline)
            List(versions, selection: $selectedVersionID) { version in
                HStack {
                    Image(systemName: selectedVersionID == version.id ? "largecircle.fill.circle" : "circle")
                    Text(version.name)
                    Spacer()
                    Button(SailuneActionCopy.rename) { nameText = version.name; nameOperation = .rename(version.id) }
                        .disabled(isReadOnly)
                    Button(SailuneActionCopy.delete, role: .destructive) { versionToDelete = version }
                        .disabled(isReadOnly || versions.count <= 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedVersionID = version.id }
                .tag(Optional(version.id))
            }
            .frame(minHeight: 210)
            HStack {
                Button { nameText = ""; nameOperation = .add } label: { Label("新增版本", systemImage: SailuneSymbol.add.systemName) }
                    .disabled(isReadOnly)
                Spacer()
                Button(SailuneActionCopy.done) { onSelectionChanged(); dismiss() }
            }
        }
        .padding(20)
        .frame(width: 560, height: 330)
        .alert(nameOperationTitle, isPresented: Binding(get: { nameOperation != nil }, set: { if !$0 { nameOperation = nil } })) {
            TextField("版本名稱", text: $nameText)
            Button(SailuneActionCopy.cancel, role: .cancel) { nameOperation = nil }
            Button(SailuneActionCopy.save) { performNameOperation() }
        }
        .alert("刪除版本？", isPresented: Binding(get: { versionToDelete != nil }, set: { if !$0 { versionToDelete = nil } })) {
            Button(SailuneActionCopy.cancel, role: .cancel) { versionToDelete = nil }
            Button(SailuneActionCopy.delete, role: .destructive) { deleteSelectedVersion() }
        } message: { Text("只會刪除這個背景版本，不會刪除地點或標記位置。") }
        .sailuneErrorAlert("無法完成操作", errorMessage: $errorMessage, acknowledgeRole: .cancel)
    }

    private var nameOperationTitle: String {
        if case .rename = nameOperation { return "重新命名版本" }
        return "新增版本"
    }

    private func performNameOperation() {
        guard !isReadOnly else { return }
        do {
            switch nameOperation {
            case .add:
                selectedVersionID = try settingsStore.createVersion(for: map, name: nameText).id
            case .rename(let versionID):
                if let version = versions.first(where: { $0.id == versionID }) { try settingsStore.renameVersion(version, on: map, to: nameText) }
            case nil: break
            }
            nameOperation = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteSelectedVersion() {
        guard !isReadOnly, let versionToDelete else { return }
        let deletedVersionID = versionToDelete.id
        do {
            try settingsStore.deleteVersion(versionToDelete, from: map)
            if selectedVersionID == deletedVersionID { selectedVersionID = versions.first?.id }
            self.versionToDelete = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
