# VivoBook 16X K3605ZF — macOS 26 (Tahoe) — working EFI

**English** · [Português (BR)](README.pt-BR.md)

OpenCore EFI for an ASUS VivoBook 16X **K3605ZF** running macOS 26.7.3, with
the Intel iGPU working (WhateverXe) and the NVIDIA RTX 2050 exposed to Metal
through the NullMoth driver (installed outside the EFI).

> **Before you use it:** the SMBIOS in this repository is **sanitized**.
> Generate your own serial/MLB/UUID with GenSMBIOS and put them in
> `PlatformInfo > Generic`. Do not use someone else's serial.

## Machine

```
ASUS VivoBook 16X K3605ZF
CPU    Intel Core i5-12450H (Alder Lake-P, 4P+4E)
iGPU   Intel UHD 48EU  8086:46A3
dGPU   NVIDIA GeForce RTX 2050 Laptop 4 GB  10DE:25A9 (GA107, Ampere)
RAM    40 GB DDR4      NVMe SSD 512 GB      Wi-Fi MediaTek MT7902 + BT
macOS  26.7.3 (Tahoe)  OpenCore 1.0.8
```

## What works

- Boot, audio (AppleALC), keyboard/touchpad (VoodooPS2 + VoodooI2C), battery
  (SMCBatteryManager), brightness, camera, USB ports
- iGPU with Metal 2 acceleration (WhateverXe + WhateverXe Graphics package)
- Keyboard backlight: `F7` and `Fn+F7` cycle off → 1 → 2 → 3 → off
  (patched AsusSMC + `SSDT-ATKH` + `tools/asuskeys`, see `docs/BACKLIGHT.md`)
- MediaTek MT7902 Wi-Fi and Bluetooth classic with the kexts in this
  repository (BLE HID has a known limit, see below)
- NVIDIA RTX 2050 with Metal 4 and compute (NullMoth 3.0 driver, outside the EFI)

## What does not work (known limits)

- **Sleep/S3**: the firmware enters S3 and never resumes (hard hang). Sleep is
  disabled (`pmset -a sleep 0 disablesleep 1`). See `docs/PLANO-SLEEP.md`.
- **HDMI on a 2K monitor**: corrupted colours. Open WhateverXe bug (issues
  #120 and #155); reproduced at 1440p60 and 1080p60.
- **165 Hz**: impossible on this machine — the laptop has no DisplayPort (its
  USB-C is USB 3.2 Gen 1 + PD only) and the monitor only reaches 165 Hz over DP.
- **The dGPU drives no display**: the internal panel and HDMI are wired to the
  iGPU, with no mux. The RTX 2050 is useful for Metal compute only.
- **BLE HID (Bluetooth mouse/keyboard)**: after the first reconnect the link
  comes up and GATT subscribes, but no HID reports arrive; only a reboot
  restores it. Use the mouse's 2.4 GHz dongle or a Broadcom USB dongle.
  See `docs/BLUETOOTH-MT7902.md`.
- USB-C 3.0 not validated.

## Layout

```
EFI/OC/config.plist     OpenCore configuration (SMBIOS sanitized)
EFI/OC/ACPI/            SSDTs (PLUG-ALT, EC-USBX, PNLF, USB-Reset, MCHC, SBUS, HPET, ATKH)
EFI/OC/Kexts/           kexts (see list below)
EFI/OC/Drivers/         OpenRuntime, OpenHfsPlus, OpenCanopy, ResetNvramEntry
EFI/OC/OpenCore.efi     OpenCore 1.0.8 (REL-108-2026-09-27)
patches/                source patches (AsusSMC keyboard backlight)
tools/                  maintenance scripts (backup, sync, rollback, boot-args)
tools/asuskeys/         F-row daemon, asusbl CLI, backlight hook
docs/                   plans and reports for this machine
```

## Enabled kexts

| Kext | Role |
|---|---|
| Lilu | base for the plugins |
| VirtualSMC, SMCProcessor, SMCSuperIO, SMCBatteryManager | SMC, sensors, battery |
| WhateverXe | Intel iGPU acceleration (ADL-P) |
| AMFIPass | allows unsigned kexts |
| CpuTscSync, CpuTopologyRebuild | TSC and hybrid P/E topology |
| RestrictEvents | hides hardware notices |
| AsusSMC, BrightnessKeys | ASUS EC / brightness / keyboard backlight (patched) |
| VoodooI2C (+Services, GPIO), VoodooI2CHID | I2C touchpad |
| VoodooPS2Controller (+Input, Keyboard, Mouse, Trackpad) | PS/2 keyboard |
| AppleALC, SimpleHDA | audio |
| XHCI-unsupported | XHCI quirk |
| HoRNDIS | USB tethering |
| AirportMtkWlan | MediaTek MT7902 Wi-Fi |
| AirportMtkBtFw, AirportMtkBtPatcher, BlueToolFixup | MT7902 Bluetooth |
| SimpleMtkWlan | alternative Wi-Fi driver (disabled) |

## Keyboard backlight

`F7` and `Fn+F7` cycle the keyboard backlight: off → 1 → 2 → 3 → off.
Needs `SSDT-ATKH.aml`, the two ACPI patches in `config.plist`, the patched
`AsusSMC.kext` and the `tools/asuskeys` daemon (keycode 98 → `asusbl`).
Full write-up, build and rollback: `docs/BACKLIGHT.md`.

## Bluetooth

Keep `AirportMtkBt` **2.2.1**: 2.2.2 dropped the MT7902 firmware and the
`13D3:3579` personality, so updating the Bluetooth kexts alone disables the
radio. BLE HID (mouse/keyboard) stops delivering reports after the first
reconnect; `tools/bt-recover.sh` restarts `bluetoothd` and brings it back
without a reboot. Permanent workaround: a 2.4 GHz dongle. Details and
evidence: `docs/BLUETOOTH-MT7902.md`.

## Boot arguments

```
-v debug=0x100 keepsyms=1 -allow3d -disablegfxfirmware -igfxdvmt
ctrsmt=full revpatch=sbvmm alcid=11 -vi2c-force-polling
TSC_sync_margin=0 -wex-adlp-allow-vcs2
nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
```

The `nvfb*`, `amfi*` and `ipc_control_port_options` arguments belong to the
NVIDIA driver (NullMoth). `csr-active-config = 0x0A43`.

**Warning:** `amfi_get_out_of_my_way=0x1` disables kext code-signing
enforcement system-wide. Without it the NVIDIA driver does not load. If you do
not want the driver, remove those arguments and set `csr` back to `0x0A03`.

## BIOS

- Above 4G Decoding: **Enabled**
- CSM: **Disabled**
- Secure Boot: **Disabled**

## dGPU (optional)

The driver is [NullMoth](https://github.com/nullmoth/nvidia-macos-driver)
(release v3.0), installed by the 1401 app into `/Library`, **not** through the
EFI. The dGPU is enabled by removing `disable-gpu` from `DeviceProperties` and
disabling `SSDT-dGPU-Off.aml` (`tools/enable-dgpu.sh`).
Rollback: the "1401: Remove NVIDIA driver" entry in the OpenCore picker.

## Credits

OpenCore (Acidanthera), Lilu/VirtualSMC/AppleALC/WhateverGreen (Acidanthera),
WhateverXe (b00t0x), VoodooI2C/VoodooPS2, AsusSMC, NullMoth (NullMoth
Systems). Every kext keeps its author's licence.
