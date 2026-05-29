# 💻 SDE Klient Audit – IT & Data, Syddansk Erhvervsskole Vejle

> PowerShell-script til automatisk gennemgang og rapport af en Windows 11 klient.  
> Udviklet til undervisningsbrug på **IT & Data, SDE Vejle**.

---

## 📋 Hvad gør scriptet?

Scriptet er designet til undervisningsbrug, hvor elever selv opsætter et klientmiljø via vSphere. Når eleven kører scriptet på deres Windows 11 klient, genereres en komplet og overskuelig rapport over hele klientmiljøet.

Miljøet består typisk af:
- 2× Windows 11 klienter
- 1× Linux maskine (Samba shares)
- 1× Windows Server 2022/2025 (AD, DHCP, DNS, GPO, Shares)

---

## 📦 Hvad rapporten indeholder

| Sektion | Indhold |
|---|---|
| 🖥️ **Systeminfo** | Computernavn, OS, CPU, RAM, disk, BIOS, sidst bootet |
| 🌐 **Netværk** | IP, subnet, gateway, DNS, DHCP-server + ping-test til gateway/DNS/internet |
| 🏢 **Domain-tilknytning** | Om maskinen er joined, AD-computerobj., aktuel bruger med Home Folder/grupper, GPO'er |
| 💾 **Drev og netværksdrev** | Lokale drev med plads, mappede netværksdrev, printere |
| 📦 **Installeret software** | Fuld liste med versioner |
| ⚙️ **Tjenester** | DHCP client, DNS client, Firewall, RDP m.fl. |
| 🔥 **Firewall** | Alle tre profiler |
| 🔄 **Windows Update** | Afventende opdateringer + seneste installerede |
| 👤 **Lokale konti** | Brugere med sidst logon, grupper med medlemmer |

Rapporten gemmes som `COMPUTERNAVN_KlientRapport.txt` på skrivebordet.

---

## 🚀 Sådan kører du scriptet

### Krav
- Windows 11
- Køres som **Administrator**
- PowerShell 5.1 eller nyere (indbygget i Windows)

### Kør direkte fra GitHub (anbefalet)

Åbn PowerShell som Administrator og indsæt:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
iwr -useb https://raw.githubusercontent.com/tpbillund/sde-klient-audit/main/Get-KlientRapport.ps1 | iex
```

### Kør lokalt

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
.\Get-KlientRapport.ps1
```

---

## 💬 Hvad sker der når scriptet kører?

1. Rapporten køres automatisk og udskrives i terminalen med farver og tydelig formatering
2. Til sidst kan du vælge at **gemme rapporten som .txt** på dit skrivebord

---

## 🖼️ Eksempel på output

```
##################################################
#  NETVAERK
##################################################

        Intel(R) Ethernet Connection
        IPv4 Adresse              : 192.168.10.101
        Subnet Mask               : 255.255.255.0
        Gateway                   : 192.168.10.1
        DNS Servere               : 192.168.10.10
        DHCP Aktiveret            : True
        DHCP Server               : 192.168.10.10

  -- Forbindelsestest --

        Ping til gateway (192.168.10.1)       [OK]  OK
        Ping til DNS (192.168.10.10)          [OK]  OK
        Internetforbindelse (8.8.8.8)         [OK]  OK

##################################################
#  DOMAIN-TILKNYTNING
##################################################

  [OK]  Maskinen er medlem af et domæne
        Domæne                    : G3TBP.local
        AD Computerobjekt         : CN=WIN11-01,OU=Klienter,DC=G3TBP,DC=local
        Sidst logon (AD)          : 15-05-2025 08:32
```

---

## ⚠️ Sikkerhed og ansvarsfraskrivelse

- Scriptet **ændrer intet** i dit miljø – det er udelukkende til læsning og rapportering.
- Brug kun scriptet i dit **eget lukkede testmiljø** – aldrig på produktionssystemer du ikke ejer.
- Rapporten kan indeholde følsomme oplysninger (brugernavne, IP-adresser). Del den kun med relevante parter.

---

## 🔧 Moduler scriptet bruger

Scriptet benytter kun **indbyggede Windows-moduler** – ingen installation nødvendig.

Mangler et modul eller en rolle, springer scriptet blot den pågældende sektion over med en neutral `[-]` besked.

---

## 🏫 Til underviseren

Scriptet kan bruges som:

- **Selvevaluering** – eleven kører scriptet og ser om klienten er korrekt sat op
- **Aflevering** – rapporten gemmes som .txt og afleveres til underviseren
- **Fejlfinding** – hurtigt overblik over netværk, domænetilknytning og GPO'er
- **Kontrol af logons** – viser om klienten rent faktisk er blevet brugt og joined korrekt

> Se også [`sde-server-audit`](https://github.com/tpbillund/sde-server-audit) for tilsvarende script til Windows Server.

---

## 📄 Licens

Dette projekt er udgivet under [MIT-licensen](LICENSE) – frit at bruge, kopiere og tilpasse.
