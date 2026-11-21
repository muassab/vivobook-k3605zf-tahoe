# Plano — Sleep / Wake no Hackintosh ASUS VivoBook 16X K3605Z (macOS 26 Tahoe)

Sessão de referência: 2026-11-20 23:15. Wi-Fi (`AirportMtkWlan`) e Bluetooth
(`AirportMtkBtFw` + patcher) funcionando. Sleep/wake é a frente separada;
falha preexistente, anterior a esses drivers.

> Correção: a versão anterior deste plano descrevia um desktop X99-D4 com
> RX 580. A máquina é um **notebook ASUS VivoBook 16X K3605Z**. As hipóteses
> sobre CSM/vBIOS da RX 580 e "SMBIOS de laptop em desktop" foram descartadas.

## Máquina

```
ASUS VivoBook 16X K3605Z
CPU     i5-12450H (Alder Lake-P, 4P+4E)
iGPU    Intel UHD 48EU, PCI 8086:46A3 — WhateverXe 0.8.2 + AppleIntelTGLCompat 0.8.1
dGPU    desligada por SSDT-dGPU-Off
RAM     40 GB      Bateria + tampa presentes (laptop)
macOS   26.7.3 (Tahoe)   OpenCore 1.0.8   SMBIOS MacBookPro16,2
```

## Estado medido

```
pmset -g:
  sleep 10, displaysleep 10, disksleep 10
  hibernatemode 0, standby 0, powernap 0, womp 1, proximitywake 1, tcpkeepalive 1

ACPI carregado:
  SSDT-PLUG-ALT, EC-USBX, PNLF, USB-Reset, dGPU-Off, MCHC, SBUS, HPET
  RTC e HPET presentes no IODeviceTree; AppleRTC carregado
  NAO existe AWAC no firmware -> SSDT-AWAC desnecessario
  NAO existe LPS0 (PNP0D80) no firmware -> e o que SSDT-DEEPIDLE cria

Quirks: DisableRtcChecksum=true, PowerTimeoutKernelPanic=true, ResetHwSig=false
Misc>Boot>HibernateMode=None, Misc>Debug>SysReport=true (nao gerou dump na ESP)

Historico (pmset -g log):
  15:32:42  Entering Sleep (Idle Sleep)
  15:40:20  Failure during sleep: 0x0000001F EFI/Bootrom Failure
  21:25:50  Entering Sleep (Software Sleep)
  21:27:38  Failure during sleep: 0x0000001F
  22:57:36  Entering Sleep (Software Sleep)
  22:58:59  Failure during sleep: 0x0000001F
  23:05:11  Entering Sleep (Software Sleep)
  23:07:42  Failure during sleep: 0x0000001F
```

Sintoma físico: tela apaga, ventoinha para por instantes, LED do teclado fica
aceso, botão power (toque curto) não responde, só desliga segurando. Depois do
boot, macOS registra `0x1F`. Nunca há panic em
`/Library/Logs/DiagnosticReports`.

Log unificado do último boot morre em `23:05:12.454`, logo após
`bluetoothd: kIOMessageSystemWillSleep` — o kernel congelou na transicao.

## O que ja foi descartado

1. **AWAC/RTC**: nao ha AWAC; RTC e HPET existem e AppleRTC carrega.
   `SSDT-RTC0`/`SSDT-AWAC` nao se aplicam.
2. **Drivers novos (Wi-Fi/BT)**: as falhas de 15:32 e 21:25 sao anteriores a
   instalacao dos kexts; `AirportItlwm::setPowerState` usa thread_call +
   `IOPMAckImplied` (padrao itlwm) e `AirportMtkBtFw::setPowerState` responde
   na hora. `PowerTimeoutKernelPanic=true` nao gerou panic -> nao e timeout de
   power state.
3. **Teste cruzado com Windows**: nao existe particao Windows no NVMe
   (`disk0` = EFI + APFS). Alternativa: Linux live USB (`cat /sys/power/mem_sleep`).
4. **Falta de S3 no firmware**: nao confirmado, mas o irmao de chassis
   K3605VV trava no suspend tambem no Linux (journal termina em
   `PM: suspend entry`), o que aponta firmware/EC do modelo.

## Causa provavel

O autor do WhateverXe documenta exatamente esta assinatura em ADL-P:
"S3 enters but never resumes (`EFI/Bootrom Failure after last point of entry
to sleep`)" — issue #117. O README classifica sleep/wake como **experimental**,
validado apenas em configuracoes MIPI DSI especificas. Ou seja: o caminho S3
neste notebook nao e confiavel nem no Linux nem no macOS com esse driver.

## Plano de acao

### Fase A — S0ixStandby na EFI interna (em andamento)

`S0ixStandby` (labrouss) faz o macOS dormir em **Deep Idle (S0)** em vez de
S3, chamando o `_DSM` do LPS0 que o firmware espera. Feito para notebooks com
S3 quebrado ou ausente. Pre-release 0.5.6; suporte a Alder Lake e "generico",
com reset de iGPU desligado por padrao (`-s0ixgpureset` fica de fora ate
provar).

Instalacao na EFI interna, com backup datado da config e script de rollback.
O pendrive 1401 fica **limpo**, como fallback de boot.

```
sudo sh ~/mtk/install-s0ix-internal.sh   # backup + kext + aml + config
# reboot normal (EFI interna)
~/mtk/s0ix/s0ix-status.sh
ioreg -rd1 -c IOPMrootDomain | grep DeepIdle    # esperado: IOPMDeepIdleSupported = Yes
sudo pmset -a hibernatemode 0 standby 0 powernap 0 tcpkeepalive 0
sudo sh ~/mtk/sleep-test.sh s0ix
```

Rollback: `sudo sh ~/mtk/rollback-s0ix.sh` (restaura o `.bak-pres0ix-*` mais
recente e remove kext/AML). Se a maquina nao bootar, bootar pelo pendrive e
rodar o mesmo rollback de la.

**Resultado (2026-11-20 23:19): falhou.** O SSDT carregou
(`IOPMDeepIdleSupported = Yes` no IORegistry) e os boot-args entraram, mas:

- o kext **nao carrega**: casa com um device ACPI `PNP0D80` e este firmware
  nao tem nenhum (`ioreg | grep -c PNP0D80` = 0). O `SSDT-DEEPIDLE` define
  apenas os metodos `\_SB.LPS0` / `\_GPE.LXEN` (opt-in), nao um device.
- o sleep travou igual: `23:19:00 Entering Sleep` -> sem wake ->
  `23:22:13 Failure 0x1F`. Sem panic, log morto antes da transicao.
- nao foi possivel determinar se o macOS escolheu tipo 7 (Deep Idle) ou S3:
  o log unificado nao sobrevive ao corte duro.

Para insistir seria preciso criar um device ACPI `PNP0D80` falso (para o kext
carregar e fazer o reset de iGPU no wake) e ainda contar com o WhateverXe
sobreviver ao wake — o upstream relata panic de iGPU nesse exato ponto.
Decisao: rollback e desabilitar sleep; hibernacao (Fase C) fica como proximo
experimento.

Boot-args adicionados no pendrive: `-s0ixd3 -s0ixacnortc`.
Criterio de sucesso: `pmset -g log` mostra `Wake from Deep Idle` e
`boottime` igual; sem `Failure during sleep`.

Se funcionar, replicar na EFI interna (`~/mtk/push-live-config.sh` + copiar
kext/aml) e depois testar com `-s0ixgpureset`.

### Fase B — fallback: WhateverXe 0.8.3

0.8.3 corrige "internal eDP support on Alder Lake after display sleep" e
"GPU recovery failure that could stall a normal restart after a graphics
hang". Barato de testar (trocar kext), mas nao resolve resume de firmware.

### Fase C — proximo experimento: hibernacao S4

`hibernatemode 25` + `Misc>Boot>HibernateMode=Auto` + `HibernationFixup.kext`.
Grava a RAM no disco e desliga; retoma em ~30 s. Nao depende de S3 nem de
resume de iGPU.

Cuidados que o upstream registra nesse caminho:

- hibernacao pode causar reset de CMOS ("Real-Time Clock power loss 005"):
  `RTCMemoryFixup` 1.0.7 com `rtcfx_exclude=80-AB` resolve o desligamento
  normal; `DisableRtcChecksum` (ja ligado aqui) tambem ajuda.
- o restore escreve a chave de hibernacao no RTC e pode repetir o 005.
- `hibernatefile` precisa caber no disco (40 GB de RAM -> arquivo grande).
- testar com a EFI do pendrive como fallback e um backup da config interna.

### Fase D — aceitar sem sleep (APLICADO 2026-11-20 23:25)

`sudo pmset -a sleep 0 disablesleep 1` para o notebook nunca dormir (fechar a
tampa deixa de travar). Reversivel com `sudo pmset -a sleep 10 disablesleep 0`.
Estado atual da maquina: EFI sem S0ix (rollback) e sleep desabilitado.

## Riscos e rollback

- Pendrive 1401 mantido no estado estavel (Wi-Fi + BT) e limpo de experimentos:
  e a via de boot se a EFI interna quebrar.
- EFI interna: backup `config.plist.bak-pres0ix-*` antes de cada mudanca.
- `-mtkbtoff` e `-mtkwlanoff` continuam como kill switches.
- Nao misturar mudancas: uma por boot, `ocvalidate` 1.0.8 antes de aplicar.

## Arquivos e comandos uteis

```
src/tools/sleep-test.sh        captura pre/pós sleep (sudo)
src/tools/dump-live-config.sh  copia config/ACPI/kexts da EFI interna
src/tools/push-live-config.sh  grava live-config.plist na EFI interna (backup)
src/tools/dump-esp-files.sh    copia logs do OpenCore da ESP
src/tools/verify-usb.sh        compara EFI do pendrive com a interna
src/tools/sync-usb-stable.sh   espelha a EFI interna no pendrive
src/tools/install-s0ix-internal.sh  instala S0ixStandby na EFI interna (backup)
src/tools/rollback-s0ix.sh          desfaz: restaura config e remove kext/AML
~/mtk/s0ix/s0ix-status.sh      status do Deep Idle
ssh mac                        acesso direto
```
