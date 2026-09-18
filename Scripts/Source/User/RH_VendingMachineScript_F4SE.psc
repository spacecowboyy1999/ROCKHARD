ScriptName RH_VendingMachineScript_F4SE Extends RH_VendingMachineScript
{ROCKHARD - F4SE variant of the ammo vending machine.

REQUIRES F4SE's script sources. Prefer RH_VendingMachineScript_GOE over this
one - it does the same job in a single verified call.

Use this only if you want the machine to respect weapon mods that change a
weapon's ammo type and you'd rather depend on F4SE than on Garden of Eden - a pipe gun
converted from .45 to .38 vends .38 here, where the vanilla script vends .45.

Everything else (pricing, dispensing, properties, setup) is inherited from
RH_VendingMachineScript unchanged. Attach this in its place and fill the same
properties.

InstanceData / GetInstanceOwner are NOT in the vanilla Creation Kit sources, and
they are NOT in Garden of Eden's either - both were searched. They ship with
F4SE's own script set, so this file needs that on your import path to compile.

UNVERIFIED: the two signatures below are carried over verbatim from the AAV
original rather than checked against F4SE's sources, which aren't on hand.
They presumably compile, since the original mod shipped with them.}

int Property iWeaponSlotIndex = 41 Auto Const
{Instance-owner slot for the equipped weapon. 41 is the standard weapon slot.}

; Overrides the vanilla base-form lookup with the instanced one.
Ammo Function GetTargetAmmo()
	InstanceData:Owner InstanceWeapon = PlayerRef.GetInstanceOwner(iWeaponSlotIndex)
	Return InstanceData.GetAmmo(InstanceWeapon)
EndFunction
