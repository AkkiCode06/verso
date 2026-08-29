// Verso licence tool.
//
// Run with:  swift Tools/licensekeygen.swift <command>
//
//   keypair                 Create a signing keypair. The private key is
//                           written to Tools/.secrets/ and must never be
//                           committed, shipped, or pasted anywhere.
//   sign [days]             Issue a licence. Omit days for a lifetime key.
//   verify <key>            Check a licence against the public key.
//
// Security model: the app embeds only the PUBLIC key, so licences cannot be
// forged without the private key held here. See LicenseManager for what this
// does and does not protect against.

import CryptoKit
import Foundation

let secretsDirectory = URL(fileURLWithPath: "Tools/.secrets")
let privateKeyFile = secretsDirectory.appendingPathComponent("private.key")
let publicKeyFile = secretsDirectory.appendingPathComponent("public.key")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func makeKeypair() {
    try? FileManager.default.createDirectory(at: secretsDirectory, withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: privateKeyFile.path) {
        fail("A private key already exists at \(privateKeyFile.path).\nDelete it deliberately if you really mean to invalidate every licence you have issued.")
    }
    let key = Curve25519.Signing.PrivateKey()
    let privateBase64 = key.rawRepresentation.base64EncodedString()
    let publicBase64 = key.publicKey.rawRepresentation.base64EncodedString()

    try? privateBase64.write(to: privateKeyFile, atomically: true, encoding: .utf8)
    try? publicBase64.write(to: publicKeyFile, atomically: true, encoding: .utf8)
    // Owner-only permissions.
    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyFile.path)

    print("Keypair created.")
    print("  private : \(privateKeyFile.path)   (never share this)")
    print("  public  : \(publicKeyFile.path)")
    print("")
    print("Paste this public key into LicenseManager.publicKeyBase64:")
    print(publicBase64)
}

func loadPrivateKey() -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOf: privateKeyFile, encoding: .utf8),
          let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
    else { fail("No private key found. Run: swift Tools/licensekeygen.swift keypair") }
    return key
}

/// Crockford-style base32, so keys avoid characters people misread.
let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

func base32Encode(_ data: Data) -> String {
    var output = "", buffer = 0, bits = 0
    for byte in data {
        buffer = (buffer << 8) | Int(byte)
        bits += 8
        while bits >= 5 {
            output.append(alphabet[(buffer >> (bits - 5)) & 31])
            bits -= 5
        }
    }
    if bits > 0 { output.append(alphabet[(buffer << (5 - bits)) & 31]) }
    return output
}

func signLicence(days: Int?) {
    let key = loadPrivateKey()
    // Payload carries only what the app needs: when it was issued, and how
    // long it lasts. A random nonce keeps two same-day keys distinct.
    let nonce = UInt32.random(in: 0..<UInt32.max)
    var payload = "\(Int(Date().timeIntervalSince1970))|\(nonce)"
    if let days { payload += "|\(days)" }

    guard let payloadData = payload.data(using: .utf8),
          let signature = try? key.signature(for: payloadData)
    else { fail("Could not sign.") }

    let blob = base32Encode(payloadData) + "~" + base32Encode(signature)
    let grouped = stride(from: 0, to: blob.count, by: 40).map { offset -> String in
        let start = blob.index(blob.startIndex, offsetBy: offset)
        let end = blob.index(start, offsetBy: min(40, blob.count - offset))
        return String(blob[start..<end])
    }.joined(separator: "\n")

    print("Licence\(days.map { " (\($0) days)" } ?? " (lifetime)"):")
    print("")
    print("WVLN1")
    print(grouped)
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("usage: swift Tools/licensekeygen.swift keypair | sign [days]")
    exit(0)
}
switch arguments[1] {
case "keypair": makeKeypair()
case "sign":
    signLicence(days: arguments.count > 2 ? Int(arguments[2]) : nil)
default: fail("Unknown command \(arguments[1])")
}
