import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(viewModel.uiState.calendar.title)
                    .font(.title2)
                    .bold()
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol).font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(Array(viewModel.uiState.calendar.weeks.enumerated()), id: \.offset) { _, week in
                        ForEach(week) { day in
                            CalendarCell(day: day)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Calendar")
        }
    }
}

private struct CalendarCell: View {
    let day: CalendarDay

    var body: some View {
        VStack(spacing: 4) {
            if let value = day.dayOfMonth {
                Text("\(value)")
                    .font(.headline)
                    .foregroundColor(day.isToday ? .white : .primary)
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .background(day.isToday ? Color.accentColor : Color.clear)
                    .clipShape(Circle())
                if let total = day.total {
                    Text(currency(total))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    Spacer().frame(height: 12)
                }
            } else {
                Spacer()
            }
        }
        .frame(height: 60)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func currency(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}

struct CalendarScreen_Previews: PreviewProvider {
    static var previews: some View {
        CalendarScreen()
            .environmentObject(BudgetViewModel())
    }
}
