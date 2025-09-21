import SwiftUI

struct NotesScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var showEditor = false
    @State private var editingNote: BudgetNote?
    @State private var noteTitle: String = ""
    @State private var noteBody: String = ""

    var body: some View {
        NavigationStack {
            List {
                if viewModel.uiState.notes.isEmpty {
                    Text("No notes recorded yet.").foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.uiState.notes) { note in
                        Button(action: {
                            editingNote = note
                            noteTitle = note.desc
                            noteBody = note.data
                            showEditor = true
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.desc.isEmpty ? "Untitled" : note.desc)
                                    .font(.headline)
                                Text(note.data)
                                    .font(.body)
                                    .lineLimit(2)
                                Text(noteDate(note.time))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { viewModel.deleteNote(id: note.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingNote = nil
                        noteTitle = ""
                        noteBody = ""
                        showEditor = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                NavigationStack {
                    Form {
                        Section(header: Text("Note")) {
                            TextField("Title", text: $noteTitle)
                            TextEditor(text: $noteBody)
                                .frame(minHeight: 160)
                        }
                    }
                    .navigationTitle(editingNote == nil ? "New Note" : "Edit Note")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showEditor = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if let note = editingNote {
                                    viewModel.updateNote(id: note.id, desc: noteTitle, body: noteBody)
                                } else {
                                    viewModel.addNote(desc: noteTitle, body: noteBody)
                                }
                                showEditor = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func noteDate(_ time: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: time / 1000))
    }
}

struct NotesScreen_Previews: PreviewProvider {
    static var previews: some View {
        NotesScreen()
            .environmentObject(BudgetViewModel())
    }
}
