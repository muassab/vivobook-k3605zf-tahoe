# Plano — dGPU (NVIDIA RTX 2050 Laptop) no macOS 26 — resultado e limites

Sessão de referência: 2026-11-21 00:15. Estado: **driver instalado e
funcionando para Metal; nenhum display na dGPU; HDMI é do iGPU.**

## Máquina

```
ASUS VivoBook 16X K3605ZF   i5-12450H   macOS 26.7.3   OpenCore 1.0.8
iGPU  Intel UHD 0x46A3  WhateverXe 0.8.2 + AppleIntelTGL* (pkg 0.4.x)
dGPU  NVIDIA RTX 2050 Laptop 4 GB  10DE:25A9 (GA107, Ampere)
      \_SB.PC00.PEG1.PEGP   PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)
```

Portas: HDMI 2.1 TMDS (única saída de vídeo) + USB-C 3.2 Gen 1 **sem
DisplayPort Alt Mode**. Não existe DP nesta máquina.

## O que foi feito

1. dGPU habilitada: `disable-gpu` removido de DeviceProperties e
   `SSDT-dGPU-Off.aml` desabilitado (`src/tools/enable-dgpu.sh`).
2. Driver **NullMoth 3.0** instalado pelo app 1401:
   `csr-active-config` 0x0A03 -> 0x0A43, boot-args
   `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1
   amfi=0x80 ipc_control_port_options=0`, entradas de picker
   "1401: Remove NVIDIA driver" e "1401: Start once without NVIDIA driver".

## Resultado medido

```
kmutil: com.nullmoth.NVRM/NVAccel/NVRMFB/NVRMAGDC (3.0) + NMXAudio carregados
system_profiler: NVIDIA GeForce RTX 2050, 4 GB, Metal 4
MTLCopyAllDevices: 2 devices
  Intel(R) TGL              lowPower=true   headless=false
  NVIDIA GeForce RTX 2050   lowPower=false  headless=false  (NVMTL over NVK GA107-A)
sem panic
```

**Objetivo (b) — Metal na dGPU: atendido.**

## O que não era o que parecia

`NVRMNVDAFramebuffer` tem **0 displays**; `AppleIntelFramebuffer` tem **2**
(painel interno + Odyssey G5). O HDMI está ligado no **iGPU**. Portanto:

- Objetivo (a) "HDMI funcionar" **nunca dependeu da dGPU** — sempre foi o iGPU.
- Cor errada e refresh baixo no monitor externo são do **WhateverXe**, não do
  NullMoth. `nvfbformat/nvfbrange/nvfbbpc` (que existem no driver NVIDIA)
  afetam só cabeças NVIDIA, e não há nenhuma.

## Cor errada no HDMI externo (bug aberto do WhateverXe)

Sintoma: 2560x1440@60, imagem tipo "nightvision", conteúdo do painel interno
correto. Link em 241,5 MHz (CVT padrão de 1440p60), sem indício de 10-bit.

Issues abertas do projeto com o mesmo quadro:

- **#120** "Tiger Lake-H35 0x9A49: external HDMI display lights but colours are
  corrupted (pixel-format mismatch), 2K monitors only" — reproduzido em dois
  monitores 2K, três cabos, todos os modos; **um monitor 1080p funciona**.
  Hipótese: formato de pixel/bit-depth do DDI externo herdado do pipe interno.
- **#155** "Native HDMI output corrupted on Tiger Lake combo-PHY (USB-C DP
  works)".
- **#41** "ADL-S UHD 770: native HDMI 300MHz timing limit blocks 4K60/HiDPI60".

Não há workaround no build stock: o `-wex-force-ext-8bpc` citado nos
comentários só existe num build instrumentado do reporter, não no 0.8.2.

Teste feito nesta máquina (2026-11-21): com o mesmo monitor em
**1920x1080@60** a corrupção continua igual (`CGDisplaySetDisplayMode`, err 0
nos dois modos). Ou seja, é independente do timing — segue o EDID/monitor,
exatamente como no #120. Texto pronto para comentar no issue:
`REPORT-WEX-120.md`.

## 165 Hz / 144 Hz no Odyssey G5

- O monitor (S27AG50 / C27G5xT) atinge **165 Hz só por DisplayPort**; por
  **HDMI 2.0 o máximo é 144 Hz** (e 60 Hz em 10-bit).
- Esta máquina **não tem DisplayPort** (USB-C é só USB 3.2 Gen 1 + PD).
- Além disso o WhateverXe tem limite de clock de timing no HDMI nativo
  (~300 MHz, issue #41). 1440p60 = 241,5 MHz; 1440p120 ~497 MHz;
  1440p144 ~586 MHz; 1440p165 ~660 MHz — todos acima do limite.

Conclusão: **165 Hz é impossível nesta máquina**, por dois motivos
independentes (sem porta DP e limite de timing do driver). 1440p@120/144
também não é alcançável hoje.

## Uso dinâmico: o que dá e o que não dá (medido 2026-11-21)

- **Trocar o display dinamicamente: impossível.** Painel e HDMI são ligados ao
  iGPU; não há mux. O modo híbrido (`nmhybrid=1` + `NMIntelFB` 2.9) carregou
  mas **não assumiu o painel**: `NMIntelFB` fez probe ("8086:46a3 display
  version 13"), `NVAccel` ficou "watching for an Intel built-in panel", e o
  painel continuou em `AppleIntelFramebuffer`. Causa provável: conflito com o
  pacote **WhateverXe Graphics**, que já é dono do eDP.
- **Navegador na dGPU: não.** Com `/Library/GPUBundles/nvmtl-gpu-policy.txt`
  forçando `nvidia Safari` e o Safari reaberto, o WebGL renderer continuou
  Intel. O WebKit fica preso na GPU dona do display.
- **Compute Metal na dGPU: sim, verificado.** `gpu-compute-test.swift` roda um
  kernel `addone` na RTX 2050 e confere 1024 elementos = 1.0, sem erro. Apps
  que enumeram devices (Blender, ML, CLI) podem usar a placa.
- **Por AC/bateria**: só faz sentido para energia (D3cold, `nvrtd3=1` +
  `nvrtd3res=<ACPI>`), não para acelerar interface. O scan do 1401 não
  reportou candidato de ACPI para o power resource.

## Decisões pendentes

1. **Manter o NullMoth?** Ele entrega Metal na dGPU mas nenhum display. Custo:
   AMFI desligado e SIP 0x0A43 no sistema inteiro.
   - Manter se houver uso de compute/Metal (Blender, ML, jogos via Metal).
   - Remover com a entrada "1401: Remove NVIDIA driver" no picker se o ganho
     não justificar a perda de segurança.
2. **Reportar a máquina ao upstream** (issue #120): temos os dados exatos
   (ADL-P 0x46A3, WEX 0.8.2, Odyssey G5 1440p, clock 241,5 MHz, cores
   corrompidas). É o caminho para esse bug ser corrigido.
3. **Monitor externo hoje**: usar um painel 1080p (relato diz que funciona) ou
   aceitar 1440p60 com cor errada até o fix.

## Rollback

```
"1401: Remove NVIDIA driver" no picker     desfaz driver + config
sudo ./uninstall.sh (pkgroot)              remove arquivos do driver
sudo sh ~/mtk/restore-efi-config.sh pre-dgpu   volta config + dGPU desligada
```

## Scripts desta frente

```
src/tools/backup-efi.sh          backup completo da EFI/OC
src/tools/enable-dgpu.sh         habilita a dGPU (DeviceProperties + ACPI)
src/tools/restore-efi-config.sh  restaura config de um backup
src/tools/add-bootarg.sh         adiciona/substitui boot-args com backup
src/tools/nullmoth-oc-prep.sh    prep manual de OpenCore para o NullMoth
```
