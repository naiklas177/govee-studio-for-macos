import Foundation
import Security
import SwiftUI

protocol CredentialStore {
    func load() throws -> String?
    func save(_ key: String) throws
    func remove() throws
}
struct KeychainCredentialStore: CredentialStore {
    private var query: [String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"de.naiklas.goveestudio.credentials",kSecAttrAccount as String:"govee-api-key"] }
    private func checked(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw StudioError.message("Schlüsselbund-Fehler \(status). Der Key wurde nicht in einer Datei gespeichert.") }
    }
    func load() throws -> String? {
        var q=query;q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?
        let status=SecItemCopyMatching(q as CFDictionary,&result)
        if status == errSecItemNotFound { return nil }
        try checked(status)
        guard let data=result as? Data,let key=String(data:data,encoding:.utf8) else { throw StudioError.message("Gespeicherter API-Key konnte nicht gelesen werden.") }
        return key
    }
    func save(_ key: String) throws {
        let value=[kSecValueData as String:Data(key.utf8)]
        let status=SecItemUpdate(query as CFDictionary,value as CFDictionary)
        if status == errSecItemNotFound {
            var add=query;add[kSecValueData as String]=Data(key.utf8);add[kSecAttrLabel as String]="Govee Studio API-Key"
            add[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            try checked(SecItemAdd(add as CFDictionary,nil))
        } else { try checked(status) }
    }
    func remove() throws {
        let status=SecItemDelete(query as CFDictionary)
        if status != errSecItemNotFound { try checked(status) }
    }
}
struct CredentialSettingsView: View {
    @ObservedObject var library: CloudLibrary
    @State private var editing=false
    var body: some View {
        VStack(alignment:.leading,spacing:9) {
            HStack {
                Label(tr(library.keySaved ? "Key im macOS-Schlüsselbund":"Govee-Verbindung"),systemImage:library.keySaved ? "lock.shield.fill":"key.fill").font(.system(size:11,weight:.medium)).foregroundStyle(Palette.mint)
                Spacer()
                if library.keySaved { Button(tr(editing ? "Schließen":"Key ändern")) { editing.toggle() }.buttonStyle(.plain).font(.system(size:10)) }
            }
            if !library.keySaved || editing {
                HStack {
                    SecureField(tr("Govee API-Key"),text:$library.key).textFieldStyle(.roundedBorder).accessibilityLabel(tr("Govee API-Key"))
                    Button(tr("Dauerhaft speichern")) { library.saveKey(); if library.keySaved { editing=false } }.buttonStyle(StudioButtonStyle()).disabled(library.key.isEmpty)
                }
            }
            Text(verbatim:tr(library.keyStatus)).font(.system(size:9)).foregroundStyle(Palette.muted)
        }.padding(12).background(Palette.raised,in:RoundedRectangle(cornerRadius:10))
    }
}
