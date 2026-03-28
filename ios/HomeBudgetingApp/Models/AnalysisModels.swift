import Foundation

enum AnalysisMode: String, CaseIterable, Identifiable {
    case budgetSpread
    case moneyIn
    case monthlySpend
    case netCashFlow
    case savingsRate

    var id: String { rawValue }
    var title: String {
        switch self {
        case .budgetSpread: return "Budget Spread"
        case .moneyIn: return "Money In"
        case .monthlySpend: return "Monthly Spend"
        case .netCashFlow: return "Cash Flow"
        case .savingsRate: return "Savings Rate"
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
        case .netCashFlow:
            return [.bar]
        case .savingsRate:
            return [.line]
        }
    }

    static func defaultStyle(for mode: AnalysisMode) -> ChartStyle {
        availableStyles(for: mode).first ?? .comparisonBars
    }
}

enum BudgetSpreadLevel: String, CaseIterable, Identifiable {
    case group
    case category

    var id: String { rawValue }

    var title: String {
        switch self {
        case .group: return "Group"
        case .category: return "Category"
        }
    }
}

struct AnalysisOptions {
    var mode: AnalysisMode = .budgetSpread
    var chartStyle: ChartStyle = ChartStyle.defaultStyle(for: .budgetSpread)
    var budgetSpreadLevel: BudgetSpreadLevel = .group
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
    let totalIncome: Double
    let leftoverBudget: Double
    let leftoverActual: Double
}

struct SeriesData {
    let labels: [String]
    let values: [Double]
    let label: String
    let total: Double
    var isPercentage: Bool = false
}

struct NetCashFlowData {
    let labels: [String]
    let income: [Double]
    let spend: [Double]
    let net: [Double]
    let totalNet: Double
    let averageNet: Double
    let savingsRate: Double
}

enum AnalysisResult {
    case budgetSpread(BudgetSpreadData)
    case series(SeriesData)
    case netCashFlow(NetCashFlowData)
}

struct AnalysisUiState {
    var options: AnalysisOptions = AnalysisOptions()
    var availableMonths: [String] = []
    var availableYears: [String] = []
    var availableGroups: [String] = []
    var availableCategories: [String] = []
    var result: AnalysisResult?
}
