ScriptName RX_VendingMachineScript_GOE Extends RX_VendingMachineScript
{ROCKHARD - Garden of Eden variant of the ammo vending machine.

REQUIRES Garden of Eden Papyrus Script Extender (LarannKiar, F4SE plugin).

Use this instead of RX_VendingMachineScript if you want the machine to respect
weapon mods that change a weapon's ammo type. Everything else - pricing,
dispensing, properties, setup - is inherited unchanged. Attach this in place of
the base script and fill the same properties.

Preferred over RX_VendingMachineScript_F4SE: one native call, no struct type and
no equip-slot magic number, and the signature is verified against GOE's own
source rather than taken on trust.}

; Overrides the vanilla base-form lookup.
; GardenOfEden.psc: Ammo Function GetEquippedWeaponAmmo(Actor akActor) native global
;   "returns the Ammo of this actor's equipped weapon"
Ammo Function GetTargetAmmo()
	Return GardenOfEden.GetEquippedWeaponAmmo(PlayerRef)
EndFunction
