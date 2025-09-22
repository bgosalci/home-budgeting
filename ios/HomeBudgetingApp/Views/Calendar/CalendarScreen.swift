import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel

    @State private var activeDay: CalendarDay?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let swipeThreshold: CGFloat = 50
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    private var monthKeys: [String] { viewModel.uiState.monthKeys }
    private var selectedMonthKey: String? { viewModel.uiState.selectedMonthKey }
    private var previousMonthKey: String? {
        guard let selected = selectedMonthKey,
              let index = monthKeys.firstIndex(of: selected),
              index > 0 else { return nil }
        return monthKeys[index - 1]
    }
    private var nextMonthKey: String? {
        guard let selected = selectedMonthKey,
              let index = monthKeys.firstIndex(of: selected),
              index + 1 < monthKeys.count else { return nil }
        return monthKeys[index + 1]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        if let key = previousMonthKey {
                            withAnimation { viewModel.selectMonth(key) }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(previousMonthKey == nil)
                    .accessibilityLabel("Previous Month")

                    Spacer()

                    Text(viewModel.uiState.calendar.title)
                        .font(.title2)
                        .bold()

                    Spacer()

                    Button {
                        if let key = nextMonthKey {
                            withAnimation { viewModel.selectMonth(key) }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(nextMonthKey == nil)
                    .accessibilityLabel("Next Month")
                }
                .font(.title3)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol).font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(Array(viewModel.uiState.calendar.weeks.enumerated()), id: \.offset) { _, week in
                        ForEach(week) { day in
                            CalendarCell(day: day, onSelect: handleDaySelection)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onEnded { value in
                        handleSwipe(value.translation)
                    }
            )
            .navigationTitle("Calendar")
        }
        .sheet(item: $activeDay) { day in
            CalendarDayDetailView(day: day, monthTitle: viewModel.uiState.calendar.title)
        }
        .onChange(of: selectedMonthKey) { _ in
            activeDay = nil
        }
    }

    private func handleDaySelection(_ day: CalendarDay) {
        guard day.dayOfMonth != nil else { return }
        activeDay = day
    }

    private func handleSwipe(_ translation: CGSize) {
        guard abs(translation.width) > abs(translation.height), abs(translation.width) > swipeThreshold else {
            return
        }
        if translation.width < 0 {
            if let key = nextMonthKey {
                withAnimation { viewModel.selectMonth(key) }
            }
        } else {
            if let key = previousMonthKey {
                withAnimation { viewModel.selectMonth(key) }
            }
        }
    }
}

private struct CalendarCell: View {
    let day: CalendarDay
    let onSelect: (CalendarDay) -> Void

    init(day: CalendarDay, onSelect: @escaping (CalendarDay) -> Void = { _ in }) {
        self.day = day
        self.onSelect = onSelect
    }

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
        .contentShape(Rectangle())
        .onTapGesture {
            guard day.dayOfMonth != nil else { return }
            onSelect(day)
        }
        .accessibilityAddTraits(day.dayOfMonth == nil ? [] : .isButton)
    }

    private func currency(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}

private struct CalendarDayDetailView: View {
    let day: CalendarDay
    let monthTitle: String

    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()

    private var title: String {
        if let date = day.date {
            return Self.dateFormatter.string(from: date)
        }
        if let value = day.dayOfMonth {
            return "\(monthTitle) \(value)"
        }
        return monthTitle
    }

    private var totalAmount: Double {
        day.transactions.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if day.transactions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No transactions for this day.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section("Transactions") {
                        ForEach(day.transactions) { tx in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(tx.desc.isEmpty ? "No description" : tx.desc)
                                        .font(.headline)
                                    Spacer()
                                    Text(currency(tx.amount))
                                        .font(.headline)
                                        .foregroundColor(tx.amount < 0 ? .red : .primary)
                                }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(tx.category.isEmpty ? "Uncategorized" : tx.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(tx.date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section {
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(currency(totalAmount))
                                .font(.headline)
                                .foregroundColor(totalAmount < 0 ? .red : .primary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        CalendarDayDetailView.amountFormatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
    }
}

struct CalendarScreen_Previews: PreviewProvider {
    static var previews: some View {
        CalendarScreen()
            .environmentObject(BudgetViewModel())
    }
}
