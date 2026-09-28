import SwiftUI

struct EmailLoginView: View {
    let authService: SailuneAccountAuthService
    let onSignedIn: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var codeWasSent = false

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(codeWasSent ? "輸入驗證碼" : "以 Email 登入")
                .font(.title2.weight(.semibold))

            if codeWasSent {
                Text("已寄送 6 位數驗證碼至 \(normalizedEmail)。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("6 位數驗證碼", text: $verificationCode)
                    .textContentType(.oneTimeCode)
                    .textFieldStyle(.roundedBorder)
                    .disabled(authService.isWorking)
                    .onChange(of: verificationCode) { _, value in
                        verificationCode = String(value.filter(\.isNumber).prefix(6))
                    }
                    .onSubmit { Task { await verifyCode() } }
            } else {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .disabled(authService.isWorking)
                    .onSubmit { Task { await sendCode() } }
            }

            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if authService.needsKeychainRetry {
                Button("重試鑰匙圈授權") {
                    Task { await authService.retryKeychainAccess() }
                }
                .disabled(authService.isWorking)
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if codeWasSent {
                    Button("重新寄送") { Task { await sendCode() } }
                        .disabled(authService.isWorking)
                    Button("登入") { Task { await verifyCode() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(authService.isWorking || authService.needsKeychainRetry || verificationCode.count != 6)
                } else {
                    Button("寄送驗證碼") { Task { await sendCode() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(authService.isWorking || authService.needsKeychainRetry || normalizedEmail.isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
        .onChange(of: authService.signedInEmail) { _, newEmail in
            guard newEmail != nil else { return }
            onSignedIn()
            dismiss()
        }
    }

    private func sendCode() async {
        guard !normalizedEmail.isEmpty else { return }
        await authService.sendCode(to: normalizedEmail)
        if authService.errorMessage == nil {
            codeWasSent = true
            verificationCode = ""
        }
    }

    private func verifyCode() async {
        guard verificationCode.count == 6 else { return }
        _ = await authService.verifyCode(verificationCode, for: normalizedEmail)
    }
}
