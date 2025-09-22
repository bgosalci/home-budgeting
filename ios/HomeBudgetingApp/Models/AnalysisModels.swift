import Foundation

enum AnalysisMode: String, CaseIterable, Identifiable {
    case budgetSpread
    case moneyIn
    case monthlySpend

    var id: String { rawValue }
    var title: String {
        switch self {
        case .budgetSpread: return "Budget Spread"
        case .moneyIn: return "Money In"
        case .monthlySpend: return "Monthly Spend"
        }
    }
}

enum ChartStyle: String, CaseIterable, Identifiable {
    case comparisonBars
    case donut
    case bar
    case line

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comparisonBars: return "Comparison Bars"
        case .donut: return "Donut"
        case .bar: return "Bar"
        case .line: return "Line"
        }
    }

    static func availableStyles(for mode: AnalysisMode) -> [ChartStyle] {
        switch mode {
        case .budgetSpread:
            return [.comparisonBars, .donut]
        case .moneyIn, .monthlySpend:
            return [.line, .bar]
        }
    }

    static func defaultStyle(for mode: AnalysisMode) -> ChartStyle {
        availableStyles(for: mode).first ?? .comparisonBars
    }
}

struct AnalysisOptions {
    var mode: AnalysisMode = .budgetSpread
    var chartStyle: ChartStyle = ChartStyle.defaultStyle(for: .budgetSpread)
    var selectedMonth: String?
    var selectedYear: String?
    var selectedGroup: String?
    var selectedCategory: String?
}

struct BudgetSpreadData {
    let labels: [String]
    let planned: [Double]
    let actual: [Double]
    let plannedPercent: [Double]
    let actualPercent: [Double]
    let plannedTotal: Double
    let actualTotal: Double
}

struct SeriesData {
    let labels: [String]
    let values: [Double]
    let label: String
    let total: Double
}

enum AnalysisResult {
    case budgetSpread(BudgetSpreadData)
    case series(SeriesData)
}

struct AnalysisUiState {
    var options: AnalysisOptions = AnalysisOptions()
    var availableMonths: [String] = []
    var availableYears: [String] = []
    var availableGroups: [String] = []
    var availableCategories: [String] = []
    var result: AnalysisResult?
}
