DefinitionBlock ("", "SSDT", 2, "ASUS", "ATKH", 0x00000005)
{
    External (_SB_.ATKD, DeviceObj)
    External (_SB_.PC00.LPCB.EC0_.KBBN, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBBS, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBSP, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBMC, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBS1, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBS2, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBS3, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBLM, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.KBLT, FieldUnitObj)
    External (KBLC, FieldUnitObj)
    External (KBBF, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.ECDP, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.ECCP, FieldUnitObj)
    External (_SB_.PC00.LPCB.EC0_.MUT0, MutexObj)
    External (_SB_.PC00.LPCB.EC0_.IRDY, MethodObj)

    Scope (\_SB)
    {
        Name (XTKP, One)
    }

    Scope (\_SB_.ATKD)
    {
        OperationRegion (KBRG, SystemMemory, 0xFE108B00, 0x0100)
        Field (KBRG, AnyAcc, NoLock, Preserve)
        {
            Offset (0x5B), 
            KB5B,   8, 
            Offset (0xA5), 
            KBLA,   8
        }

        Method (SKBA, 1, NotSerialized)
        {
            KBLA = Arg0
            Return (Arg0)
        }

        Method (GKBA, 0, NotSerialized) { Return (KBLA) }

        Method (EWRB, 2, Serialized)
        {
            Acquire (\_SB.PC00.LPCB.EC0.MUT0, 0x2000)
            \_SB.PC00.LPCB.EC0.IRDY ()
            \_SB.PC00.LPCB.EC0.ECCP = 0x81
            \_SB.PC00.LPCB.EC0.IRDY ()
            \_SB.PC00.LPCB.EC0.ECDP = Arg0
            \_SB.PC00.LPCB.EC0.IRDY ()
            \_SB.PC00.LPCB.EC0.ECDP = Arg1
            Release (\_SB.PC00.LPCB.EC0.MUT0)
            Return (Arg1)
        }

        Method (ERDB, 1, Serialized)
        {
            Local0 = 0xFF
            Acquire (\_SB.PC00.LPCB.EC0.MUT0, 0x2000)
            \_SB.PC00.LPCB.EC0.IRDY ()
            \_SB.PC00.LPCB.EC0.ECCP = 0x80
            \_SB.PC00.LPCB.EC0.IRDY ()
            \_SB.PC00.LPCB.EC0.ECDP = Arg0
            \_SB.PC00.LPCB.EC0.IRDY ()
            Local0 = \_SB.PC00.LPCB.EC0.ECDP
            Release (\_SB.PC00.LPCB.EC0.MUT0)
            Return (Local0)
        }        Method (SK5B, 1, NotSerialized) { KB5B = Arg0; Return (Arg0) }
        Method (GK5B, 0, NotSerialized) { Return (KB5B) }

        Method (SKBB, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBBN = Arg0
            Return (Arg0)
        }

        Method (SKBS, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBBS = Arg0
            Return (Arg0)
        }

        Method (SKSP, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBSP = Arg0
            Return (Arg0)
        }

        Method (SKMC, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBMC = Arg0
            Return (Arg0)
        }

        Method (SKL1, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBS1 = Arg0
            Return (Arg0)
        }

        Method (SKL2, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBS2 = Arg0
            Return (Arg0)
        }

        Method (SKL3, 1, NotSerialized)
        {
            \_SB.PC00.LPCB.EC0.KBS3 = Arg0
            Return (Arg0)
        }

        Method (SKBC, 1, NotSerialized)
        {
            \KBLC = Arg0
            Return (Arg0)
        }

        Method (GKBC, 0, NotSerialized) { Return (\KBLC) }

        Method (GKBB, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBBN) }        Method (GKBS, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBBS) }
        Method (GKSP, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBSP) }
        Method (GKMC, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBMC) }
        Method (GKL1, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBS1) }
        Method (GKL2, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBS2) }
        Method (GKL3, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBS3) }
        Method (GKLM, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBLM) }
        Method (GKLT, 0, NotSerialized) { Return (\_SB.PC00.LPCB.EC0.KBLT) }
        Method (GKBF, 0, NotSerialized) { Return (\KBBF) }
    }
}
