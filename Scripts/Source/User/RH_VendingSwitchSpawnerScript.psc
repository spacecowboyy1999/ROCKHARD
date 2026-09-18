ScriptName RH_VendingSwitchSpawnerScript Extends ObjectReference
{ROCKHARD - optional helper for the ammo vending machine.

Only needed if your machine is a Static/Furniture (which can't run OnActivate)
and you'd rather the hidden activator be spawned at runtime than placed by hand
in the Creation Kit.

Put this on the MACHINE reference. It spawns RH_VendingSwitchActi, links it back
to the machine, and attaches it to the mesh.

Note: the AAV original did this from OnWorkshopObjectPlaced, which only ever
fires for settlement-built objects. A machine placed in a worldspace never gets
that event, so this version hooks OnInit / OnCellAttach instead - and keeps the
workshop events too, in case you later make the machine buildable.}

Activator Property RH_VendingSwitchActi Auto Const Mandatory
{The hidden activator carrying RH_VendingMachineScript.}

bool Property bAttachToMesh = true Auto Const
{Off = the switch is left free-standing at the machine's origin instead of
being parented to the mesh. AttachTo parents to the root node only, so if the
activator needs to sit somewhere specific, place it by hand in the CK and skip
this script entirely.}

ObjectReference SwitchRef

;------------------------------------------------------------------------------
; WORLDSPACE / STATICALLY PLACED
;------------------------------------------------------------------------------
Event OnInit()
	SpawnSwitch()
EndEvent

; Backstop: covers refs that already existed in a save made before this script
; was added, and any case where OnInit was missed.
Event OnCellAttach()
	SpawnSwitch()
EndEvent

Event OnLoad()
	SpawnSwitch()
EndEvent

;------------------------------------------------------------------------------
; WORKSHOP / SETTLEMENT BUILT (harmless if the machine isn't buildable)
;------------------------------------------------------------------------------
Event OnWorkshopObjectPlaced(ObjectReference akReference)
	SpawnSwitch()
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
	ClearSwitch()
EndEvent

;------------------------------------------------------------------------------
; HELPERS
;------------------------------------------------------------------------------

; Guarded so repeated OnLoad/OnCellAttach calls can't stack up duplicate
; switches, which is the usual way this pattern leaks refs across save reloads.
Function SpawnSwitch()
	if SwitchRef != None
		Return
	Endif

	SwitchRef = PlaceAtMe(RH_VendingSwitchActi, 1, abDeleteWhenAble = false)
	if SwitchRef == None
		Return
	Endif

	SwitchRef.SetLinkedRef(Self as ObjectReference)

	if bAttachToMesh
		SwitchRef.AttachTo(Self as ObjectReference)
	Endif
EndFunction

Function ClearSwitch()
	if SwitchRef == None
		Return
	Endif

	; No Detach() exists on ObjectReference - Delete() drops the attachment.
	SwitchRef.Disable()
	SwitchRef.Delete()
	SwitchRef = None
EndFunction
