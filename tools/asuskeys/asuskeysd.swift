import Foundation
import AppKit
import CoreGraphics
import CoreAudio
import IOKit
import IOKit.graphics

// asuskeysd - F-row action keys for ASUS Vivobook K3605ZF on macOS
// F1/F2/F3 are handled natively by macOS (mute, vol-, vol+).
// F4..F12 arrive as plain function keys and are consumed here.

let logURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/asuskeysd.log")
let hookDir = NSHomeDirectory() + "/.config/asuskeys"

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "\(ts) \(msg)\n"
    if let fh = try? FileHandle(forWritingTo: logURL) {
        fh.seekToEndOfFile()
        fh.write(line.data(using: .utf8)!)
        try? fh.close()
    } else {
        try? line.data(using: .utf8)!.write(to: logURL)
    }
}

func runHook(_ name: String) {
    let path = hookDir + "/" + name
    guard FileManager.default.isExecutableFile(atPath: path) else {
        log("hook missing: \(path)")
        return
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    do { try p.run() } catch { log("hook failed \(name): \(error)") }
}

// MARK: - brightness

func displayService() -> io_service_t {
    IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleBacklightDisplay"))
}

func brightnessStep(_ delta: Float) {
    let svc = displayService()
    guard svc != 0 else { log("brightness: no display service"); return }
    var cur: Float = 0.5
    IODisplayGetFloatParameter(svc, 0, kIODisplayBrightnessKey as CFString, &cur)
    var next = cur + delta
    if next < 0 { next = 0 }
    if next > 1 { next = 1 }
    let r = IODisplaySetFloatParameter(svc, 0, kIODisplayBrightnessKey as CFString, next)
    log("brightness \(cur) -> \(next) ret=0x\(String(r, radix: 16))")
}

// MARK: - display mirroring

func toggleDisplayMode() {
    var online = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    CGGetOnlineDisplayList(16, &online, &count)
    let main = CGMainDisplayID()
    let others = (0..<Int(count)).map { online[$0] }.filter { $0 != main && CGDisplayIsBuiltin($0) == 0 }
    guard let ext = others.first else {
        log("display: no external display, opening Displays settings")
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!)
        return
    }
    var cfg: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&cfg)
    if CGDisplayMirrorsDisplay(ext) == kCGNullDirectDisplay {
        CGConfigureDisplayMirrorOfDisplay(cfg, ext, main)
        log("display: mirror on \(ext) -> \(main)")
    } else {
        CGConfigureDisplayMirrorOfDisplay(cfg, ext, kCGNullDirectDisplay)
        log("display: extend \(ext)")
    }
    CGCompleteDisplayConfiguration(cfg, .permanently)
}

// MARK: - microphone mute

func toggleMicMute() {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var dev = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let st = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
    guard st == noErr, dev != 0 else { log("mic: no default input device"); return }

    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    var mute = UInt32(0)
    var msize = UInt32(MemoryLayout<UInt32>.size)
    if AudioObjectGetPropertyData(dev, &muteAddr, 0, nil, &msize, &mute) == noErr {
        var next = mute == 0 ? UInt32(1) : UInt32(0)
        let r = AudioObjectSetPropertyData(dev, &muteAddr, 0, nil, msize, &next)
        log("mic mute \(mute) -> \(next) ret=\(r)")
        return
    }
    log("mic: mute property unsupported")
}

// MARK: - actions

func action(for keyCode: Int64) -> String? {
    switch keyCode {
    case 118: return "brightness-down"
    case 96:  return "brightness-up"
    case 97:  return "touchpad"
    case 98:  return "kbd-backlight"
    case 100: return "display"
    case 101: return "mic"
    case 103: return "screenshot"
    case 111: return "myasus"
    default:  return nil
    }
}

func perform(_ name: String) {
    log("action \(name)")
    switch name {
    case "brightness-down": brightnessStep(-0.0625)
    case "brightness-up":   brightnessStep(0.0625)
    case "display":         toggleDisplayMode()
    case "mic":             toggleMicMute()
    case "screenshot":
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"),
                                           configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    case "myasus":
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
    case "touchpad":        runHook("touchpad.sh")
    case "kbd-backlight":   runHook("kbd-backlight.sh")
    default: break
    }
}

// MARK: - event tap

var swallowed = Set<Int64>()
var held = Set<Int64>()
var activeTap: CFMachPort?

func startTap() -> Bool {
    let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                swallowed.removeAll()
                held.removeAll()
                if let t = activeTap { CGEvent.tapEnable(tap: t, enable: true) }
                log("tap re-enabled after \(type == .tapDisabledByTimeout ? "timeout" : "user input")")
                return Unmanaged.passUnretained(event)
            }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let hasModifier = flags.contains(.maskCommand) || flags.contains(.maskControl) ||
                              flags.contains(.maskAlternate) || flags.contains(.maskShift)
            // Fn+F7 is handled by AsusSMC through the EC query; swallow the raw event
            // so the backlight is not stepped twice.
            if code == 98 && flags.contains(.maskSecondaryFn) {
                return nil
            }
            guard !hasModifier, let name = action(for: code) else {
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown {
                if held.contains(code) { return nil }
                held.insert(code)
                swallowed.insert(code)
                DispatchQueue.main.async { perform(name) }
                return nil
            }
            if type == .keyUp {
                held.remove(code)
                if swallowed.remove(code) != nil { return nil }
            }
            return Unmanaged.passUnretained(event)
        },
        userInfo: nil) else { return false }

    activeTap = tap
    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
}

log("start")
if !startTap() {
    log("event tap denied - grant Accessibility permission")
    FileHandle.standardError.write("event tap denied\n".data(using: .utf8)!)
    exit(2)
}
log("tap ready")
RunLoop.current.run()
