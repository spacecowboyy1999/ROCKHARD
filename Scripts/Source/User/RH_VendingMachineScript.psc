ScriptName RH_VendingMachineScript Extends ObjectReference
{ROCKHARD - ammo vending machine.
Sells ammo for the weapon the player currently has equipped, priced off the
player's Charisma and Barter perks, and drops the rounds out of the machine.

Attach this to EITHER:
  a) the vending machine reference itself, if the machine is an Activator, or
  b) a small hidden Activator placed in front of the machine, with its
     Linked Ref pointing at the machine (see MachineRef resolution below).

This version is VANILLA ONLY - no script extender needed. It reads the ammo off
the equipped weapon's base form, so a weapon whose ammo type was changed by a
mod (a .38 receiver on a .45 pipe gun) vends the BASE ammo, not the converted
ammo. If that matters, use RH_VendingMachineScript_F4SE instead, which overrides
GetTargetAmmo() to read the instanced ammo.}

;------------------------------------------------------------------------------
; REQUIRED PROPERTIES
;------------------------------------------------------------------------------
Actor Property PlayerRef Auto Const Mandatory
{Point at the vanilla PlayerRef.}

MiscObject Property Caps001 Auto Const Mandatory
{Point at the vanilla Caps001.}

ActorValue Property Charisma Auto Const Mandatory
{Point at the vanilla Charisma actor value.}

;------------------------------------------------------------------------------
; OPTIONAL PROPERTIES - all of these are None-safe, fill in what you want
;------------------------------------------------------------------------------
Perk Property CapCollector01 Auto Const
Perk Property CapCollector02 Auto Const
Perk Property PerkBobbleheadBarter Auto Const

GlobalVariable Property RH_VendingAmmoPrice Auto Const
{Max caps the machine will take in one purchase. If left empty,
fFallbackMaxCaps is used instead.}

Sound Property RH_MachineSound01 Auto Const
{Vend / clunk sound. Plays on the machine.}

Keyword Property MachineLinkKeyword Auto Const
{Optional keyword for GetLinkedRef, if you use keyworded linked refs.}

Message Property RH_NoAmmoUseMsg Auto Const
{"You have no weapon equipped that uses ammo."}

Message Property RH_OverPriceMsg Auto Const
{Shown when a single round costs more than the machine accepts.
Needs one replacement token in the message text for the caps limit.}

Message Property RH_NoCapsMsg Auto Const
{"You can't afford a single round."}

Message Property RH_RemainCapsMsg Auto Const
{Shown once per load when the machine capped your spend.
Needs one replacement token in the message text for the leftover caps.}

Message Property RH_NoDropNodeMsg Auto Const
{Debug only. Shown if the drop node is missing and the offset fallback ran.}

;------------------------------------------------------------------------------
; TUNING
;------------------------------------------------------------------------------
string Property sDropNodeName = "AmmoDropNode" Auto Const
{NiNode on the machine's mesh that ammo spawns from. If your mesh has no such
node, leave this as-is and the script falls back to the fDropOffset values.}

float Property fFallbackMaxCaps = 500.0 Auto Const
{Used only when RH_VendingAmmoPrice is empty.}

int Property iEquipIndex = 0 Auto Const
{Which equipped-weapon slot to read. 0 is the primary weapon.}

float Property fBaseMoveRange = 5.0 Auto Const
{Random scatter, in units, applied to the dropped ammo.}

float Property fDropOffsetX = 0.0 Auto Const
float Property fDropOffsetY = 0.0 Auto Const
float Property fDropOffsetZ = 8.0 Auto Const
{Offset from the machine used when sDropNodeName isn't on the mesh.}

int Property iMaxRoundsPerPurchase = 0 Auto Const
{Hard cap on rounds per activation. 0 = no cap (vanilla AAV behaviour).}

float Property fCooldown = 0.0 Auto Const
{Seconds before the machine can be used again. 0 = no cooldown.}

bool Property bPlayerOnly = true Auto Const
{Block companions and other actors from working the machine.}

;------------------------------------------------------------------------------
; STATE
;------------------------------------------------------------------------------
bool bIsNotFirstBuy
bool bBusy
float fLastUseTime

Event OnActivate(ObjectReference akActionRef)
	; Re-entrancy guard. Papyrus will happily run this twice on a fast
	; double-activate, which double-charges the player.
	if bBusy
		Return
	Endif

	if bPlayerOnly && akActionRef != PlayerRef as ObjectReference
		Return
	Endif

	if fCooldown > 0.0 && fLastUseTime > 0.0
		if (Utility.GetCurrentRealTime() - fLastUseTime) < fCooldown
			Return
		Endif
	Endif

	bBusy = true
	BlockActivation(true, true)

	; --- caps the player has, vs caps this machine will accept at once ---
	int iMaxCaps = GetMaxCaps()
	int iOriginCaps = PlayerRef.GetItemCount(Caps001)
	int iBuyCaps = iOriginCaps
	if iBuyCaps >= iMaxCaps
		iBuyCaps = iMaxCaps
	Endif

	; --- what ammo does the equipped weapon take? ---
	Ammo tAmmo = GetTargetAmmo()

	if tAmmo == None
		ShowMsg(RH_NoAmmoUseMsg)
		Release()
		Return
	Endif

	; --- price per round: Charisma + barter perks ---
	int iAmmoPrice = GetRoundPrice(tAmmo)

	if iAmmoPrice > iMaxCaps
		ShowMsg(RH_OverPriceMsg, iMaxCaps as float)
		Release()
		Return
	elseif iAmmoPrice > iBuyCaps
		ShowMsg(RH_NoCapsMsg)
		Release()
		Return
	Endif

	int iBuyAmmoCount = iBuyCaps / iAmmoPrice
	if iMaxRoundsPerPurchase > 0 && iBuyAmmoCount > iMaxRoundsPerPurchase
		iBuyAmmoCount = iMaxRoundsPerPurchase
	Endif

	if iBuyAmmoCount < 1
		ShowMsg(RH_NoCapsMsg)
		Release()
		Return
	Endif

	int iPaidCaps = iBuyAmmoCount * iAmmoPrice

	; --- dispense ---
	ObjectReference MachineRef = GetMachineRef()
	ObjectReference AmmoRef = MachineRef.PlaceAtNode(sDropNodeName, tAmmo, iBuyAmmoCount, \
		abInitiallyDisabled = true, abDeleteWhenAble = false)

	if AmmoRef == None
		; Mesh has no node by that name. Drop at an offset instead so the
		; machine still works on any model.
		AmmoRef = MachineRef.PlaceAtMe(tAmmo, iBuyAmmoCount, \
			abInitiallyDisabled = true, abDeleteWhenAble = false)
		if AmmoRef == None
			; Nothing we can do - refund nothing, charge nothing.
			ShowMsg(RH_NoDropNodeMsg)
			Release()
			Return
		Endif
		AmmoRef.MoveTo(MachineRef, fDropOffsetX, fDropOffsetY, fDropOffsetZ)
		ShowMsg(RH_NoDropNodeMsg)
	Endif

	AmmoRef.MoveTo(AmmoRef, Utility.RandomFloat(-fBaseMoveRange, fBaseMoveRange), \
		Utility.RandomFloat(-fBaseMoveRange, fBaseMoveRange), 0.0)
	AmmoRef.SetAngle(Utility.RandomFloat(0.0, 360.0), 0.0, Utility.RandomFloat(0.0, 360.0))

	if RH_MachineSound01
		RH_MachineSound01.Play(MachineRef)
	Endif

	AmmoRef.Enable()

	PlayerRef.RemoveItem(Caps001, iPaidCaps, true)

	; One-time nudge so the player knows the machine capped their spend.
	if !bIsNotFirstBuy
		bIsNotFirstBuy = true
		if iOriginCaps > iBuyCaps
			ShowMsg(RH_RemainCapsMsg, (iOriginCaps - iBuyCaps) as float)
		Endif
	Endif

	fLastUseTime = Utility.GetCurrentRealTime()
	Release()
EndEvent

Event OnUnload()
	bIsNotFirstBuy = false
	bBusy = false
EndEvent

;------------------------------------------------------------------------------
; HELPERS
;------------------------------------------------------------------------------

; Where the ammo comes out of. Linked ref if there is one (hidden-activator
; setup), otherwise ourselves (script straight on the machine).
ObjectReference Function GetMachineRef()
	; GetLinkedRef's keyword parameter already defaults to None, so passing an
	; empty property through is the same as the no-argument call.
	ObjectReference kRef = GetLinkedRef(MachineLinkKeyword)

	if kRef == None
		kRef = Self as ObjectReference
	Endif
	Return kRef
EndFunction

; Overridden by RH_VendingMachineScript_F4SE to read instanced (weapon-mod
; aware) ammo. Vanilla path: base form's ammo.
Ammo Function GetTargetAmmo()
	Weapon kWeapon = PlayerRef.GetEquippedWeapon(iEquipIndex)
	if kWeapon == None
		Return None
	Endif
	Return kWeapon.GetAmmo()
EndFunction

int Function GetMaxCaps()
	if RH_VendingAmmoPrice
		Return RH_VendingAmmoPrice.GetValueInt()
	Endif
	Return fFallbackMaxCaps as int
EndFunction

; Charisma drives the markup, barter perks cut it. Recomputed every purchase so
; a fresh perk or a chem buff is picked up straight away.
int Function GetRoundPrice(Ammo akAmmo)
	float fSaleMult = 1.0
	int iPlayerCharisma = PlayerRef.GetValue(Charisma) as int

	if CapCollector02 && PlayerRef.HasPerk(CapCollector02)
		fSaleMult = 0.72
	elseif CapCollector01 && PlayerRef.HasPerk(CapCollector01)
		fSaleMult = 0.9
	Endif

	if PerkBobbleheadBarter && PlayerRef.HasPerk(PerkBobbleheadBarter)
		fSaleMult *= 0.95
	Endif

	float fSaleCount = (3.5 - (iPlayerCharisma * 0.15)) * fSaleMult
	if fSaleCount < 1.2
		fSaleCount = 1.2
	Endif

	int iPrice = Math.Floor(akAmmo.GetGoldValue() * fSaleCount + 0.51)
	if iPrice < 1
		iPrice = 1
	Endif
	Return iPrice
EndFunction

Function ShowMsg(Message akMessage, float afArg1 = 0.0)
	if akMessage
		akMessage.Show(afArg1)
	Endif
EndFunction

Function Release()
	BlockActivation(false)
	bBusy = false
EndFunction
