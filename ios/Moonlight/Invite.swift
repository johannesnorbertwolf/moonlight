// Invite links, codes and the invite sheet (link, QR code, code).
//
// A link looks like https://johannesnorbertwolf.github.io/moonlight/?join=K7QM4P. It opens the
// web app, which handles it for Android and browsers and offers "Open in the Moonlight app" on
// iPhone (moonlight://join/K7QM4P). Once the site's apple-app-site-association file is live, iOS
// opens the app directly (universal link).

import CoreImage.CIFilterBuiltins
import SwiftUI

enum Invite {
    static let webBase = "https://johannesnorbertwolf.github.io/moonlight/"

    static func link(_ code: String) -> URL { URL(string: webBase + "?join=" + code)! }

    /// Upper case, letters and digits only: "k7qm-4p" → "K7QM4P".
    static func normalize(_ s: String) -> String {
        String(s.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII }.map(Character.init))
    }

    /// The code in a moonlight://join/CODE or https://…/moonlight/?join=CODE link.
    static func code(from url: URL) -> String? {
        let c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var raw: String?
        if url.scheme == "moonlight" {
            raw = url.host == "join" ? url.pathComponents.dropFirst().first : nil
            raw = raw ?? c?.queryItems?.first { $0.name == "join" || $0.name == "code" }?.value
        } else {
            raw = c?.queryItems?.first { $0.name == "join" }?.value
        }
        guard let raw else { return nil }
        let code = normalize(raw)
        return code.count == 6 ? code : nil
    }

    static func qr(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let img = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// "K7QM4P" → "K7Q M4P", easier to read aloud and type.
    static func spaced(_ code: String) -> String {
        code.count == 6 ? "\(code.prefix(3)) \(code.suffix(3))" : code
    }
}

struct InviteSheet: View {
    let group: GroupModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(t("invite.body", ["group": group.name]))
                        .foregroundStyle(Color.text2).multilineTextAlignment(.center)
                    if let code = group.code {
                        if let img = Invite.qr(Invite.link(code).absoluteString) {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(12)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityLabel(t("invite.qr"))
                        }
                        VStack(spacing: 4) {
                            Text(t("invite.code")).font(.footnote).foregroundStyle(Color.text2)
                            Text(Invite.spaced(code))
                                .font(.system(size: 40, weight: .semibold, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        ShareLink(item: Invite.link(code),
                                  message: Text(t("invite.message", ["group": group.name, "code": code]))) {
                            Label(t("invite.share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButton())
                    } else {
                        Text(t("error.load"))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(t("invite.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(t("onb.done")) { dismiss() } }
            .screen()
        }
    }
}
