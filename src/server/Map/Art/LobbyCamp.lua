-- Реквизит лагеря в лобби: кострище, бревно-сиденье, палатка, ящики, бочка, фонарь,
-- резная табличка, поленница, бельевая верёвка. cf — точка на земле, «перед» смотрит в -Z.
local Kit = require(script.Parent.Kit)
local Nature = require(script.Parent.Nature)
local Trees = require(script.Parent.NatureTrees)
local Ground = require(script.Parent.NatureGround)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local Camp = {}

local DECOR = { Decor = true }
local CANVAS = Color3.fromRGB(112, 104, 78)
local BARK = Color3.fromRGB(66, 52, 40)
local CUT = Color3.fromRGB(132, 104, 74)
local IRON = Color3.fromRGB(40, 38, 36)

------------------------------------------------------------------------
-- Кострище
------------------------------------------------------------------------

-- Кострище: зола, угли, кольцо камней, «шалаш» горящих брёвен, тренога с котелком и огонь
function Camp.firePit(parent: Instance, cf: CFrame, rng: Random): BasePart
	Kit.vcyl(parent, cf * C(0, 0.05, 0), 0.1, 4.6, Color3.fromRGB(34, 31, 29), Mat.Slate, DECOR)
	-- Тлеющие угли (Neon светится в темноте)
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.3, 1.4)
		local s = V(0.5, 0.22, 0.4) * rng:NextNumber(0.7, 1.3)
		Kit.box(parent, cf * C(math.cos(a) * r, 0.12, math.sin(a) * r) * A(rng:NextNumber(-15, 15), rng:NextNumber(0, 360), 0), s, Color3.fromRGB(150, 46, 14), Mat.Neon, DECOR)
	end
	-- Кольцо камней: изнутри закопчённые
	local n = 11
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local s = V(rng:NextNumber(1, 1.5), rng:NextNumber(0.6, 1), rng:NextNumber(0.8, 1.1))
		local rot = cf * C(math.cos(a) * 2.6, 0, math.sin(a) * 2.6) * A(0, -math.deg(a) + 90 + rng:NextNumber(-15, 15), 0) * A(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		local stone = Kit.jitter(Color3.fromRGB(84, 82, 80), 0.06, rng):Lerp(Color3.fromRGB(26, 24, 22), rng:NextNumber(0.1, 0.45))
		local p = Kit.box(parent, Ground.seat(rot, s, s.Y * 0.3), s, stone, rng:NextNumber() < 0.5 and Mat.Slate or Mat.Rock)
		p.Name = "FireStone"
	end
	-- «Шалаш» из брёвен: обугленные, сходятся над углями
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local bottom = cf * C(math.cos(a) * 1.55, 0.25, math.sin(a) * 1.55)
		local top = cf * C(math.cos(a + 0.5) * 0.2, rng:NextNumber(1.6, 1.9), math.sin(a + 0.5) * 0.2)
		local charred = Color3.fromRGB(44, 33, 26):Lerp(Color3.fromRGB(20, 18, 17), rng:NextNumber(0, 0.6))
		Kit.rod(parent, bottom.Position, top.Position, rng:NextNumber(0.42, 0.56), charred, Mat.Wood, DECOR)
	end
	-- Тренога с котелком на цепи
	local apex = cf * C(0, 5.3, 0)
	local yaw = rng:NextNumber(0, math.pi * 2)
	for i = 1, 3 do
		local a = yaw + i / 3 * math.pi * 2
		local foot = cf * C(math.cos(a) * 3.3, -0.2, math.sin(a) * 3.3)
		local dir = (apex.Position - foot.Position).Unit
		Kit.bar(parent, foot.Position, apex.Position + dir * 0.5, 0.2, Kit.jitter(P.DarkWood, 0.06, rng), Mat.Wood, DECOR)
	end
	local potTop = cf * C(0, 3.1, 0)
	Kit.chain(parent, { apex.Position - Vector3.new(0, 0.15, 0), potTop.Position + Vector3.new(0, 0.55, 0) }, 0.42, Color3.fromRGB(58, 54, 50))
	Kit.vcyl(parent, potTop * C(0, -0.4, 0), 0.8, 1.15, IRON, Mat.Metal, DECOR)
	Kit.vcyl(parent, potTop * C(0, 0.02, 0), 0.1, 1.25, Kit.dark(IRON, 0.2), Mat.Metal, DECOR)
	Kit.arc(parent, potTop * A(0, math.deg(yaw), 0), 0.6, 0, 180, 3, 0.06, IRON, Mat.Metal, DECOR)
	return Nature.fire(parent, cf * C(0, 0.6, 0), 2.2)
end

------------------------------------------------------------------------
-- Бревно-сиденье
------------------------------------------------------------------------

-- Бревно-сиденье. Сама деталь Seat — бревно (цилиндр 5 x 1.4, группа DBDSeats), смотрит на lookAt.
-- Спилы, сучок и подпорки — декор, не мешают садиться.
function Camp.logSeat(parent: Instance, pos: Vector3, lookAt: Vector3, rng: Random): Seat
	local seat = Kit.part(parent, {
		Name = "LogSeat",
		Shape = Enum.PartType.Cylinder,
		Size = V(5, 1.4, 1.4),
		CFrame = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z)),
		Color = Kit.jitter(BARK, 0.06, rng),
		Material = Mat.Wood,
	}, "Seat") :: Seat
	seat.CollisionGroup = "DBDSeats"
	local cf = seat.CFrame
	-- Спилы на торцах, на одном — тёмная сердцевина
	for _, s in { -1, 1 } do
		Kit.cyl(parent, cf * C(s * 2.5, 0, 0), 0.08, 1.3, Kit.jitter(CUT, 0.05, rng), Mat.Wood, DECOR)
	end
	Kit.cyl(parent, cf * C(2.55, 0, 0), 0.04, 0.55, Kit.dark(CUT, 0.3), Mat.Wood, DECOR)
	-- Обрубленный сучок
	local x = rng:NextNumber(-1.6, 1.6)
	local stub = cf * C(x, 0, 0) * A(rng:NextNumber(-70, -20), 0, 0)
	Kit.cyl(parent, stub * C(0, 0, -0.75) * A(0, 90, 0), 0.5, 0.32, Kit.dark(BARK, 0.1), Mat.Wood, DECOR)
	-- Подпорки-клинья с двух сторон, чтобы бревно не катилось
	for _, side in { -1, 1 } do
		Kit.wedge(parent, cf * C(side * 1.6, -0.5, side * 0.75) * A(0, side == 1 and 0 or 180, 0), V(0.5, 0.4, 0.5), Kit.jitter(P.DarkWood, 0.06, rng), Mat.Wood, DECOR)
	end
	return seat
end

------------------------------------------------------------------------
-- Палатка
------------------------------------------------------------------------

-- Полоса брезента между точками p и q сечения (локальная плоскость XY палатки), длиной len по Z
local function panel(parent: Instance, cf: CFrame, p: Vector3, q: Vector3, len: number, color: Color3, extra: Kit.Props?): BasePart
	local right = (q - p).Unit
	local local_ = CFrame.fromMatrix((p + q) / 2, right, Vector3.zAxis:Cross(right))
	return Kit.box(parent, cf * local_, V((q - p).Magnitude + 0.1, 0.12, len), color, Mat.Fabric, extra)
end

-- Старая армейская палатка-«домик»: брезент провисает, вход наполовину открыт, растяжки и колья.
-- Боковые полотнища твёрдые (сквозь палатку не пройти), остальное — декор.
function Camp.tent(parent: Instance, cf: CFrame, rng: Random, scale: number?)
	local k = scale or 1
	local W, H, L = 5.4 * k, 4.4 * k, 7 * k
	local canvas = Kit.jitter(CANVAS, 0.05, rng)
	local pole = Kit.jitter(P.DarkWood, 0.05, rng)
	-- Подстилка и спальник внутри
	Kit.box(parent, cf * C(0, 0.04, -0.3), V(W + 0.6, 0.08, L + 1.2), Kit.jitter(Color3.fromRGB(58, 56, 46), 0.04, rng), Mat.Fabric, DECOR)
	Kit.cyl(parent, cf * C(W * 0.18, 0.38, 0.6) * A(0, 90, 0), L * 0.55, 0.7, Kit.jitter(Color3.fromRGB(70, 74, 52), 0.05, rng), Mat.Fabric, DECOR)
	-- Конёк и А-образные стойки
	Kit.cyl(parent, cf * C(0, H, 0) * A(0, 90, 0), L + 0.8, 0.22, pole, Mat.Wood, DECOR)
	for _, z in { -L / 2 - 0.15, L / 2 + 0.15 } do
		for _, x in { -1, 1 } do
			local foot = cf * C(x * (W / 2 + 0.15), -0.1, z)
			local top = cf * C(-x * 0.25, H + 0.35, z)
			Kit.bar(parent, foot.Position, top.Position, 0.18, pole, Mat.Wood, DECOR)
		end
	end
	-- Бока: по два полотнища с провисом внутрь
	for _, x in { -1, 1 } do
		local top = V(0, H, 0)
		local bottom = V(x * W / 2, 0.12, 0)
		local mid = top:Lerp(bottom, 0.5) + V(-x * 0.2, -0.12, 0)
		local upper = panel(parent, cf, top, mid, L, canvas)
		-- Низ полотнища темнее: грязь и сырость от земли
		local lower = panel(parent, cf, mid, bottom, L, Kit.jitter(Kit.dark(canvas, 0.14), 0.03, rng))
		upper.Name, lower.Name = "Canvas", "Canvas"
		-- Заплата снаружи (у левого бока локальная Y полотнища смотрит внутрь)
		Kit.box(parent, upper.CFrame * C(rng:NextNumber(-0.6, 0.6), x * 0.07, rng:NextNumber(-L / 3, L / 3)), V(0.9, 0.04, 1.1), Kit.jitter(Color3.fromRGB(86, 82, 60), 0.05, rng), Mat.Fabric, DECOR)
	end
	-- Задняя стенка — два клина; спереди закрыта только половина, вторая скатана у стойки
	for _, x in { -1, 1 } do
		Kit.wedge(parent, cf * C(x * W / 4, H / 2, L / 2) * A(0, -x * 90, 0), V(0.12, H, W / 2), Kit.dark(canvas, 0.08), Mat.Fabric, DECOR)
	end
	Kit.wedge(parent, cf * C(W / 4, H / 2, -L / 2) * A(0, -90, 0), V(0.12, H, W / 2), Kit.dark(canvas, 0.04), Mat.Fabric, DECOR)
	Kit.rod(parent, (cf * C(-0.4, H - 0.4, -L / 2 - 0.1)).Position, (cf * C(-W / 2 + 0.5, 0.4, -L / 2 - 0.15)).Position, 0.38, Kit.dark(canvas, 0.12), Mat.Fabric, DECOR)
	-- Растяжки от конька к кольям
	for _, z in { -1, 1 } do
		local from = cf * C(0, H + 0.1, z * (L / 2 + 0.4))
		local stake = cf * C(rng:NextNumber(-0.3, 0.3), 0.15, z * (L / 2 + 2.6))
		Kit.bar(parent, from.Position, stake.Position, 0.05, Color3.fromRGB(150, 140, 110), Mat.Fabric, DECOR)
		Kit.box(parent, stake * A(z * 20, 0, 0), V(0.14, 0.6, 0.14), pole, Mat.Wood, DECOR)
	end
end

------------------------------------------------------------------------
-- Ящики, бочка, мешок
------------------------------------------------------------------------

-- Деревянный ящик: доски, обвязка, по желанию — надпись по трафарету
function Camp.crate(parent: Instance, cf: CFrame, size: Vector3, rng: Random, label: string?)
	local wood = Kit.jitter(P.Plank, 0.07, rng):Lerp(P.OldWood, rng:NextNumber(0.2, 0.6))
	local body = Kit.box(parent, cf * C(0, size.Y / 2, 0), size, wood, Mat.WoodPlanks)
	body.Name = "Crate"
	local batten = Kit.dark(wood, 0.25)
	for _, y in { -1, 1 } do
		Kit.box(parent, cf * C(0, size.Y / 2 + y * (size.Y / 2 - 0.14), -size.Z / 2 - 0.04), V(size.X + 0.04, 0.22, 0.1), batten, Mat.Wood, DECOR)
	end
	local diag = math.deg(math.atan2(size.Y - 0.5, size.X))
	Kit.box(parent, cf * C(0, size.Y / 2, -size.Z / 2 - 0.04) * A(0, 0, diag), V(math.sqrt(size.X ^ 2 + (size.Y - 0.5) ^ 2) - 0.2, 0.2, 0.08), batten, Mat.Wood, DECOR)
	if label then
		local plate = Kit.box(parent, cf * C(0, size.Y * 0.62, -size.Z / 2 - 0.1), V(size.X * 0.7, size.Y * 0.22, 0.02), wood, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		Kit.label(plate, Enum.NormalId.Front, label, Color3.fromRGB(30, 26, 22))
	end
	Kit.grime(body, Enum.NormalId.Front, 0.5)
end

-- Ржавая бочка с обручами
function Camp.drum(parent: Instance, cf: CFrame, rng: Random)
	local rust = Kit.jitter(P.Rust, 0.08, rng):Lerp(Color3.fromRGB(60, 70, 58), rng:NextNumber(0, 0.5))
	local body = Kit.vcyl(parent, cf * C(0, 1.4, 0), 2.8, 1.9, rust, Mat.CorrodedMetal)
	body.Name = "Drum"
	for _, y in { 0.7, 2.1 } do
		Kit.vcyl(parent, cf * C(0, y, 0), 0.14, 1.98, Kit.dark(rust, 0.25), Mat.CorrodedMetal, DECOR)
	end
	Kit.vcyl(parent, cf * C(0, 2.81, 0), 0.04, 1.7, Kit.dark(rust, 0.4), Mat.CorrodedMetal, DECOR)
end

-- Вещмешок, прислонённый к чему-нибудь
function Camp.duffel(parent: Instance, cf: CFrame, rng: Random)
	local color = Kit.jitter(Color3.fromRGB(72, 76, 52), 0.06, rng)
	local bag = cf * C(0, 0.55, 0) * A(0, 0, rng:NextNumber(-8, 8))
	Kit.cyl(parent, bag, 2.2, 1.1, color, Mat.Fabric, DECOR)
	Kit.cyl(parent, bag * C(1.12, 0, 0), 0.1, 0.8, Kit.dark(color, 0.2), Mat.Leather, DECOR)
	Kit.box(parent, bag * C(0, 0.5, 0) * A(0, 0, 8), V(1.8, 0.08, 0.25), Color3.fromRGB(56, 44, 34), Mat.Leather, DECOR)
end

------------------------------------------------------------------------
-- Фонарь
------------------------------------------------------------------------

-- Керосиновый фонарь (cf — дно). Тёплый свет без теней, малый радиус.
function Camp.lantern(parent: Instance, cf: CFrame, rng: Random)
	local metal = Kit.jitter(Color3.fromRGB(58, 52, 44), 0.05, rng)
	Kit.vcyl(parent, cf * C(0, 0.09, 0), 0.18, 0.7, metal, Mat.Metal, DECOR)
	Kit.vcyl(parent, cf * C(0, 0.55, 0), 0.75, 0.55, Color3.fromRGB(255, 214, 150), Mat.Glass, { Decor = true, Transparency = 0.45 })
	local flame = Kit.ball(parent, cf * C(0, 0.5, 0), 0.22, Color3.fromRGB(255, 176, 90), Mat.Neon, DECOR)
	Kit.vcyl(parent, cf * C(0, 1.02, 0), 0.2, 0.62, metal, Mat.Metal, DECOR)
	Kit.arc(parent, cf * C(0, 1.1, 0) * A(0, rng:NextNumber(0, 180), 0), 0.32, 0, 180, 3, 0.05, Kit.dark(metal, 0.3), Mat.Metal, DECOR)
	Kit.pointLight(flame, Color3.fromRGB(255, 168, 88), 11, 1.3)
end

-- Фонарь на столбе с кронштейном
function Camp.lanternPost(parent: Instance, cf: CFrame, rng: Random)
	local wood = Kit.jitter(P.DarkWood, 0.06, rng)
	Kit.box(parent, cf * C(0, 2.6, 0) * A(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), V(0.35, 5.6, 0.35), wood, Mat.Wood).Name = "LanternPost"
	Kit.bar(parent, (cf * C(0, 5, 0)).Position, (cf * C(0, 5.1, -1.4)).Position, 0.16, wood, Mat.Wood, DECOR)
	Kit.bar(parent, (cf * C(0, 4.98, -1.25)).Position, (cf * C(0, 4.55, -1.25)).Position, 0.05, IRON, Mat.Metal, DECOR)
	Camp.lantern(parent, cf * C(0, 3.35, -1.25), rng)
end

------------------------------------------------------------------------
-- Табличка, поленница, верёвка
------------------------------------------------------------------------

-- Резная табличка на двух столбах под козырьком. Надпись «вырезана»: тёмные буквы со светлым краем.
function Camp.sign(parent: Instance, cf: CFrame, rng: Random, text: string)
	for _, x in { -4.7, 4.7 } do
		Kit.vcyl(parent, cf * C(x, 3, 0) * A(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), 6.6, 0.6, Kit.jitter(BARK, 0.06, rng), Mat.Wood).Name = "SignPost"
	end
	local board = cf * C(0, 4.2, 0)
	Kit.planks(parent, board, V(9.6, 2.7, 0.3), { Rng = Random.new(rng:NextInteger(1, 1e6)), PlankWidth = 0.8, Gap = 0.07, Color = P.OldWood, Tilt = 0.8 })
	-- Поперечины за досками
	for _, x in { -3.2, 3.2 } do
		Kit.box(parent, board * C(x, 0, 0.24), V(0.3, 3, 0.18), Kit.dark(P.OldWood, 0.2), Mat.Wood, DECOR)
	end
	-- Двускатный козырёк (крутой, с выносом над досками)
	for _, s in { -1, 1 } do
		Kit.box(parent, cf * C(0, 6.15, s * 0.42) * A(s * 42, 0, 0), V(10.8, 0.14, 1.25), Kit.jitter(P.DarkWood, 0.05, rng), Mat.WoodPlanks, DECOR)
	end
	-- Надпись на прозрачной пластине перед досками
	local face = Kit.box(parent, board * C(0, 0, -0.17), V(9.2, 2.4, 0.02), P.OldWood, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
	face.Name = "SignFace"
	local gui = Kit.label(face, Enum.NormalId.Front, text, Color3.fromRGB(46, 20, 16), Enum.Font.Creepster)
	local label = gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.TextStrokeColor3 = Color3.fromRGB(160, 128, 92)
		label.TextStrokeTransparency = 0.55
	end
end

-- Поленница между двумя кольями и колода с воткнутым топором
function Camp.woodpile(parent: Instance, cf: CFrame, rng: Random)
	local rows = { 4, 3, 2 }
	for r, count in rows do
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 0.72
			local d = rng:NextNumber(0.6, 0.72)
			local log = cf * C(x + rng:NextNumber(-0.05, 0.05), 0.33 + (r - 1) * 0.6, rng:NextNumber(-0.15, 0.15)) * A(0, 90 + rng:NextNumber(-4, 4), 0)
			local p = Kit.cyl(parent, log, rng:NextNumber(2.4, 2.8), d, Kit.jitter(BARK, 0.07, rng), Mat.Wood, r > 1 and DECOR or nil)
			if r == 1 then
				p.Name = "Woodpile"
			end
		end
	end
	for _, x in { -1.75, 1.75 } do
		Kit.box(parent, cf * C(x, 1, 0) * A(0, 0, x > 0 and -4 or 4), V(0.2, 2.2, 0.2), Kit.jitter(P.DarkWood, 0.05, rng), Mat.Wood, DECOR)
	end
	-- Колода с топором
	local block = cf * C(3.4, 0, -0.8)
	local top = Trees.stump(parent, block, rng, {})
	-- Лезвие наполовину в древесине, топорище смотрит вверх-назад
	local head = block * C(0.1, top - 0.05, 0) * A(0, rng:NextNumber(0, 360), 0) * A(-20, 0, 0)
	Kit.box(parent, head, V(0.14, 0.5, 0.8), Color3.fromRGB(86, 88, 90), Mat.Metal, DECOR)
	Kit.bar(parent, (head * C(0, 0.15, 0.3)).Position, (head * C(0, 1, 2.5)).Position, 0.16, Color3.fromRGB(118, 92, 62), Mat.Wood, DECOR)
end

-- Бельевая верёвка между двумя шестами, на ней сохнут тряпки
function Camp.clothesline(parent: Instance, a: CFrame, b: CFrame, rng: Random)
	local wood = Kit.jitter(P.DarkWood, 0.05, rng)
	for _, p in { a, b } do
		Kit.box(parent, p * C(0, 2.7, 0), V(0.22, 5.4, 0.22), wood, Mat.Wood, DECOR)
	end
	local pa, pb = (a * C(0, 5.1, 0)).Position, (b * C(0, 5.1, 0)).Position
	local pts = Kit.sag(pa, pb, 0.5, 4)
	Kit.cable(parent, pts, 0.05, Color3.fromRGB(150, 140, 110), Mat.Fabric, DECOR)
	local dir = (pb - pa).Unit
	for i, t in { 0.33, 0.62 } do
		local top = pa:Lerp(pb, t) - Vector3.new(0, 0.5 * 4 * t * (1 - t), 0)
		local w = rng:NextNumber(1, 1.5)
		local h = rng:NextNumber(1.2, 1.8)
		local cloth = CFrame.lookAt(top, top + dir) * A(0, 90, 0) * C(0, -h / 2, 0) * A(rng:NextNumber(-6, 6), 0, 0)
		local color = i == 1 and Color3.fromRGB(150, 140, 118) or Color3.fromRGB(104, 50, 40)
		Kit.box(parent, cloth, V(w, h, 0.05), Kit.jitter(color, 0.05, rng), Mat.Fabric, DECOR)
	end
end

return Camp
