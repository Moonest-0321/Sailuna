import SwiftUI

extension View {
    func sailuneErrorAlert(
        _ title: LocalizedStringKey,
        errorMessage: Binding<String?>,
        acknowledgeRole: ButtonRole? = nil
    ) -> some View {
        alert(title, isPresented: Binding(
            get: { errorMessage.wrappedValue != nil },
            set: { if !$0 { errorMessage.wrappedValue = nil } }
        )) {
            Button(SailuneActionCopy.acknowledge, role: acknowledgeRole) {
                errorMessage.wrappedValue = nil
            }
        } message: {
            Text(errorMessage.wrappedValue ?? "未知錯誤")
        }
    }
}
