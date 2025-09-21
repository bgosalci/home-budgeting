import SwiftUI
import UniformTypeIdentifiers

struct BudgetScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var newMonthKey: String = ""
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
    @State private var dataAlert: DataAlert?

    private var totals: MonthTotals { viewModel.uiState.totals }

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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Collapse") { viewModel.setAllGroupsCollapsed(true) }
                    Button("Expand") { viewModel.setAllGroupsCollapsed(false) }
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
            .alert(item: $dataAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear { syncMonthInputs() }
        .onChange(of: viewModel.uiState.selectedMonthKey) { _ in syncMonthInputs() }
        .onChange(of: viewModel.uiState.monthKeys) { _ in syncMonthInputs() }
    }

    private var monthSection: some View {
        Section(header: Text("Month")) {
            Picker("Selected Month", selection: Binding(
                get: { viewModel.uiState.selectedMonthKey ?? "" },
                set: { viewModel.selectMonth($0) }
            )) {
                ForEach(viewModel.uiState.monthKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("YYYY-MM", text: $newMonthKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button("Create") {
                    viewModel.createMonth(newMonthKey)
                    newMonthKey = ""
                }
                .buttonStyle(.borderedProminent)
            }
            if let selected = viewModel.uiState.selectedMonthKey {
                Button(role: .destructive) {
                    viewModel.deleteNextMonth()
                } label: {
                    Label("Delete next future month", systemImage: "trash")
                }
                .disabled(viewModel.uiState.monthKeys.last == selected)
            }
        }
    }

    private var summarySection: some View {
        Section(header: Text("Summary")) {
            HStack {
                summaryTile(title: "Income", value: totals.totalIncome)
                summaryTile(title: "Budget", value: totals.budgetTotal)
                summaryTile(title: "Actual", value: totals.actualTotal)
            }
            HStack {
                summaryTile(title: "Left (actual)", value: totals.leftoverActual)
                summaryTile(title: "Left (budget)", value: totals.leftoverBudget)
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
                        Text("ID: \(income.id)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(currency(income.amount))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { viewModel.deleteIncome(id: income.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            VStack {
                TextField("Name", text: $incomeName)
                TextField("Amount", text: $incomeAmount)
                    .keyboardType(.decimalPad)
                Button("Add Income") {
                    if let amount = Double(incomeAmount) {
                        viewModel.addIncome(name: incomeName, amount: amount)
                        incomeName = ""
                        incomeAmount = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var categoriesSection: some View {
        Section(header: Text("Categories")) {
            if viewModel.uiState.categories.isEmpty {
                Text("No categories configured").foregroundColor(.secondary)
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
                                Button(role: .destructive) { viewModel.deleteCategory(name: category.name) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    },
                    label: {
                        HStack {
                            Text(key)
                            Spacer()
                            if let summary = viewModel.uiState.totals.groups.first(where: { $0.name == key }) {
                                Text(currency(summary.actual)).font(.footnote)
                            }
                        }
                    }
                )
            }
            VStack {
                TextField("Category name", text: $categoryName)
                TextField("Group", text: $categoryGroup)
                TextField("Budget", text: $categoryBudget)
                    .keyboardType(.decimalPad)
                Button("Save Category") {
                    if let budget = Double(categoryBudget) {
                        viewModel.addOrUpdateCategory(name: categoryName, group: categoryGroup, budget: budget)
                        categoryName = ""
                        categoryGroup = ""
                        categoryBudget = ""
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var dataSection: some View {
        Section(header: Text("Data")) {
            Button {
                exportKind = .transactions
                exportFormat = .json
                exportMonth = exportMonth.isEmpty ? defaultMonthKey() : exportMonth
                showExportSheet = true
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            Button {
                importKind = .transactions
                importFormat = .json
                importMonth = importMonth.isEmpty ? defaultMonthKey() : importMonth
                showImportSheet = true
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func summaryTile(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(currency(value)).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            ?? defaultMonthKey()
        if exportMonth.isEmpty || !viewModel.uiState.monthKeys.contains(exportMonth) {
            exportMonth = defaultKey
        }
        if importMonth.isEmpty || !viewModel.uiState.monthKeys.contains(importMonth) {
            importMonth = defaultKey
        }
    }

    private func handleExportConfirm() {
        guard !exportKind.requiresMonth || normalizeMonth(exportMonth) != nil else {
            dataAlert = DataAlert(title: "Invalid Month", message: "Enter a month in YYYY-MM format.")
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
                dataAlert = DataAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    private func handleImportConfirm() {
        guard !importKind.requiresMonth || normalizeMonth(importMonth) != nil else {
            dataAlert = DataAlert(title: "Invalid Month", message: "Enter a month in YYYY-MM format.")
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
            dataAlert = DataAlert(title: "Export Complete", message: "Saved \(exportFileName)")
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                dataAlert = DataAlert(title: "Export Failed", message: error.localizedDescription)
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
                dataAlert = DataAlert(title: "Import Failed", message: "Unable to read the selected file.")
                return
            }
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard let data = try? Data(contentsOf: url) else {
                dataAlert = DataAlert(title: "Import Failed", message: "Unable to read the selected file.")
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
                    dataAlert = DataAlert(title: "Import Complete", message: summary.message)
                } catch {
                    dataAlert = DataAlert(title: "Import Failed", message: error.localizedDescription)
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                dataAlert = DataAlert(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }

    private func defaultMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private func normalizeMonth(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: trimmed) != nil ? trimmed : nil
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
                        TextField("YYYY-MM", text: $month)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
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
                        TextField("YYYY-MM", text: $month)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
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

private struct DataAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
