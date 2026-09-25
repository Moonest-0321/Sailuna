import Foundation

struct TimelineCardPresentation {
    let isWritten: Bool
    let locationText: String
    let excerpt: String
    let accessibilityText: String
}

@MainActor
enum TimelineCardProjection {
    static func presentation(
        event: Event,
        book: Book,
        metadata: TimelineEventCardMetadata?,
        planningStore: StoryPlanningStore
    ) -> TimelineCardPresentation {
        let sections = BookStructure.orderedSections(in: book)
        let legacySection = event.section.flatMap { section in sections.first { $0.id == section.id } }
        var resolvedSection: Section?
        var sourceIsValid = false
        var excerpt = ""

        let linkedOutlineItem: OutlineItem? = metadata.flatMap { metadata -> OutlineItem? in
            guard metadata.bookID == book.id, let outlineItemID = metadata.outlineItemID else { return nil }
            return planningStore.items(bookID: book.id).first { $0.id == outlineItemID }
        }

        if let metadata,
           metadata.bookID == book.id,
           let outlineItemID = metadata.outlineItemID,
           linkedOutlineItem?.id == outlineItemID,
           let anchor = planningStore.anchor(outlineItemID: outlineItemID),
           anchor.bookID == book.id,
           let section = sections.first(where: { $0.id == anchor.sectionID }) {
            resolvedSection = section
            sourceIsValid = true
            excerpt = metadata.excerptMode == .manual
                ? TimelineEventCardMetadata.limitedExcerpt(metadata.manualExcerpt)
                : automaticExcerpt(anchor: anchor, section: section)
        } else if let metadata, metadata.excerptMode == .manual {
            excerpt = TimelineEventCardMetadata.limitedExcerpt(metadata.manualExcerpt)
        }

        let section = resolvedSection ?? legacySection
        let location: String
        if let section {
            let volume = section.volume?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sectionTitle = section.title.trimmingCharacters(in: .whitespacesAndNewlines)
            location = "\(volume.isEmpty ? "未命名卷次" : volume)・\(sectionTitle.isEmpty ? "未命名節次" : sectionTitle)"
        } else if linkedOutlineItem != nil {
            location = "尚無正文來源"
        } else if metadata?.outlineItemID != nil {
            location = "來源失效"
        } else {
            location = "尚未綁定"
        }
        let isWritten = sourceIsValid || legacySection != nil
        let title = event.title.isEmpty ? "未命名事件" : event.title
        return TimelineCardPresentation(
            isWritten: isWritten,
            locationText: location,
            excerpt: excerpt,
            accessibilityText: "\(title)，\(isWritten ? "已寫入" : "未寫入")，\(location)\(excerpt.isEmpty ? "" : "，\(excerpt)")"
        )
    }

    static func automaticExcerpt(anchor: OutlineItemAnchor, section: Section) -> String {
        let plainText = String(section.content.characters)
        let offset = anchor.resolvedOffset(in: plainText)
        let nsText = plainText as NSString
        guard offset < nsText.length else { return normalizedExcerpt(anchor.anchorText) }
        let candidate = nsText.substring(from: offset)
        let normalized = normalizedExcerpt(candidate)
        return normalized.isEmpty ? normalizedExcerpt(anchor.anchorText) : normalized
    }

    static func normalizedExcerpt(_ value: String) -> String {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(normalized.prefix(30))
    }
}
