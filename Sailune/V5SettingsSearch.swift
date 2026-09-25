import Foundation

enum V5SettingsSearch {
    static func places(_ places: [Place], matching query: String) -> [Place] {
        filter(places, query: query) { place in
            [place.name, place.alternateNames ?? "", place.placeType ?? "", place.placeDescription]
        }
    }

    static func worldTerms(_ terms: [WorldTerm], matching query: String) -> [WorldTerm] {
        filter(terms, query: query) { term in
            [term.name, term.alternateNames ?? "", term.termCategory ?? "", term.termDescription]
        }
    }

    private static func filter<Model>(
        _ models: [Model],
        query: String,
        fields: (Model) -> [String]
    ) -> [Model] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return models }
        return models.filter { fields($0).contains { $0.localizedCaseInsensitiveContains(normalizedQuery) } }
    }
}

