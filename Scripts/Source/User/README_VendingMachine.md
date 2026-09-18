# ROCKHARD Ammo Vending Machine

A remade, worldspace-friendly version of the AAV ammo vending machine scripts.

| File | Goes on | Required? |
|---|---|---|
| `RX_VendingMachineScript.psc` | the thing the player activates | yes (vanilla, no dependencies) |
| `RX_VendingMachineScript_GOE.psc` | same, *instead of* the above | only if you want weapon-mod-aware ammo |
| `RX_VendingMachineScript_F4SE.psc` | same, *instead of* the above | alternative to the GOE variant |
| `RX_VendingSwitchSpawnerScript.psc` | the machine ref | only for the spawner setup |

## Vanilla vs extender

The AAV original used `InstanceData:Owner` / `InstanceData.GetAmmo()`, which
**is not in the vanilla Creation Kit sources** — a search of all 7,831 base
`.psc` files finds no `InstanceData.psc` and not one reference to it. It comes
from a script extender, so the original mod can't compile or run without one.

That matters because the two lookups behave differently:

- **Vanilla** (`GetEquippedWeapon().GetAmmo()`) reads the weapon's *base form*
  ammo. A pipe gun converted from .45 to .38 by a receiver mod vends **.45**.
- **Extender** (`InstanceData.GetAmmo()`) reads the *instanced* ammo, so the
  same gun correctly vends **.38**.

`RX_VendingMachineScript` uses the vanilla path, so it compiles with nothing but
the CK and ships with no dependency. Both extender variants extend it and
override the single `GetTargetAmmo()` function — everything else is inherited,
so there's only one copy of the real logic.

**Prefer `_GOE` over `_F4SE`.** Garden of Eden exposes
`GardenOfEden.GetEquippedWeaponAmmo(Actor)` — one native call, no struct type and
no equip-slot magic number — and its signature is verified against GOE's own
source. The `_F4SE` variant's `InstanceData` / `GetInstanceOwner` are carried
over from the AAV original unverified, because F4SE's script sources weren't
available to check them against. They're in neither the vanilla set nor GOE's.

One thing to test in-game rather than take on faith: GOE documents
`GetEquippedWeaponAmmo` as "returns the Ammo of this actor's equipped weapon"
without saying explicitly whether that's the instanced or base ammo. Put a
converted receiver on a pipe gun and check which round drops.

## How it works

Player activates the machine → the script reads the ammo type of the weapon
currently in their hands → prices one round off Charisma + barter perks → buys
as many rounds as their caps allow (capped by the machine's max-caps global) →
drops the stack out of the machine's drop node.

Price per round: `floor(ammoValue * saleMult + 0.51)` where
`saleMult = (3.5 - Charisma * 0.15) * perkMult`, floored at `1.2`.
`perkMult` is `0.72` with Cap Collector 2, `0.9` with Cap Collector 1, times
`0.95` with the Barter bobblehead. So a high-Charisma character with maxed
barter pays roughly ammo value; a dumb one pays over triple.

## Setup A — machine is an Activator (simplest, recommended)

1. Make your vending machine an **Activator** form.
2. Put `RX_VendingMachineScript` on it, fill the properties.
3. Place it in your worldspace. Done.

`MachineRef` falls back to `Self` when there's no linked ref, so no second
object and no linking is needed.

## Setup B — machine is a Static/Furniture

Statics can't run `OnActivate`, so the player needs something else to click.

1. Make a small hidden Activator (`RX_VendingSwitchActi`) — collision-only
   trigger-ish shape, no mesh or an invisible one.
2. Put `RX_VendingMachineScript` on **the activator**.
3. Place the activator in front of the machine in the CK, then set its
   **Linked Ref** to the machine reference.

The ammo then drops from the machine, not from the activator.

## Setup C — spawn the activator at runtime

Same as B, but instead of placing and linking the activator by hand, put
`RX_VendingSwitchSpawnerScript` on the **machine** reference and point its
`RX_VendingSwitchActi` property at the activator. It spawns, links and attaches
the switch on cell attach.

**Why not the original's `OnWorkshopObjectPlaced`:** that event only fires for
objects built in a settlement workshop. A machine you place in a worldspace in
the CK never receives it, so the original spawner would silently do nothing.
This version uses `OnInit` / `OnCellAttach` / `OnLoad` with a `SwitchRef != None`
guard so reloads don't stack up duplicate switches.

Setup A or B is more robust than C — prefer them unless you need the machine to
be duplicated around at runtime.

## Properties worth knowing

- **`sDropNodeName`** — the NiNode on your mesh the ammo spawns from, default
  `"AmmoDropNode"`. Open your `.nif` in NifSkope and check the node names. If
  the node doesn't exist, `PlaceAtNode` returns `None` and the script falls back
  to `PlaceAtMe` + `fDropOffsetX/Y/Z`, so the machine still works on any model.
- **`RX_VendingAmmoPrice`** — GlobalVariable, max caps taken per purchase. Leave
  it empty and `fFallbackMaxCaps` (500) is used.
- **`iMaxRoundsPerPurchase`** — hard round cap, `0` = unlimited (original
  behaviour). Set it if the caps cap alone lets players buy 800 rounds of .38.
- **`fCooldown`** — seconds between uses, `0` = off. Uses real time, not game
  time.
- **`bPlayerOnly`** — on by default; keeps companions from triggering it.
- All `Perk`, `Message`, `Sound` and `Keyword` properties are **None-safe**. Fill
  in only what you have. The original would throw a Papyrus error on
  `HasPerk(None)`.

## Messages

`RX_OverPriceMsg` and `RX_RemainCapsMsg` each take one argument, so add a
replacement token in the message text in the CK.

## Changes from the AAV original

- Worldspace-safe activator attachment (see above).
- Re-entrancy guard (`bBusy`) — a fast double-activate on the original could
  run `OnActivate` twice and charge the player twice.
- `bPlayerOnly` actor check.
- `None` guards on perks, messages, sound, the global, the linked ref, and the
  `PlaceAtNode` result.
- `iBuyAmmoCount < 1` guard — the original could pay caps for a zero-count
  stack in edge cases.
- Price logic moved into `GetRoundPrice()`; the original had the recalculation
  wrapped in commented-out `if !bIsNotFirstBuy`, which left dead state around.
- `fSaleCount` is now local instead of a script variable that outlived the call.
- Optional round cap and cooldown.

## Verified against the vanilla sources

Every function, event and signature used by these scripts was checked against
the Creation Kit's base `.psc` set. Things that got corrected in the process:

- `AttachTo()` takes **only** a parent ref — there is no node-name overload.
- `ObjectReference` has **no `Detach()`** at all; `Delete()` drops the
  attachment.
- `PlaceAtNode()` has no `abMatchRotation` parameter (`PlaceAtMe` doesn't
  either) — the parameter list ends `..., abDeleteWhenAble, abAttach`.
- `GetValue(ActorValue)` lives on `ObjectReference`, not `Actor`.
- `GetLinkedRef(Keyword apKeyword = None)` already defaults its keyword, so a
  separate no-argument branch is dead code.
- `MoveTo`'s `abMatchRotation` defaults to **true**, not false.
- `Math.Floor` returns `int`, and `Utility.GetCurrentRealTime()` does exist.
- `InstanceData` / `GetInstanceOwner` are in **neither** the vanilla sources nor
  Garden of Eden's — searched both.

Re-run the check yourself any time:

```
python3 tools/papyrus_api.py verify Scripts/Source/User/RX_VendingMachineScript.psc
```

## Compiling

Not compiled here — that needs the Creation Kit's Papyrus compiler and the
vanilla base scripts. Drop both `.psc` files in
`Data\Scripts\Source\User\` and compile from the CK
(**Gameplay → Papyrus Script Manager**) or with `PapyrusCompiler.exe`.

`RX_VendingMachineScript` needs nothing but the extracted base scripts.

If you use `RX_VendingMachineScript_F4SE`, the compiler needs the extender's
`InstanceData.psc` on its import path too. "Type InstanceData does not exist" at
compile time means that import is missing — not that your base scripts are.
