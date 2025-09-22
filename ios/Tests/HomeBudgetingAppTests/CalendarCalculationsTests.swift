import XCTest
@testable import HomeBudgetingApp

final class CalendarCalculationsTests: XCTestCase {
    func testCalendarTotalsUseSignedTransactions() throws {
        let month = BudgetMonth(
            incomes: [],
            transactions: [
                BudgetTransaction(id: "1", date: "20-09-2025", desc: "Groceries", amount: 40.0, category: "Food"),
                BudgetTransaction(id: "2", date: "20-09-2025", desc: "Fuel", amount: 27.75, category: "Travel"),
                BudgetTransaction(id: "3", date: "20-09-2025", desc: "Temu refund", amount: -7.44, category: "Shopping")
            ],
            categories: [:]
        )

        let calendarMonth = buildCalendar(monthKey: "2025-09", month: month, today: Date(timeIntervalSince1970: 0))

        let calendarDay = calendarMonth.weeks
            .flatMap { $0 }
            .first { $0.dayOfMonth == 20 }

        XCTAssertNotNil(calendarDay)
        XCTAssertEqual(calendarDay?.total, 60.31, accuracy: 0.0001)
    }
}
