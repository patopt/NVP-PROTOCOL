import SwiftUI
import UniformTypeIdentifiers

/// Reliable folder picker (the SwiftUI `.fileImporter` for `.folder` often leaves
/// the "Open" button disabled). Opens the Files browser in folder-selection mode
/// and returns the chosen directory URL. Security-scoped access is started inside
/// the delegate (before `onPick`) so the caller can create a persistent bookmark.
struct FolderPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let u = urls.first else { onCancel(); return }
            // Keep the security scope open across onPick so bookmark creation works.
            let access = u.startAccessingSecurityScopedResource()
            onPick(u)
            if access { u.stopAccessingSecurityScopedResource() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onCancel() }
    }
}
