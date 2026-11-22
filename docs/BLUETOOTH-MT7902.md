# Bluetooth MT7902 — estado e limitação BLE HID

Máquina: ASUS VivoBook 16X K3605ZF, macOS 26.7.3 (Tahoe).
Controlador: MediaTek MT7902, USB `13D3:3579`, transporte USB.

## O que funciona

- Firmware carrega (`AirportMtkBtFw` + `AirportMtkBtPatcher` + `BlueToolFixup`).
- Bluetooth clássico: A2DP/HFP (fones), teclado clássico.
- Pareamento BLE e reconexão de link.

## NVRAM necessário

`config.plist → NVRAM → Add`, GUID `7C436110-AB2A-4BBB-A880-FE41995C9F82`
(repita as chaves em `NVRAM → Delete` para o OpenCore reescrever a cada boot):

| Chave | Valor |
|---|---|
| `bluetoothExternalDongleFailed` | `00` |
| `bluetoothInternalControllerInfo` | 14 bytes `00` |

Sem elas o `bluetoothd` trata o MT7902 como módulo interno Broadcom e envia
comandos que o chip não entende.

## O que não funciona

**BLE HID (mouse/teclado BLE) para de entregar reports depois da primeira
reconexão.**

Sequência observada:

1. Boot. O mouse BLE conecta e funciona.
2. O mouse dorme/desconecta (`LE Link disconnected ... reason 708`).
3. Reconecta: link sobe, `HID Service detected`, `Subscribing to updates of
   characteristic handle 0x003b` — mas **nenhum report chega**.
4. Só um reboot (recarrega o firmware) restaura. Toggle de Bluetooth,
   `blueutil -p 0/1` e reconexão não resolvem.

Evidência:

```
bluetoothd: addScanFilterByUUID failed 0x1812     (loop ~20 s)
bluetoothd: Device <private> does not have _HID_SERVICE_
ioreg AppleUserHIDEventService -> LastActivityTimestamp não muda
ioreg IOHIDInterface -> ReportAvailableCalls = 0
```

Causa provável: o firmware MediaTek não envia `LE PHY Update Complete` /
`LE Data Length Change`, e o `bluetoothd` do Tahoe espera esses eventos antes
de concluir o HID over GATT. Mesmo problema relatado para Intel
(`IntelBluetoothFirmware` PR #446) e MediaTek (`SimpleMtkBtFw` issue #2).

## Versões — não atualize o Bluetooth

- **`AirportMtkWlan` / `AirportMtkBt` 2.2.1**: última versão com firmware
  `BT_RAM_CODE_MT7902_1_1_hdr.bin` e personality `13D3:3579`.
- **2.2.2** (21/11/2026): removeu o firmware MT7902 **e** a personality
  `13D3:3579`. Atualizar só o pacote de Bluetooth desliga o rádio.
- **`SimpleMtkBtFw`** (laobamac/upstream): só MT7921 (`0x7961`) e MT7922
  (`0x7922`). Não carrega no MT7902.

## Tentativa que falhou (registro)

Fork `SimpleMtkBtFw` PR #3 (`-smbtlefix`, eventos LE sintéticos) adaptado
para MT7902: firmware do `linux-firmware`, `case 0x7902` no `setupUsb`,
personality `13d3:3579`. O controlador subiu e os dois dispositivos BLE
conectaram, mas:

- teclado BLE nunca registrou `_HID_SERVICE_`;
- mouse criou `IOHIDUserDevice` e não entregou reports;
- `blueutil -p 0` passou a dar timeout (`Failed to switch bluetooth power
  off in 10 seconds`).

Resultado pior que o estado original. Revertido. Não repita sem uma correção
real no fluxo WMT/firmware.

## Recuperação sem reboot (verificado)

Reiniciar o `bluetoothd` recria o HID shim e o mouse volta a entregar reports:

```sh
tools/bt-recover.sh
```

Medido em 2026-11-22: queda às 18:04:54 (`reason 719`), reconexão às 18:05:51
sem HID; `launchctl kickstart -k system/com.apple.bluetoothd` recriou o
`IOHIDUserDevice` e o contador foi de 141 para 421 eventos.

O script pede senha de admin (diálogo do macOS). Não recarrega firmware: o
estado quebrado está no `bluetoothd`, não no chip — por isso o toggle de
Bluetooth não resolve, mas o restart do daemon sim.

## Workaround

- **Mouse**: use o receptor 2.4 GHz (dongle USB). Zero kext, imune ao bug.
- **Alternativa**: dongle USB Bluetooth com chipset Broadcom BCM20702
  (suporte nativo no macOS, sem kext).
- Teclado e áudio Bluetooth continuam utilizáveis.

## Verificação

```sh
system_profiler SPBluetoothDataType | head -12
ioreg -rc AirportMtkBtFw -l -w0 | grep '"fw_name"'
ioreg -c AppleUserHIDEventService -r -l -w0 | grep -A2 'X6 Mouse1'
```

Se `fw_name` não for `BT_RAM_CODE_MT7902_1_1_hdr.bin`, o kext errado está na
EFI. Se `LastActivityTimestamp` não muda com o mouse em uso, é o bug acima.

## Referências

- `flxxxxddd/SimpleMtkBtFw` — issue #2, PR #3
- `OpenIntelWireless/IntelBluetoothFirmware` — PR #446
- `linux-firmware` — `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`
