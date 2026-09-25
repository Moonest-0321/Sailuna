import SwiftUI
import SwiftData

// MARK: - 4. 關係圖頁
struct KinshipGraphView: View {
    let character: Character
    let book: Book
    let onBack: () -> Void
    let onSelectCharacter: (Character) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query(sort: \CharacterRelationship.createdAt) private var allRelationships: [CharacterRelationship]
    @Query private var allAliases: [CharacterAlias]
    @Query private var allProfiles: [CharacterProfile]
    @State private var showingAddSheet = false
    @State private var showingAddGeneralRelationship = false
    @State private var selectedView = RelationshipView.network
    @State private var selectedGroup: RelationshipGroup?
    @State private var searchText = ""
    @State private var selectedFilter = "全部"
    @State private var canvasScale: CGFloat = 1

    private enum RelationshipView: String, CaseIterable, Identifiable {
        case network = "關係網"
        case list = "關係列表"
        var id: String { rawValue }
    }

    private var availableTargets: [Character] {
        allCharacters.filter { $0.id != character.id && $0.book?.id == book.id }
    }

    private var graphGroups: [RelationshipGroup] {
        RelationshipGroupBuilder.directGroups(for: character, relationships: allRelationships)
    }

    private var graphNodes: [Character] {
        var ids = Set<UUID>()
        return visibleGroups.compactMap { group in
            let peer = group.source.id == character.id ? group.target : group.source
            return ids.insert(peer.id).inserted ? peer : nil
        }
    }

    private var filterOptions: [String] {
        var values = Set<String>()
        for group in graphGroups {
            if !group.kinships.isEmpty { values.insert("血緣") }
            values.formUnion(group.currentNames)
        }
        return ["全部"] + values.sorted()
    }

    private var visibleGroups: [RelationshipGroup] {
        graphGroups.filter { group in
            let peer = group.source.id == character.id ? group.target : group.source
            let aliasNames = allAliases
                .filter { $0.character?.id == peer.id }
                .map(\.name)
            let matchesSearch = CharacterSearchMatcher.matches(
                query: searchText,
                realName: peer.realName,
                aliasNames: aliasNames
            )
            let matchesFilter = selectedFilter == "全部" ||
                (selectedFilter == "血緣" ? !group.kinships.isEmpty : group.currentNames.contains(selectedFilter))
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: SailuneSymbol.back.systemName)
                    Text("返回詳情")
                }
                .buttonStyle(.plain)
                Spacer()
                Menu {
                    Button(SailuneActionCopy.addRelationship) { showingAddGeneralRelationship = true }
                    Button("新增血緣關係") { showingAddSheet = true }
                } label: {
                    Image(systemName: SailuneSymbol.addCircleFilled.systemName).font(.title3)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(SailuneTheme.controlSurface)

            Picker("檢視", selection: $selectedView) {
                ForEach(RelationshipView.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            HStack {
                SailuneSearchField(placeholder: "搜尋角色", text: $searchText, compact: true)
                Picker("篩選", selection: $selectedFilter) {
                    ForEach(filterOptions, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 130)
                if selectedView == .network {
                    Button { canvasScale = max(0.6, canvasScale - 0.1) } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    Button { canvasScale = min(2, canvasScale + 0.1) } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if selectedView == .list {
                RelationshipListView(center: character, book: book, searchText: searchText, selectedFilter: selectedFilter)
            } else {
                GeometryReader { viewport in
                    let baseSize = CGSize(
                        width: max(viewport.size.width, CGFloat(graphNodes.count) * 150),
                        height: max(viewport.size.height, 360)
                    )
                    let scaledSize = CGSize(width: baseSize.width * canvasScale, height: baseSize.height * canvasScale)
                    ScrollView([.horizontal, .vertical]) {
                        graphCanvas(size: baseSize)
                            .frame(width: baseSize.width, height: baseSize.height)
                            .scaleEffect(canvasScale, anchor: .topLeading)
                            .frame(width: scaledSize.width, height: scaledSize.height, alignment: .topLeading)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddKinshipSheet(
                sourceCharacter: character,
                book: book,
                allCharacters: availableTargets
            )
        }
        .sheet(isPresented: $showingAddGeneralRelationship) {
            AddGeneralRelationshipSheet(
                center: character,
                book: book,
                characters: availableTargets
            )
        }
        .popover(item: $selectedGroup, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) { group in
            RelationshipDetailSheet(group: group, book: book)
        }
    }

    @ViewBuilder
    private func graphCanvas(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let nodeSize: CGFloat = 76
        let indexedNodes = Array(graphNodes.enumerated())

        ZStack {
            Color.appBackground.opacity(0.5)
            Path { path in
                for group in visibleGroups {
                    let peer = group.source.id == character.id ? group.target : group.source
                    guard let index = graphNodes.firstIndex(where: { $0.id == peer.id }) else { continue }
                    let targetPos = position(index: index, total: graphNodes.count, center: center)
                    path.move(to: center)
                    path.addLine(to: targetPos)
                }
            }
            .stroke(Color.secondary.opacity(0.5), lineWidth: 1.5)

            nodeView(character, at: center, size: nodeSize, isCenter: true)
            ForEach(indexedNodes, id: \.element.id) { index, node in
                nodeView(node, at: position(index: index, total: indexedNodes.count, center: center), size: nodeSize * 0.8, isCenter: false)
            }
            ForEach(Array(visibleGroups.enumerated()), id: \.element.id) { groupIndex, group in
                let peer = group.source.id == character.id ? group.target : group.source
                if let index = graphNodes.firstIndex(where: { $0.id == peer.id }) {
                    let pos = position(index: index, total: graphNodes.count, center: center)
                    Button { selectedGroup = group } label: {
                        Text("\(group.source.id == character.id ? "→" : "←") \(group.currentNames.prefix(2).joined(separator: "・"))")
                            .font(.caption2).lineLimit(1).padding(8)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .position(x: (center.x + pos.x) / 2, y: (center.y + pos.y) / 2 + CGFloat(groupIndex.isMultiple(of: 2) ? -10 : 10))
                }
            }
        }
    }

    private func nodeView(_ char: Character, at pos: CGPoint, size: CGFloat, isCenter: Bool) -> some View {
        Button { onSelectCharacter(char) } label: {
            ZStack {
                Circle()
                    .fill(isCenter ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .frame(width: size, height: size).shadow(radius: 2)
                VStack(spacing: 2) {
                    Text(char.realName.isEmpty ? "?" : char.realName)
                        .font(.caption).fontWeight(.medium).lineLimit(1).padding(.horizontal, 4)
                    if isCenter, let role = allProfiles.first(where: { $0.character?.id == char.id })?.role, !role.isEmpty {
                        Text(role).font(.caption2).lineLimit(1).padding(.horizontal, 4)
                    }
                }
            }
            .position(pos)
        }
        .buttonStyle(.plain)
    }

    private func position(index: Int, total: Int, center: CGPoint) -> CGPoint {
        guard total > 0 else { return center }
        let radius: CGFloat = 130
        let angle = (Double(index) / Double(total)) * (.pi * 2) - (.pi / 2)
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}

// MARK: - 5. 新增關係彈出視窗
struct AddKinshipSheet: View {
    let sourceCharacter: Character
    let book: Book
    let allCharacters: [Character]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 【修正】使用新版 Enum case
    @State private var selectedRole: KinshipRole = .fatherToChild
    @State private var selectedTargetIDString: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("新增血緣關係").font(.headline)

            Form {
                Picker("關係類型 (從 \(sourceCharacter.realName.isEmpty ? "此角色" : sourceCharacter.realName) 的角度)", selection: $selectedRole) {
                    // 【修正】使用 selectableCases + displayName
                    ForEach(KinshipRole.selectableCases) { role in
                        Text(role.displayName).tag(role)
                    }
                }

                Picker("目標角色", selection: $selectedTargetIDString) {
                    Text("請選擇...").tag("")
                    ForEach(allCharacters) { char in
                        Text(char.realName.isEmpty ? "未命名" : char.realName).tag(char.id.uuidString)
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Button(SailuneActionCopy.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(SailuneActionCopy.create) {
                    createRelation()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedTargetIDString.isEmpty)
            }
        }
        .padding(20).frame(width: 400, height: 250)
    }

    private func createRelation() {
        guard let targetID = UUID(uuidString: selectedTargetIDString),
              let targetChar = allCharacters.first(where: { $0.id == targetID }) else { return }

        let forwardRelation = KinshipRelation(role: selectedRole, targetCharacter: targetChar)
        sourceCharacter.kinships.append(forwardRelation)
        modelContext.insert(forwardRelation)

        let inverseRelation = KinshipRelation(role: selectedRole.inverseRole, targetCharacter: sourceCharacter)
        targetChar.kinships.append(inverseRelation)
        modelContext.insert(inverseRelation)
    }
}
