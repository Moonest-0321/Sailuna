import SwiftData

@MainActor
enum SectionUnitCoordinator {
    static func apply(_ unit: BookTextSectionMarker, to books: [Book], in context: ModelContext) throws {
        var originalTitles: [(section: Section, title: String)] = []

        for book in books {
            for volume in book.volumes {
                for section in volume.sections {
                    let displayedTitle = unit.displayTitle(section.title)
                    guard displayedTitle != section.title else { continue }
                    originalTitles.append((section, section.title))
                    section.title = displayedTitle
                }
            }
        }

        guard !originalTitles.isEmpty else { return }
        do {
            try context.save()
        } catch {
            for change in originalTitles {
                change.section.title = change.title
            }
            throw error
        }
    }
}
