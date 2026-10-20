local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "Run this script on the client, after joining the game.")
local playerGui = player:WaitForChild("PlayerGui")

local CONTROLLER_NAME = "LocalNPCMarkerController"
local oldController = Workspace:FindFirstChild(CONTROLLER_NAME)
if oldController then oldController:Destroy() end
local oldGui = playerGui:FindFirstChild("LocalVisualControls")
if oldGui then oldGui:Destroy() end

local controller = Instance.new("Folder")
controller.Name = CONTROLLER_NAME
controller.Parent = Workspace
local alive, hubVisible = true, true
local connections, watched, entries = {}, {}, {}
local categories = {
	buyers = {name = "Drug buyers", label = "Buying NPC", color = Color3.fromRGB(255, 55, 65), enabled = true},
	merchant = {name = "Traveling merchant", label = "พ่อค้าพเนจร", description = "appears every 20 minutes", color = Color3.fromRGB(180, 70, 255), enabled = true},
	doors = {name = "Trick-or-treat doors", label = "Trick or Treat", description = "hold candy bucket to show", color = Color3.fromRGB(255, 155, 45), enabled = true},
}
local gui, updatePanel, updateStockPanel
local refreshPrompt, updateVisuals

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function removeEntry(prompt)
	local entry = entries[prompt]
	if not entry then return end
	entries[prompt] = nil
	entry.highlight:Destroy()
	entry.billboard:Destroy()
end

local function createEntry(prompt, categoryKey, target, anchor)
	local category = categories[categoryKey]
	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalVisualHighlight"
	highlight.Adornee = target
	highlight.FillColor, highlight.OutlineColor = category.color, category.color
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = controller
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LocalVisualLabel"
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromOffset(160, 32)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000
	billboard.Enabled = false
	billboard.Parent = controller
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = false
	label.TextSize = 12
	label.TextColor3 = category.color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.Text = category.label
	label.Parent = billboard
	local entry = {
		category = categoryKey, target = target, anchor = anchor,
		highlight = highlight, billboard = billboard, label = label,
		lastDistance = nil,
	}
	entries[prompt] = entry
	return entry
end

local function setHubVisible(enabled)
	hubVisible = enabled
	updatePanel(hubVisible)
end

local function setCategory(key, enabled)
	categories[key].enabled = enabled
	updatePanel(hubVisible)
	updateVisuals()
end

-- Native, self-contained visual controls. No executor, HTTP, or external UI library.
local function buildPanel(playerGui, categories, connections, setCategory, setHubVisible)
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local gui = Instance.new("ScreenGui")
	gui.Name = "LocalVisualControls"; gui.ResetOnSpawn = false; gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = playerGui
	local function keep(c) table.insert(connections, c); return c end
	local function new(className, props, parent)
		local object = Instance.new(className)
		if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
		for property, value in pairs(props) do object[property] = value end
		object.Parent = parent; return object
	end
	local function corner(parent, radius) return new("UICorner", {CornerRadius = UDim.new(0, radius)}, parent) end
	local function label(parent, value, size, color, font)
		return new("TextLabel", {BackgroundTransparency = 1, Text = value, TextColor3 = color, Font = font or Enum.Font.GothamMedium, TextSize = size, TextXAlignment = Enum.TextXAlignment.Left}, parent)
	end
	local panel = new("Frame", {Position = UDim2.fromOffset(18, 72), Size = UDim2.fromOffset(360, 420), BackgroundColor3 = Color3.fromRGB(14, 20, 35), BackgroundTransparency = .04, Active = true}, gui)
	corner(panel, 14); new("UIStroke", {Color = Color3.fromRGB(55, 72, 103), Thickness = 1, Transparency = .2}, panel)
	local scale = new("UIScale", {Scale = 1}, panel); new("UISizeConstraint", {MinSize = Vector2.new(300, 250), MaxSize = Vector2.new(420, 460)}, panel)
	local header = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 52), Position = UDim2.fromOffset(12, 8), Active = true}, panel)
	local title = label(header, "BigTig Lineage Hub", 17, Color3.fromRGB(245, 248, 255), Enum.Font.GothamBold); title.Size = UDim2.new(1, -42, 0, 24)
	local subtitle = label(header, "WORLD VISUALS", 10, Color3.fromRGB(127, 145, 178)); subtitle.Position = UDim2.fromOffset(0, 26); subtitle.Size = UDim2.new(1, -42, 0, 18)
	local hide = new("TextButton", {BackgroundTransparency = 1, Text = "×", TextColor3 = Color3.fromRGB(150, 166, 198), Font = Enum.Font.GothamBold, TextSize = 22, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -30, 0, 0), AutoButtonColor = false}, header)
	keep(hide.Activated:Connect(function() setHubVisible(false) end))
	local cards = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 180), Position = UDim2.fromOffset(12, 63)}, panel); new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, cards)
	local switches, order = {}, {"buyers", "merchant", "doors"}
	local function setSwitch(key, enabled, instant)
		local item = switches[key]; if not item then return end
		if item.enabled == enabled and not instant then return end
		item.enabled = enabled
		item.state.Text = enabled and "ON" or "OFF"; item.state.TextColor3 = enabled and item.accent or Color3.fromRGB(120, 134, 160)
		local goal, thumbGoal = {BackgroundColor3 = enabled and item.accent or Color3.fromRGB(44, 53, 72)}, {Position = enabled and UDim2.new(1, -21, .5, -9) or UDim2.new(0, 3, .5, -9)}
		for _, tween in ipairs(item.tweens) do tween:Cancel() end; item.tweens = {}
		if instant then item.track.BackgroundColor3 = goal.BackgroundColor3; item.thumb.Position = thumbGoal.Position else
			table.insert(item.tweens, TweenService:Create(item.track, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)); table.insert(item.tweens, TweenService:Create(item.thumb, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), thumbGoal)); for _, tween in ipairs(item.tweens) do tween:Play() end
		end
	end
	for index, key in ipairs(order) do
		local category, accent = categories[key], categories[key].color or Color3.fromRGB(97, 165, 250)
		local row = new("TextButton", {LayoutOrder = index, Size = UDim2.new(1, 0, 0, 55), BackgroundColor3 = Color3.fromRGB(23, 31, 50), AutoButtonColor = false, Text = "", Active = true}, cards); corner(row, 9); new("UIStroke", {Color = Color3.fromRGB(44, 57, 82), Thickness = 1, Transparency = .35}, row)
		local name = label(row, category.name, 13, Color3.fromRGB(230, 235, 246), Enum.Font.GothamMedium); name.Position = UDim2.fromOffset(13, 9); name.Size = UDim2.new(1, -105, 0, 20)
		local hint = label(row, category.description or category.label or "World marker", 10, Color3.fromRGB(126, 143, 173), Enum.Font.Gotham); hint.Position = UDim2.fromOffset(13, 29); hint.Size = UDim2.new(1, -105, 0, 16)
		local track = new("Frame", {Size = UDim2.fromOffset(48, 24), Position = UDim2.new(1, -63, .5, -12), BackgroundColor3 = Color3.fromRGB(44, 53, 72)}, row); corner(track, 12)
		local thumb = new("Frame", {Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 3, .5, -9), BackgroundColor3 = Color3.fromRGB(248, 250, 255)}, track); corner(thumb, 9)
		local state = label(row, "OFF", 9, Color3.fromRGB(120, 134, 160), Enum.Font.GothamBold); state.TextXAlignment = Enum.TextXAlignment.Center; state.Position = UDim2.new(1, -62, 0, 38); state.Size = UDim2.fromOffset(48, 12)
		switches[key] = {track = track, thumb = thumb, state = state, accent = accent, tweens = {}}
		keep(row.Activated:Connect(function() setCategory(key, not (categories[key].enabled == true)) end)); setSwitch(key, category.enabled == true, true)
	end

	local stockCard = new("Frame", {
		Name = "DrugStock", Position = UDim2.fromOffset(12, 250),
		Size = UDim2.new(1, -24, 0, 125), BackgroundColor3 = Color3.fromRGB(23, 31, 50),
	}, panel)
	corner(stockCard, 9)
	local stockTitle = label(stockCard, "DRUG STOCK", 12, Color3.fromRGB(230, 235, 246), Enum.Font.GothamBold)
	stockTitle.Position = UDim2.fromOffset(13, 10)
	stockTitle.Size = UDim2.new(1, -26, 0, 20)
	local stockLabels = {}
	for index, name in ipairs({"YABA", "COCA", "TRAM"}) do
		local value = label(stockCard, name .. ": --", 13, Color3.fromRGB(180, 195, 218))
		value.Position = UDim2.fromOffset(13, 33 + (index - 1) * 25)
		value.Size = UDim2.new(1, -26, 0, 22)
		stockLabels[name] = value
	end
	local toast = new("Frame", {
		Name = "RestockNotification", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18), Size = UDim2.new(.85, 0, 0, 94),
		BackgroundColor3 = Color3.fromRGB(23, 31, 50), Visible = false,
	}, gui)
	corner(toast, 12)
	new("UISizeConstraint", {MaxSize = Vector2.new(360, 94)}, toast)
	local toastTitle = label(toast, "DRUGS RESTOCKED", 13, Color3.fromRGB(100, 235, 160), Enum.Font.GothamBold)
	toastTitle.Position = UDim2.fromOffset(14, 10)
	toastTitle.Size = UDim2.new(1, -28, 0, 20)
	local toastText = label(toast, "", 12, Color3.fromRGB(230, 235, 246))
	toastText.Position = UDim2.fromOffset(14, 34)
	toastText.Size = UDim2.new(1, -28, 0, 48)
	toastText.TextWrapped = true
	local toastVersion = 0
	local function updateStockPanel(counts, increases)
		for name, value in pairs(stockLabels) do
			local count = counts[name]
			value.Text = name .. ": " .. (count ~= nil and tostring(count) or "--")
		end
		if #increases == 0 then return end
		toastVersion += 1
		local version = toastVersion
		toastText.Text = table.concat(increases, "  •  ")
		toast.Visible = true
		task.delay(7, function()
			if alive and gui.Parent and version == toastVersion then toast.Visible = false end
		end)
	end

	local footer = label(panel, "Right Shift to Toggle", 10, Color3.fromRGB(127, 145, 178)); footer.Position = UDim2.new(0, 14, 1, -28); footer.Size = UDim2.new(1, -28, 0, 16)
	local loading = true
	panel.Visible = false
	local splash = new("Frame", {
		Name = "LoadingSplash", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5), Size = UDim2.new(.8, 0, 0, 100),
		BackgroundColor3 = Color3.fromRGB(14, 20, 35), BackgroundTransparency = .08,
	}, gui)
	corner(splash, 14)
	new("UISizeConstraint", {MaxSize = Vector2.new(480, 100)}, splash)
	local loadingText = label(splash, "NIC IS GAY", 36, Color3.new(1, 1, 1), Enum.Font.GothamBold)
	loadingText.Size = UDim2.fromScale(1, 1)
	loadingText.TextXAlignment = Enum.TextXAlignment.Center
	loadingText.TextScaled = true
	new("UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 36}, loadingText)
	local colors = {}
	for index = 0, 6 do
		table.insert(colors, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1)))
	end
	local rainbow = new("UIGradient", {Color = ColorSequence.new(colors)}, loadingText)
	local rainbowTween = TweenService:Create(rainbow, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
	rainbowTween:Play()
	keep(gui.Destroying:Connect(function() rainbowTween:Cancel() end))
	task.delay(10, function()
		rainbowTween:Cancel()
		if not alive or not gui.Parent then return end
		splash:Destroy()
		loading = false
		panel.Visible = hubVisible
	end)
	local dragStart, panelStart
	local function availableSize()
		local size = gui.AbsoluteSize
		if size.X > 0 and size.Y > 0 then return size end
		return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
	end
	keep(header.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart, panelStart = input.Position, panel.Position end end))
	keep(UserInputService.InputChanged:Connect(function(input)
		if not dragStart or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end
		local delta = input.Position - dragStart
		local viewport = availableSize()
		local maxX = math.max(8, viewport.X - panel.AbsoluteSize.X - 8)
		local maxY = math.max(8, viewport.Y - panel.AbsoluteSize.Y - 8)
		panel.Position = UDim2.fromOffset(math.clamp(panelStart.X.Offset + delta.X, 8, maxX), math.clamp(panelStart.Y.Offset + delta.Y, 8, maxY))
	end))
	keep(UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart = nil end end))
	local function fitViewport()
		local viewport = availableSize()
		scale.Scale = math.clamp(math.min(viewport.X / 400, viewport.Y / 460), .55, 1)
		local maxX = math.max(8, viewport.X - panel.AbsoluteSize.X - 8)
		local maxY = math.max(8, viewport.Y - panel.AbsoluteSize.Y - 8)
		panel.Position = UDim2.fromOffset(math.clamp(panel.Position.X.Offset, 8, maxX), math.clamp(panel.Position.Y.Offset, 8, maxY))
	end
	fitViewport()
	keep(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitViewport))
	keep(gui.Destroying:Connect(function() for _, item in pairs(switches) do for _, tween in ipairs(item.tweens) do tween:Cancel() end end end))
	local function updatePanel(enabled)
		panel.Visible = enabled == true and not loading
		for key, category in pairs(categories) do setSwitch(key, category.enabled == true, false) end
	end
	return gui, updatePanel, updateStockPanel
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local function classify(prompt)
	local model = prompt:FindFirstAncestorOfClass("Model")
	if model then
		local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
		local part = prompt:FindFirstAncestorWhichIsA("BasePart")
		local anchor = head and head:IsA("BasePart") and head or part
		if anchor then
			if model.Name == "ขายยา" and prompt.ObjectText == "ขายยา" and prompt.ActionText == "ขายยา" then
				return "buyers", model, anchor
			end
			if (prompt.ObjectText == "พ่อค้าพเนจร" and prompt.ActionText == "เปิดร้าน")
				or (prompt.Name == "openshop" and (model.Name:match("^SecretShopNPC_%d+$") or model.Name == "พ่อค้าพเนจร")) then
				return "merchant", model, anchor
			end
		end
	end
	local halloween = Workspace:FindFirstChild("Helloween")
	local savedDoor = prompt.Name == "KnockPrompt" and halloween and prompt:IsDescendantOf(halloween)
	local taggedDoor = prompt:GetAttribute("HKind") == "knock" and CollectionService:HasTag(prompt, "HalloweenPrompt")
	if savedDoor or taggedDoor then
		local anchor = prompt:FindFirstAncestorWhichIsA("BasePart")
		if not anchor then return end
		local target = anchor
		local ancestor = prompt.Parent
		while ancestor and ancestor ~= Workspace do
			if (ancestor.Name == "ประตู" or ancestor.Name == "ประตู้")
				and (ancestor:IsA("Model") or ancestor:IsA("BasePart")) then
				target = ancestor
				break
			end
			ancestor = ancestor.Parent
		end
		return "doors", target, anchor
	end
end

local function doorAvailable(prompt, now)
	-- Enabled also reflects the game's equipped-container requirement.
	if not prompt.Enabled or prompt:GetAttribute("Busy") then return false end
	if prompt:GetAttribute("Golden") == true then
		local halloween = ReplicatedStorage:FindFirstChild("Halloween")
		local id = halloween and halloween:GetAttribute("GoldenId")
		return not (type(id) == "string" and id ~= "" and player:GetAttribute("GoldClaimed") == id)
	end
	local readyAt = prompt:GetAttribute("ReadyAt")
	return type(readyAt) ~= "number" or readyAt <= now
end

local function renderEntry(prompt, entry, root, now)
	local category = categories[entry.category]
	local enabled = category.enabled and prompt.Enabled
	if enabled and entry.category == "doors" then enabled = doorAvailable(prompt, now) end
	if entry.highlight.Enabled ~= enabled then entry.highlight.Enabled = enabled end
	if entry.billboard.Enabled ~= enabled then entry.billboard.Enabled = enabled end
	if not enabled then return end
	local distance = root and math.floor((root.Position - entry.anchor.Position).Magnitude)
	if distance ~= entry.lastDistance then
		entry.lastDistance = distance
		entry.label.Text = category.label .. (distance and string.format("\n%d studs", distance) or "\n-- studs")
	end
end

local function localRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

refreshPrompt = function(prompt)
	if not alive or not watched[prompt] then return end
	if not prompt:IsDescendantOf(Workspace) then removeEntry(prompt); return end
	local key, target, anchor = classify(prompt)
	if not key then removeEntry(prompt); return end
	local entry = entries[prompt]
	if not entry or entry.target ~= target or entry.anchor ~= anchor or entry.category ~= key then
		removeEntry(prompt)
		entry = createEntry(prompt, key, target, anchor)
	end
	renderEntry(prompt, entry, localRoot(), Workspace:GetServerTimeNow())
end

updateVisuals = function()
	if not alive then return end
	local root, now = localRoot(), Workspace:GetServerTimeNow()
	for prompt, entry in pairs(entries) do
		if not prompt:IsDescendantOf(Workspace) then
			removeEntry(prompt)
		elseif not entry.anchor:IsDescendantOf(Workspace) or not entry.target:IsDescendantOf(Workspace) then
			refreshPrompt(prompt)
		else
			renderEntry(prompt, entry, root, now)
		end
	end
end

local function unwatch(prompt)
	local record = watched[prompt]
	if not record then return end
	watched[prompt] = nil
	for _, connection in ipairs(record.connections) do connection:Disconnect() end
	removeEntry(prompt)
end

local function watch(prompt)
	if not alive or watched[prompt] or not prompt:IsA("ProximityPrompt") then return end
	local record = {connections = {}, pending = false}
	watched[prompt] = record
	local function schedule()
		if not alive or watched[prompt] ~= record or record.pending then return end
		record.pending = true
		task.defer(function()
			record.pending = false
			if alive and watched[prompt] == record then refreshPrompt(prompt) end
		end)
	end
	-- Observe text changes too: streamed prompts can arrive before their properties.
	for _, property in ipairs({"Name", "ObjectText", "ActionText", "Enabled"}) do
		table.insert(record.connections, prompt:GetPropertyChangedSignal(property):Connect(schedule))
	end
	table.insert(record.connections, prompt.AttributeChanged:Connect(function(name)
		if name == "HKind" or name == "Busy" or name == "ReadyAt" or name == "Golden" then schedule() end
	end))
	table.insert(record.connections, prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(Workspace) then unwatch(prompt) else schedule() end
	end))
	refreshPrompt(prompt)
end

gui, updatePanel, updateStockPanel = buildPanel(playerGui, categories, connections, setCategory, setHubVisible)
updatePanel(hubVisible)
connect(UserInputService.InputBegan, function(input, processed)
	if input.KeyCode == Enum.KeyCode.RightShift and not processed and not UserInputService:GetFocusedTextBox() then
		setHubVisible(not hubVisible)
	end
end)

connect(Workspace.DescendantAdded, function(instance)
	if instance:IsA("ProximityPrompt") then
		watch(instance)
	elseif instance:IsA("BasePart") and (instance.Name == "Head" or instance.Name == "HumanoidRootPart") then
		local model = instance:FindFirstAncestorOfClass("Model")
		if model then
			-- A streamed prompt may have arrived before its NPC's body parts.
			for _, descendant in ipairs(model:GetDescendants()) do
				if watched[descendant] then refreshPrompt(descendant) end
			end
		end
	end
end)
connect(CollectionService:GetInstanceAddedSignal("HalloweenPrompt"), function(instance)
	if instance:IsA("ProximityPrompt") and instance:IsDescendantOf(Workspace) then
		watch(instance)
		refreshPrompt(instance)
	end
end)
connect(CollectionService:GetInstanceRemovedSignal("HalloweenPrompt"), function(instance)
	if watched[instance] then refreshPrompt(instance) end
end)
connect(player.CharacterAdded, function() task.defer(updateVisuals) end)
connect(player:GetAttributeChangedSignal("GoldClaimed"), updateVisuals)
connect(controller.Destroying, function()
	alive = false
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for prompt in pairs(watched) do unwatch(prompt) end
	gui:Destroy()
end)

local initial = Workspace:GetDescendants()
for index, instance in ipairs(initial) do
	if not alive then break end
	if instance:IsA("ProximityPrompt") then
		watch(instance)
	elseif (instance:IsA("Highlight") or instance:IsA("BillboardGui"))
		and (instance.Name == "LocalBuyerHighlight" or instance.Name == "LocalTravelingMerchantHighlight"
			or instance.Name == "LocalBuyerHighlightBillboard" or instance.Name == "LocalTravelingMerchantHighlightBillboard") then
		instance:Destroy()
	end
	if index % 2000 == 0 then task.wait() end
end
initial = nil
updateVisuals()
task.spawn(function()
	while alive do
		task.wait(0.3)
		if alive then updateVisuals() end
	end
end)
local stockItems = {
	{name = "YABA", id = "ยาบ้า"},
	{name = "COCA", id = "ผงไอซ์"},
	{name = "TRAM", id = "เขียวเหลือง"},
}

local function readStockSnapshot(snapshot, previous)
	if type(snapshot) ~= "table" then return nil end
	local counts, increases = {}, {}
	for _, item in ipairs(stockItems) do
		local count = snapshot[item.id]
		if count == nil then count = 0 end
		if type(count) ~= "number" or count ~= count or count < 0 or count == math.huge then
			return nil
		end
		count = math.floor(count)
		counts[item.name] = count
		if previous and count > previous[item.name] then
			table.insert(increases, item.name .. ": " .. count)
		end
	end
	return counts, increases
end

-- Subscribe before the initial read so an older response cannot replace an event.
task.spawn(function()
	local job = ReplicatedStorage:WaitForChild("Job", 10)
	if not job or not alive then return end
	local stockUpdated = job:WaitForChild("StockUpdated", 10)
	local getStock = job:WaitForChild("GetStock", 10)
	if not alive then return end
	local previous, revision = nil, 0
	local function accept(snapshot)
		if not alive then return end
		local counts, increases = readStockSnapshot(snapshot, previous)
		if not counts then return end
		previous = counts
		revision += 1
		updateStockPanel(counts, increases)
	end
	if stockUpdated and stockUpdated:IsA("RemoteEvent") then
		connect(stockUpdated.OnClientEvent, accept)
	end
	if getStock and getStock:IsA("RemoteFunction") then
		local before = revision
		local success, snapshot = pcall(function() return getStock:InvokeServer() end)
		if success and alive and revision == before then accept(snapshot) end
	end
end)
