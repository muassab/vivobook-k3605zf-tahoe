# Backlight do teclado (F7) — solução

Máquina: ASUS VivoBook 16X K3605ZF, macOS 26.7.3 (Tahoe), OpenCore 1.0.8.
Status: **resolvido** em 2026-11-22.

## Resultado

`Fn+F7` e `F7` puro ciclam o backlight: **off → 1 → 2 → 3 → off**.
`Fn+Esc` (`0x4E`) não mexe no LED. Nível 1 acende fraco (`KBS1 = 0x40`);
2 e 3 mais fortes.

## Como funciona

O EC recebe o nível em `KBBN` (`ERM2`, offset `0x3F`, base `0xFE108B00`) com
**bit 7 como enable**: `0x80 | nível` (`0x81`..`0x83`), desligado = `0x80`.
O nível atual é lido de `KBBS` (`ERM2` `0x2E`) — `KBBN` é one-shot e o EC
zera depois de aplicar.

Teclas:

| Tecla | Código | Caminho |
|---|---|---|
| `Fn+F7` (Fn-lock off) | `0xC7` | `_Q78` → `IANE(0xC7)` → kext |
| `F7` puro (Fn-lock on) | `0xC4` | `_Q16/_Q17` → `IANE(0xC4/0xC5)` → kext |
| `Fn+Esc` | `0x4E` | ignorado pelo kext |

Além do caminho ACPI, o `asuskeysd` intercepta o keycode 98 (`F7`) e chama
`asusbl +`, que fala com o `IOUserClient` do kext. Assim o `F7` puro também
funciona quando o EC não manda query.

## Componentes neste repositório

1. `EFI/OC/ACPI/SSDT-ATKH.aml` (+ `.dsl`) — `SKBB`/`GKBB`/`GKBS`/`GKBF`,
   `EWRB`/`ERDB` (leitura/escrita crua de EC) e `XTKP = One`.
2. `EFI/OC/config.plist`
   - `ACPI → Add`: `SSDT-ATKH.aml`
   - `ACPI → Patch`: `ATKP` → `XTKP` nos predicados `If` (mascarado)
   - `ACPI → Patch`: `KBLC & 0x80` `And` → `Or` (`_Q16/_Q17`, `Count = 2`)
3. `EFI/OC/Kexts/AsusSMC.kext` — 1.4.1 recompilado. Diff completo em
   `patches/AsusSMC-1.4.1-k3605zf.patch`:
   - ciclo wrap `3 → 0 → 1 → 2 → 3` em `0xC4/0xC7`, `0xC5` desce
   - nível de boot lido de `GKBS`
   - `case 0xC7` (Fn+F7)
   - `writeKBBN`/`readECRam`/`writeECRam`
   - `AsusSMCUserClient` (selector 0 = set, 1 = get) para o `asusbl`
4. `tools/asuskeys/` — daemon, CLI e hook (ver README da pasta).

## Instalação

1. Copie `EFI/OC` para a ESP (ACPI, config, kext).
2. Build do kext (opcional; o binário já está no repo):

   ```sh
   git clone --branch 1.4.1 https://github.com/hieplpvip/AsusSMC.git
   cd AsusSMC
   patch -p1 < /caminho/patches/AsusSMC-1.4.1-k3605zf.patch
   xcodebuild -project AsusSMC.xcodeproj -target AsusSMC \
     -configuration Release ARCHS=x86_64 build
   ```

3. Daemon:

   ```sh
   cd tools/asuskeys && ./build.sh && ./install.sh
   ```

   Conceda **Acessibilidade** ao binário em
   Ajustes do Sistema → Privacidade e Segurança → Acessibilidade.

## Verificação

```sh
ioreg -rc AsusSMC -l -w0 | grep -E "IsKeyboardBacklightSupported|KBBN|KBBF|KBLevel"
```

Esperado: `IsKeyboardBacklightSupported = Yes`, `KBBNBefore`/`KBBNAfter`
mudando a cada toque. O log do kext (`SYSLOG`) não aparece no `log show`
nesta máquina; use as propriedades do IORegistry.

Teste manual: `Fn+F7` três vezes (off→1→2→3), depois `Fn+Esc` (não deve mudar).

## Notas

- O patch `ATKP` → `XTKP` é necessário porque `ATKP` é externo e nunca é
  definido por nenhuma tabela no macOS; sem ele todos os `_Qxx` abortam.
- O patch `KBLC` destrava `_Q16/_Q17`; sem ele `F7` puro não gera `0xC4`.
- `F6`/`F4`/`F5` em modo hotkey podem exigir `Fn+Esc` para o EC entrar no
  modo de queries ACPI.
- Código de teste `-kbtest` (escrita crua no EC via portas `0x62/0x66`)
  segue no kext, dormente.

## Reverter

Remova `SSDT-ATKH.aml` de `ACPI → Add`, apague os dois patches e restaure o
`AsusSMC.kext` original. O resto da EFI não depende disso.
