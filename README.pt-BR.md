# VivoBook 16X K3605ZF — macOS 26 (Tahoe) — EFI estável

[English](README.md) · **Português (BR)**

EFI/OpenCore de um ASUS VivoBook 16X **K3605ZF** rodando macOS 26.7.3, com
iGPU Intel funcionando (WhateverXe) e dGPU NVIDIA RTX 2050 com Metal via
driver NullMoth (instalado fora da EFI).

> **Antes de usar:** o SMBIOS deste repositório foi **sanitizado**. Gere o seu
> próprio serial/MLB/UUID com GenSMBIOS e coloque em `PlatformInfo > Generic`.
> Não use serial de terceiros.

## Máquina

```
ASUS VivoBook 16X K3605ZF
CPU    Intel Core i5-12450H (Alder Lake-P, 4P+4E)
iGPU   Intel UHD 48EU  8086:46A3
dGPU   NVIDIA GeForce RTX 2050 Laptop 4 GB  10DE:25A9 (GA107, Ampere)
RAM    40 GB DDR4      SSD NVMe 512 GB      Wi-Fi MediaTek MT7902 + BT
macOS  26.7.3 (Tahoe)  OpenCore 1.0.8
```

## O que funciona

- Boot, áudio (AppleALC), teclado/touchpad (VoodooPS2 + VoodooI2C), bateria
  (SMCBatteryManager), brilho, câmera, portas USB
- iGPU com aceleração Metal 2 (WhateverXe + pacote WhateverXe Graphics)
- Backlight do teclado: `F7` e `Fn+F7` ciclam off → 1 → 2 → 3 → off
  (AsusSMC patchado + `SSDT-ATKH` + `tools/asuskeys`, ver `docs/BACKLIGHT.md`)
- Wi-Fi e Bluetooth clássico MediaTek MT7902 com os kexts deste repositório
  (BLE HID tem limitação conhecida, ver abaixo)
- dGPU NVIDIA RTX 2050 com Metal 4 e compute (driver NullMoth 3.0, fora da EFI)

## O que não funciona (limitações conhecidas)

- **Sleep/S3**: o firmware entra em S3 e não retoma (trava duro). Sleep está
  desabilitado (`pmset -a sleep 0 disablesleep 1`). Ver `docs/PLANO-SLEEP.md`.
- **HDMI externo em monitor 2K**: cores corrompidas. Bug aberto do WhateverXe
  (issues #120 e #155); reproduzido em 1440p60 e 1080p60.
- **165 Hz**: impossível nesta máquina — o notebook não tem DisplayPort (USB-C
  é só USB 3.2 Gen 1 + PD) e o monitor só faz 165 Hz por DP.
- **dGPU não dirige display**: painel interno e HDMI estão ligados ao iGPU, sem
  mux. A RTX 2050 serve para compute Metal.
- **BLE HID (mouse/teclado Bluetooth)**: depois da primeira reconexão o link
  sobe e o GATT assina, mas nenhum report HID chega; só reboot restaura. Use o
  dongle 2.4 GHz do mouse ou um dongle USB Broadcom. Ver
  `docs/BLUETOOTH-MT7902.md`.
- USB-C 3.0 não validado.

## Estrutura

```
EFI/OC/config.plist     configuração do OpenCore (SMBIOS sanitizado)
EFI/OC/ACPI/            SSDTs (PLUG-ALT, EC-USBX, PNLF, USB-Reset, MCHC, SBUS, HPET, ATKH)
EFI/OC/Kexts/           kexts (ver lista abaixo)
EFI/OC/Drivers/         OpenRuntime, OpenHfsPlus, OpenCanopy, ResetNvramEntry
EFI/OC/OpenCore.efi     OpenCore 1.0.8 (REL-108-2026-09-27)
patches/                patches de código-fonte (backlight do AsusSMC)
tools/                  scripts de manutenção (backup, sync, rollback, boot-args)
tools/asuskeys/         daemon da linha F, CLI asusbl, hook do backlight
docs/                   planos e relatórios desta máquina
```

## Kexts habilitados

| Kext | Papel |
|---|---|
| Lilu | base para os plugins |
| VirtualSMC, SMCProcessor, SMCSuperIO, SMCBatteryManager | SMC, sensores, bateria |
| WhateverXe | aceleração da iGPU Intel (ADL-P) |
| AMFIPass | permite kexts não assinados |
| CpuTscSync, CpuTopologyRebuild | TSC e topologia híbrida P/E |
| RestrictEvents | esconde avisos de hardware |
| AsusSMC, BrightnessKeys | EC/brilho ASUS/backlight do teclado (patchado) |
| VoodooI2C (+Services, GPIO), VoodooI2CHID | touchpad I2C |
| VoodooPS2Controller (+Input, Keyboard, Mouse, Trackpad) | teclado PS/2 |
| AppleALC, SimpleHDA | áudio |
| XHCI-unsupported | quirk de XHCI |
| HoRNDIS | tethering USB |
| AirportMtkWlan | Wi-Fi MediaTek MT7902 |
| AirportMtkBtFw, AirportMtkBtPatcher, BlueToolFixup | Bluetooth MT7902 |
| SimpleMtkWlan | alternativa de Wi-Fi (desabilitado) |

## Backlight do teclado

`F7` e `Fn+F7` ciclam o backlight: off → 1 → 2 → 3 → off. Precisa do
`SSDT-ATKH.aml`, dos dois patches ACPI no `config.plist`, do `AsusSMC.kext`
patchado e do daemon em `tools/asuskeys` (keycode 98 → `asusbl`).
Detalhes, build e rollback: `docs/BACKLIGHT.md`.

## Bluetooth

Mantenha o `AirportMtkBt` **2.2.1**: o 2.2.2 removeu o firmware MT7902 e a
personality `13D3:3579`, então atualizar só os kexts de Bluetooth desliga o
rádio. BLE HID (mouse/teclado) para de entregar reports depois da primeira
reconexão; workaround é dongle 2.4 GHz. Evidências:
`docs/BLUETOOTH-MT7902.md`.

## Boot-args

```
-v debug=0x100 keepsyms=1 -allow3d -disablegfxfirmware -igfxdvmt
ctrsmt=full revpatch=sbvmm alcid=11 -vi2c-force-polling
TSC_sync_margin=0 -wex-adlp-allow-vcs2
nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
```

Os argumentos `nvfb*`, `amfi*` e `ipc_control_port_options` são do driver
NVIDIA (NullMoth). `csr-active-config = 0x0A43`.

**Atenção:** `amfi_get_out_of_my_way=0x1` desliga a checagem de assinatura de
kexts no sistema inteiro. Sem isso o driver NVIDIA não carrega. Se você não
quer o driver, remova esses argumentos e volte `csr` para `0x0A03`.

## BIOS

- Above 4G Decoding: **Enabled**
- CSM: **Disabled**
- Secure Boot: **Disabled**

## dGPU (opcional)

O driver é o [NullMoth](https://github.com/nullmoth/nvidia-macos-driver)
(release v3.0), instalado pelo app 1401 em `/Library`, **não** pela EFI.
A dGPU é habilitada removendo `disable-gpu` de `DeviceProperties` e
desabilitando `SSDT-dGPU-Off.aml` (script `tools/enable-dgpu.sh`).
Rollback: entrada "1401: Remove NVIDIA driver" no picker do OpenCore.

## Créditos

OpenCore (Acidanthera), Lilu/VirtualSMC/AppleALC/WhateverGreen (Acidanthera),
WhateverXe (b00t0x), VoodooI2C/VoodooPS2, AsusSMC, NullMoth (NullMoth
Systems). Cada kext mantém a licença do seu autor.
