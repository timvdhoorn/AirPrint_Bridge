import SwiftUI

struct SettingsAboutView: View {
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .padding(.top, 16)

                // App info
                VStack(spacing: 4) {
                    Text("AirPrint Bridge")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Versie 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Van plannen tot plakken")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.165, green: 0.714, blue: 0.945)) // LEM Blue #2AB6F1
                        .italic()
                }

                Divider()

                // Company info
                VStack(spacing: 8) {
                    Text("Labels en Meer B.V.")
                        .font(.headline)
                    VStack(spacing: 4) {
                        Text("Heijligerweg 2, 4906MJ Oosterhout")
                        Text("085 303 7132")
                        Text("info@labelsenmeer.nl")
                            .foregroundColor(Color(red: 0.165, green: 0.714, blue: 0.945))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Divider()

                // Links
                VStack(spacing: 12) {
                    Button("Privacybeleid") {
                        showPrivacyPolicy = true
                    }
                    Button("Algemene Voorwaarden") {
                        showTerms = true
                    }
                }

                Text("Copyright \u{00A9} 2026 Labels en Meer B.V. Alle rechten voorbehouden.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: 450, height: 500)
        .sheet(isPresented: $showPrivacyPolicy) {
            PolicySheet(title: "Privacybeleid", content: privacyPolicyText)
        }
        .sheet(isPresented: $showTerms) {
            PolicySheet(title: "Algemene Voorwaarden", content: termsText)
        }
    }
}

// MARK: - Policy Sheet

struct PolicySheet: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Sluiten") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                Text(content)
                    .font(.system(.body, design: .default))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Privacy Policy

private let privacyPolicyText = """
Privacybeleid — AirPrint Bridge
Laatst bijgewerkt: 7 april 2026

Labels en Meer B.V. ("wij", "ons", "onze") respecteert uw privacy. Dit privacybeleid \
beschrijft hoe de AirPrint Bridge applicatie omgaat met gegevens.

1. Welke gegevens verwerken wij?

AirPrint Bridge verwerkt uitsluitend lokale gegevens op uw Mac:
• Printernamen en -configuratie (via CUPS)
• Papierformaat instellingen
• AirPrint service registraties op het lokale netwerk

2. Geen gegevensverzameling

AirPrint Bridge verzamelt, verstuurt of deelt GEEN persoonlijke gegevens. \
Alle gegevens blijven lokaal op uw Mac. Er wordt geen verbinding gemaakt \
met externe servers, cloud diensten of analytics platformen.

3. Lokale opslag

Uw instellingen worden opgeslagen in macOS UserDefaults op uw Mac. \
Deze gegevens worden niet gesynchroniseerd met iCloud of andere diensten.

4. Netwerkverkeer

AirPrint Bridge registreert printers op uw lokale netwerk via het \
Bonjour/mDNS protocol (dns-sd). Dit verkeer verlaat uw lokale netwerk niet.

5. Systeemtoegang

De applicatie heeft toegang nodig tot:
• CUPS printersysteem (voor printerbeheer)
• Lokaal netwerk (voor AirPrint advertenties)
• macOS Firewall instellingen (om CUPS toegang te garanderen)

6. Contact

Voor vragen over dit privacybeleid kunt u contact opnemen met:

Labels en Meer B.V.
Heijligerweg 2, 4906MJ Oosterhout
085 303 7132
info@labelsenmeer.nl
"""

// MARK: - Terms and Conditions

private let termsText = """
Algemene Voorwaarden — AirPrint Bridge
Laatst bijgewerkt: 7 april 2026

1. Algemeen

Deze algemene voorwaarden zijn van toepassing op het gebruik van de AirPrint Bridge \
applicatie ("de Software"), ontwikkeld door Labels en Meer B.V., gevestigd te Oosterhout.

2. Licentie

Labels en Meer B.V. verleent u een niet-exclusief, niet-overdraagbaar recht om de \
Software te gebruiken op de systemen waarvoor het is geleverd. De Software is gebaseerd \
op het open source AirPrint Bridge project (MIT-licentie) door Eliran Sapir.

3. Gebruiksbeperkingen

Het is niet toegestaan de Software:
• Te kopiëren of distribueren aan derden zonder toestemming
• Te decompileren, reverse-engineeren of wijzigen (behoudens wettelijke uitzonderingen)
• Te gebruiken voor onwettige doeleinden

4. Aansprakelijkheid

De Software wordt geleverd "as is". Labels en Meer B.V. is niet aansprakelijk voor:
• Directe of indirecte schade voortvloeiend uit het gebruik van de Software
• Compatibiliteitsproblemen met specifieke printers of macOS versies
• Onderbrekingen in de printfunctionaliteit

Labels en Meer B.V. spant zich in om de Software naar behoren te laten functioneren, \
maar geeft geen garanties ten aanzien van beschikbaarheid of foutloze werking.

5. Ondersteuning

Ondersteuning voor de Software wordt geboden door Labels en Meer B.V. via de \
reguliere servicekanalen. Neem contact op via:
• Telefoon: 085 303 7132
• E-mail: info@labelsenmeer.nl

6. Wijzigingen

Labels en Meer B.V. behoudt zich het recht voor deze voorwaarden te wijzigen. \
Wijzigingen treden in werking na publicatie van de bijgewerkte voorwaarden.

7. Toepasselijk recht

Op deze voorwaarden is Nederlands recht van toepassing. Geschillen worden \
voorgelegd aan de bevoegde rechter in Breda.

8. Contact

Labels en Meer B.V.
Heijligerweg 2, 4906MJ Oosterhout
KvK: zie labelsenmeer.nl
085 303 7132
info@labelsenmeer.nl
"""
