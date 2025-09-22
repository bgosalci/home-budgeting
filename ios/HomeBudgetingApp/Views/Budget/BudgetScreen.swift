import SwiftUI
import UniformTypeIdentifiers

struct BudgetScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var newMonthKey: String = BudgetScreen.defaultMonthKey()
    @State private var incomeName: String = ""
    @State private var incomeAmount: String = ""
    @State private var categoryName: String = ""
    @State private var categoryGroup: String = ""
    @State private var categoryBudget: String = ""
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var exportKind: BudgetViewModel.DataTransferKind = .transactions
    @State private var exportFormat: BudgetViewModel.DataFormat = .json
    @State private var exportMonth: String = ""
    @State private var importKind: BudgetViewModel.DataTransferKind = .transactions
    @State private var importFormat: BudgetViewModel.DataFormat = .json
    @State private var importMonth: String = ""
    @State private var exportDocument: ExportDocument?
    @State private var exportFileName: String = ""
    @State private var exportContentType: UTType = .json
    @State private var isExportingFile = false
    @State private var isImportingFile = false
    @State private var pendingImport: PendingImport?
    @State private var activeDialog: AppDialog?
    @State private var editingIncomeId: String?
    @State private var editingCategoryOriginalName: String?
    @FocusState private var focusedField: Field?

    private var totals: MonthTotals { viewModel.uiState.totals }

    private var deletableFutureMonthKey: String? {
        guard let selected = viewModel.uiState.selectedMonthKey else { return nil }
        let months = viewModel.uiState.monthKeys
        guard let index = months.firstIndex(of: selected), index + 1 < months.count else { return nil }
        let candidate = months[index + 1]
        guard let nextCalendarMonth = nextMonthKey(after: Self.defaultMonthKey()), candidate == nextCalendarMonth else {
            return nil
        }
        return candidate
    }

    private var selectedMonthValue: String {
        viewModel.uiState.selectedMonthKey
            ?? viewModel.uiState.monthKeys.last
            ?? ""
    }

    private var selectedMonthLabel: String {
        selectedMonthValue.isEmpty ? "Select Month" : selectedMonthValue
    }

    private var selectedMonthBinding: Binding<String> {
        Binding(
            get: { selectedMonthValue },
            set: { viewModel.selectMonth($0) }
        )
    }

    private var floatingMonthSelector: some View {
        GeometryReader { proxy in
            HStack {
                Picker(selection: selectedMonthBinding) {
                    ForEach(viewModel.uiState.monthKeys, id: \.self) { key in
                        Text(key).tag(key)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.headline)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedMonthLabel)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(width: max(proxy.size.width / 2, 0), alignment: .leading)
                    .background(.thinMaterial, in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
                }
                .pickerStyle(.menu)
                .disabled(viewModel.uiState.monthKeys.isEmpty)
                .accessibilityLabel("Month")
                .accessibilityValue(Text(selectedMonthLabel))
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .frame(height: 76)
    }

    @ViewBuilder
    private var monthSectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            floatingMonthSelector
            Text("Months")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }

    private enum Field: Hashable {
        case incomeName
        case incomeAmount
        case categoryName
        case categoryGroup
        case categoryBudget
    }

    var body: some View {
        NavigationStack {
            List {
                monthSection
                summarySection
                incomesSection
                categoriesSection
                dataSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportOptionsView(
                    monthKeys: viewModel.uiState.monthKeys,
                    kind: $exportKind,
                    format: $exportFormat,
                    month: $exportMonth,
                    onCancel: { showExportSheet = false },
                    onConfirm: handleExportConfirm
                )
            }
            .sheet(isPresented: $showImportSheet) {
                ImportOptionsView(
                    monthKeys: viewModel.uiState.monthKeys,
                    kind: $importKind,
                    format: $importFormat,
                    month: $importMonth,
                    onCancel: { showImportSheet = false },
                    onConfirm: handleImportConfirm
                )
            }
            .fileExporter(
                isPresented: $isExportingFile,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFileName,
                onCompletion: handleExportResult
            )
            .fileImporter(
                isPresented: $isImportingFile,
                allowedContentTypes: pendingImport?.allowedContentTypes ?? [.json],
                allowsMultipleSelection: false,
                onCompletion: handleImportResult
            )
            .appDialog($activeDialog)
        }
        .onAppear { syncMonthInputs() }
        .onChange(of: viewModel.uiState.selectedMonthKey) { _ in syncMonthInputs() }
        .onChange(of: viewModel.uiState.monthKeys) { _ in syncMonthInputs() }
    }

    private var monthSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create Month").font(.subheadline).foregroundStyle(.secondary)
                MonthPickerField(month: $newMonthKey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Create") {
                    viewModel.createMonth(newMonthKey)
                    advanceNewMonthKey()
                }
                .buttonStyle(.borderedProminent)
            }
            Button(role: .destructive) {
                guard let nextKey = deletableFutureMonthKey else { return }
                activeDialog = AppDialog.confirm(
                    title: "Delete \(nextKey)?",
                    message: "Are you sure you want to delete the future month \(nextKey)? This action cannot be undone.",
                    confirmTitle: "Delete",
                    destructive: true,
                    onConfirm: { viewModel.deleteNextMonth() }
                )
            } label: {
                Label("Delete next future month", systemImage: "trash")
            }
            .disabled(deletableFutureMonthKey == nil)
        } header: {
            monthSectionHeader
        }
    }

    private var summarySection: some View {
        Section(header: Text("Summary")) {
            HStack {
                summaryTile(title: "Income", value: totals.totalIncome)
                summaryTile(title: "Budget", value: totals.budgetTotal)
                summaryTile(title: "Actual", value: totals.actualTotal)
            }
            HStack(alignment: .top) {
                summaryTile(title: "Left (actual)", value: totals.leftoverActual, highlightNegative: true)
                summaryTile(title: "Left (budget)", value: totals.leftoverBudget, highlightNegative: true)
                if let prediction = viewModel.uiState.prediction {
                    predictionTile(prediction)
                }
            }
        }
    }

    private var incomesSection: some View {
        Section(header: Text("Income")) {
            if viewModel.uiState.incomes.isEmpty {
                Text("No income recorded").foregroundColor(.secondary)
            }
            ForEach(viewModel.uiState.incomes) { income in
                HStack {
                    VStack(alignment: .leading) {
                        Text(income.name).font(.headline)
                    }
                    Spacer()
                    Text(currency(income.amount))
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        editingIncomeId = income.id
                        incomeName = income.name
                        incomeAmount = String(format: "%.2f", income.amount)
                        focusedField = .incomeName
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        activeDialog = AppDialog.confirm(
                            title: "Delete Income",
                            message: "Are you sure you want to delete \(income.name)?",
                            confirmTitle: "Delete",
                            destructive: true,
                            onConfirm: { viewModel.deleteIncome(id: income.id) }
                        )
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
            VStack {
                TextField("Name", text: $incomeName)
                    .focused($focusedField, equals: .incomeName)
                TextField("Amount", text: $incomeAmount)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .incomeAmount)
                Button(editingIncomeId == nil ? "Add Income" : "Save Income") {
                    if let amount = Double(incomeAmount) {
                        if let editingIncomeId {
                            viewModel.updateIncome(id: editingIncomeId, name: incomeName, amount: amount)
                        } else {
                            viewModel.addIncome(name: incomeName, amount: amount)
                        }
                        incomeName = ""
                        incomeAmount = ""
                        editingIncomeId = nil
                        focusedField = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                if editingIncomeId != nil {
                    Button("Cancel") {
                        incomeName = ""
                        incomeAmount = ""
                        editingIncomeId = nil
                        focusedField = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var categoriesSection: some View {
        Section(header: Text("Categories")) {
            if viewModel.uiState.categories.isEmpty {
                Text("No categories configured").foregroundColor(.secondary)
            }
            if !viewModel.uiState.categories.isEmpty {
                categoryTotalsSummary
            }
            let groups = Dictionary(grouping: viewModel.uiState.categories, by: { $0.group })
            ForEach(groups.keys.sorted(), id: \.self) { key in
                let items = groups[key] ?? []
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { !viewModel.uiState.collapsedGroups.contains(key) },
                        set: { _ in viewModel.toggleGroup(key) }
                    ),
                    content: {
                        ForEach(items, id: \.name) { category in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(category.name).font(.headline)
                                    Text("Budget: \(currency(category.budget))").font(.caption)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Actual: \(currency(category.actual))")
                                    Text("Diff: \(currency(category.difference))")
                                        .foregroundColor(category.difference >= 0 ? .green : .red)
                                }.font(.caption)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    editingCategoryOriginalName = category.name
                                    categoryName = category.name
                                    categoryGroup = category.group
                                    categoryBudget = String(format: "%.2f", category.budget)
                                    focusedField = .categoryName
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    activeDialog = AppDialog.confirm(
                                        title: "Delete Category",
                                        message: "Are you sure you want to delete \(category.name)?",
                                        confirmTitle: "Delete",
                                        destructive: true,
                                        onConfirm: { viewModel.deleteCategory(name: category.name) }
                                    )
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    },
                    label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(key)
                                .font(.headline)
                            if let summary = viewModel.uiState.totals.groups.first(where: { $0.name == key }) {
                                HStack(spacing: 12) {
                                    categorySummaryValue(title: "Budgeted", value: summary.budget, valueFont: .footnote)
                                    categorySummaryValue(title: "Actual", value: summary.actual, valueFont: .footnote)
                                    categorySummaryValue(title: "Diff", value: summary.difference, highlightDelta: true, valueFont: .footnote)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                )
            }
            VStack {
                TextField("Category name", text: $categoryName)
                    .focused($focusedField, equals: .categoryName)
                TextField("Group", text: $categoryGroup)
                    .focused($focusedField, equals: .categoryGroup)
                TextField("Budget", text: $categoryBudget)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .categoryBudget)
                Button(editingCategoryOriginalName == nil ? "Add Category" : "Save Category") {
                    if let budget = Double(categoryBudget) {
                        if let editingCategoryOriginalName {
                            viewModel.updateCategory(
                                originalName: editingCategoryOriginalName,
                                name: categoryName,
                                group: categoryGroup,
                                budget: budget
                            )
                        } else {
                            viewModel.addOrUpdateCategory(name: categoryName, group: categoryGroup, budget: budget)
                        }
                        categoryName = ""
                        categoryGroup = ""
                        categoryBudget = ""
                        editingCategoryOriginalName = nil
                        focusedField = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                if editingCategoryOriginalName != nil {
                    Button("Cancel") {
                        categoryName = ""
                        categoryGroup = ""
                        categoryBudget = ""
                        editingCategoryOriginalName = nil
                        focusedField = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var categoryTotalsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Totals")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                categorySummaryValue(title: "Budgeted", value: totals.budgetTotal)
                categorySummaryValue(title: "Actual", value: totals.actualTotal)
                categorySummaryValue(title: "Diff", value: totals.budgetTotal - totals.actualTotal, highlightDelta: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func categorySummaryValue(title: String, value: Double, highlightDelta: Bool = false, valueFont: Font = .subheadline) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currency(value))
                .font(valueFont)
                .foregroundColor(highlightDelta ? (value >= 0 ? .green : .red) : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dataSection: some View {
        Section(header: Text("Data")) {
            Button {
                exportKind = .transactions
                exportFormat = .json
                exportMonth = exportMonth.isEmpty ? Self.defaultMonthKey() : exportMonth
                showExportSheet = true
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            Button {
                importKind = .transactions
                importFormat = .json
                importMonth = importMonth.isEmpty ? Self.defaultMonthKey() : importMonth
                showImportSheet = true
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func summaryTile(title: String, value: Double, highlightNegative: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(currency(value))
                .font(.headline)
                .foregroundColor(highlightNegative && value < 0 ? .red : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func predictionTile(_ prediction: BalancePrediction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Predicted left").font(.caption).foregroundStyle(.secondary)
            Text(currency(prediction.predictedLeftover))
                .font(.headline)
                .foregroundColor(prediction.predictedLeftover < 0 ? .red : .primary)
            if let summary = predictionSummary(for: prediction) {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func predictionSummary(for prediction: BalancePrediction) -> String? {
        guard prediction.sampleSize > 0 else { return nil }
        let plural = prediction.sampleSize == 1 ? "" : "s"
        let dayLabel: String
        if let day = prediction.remainderUsedDay {
            dayLabel = "day \(day)"
        } else {
            dayLabel = "historical data"
        }
        return "Based on \(prediction.sampleSize) historical month\(plural) (\(dayLabel))."
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func syncMonthInputs() {
        let defaultKey = viewModel.uiState.selectedMonthKey
            ?? viewModel.uiState.monthKeys.last
            ?? Self.defaultMonthKey()
        if exportMonth.isEmpty || !viewModel.uiState.monthKeys.contains(exportMonth) {
            exportMonth = defaultKey
        }
        if importMonth.isEmpty || !viewModel.uiState.monthKeys.contains(importMonth) {
            importMonth = defaultKey
        }
        if newMonthKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newMonthKey = nextMonthKey(after: defaultKey) ?? Self.defaultMonthKey()
        }
    }

    private func handleExportConfirm() {
        guard !exportKind.requiresMonth || normalizeMonth(exportMonth) != nil else {
            activeDialog = AppDialog.info(title: "Invalid Month", message: "Select a valid month before continuing.")
            return
        }
        showExportSheet = false
        Task {
            do {
                let month = exportKind.requiresMonth ? normalizeMonth(exportMonth) : nil
                let payload = try await viewModel.exportData(kind: exportKind, monthKey: month, format: exportFormat)
                exportDocument = ExportDocument(data: payload.data)
                exportContentType = payload.contentType
                exportFileName = payload.filename
                isExportingFile = true
            } catch {
                activeDialog = AppDialog.error(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    private func handleImportConfirm() {
        guard !importKind.requiresMonth || normalizeMonth(importMonth) != nil else {
            activeDialog = AppDialog.info(title: "Invalid Month", message: "Select a valid month before continuing.")
            return
        }
        let normalized = importKind.requiresMonth ? normalizeMonth(importMonth) : nil
        pendingImport = PendingImport(kind: importKind, format: importFormat, month: normalized)
        showImportSheet = false
        isImportingFile = true
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            activeDialog = AppDialog.info(title: "Export Complete", message: "Saved \(exportFileName)")
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                activeDialog = AppDialog.error(title: "Export Failed", message: error.localizedDescription)
            }
        }
        exportDocument = nil
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        defer { pendingImport = nil }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard let request = pendingImport else {
                activeDialog = AppDialog.error(title: "Import Failed", message: "Unable to read the selected file.")
                return
            }
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard let data = try? Data(contentsOf: url) else {
                activeDialog = AppDialog.error(title: "Import Failed", message: "Unable to read the selected file.")
                return
            }
            Task {
                do {
                    let summary = try await viewModel.importData(
                        kind: request.kind,
                        monthKey: request.month,
                        format: request.format,
                        content: data
                    )
                    activeDialog = AppDialog.info(title: "Import Complete", message: summary.message)
                } catch {
                    activeDialog = AppDialog.error(title: "Import Failed", message: error.localizedDescription)
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                activeDialog = AppDialog.error(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }

    fileprivate static var monthCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        if let gmt = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = gmt
        }
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    fileprivate static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = monthCalendar
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func defaultMonthKey() -> String {
        Self.monthFormatter.string(from: Date())
    }

    private func normalizeMonth(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7 else { return nil }
        return Self.monthFormatter.date(from: trimmed) != nil ? trimmed : nil
    }

    private func advanceNewMonthKey() {
        guard let next = nextMonthKey(after: newMonthKey) else { return }
        newMonthKey = next
    }

    private func nextMonthKey(after month: String) -> String? {
        guard let date = Self.monthFormatter.date(from: month) else { return nil }
        guard let next = Self.monthCalendar.date(byAdding: DateComponents(month: 1), to: date) else { return nil }
        return Self.monthFormatter.string(from: next)
    }
}

struct BudgetScreen_Previews: PreviewProvider {
    static var previews: some View {
        BudgetScreen()
            .environmentObject(BudgetViewModel())
    }
}

private struct ExportOptionsView: View {
    let monthKeys: [String]
    @Binding var kind: BudgetViewModel.DataTransferKind
    @Binding var format: BudgetViewModel.DataFormat
    @Binding var month: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Set") {
                    Picker("Kind", selection: $kind) {
                        ForEach(BudgetViewModel.DataTransferKind.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
                if kind.requiresMonth {
                    Section("Month") {
                        MonthPickerField(month: $month)
                        if !monthKeys.isEmpty {
                            Menu("Use existing month") {
                                ForEach(monthKeys, id: \.self) { key in
                                    Button(key) { month = key }
                                }
                            }
                        }
                    }
                }
                Section("Format") {
                    if kind.supportsCSV {
                        Picker("Format", selection: $format) {
                            ForEach(BudgetViewModel.DataFormat.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("JSON")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export", action: onConfirm)
                        .disabled(kind.requiresMonth && month.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: kind) { newKind in
                if !newKind.supportsCSV {
                    format = .json
                }
            }
        }
    }
}

private struct ImportOptionsView: View {
    let monthKeys: [String]
    @Binding var kind: BudgetViewModel.DataTransferKind
    @Binding var format: BudgetViewModel.DataFormat
    @Binding var month: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Set") {
                    Picker("Kind", selection: $kind) {
                        ForEach(BudgetViewModel.DataTransferKind.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
                if kind.requiresMonth {
                    Section("Month") {
                        MonthPickerField(month: $month)
                        if !monthKeys.isEmpty {
                            Menu("Use existing month") {
                                ForEach(monthKeys, id: \.self) { key in
                                    Button(key) { month = key }
                                }
                            }
                        }
                    }
                }
                Section("Format") {
                    if kind.supportsCSV {
                        Picker("Format", selection: $format) {
                            ForEach(BudgetViewModel.DataFormat.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("JSON")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select", action: onConfirm)
                        .disabled(kind.requiresMonth && month.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: kind) { newKind in
                if !newKind.supportsCSV {
                    format = .json
                }
            }
        }
    }
}

private struct MonthPickerField: View {
    @Binding var month: String
    @State private var cachedDate: Date
    @State private var workingDate: Date
    @State private var isPresentingPicker = false
    @State private var yearRange: ClosedRange<Int>

    fileprivate static var calendar: Calendar = BudgetScreen.monthCalendar
    fileprivate static let formatter: DateFormatter = BudgetScreen.monthFormatter
    private static let accessibilityFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()

    init(month: Binding<String>) {
        _month = month
        let initialDate = MonthPickerField.formatter.date(from: month.wrappedValue)
            ?? MonthPickerField.normalize(Date())
        _cachedDate = State(initialValue: initialDate)
        _workingDate = State(initialValue: initialDate)
        _yearRange = State(initialValue: MonthPickerField.initialYearRange(for: initialDate))
        if month.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || MonthPickerField.formatter.date(from: month.wrappedValue) == nil {
            month.wrappedValue = MonthPickerField.formatter.string(from: initialDate)
        }
    }

    var body: some View {
        Button {
            workingDate = cachedDate
            isPresentingPicker = true
        } label: {
            HStack {
                Text(MonthPickerField.formatter.string(from: cachedDate))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .accessibilityLabel("Month")
        .accessibilityValue(MonthPickerField.accessibilityFormatter.string(from: cachedDate))
        .sheet(isPresented: $isPresentingPicker) {
            MonthPickerSheet(
                date: $workingDate,
                calendar: MonthPickerField.calendar,
                yearRange: $yearRange,
                onCancel: { isPresentingPicker = false },
                onConfirm: {
                    commitSelection()
                    isPresentingPicker = false
                }
            )
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: month) { newValue in
            guard let parsed = MonthPickerField.formatter.date(from: newValue) else { return }
            cachedDate = parsed
            expandYearRange(toInclude: parsed)
        }
    }

    private func commitSelection() {
        let normalized = MonthPickerField.normalize(workingDate)
        cachedDate = normalized
        month = MonthPickerField.formatter.string(from: normalized)
        expandYearRange(toInclude: normalized)
    }

    private func expandYearRange(toInclude date: Date) {
        let year = MonthPickerField.calendar.component(.year, from: date)
        yearRange = MonthPickerField.extendedRange(yearRange, toInclude: year)
    }

    private static func initialYearRange(for date: Date) -> ClosedRange<Int> {
        let year = calendar.component(.year, from: date)
        let lower = max(1, year - 20)
        let upper = year + 50
        return lower...upper
    }

    fileprivate static func extendedRange(_ range: ClosedRange<Int>, toInclude year: Int) -> ClosedRange<Int> {
        var lower = range.lowerBound
        var upper = range.upperBound
        if year <= lower {
            lower = max(1, year - 10)
        }
        if year >= upper {
            upper = year + 10
        }
        return lower...upper
    }

    fileprivate static func normalize(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}

private struct MonthPickerSheet: View {
    @Binding var date: Date
    let calendar: Calendar
    @Binding var yearRange: ClosedRange<Int>
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                MonthYearPicker(
                    date: $date,
                    calendar: calendar,
                    yearRange: yearRange,
                    onYearChange: { newYear in
                        yearRange = MonthPickerField.extendedRange(yearRange, toInclude: newYear)
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 16)
            .navigationTitle("Select Month")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onConfirm)
                }
            }
        }
    }
}

private struct MonthYearPicker: View {
    @Binding var date: Date
    let calendar: Calendar
    let yearRange: ClosedRange<Int>
    var onYearChange: (Int) -> Void

    private var monthNames: [String] {
        calendar.monthSymbols
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Month", selection: monthBinding) {
                ForEach(Array(monthNames.enumerated()), id: \.offset) { index, name in
                    Text(name).tag(index + 1)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Picker("Year", selection: yearBinding) {
                ForEach(Array(yearRange), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .frame(height: 216)
        .clipped()
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.month, from: date) },
            set: { newMonth in updateDate(month: newMonth, year: nil) }
        )
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.year, from: date) },
            set: { newYear in
                updateDate(month: nil, year: newYear)
                onYearChange(newYear)
            }
        )
    }

    private func updateDate(month: Int?, year: Int?) {
        var components = calendar.dateComponents([.year, .month], from: date)
        if let month {
            components.month = month
        }
        if let year {
            components.year = year
        }
        components.day = 1
        if let updated = calendar.date(from: components) {
            date = updated
        }
    }
}

private struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct PendingImport {
    let kind: BudgetViewModel.DataTransferKind
    let format: BudgetViewModel.DataFormat
    let month: String?

    var allowedContentTypes: [UTType] {
        switch format {
        case .json:
            return [.json]
        case .csv:
            return [.commaSeparatedText, .plainText]
        }
    }
}

