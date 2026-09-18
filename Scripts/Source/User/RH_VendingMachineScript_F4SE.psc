ScriptName RH_VendingMachineScript_F4SE Extends RH_VendingMachineScript
{ROCKHARD - F4SE variant of the ammo vending machine.

REQUIRES F4SE. Use this instead of RH_VendingMachineScript only if you want the
machine to respect weapon mods that change a weapon's ammo type - a pipe gun
converted from .45 to .38 vends .38 here, where the vanilla script vends .45.

Everything else (pricing, dispensing, properties, setup) is inherited from
RH_VendingMachineScript unchanged. Attach this in its place and fill the same
properties.

InstanceData / GetInstanceOwner are NOT in the vanilla Creation Kit sources -
they come from the extender, so this file will not compile without it on your
import path. That's the whole reason it's split out.}

int Property iWeaponSlotIndex = 41 Auto Const
{Instance-owner slot for the equipped weapon. 41 is the standard weapon slot.}

; Overrides the vanilla base-form lookup with the instanced one.
Ammo Function GetTargetAmmo()
	InstanceData:Owner InstanceWeapon = PlayerRef.GetInstanceOwner(iWeaponSlotIndex)
	Return InstanceData.GetAmmo(InstanceWeapon)
EndFunction
