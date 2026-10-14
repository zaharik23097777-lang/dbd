-- Процедурные позы R6. Каждая поза — функция, возвращающая таблицу поворотов суставов:
--   Root (поворот торса вокруг HumanoidRootPart), RootPos (сдвиг торса в стадах),
--   Neck, LArm, RArm, LLeg, RLeg.
-- Углы в градусах: +X — вперёд (руку поднять перед собой), +Y — влево, +Z — вправо.
-- Корпус наклоняется вперёд ОТРИЦАТЕЛЬНЫМ X. Не указанные суставы берутся из базовой позы.
--   Poses.locomotion / Poses.stepRate — походка (Anim/Gait.lua)
--   Poses.State.*  — особые состояния (Anim/States.lua)
--   Poses.Action.* — действия, пока игрок держит кнопку: (t от начала действия, p) -> поза
--     (Anim/Actions.lua — ключевые клипы)
--   Poses.OneShot.* — одноразовые: { Duration, Fn(a, p) -> поза } или клип Anim/Clip.lua
--     (необязательно: FadeIn, FadeOut, Additive, Stiffness, Upper — см. Anim/Clips.lua);
--     накладываются через Poses.applyShot, вариант по обстоятельствам — Poses.shotVariant
local Rig = require(script.Parent.Rig)
local Gait = require(script.Parent.Gait)
local States = require(script.Parent.States)
local Clips = require(script.Parent.Clips)
local Actions = require(script.Parent.Actions)

local Poses = {}

local A = Rig.A
Poses.A = A

export type Params = Gait.Params

local function merge(base, over)
	local out = table.clone(base)
	for k, v in over do
		out[k] = v
	end
	return out
end
Poses.merge = merge

Poses.stepRate = Gait.stepRate
Poses.locomotion = Gait.locomotion
Poses.State = States

-- Действия (Anim/Actions.lua): Repair, Heal, Cleanse, OpenChest, FreeTrap/DisarmTrap, Unhook,
-- OpenGate, SelfHeal, EscapeTrap; маньяк: Hook, Break, Kick, SearchLocker,
-- SetTrap/PickupTrap/ResetTrap/CloseHatch
Poses.Action = Actions.Action
Poses.ActionLength = Actions.Length

-- Одноразовые (Anim/Clips.lua): Swing, Wipe, Stun, Blind, Pickup, Vault (+VaultWalk), KillerVault,
-- PalletDrop, Flinch, Windup, Throw, Bell (+BellUncloak), HookScream, Entity
Poses.OneShot = Clips.OneShot
Poses.applyShot = Clips.apply
Poses.shotVariant = Clips.variant

return Poses
