import Foundation

enum CharacterDetailPreviewOrdering {
    static func latest<Value>(
        in values: [Value],
        updatedAt: (Value) -> Date,
        id: (Value) -> UUID
    ) -> Value? {
        values.max { lhs, rhs in
            let lhsDate = updatedAt(lhs)
            let rhsDate = updatedAt(rhs)
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return id(lhs).uuidString < id(rhs).uuidString
        }
    }

    static func last<Value>(
        in values: [Value],
        sortOrder: (Value) -> Double,
        id: (Value) -> UUID
    ) -> Value? {
        values.max { lhs, rhs in
            let lhsOrder = sortOrder(lhs)
            let rhsOrder = sortOrder(rhs)
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return id(lhs).uuidString < id(rhs).uuidString
        }
    }
}
