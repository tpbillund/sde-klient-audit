# Changelog

Alle væsentlige ændringer til dette projekt dokumenteres her.

Format følger [Keep a Changelog](https://keepachangelog.com/da/1.0.0/).

---

## [1.0.0] – 2025

### Tilføjet
- `Get-KlientRapport.ps1` – klientrapport med:
  - Systeminfo: OS, CPU, RAM, disk, BIOS, sidst bootet
  - Netværk: IP, subnet, gateway, DNS, DHCP-server + ping-test til gateway/DNS/internet
  - Domain-tilknytning: domænemedlemskab, AD-computerobj., aktuel bruger med Home Folder/grupper, GPO'er via gpresult
  - Drev og netværksdrev: lokale drev med plads, mappede netværksdrev, printere
  - Installeret software: fuld liste med versioner
  - Tjenester: DHCP client, DNS client, Firewall, RDP m.fl.
  - Firewall: alle tre profiler
  - Windows Update: afventende opdateringer + seneste installerede
  - Lokale konti: brugere med sidst logon, grupper med medlemmer
  - Gem rapport som `COMPUTERNAVN_KlientRapport.txt` på skrivebordet
  - Dual output: farver på skærm, ren tekst i .txt fil
  - Dansk sprog i hele scriptet
