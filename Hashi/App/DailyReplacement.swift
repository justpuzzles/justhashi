import SwiftUI

/// Opening `day` would replace the unfinished Daily from `earlier`, which
/// holds the one daily save slot.
struct DailyReplacement: Identifiable, Equatable {
    let day: DayKey
    let earlier: DayKey
    var id: DayKey { day }
}

extension View {
    /// Asks before a Daily's first move replaces another unfinished Daily.
    /// Shared by Home and the archive so both say the same thing.
    func dailyReplacementDialog(_ pending: Binding<DailyReplacement?>,
                                open: @escaping (DayKey) -> Void) -> some View {
        confirmationDialog(
            "Start this Daily?",
            isPresented: Binding(get: { pending.wrappedValue != nil },
                                 set: { if !$0 { pending.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { replacement in
            Button("Start Daily") { open(replacement.day) }
            Button("Cancel", role: .cancel) {}
        } message: { replacement in
            Text("Your unfinished Daily from \(replacement.earlier.date().formatted(.dateTime.month(.wide).day())) is replaced once you draw a bridge on this one.")
        }
    }
}
