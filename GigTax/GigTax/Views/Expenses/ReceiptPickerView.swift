import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Attach-a-receipt control: camera, photo library, or file import (PDF or
/// image), all saving into ReceiptStorage and reporting back a relative path.
struct ReceiptPickerView: View {
    @Binding var receiptPath: String?

    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var isPickingFile = false
    @State private var photosPickerItem: PhotosPickerItem?

    var body: some View {
        Section("Receipt") {
            if let path = receiptPath {
                HStack {
                    if let uiImage = UIImage(contentsOfFile: ReceiptStorage.fullURL(for: path).path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Label("Receipt attached", systemImage: "doc.fill")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        ReceiptStorage.delete(relativePath: path)
                        receiptPath = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete Receipt")
                }
            } else {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                    Button { showPhotosPicker = true } label: {
                        Label("Choose from Photos", systemImage: "photo")
                    }
                    Button { isPickingFile = true } label: {
                        Label("Choose File", systemImage: "folder")
                    }
                } label: {
                    Label("Add Receipt", systemImage: "camera.fill")
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    receiptPath = ReceiptStorage.save(data: data, fileExtension: "jpg")
                }
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        receiptPath = ReceiptStorage.save(data: data, fileExtension: "jpg")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.pdf, .image]
        ) { result in
            if case .success(let url) = result {
                receiptPath = ReceiptStorage.save(fileAt: url)
            }
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
