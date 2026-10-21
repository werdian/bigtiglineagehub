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
local aimGui
local aimSettings = {
 name = "Silent aim", description = "90 px radius • closest player",
 color = Color3.fromRGB(120, 180, 255), enabled = false, ready = false,
 status = "Silent aim: checking weapon support…",
}
local function setAimEnabled(enabled)
 aimSettings.enabled = enabled == true and aimSettings.ready
 if aimGui then aimGui.Enabled = aimSettings.enabled end
 if aimSettings.ready then
  aimSettings.status = aimSettings.enabled and "Silent aim: ON — 90 px radius" or "Silent aim: OFF"
 end
 if updatePanel then updatePanel(hubVisible) end
end

local inspectConnections = type(getconnections) == "function" and getconnections or nil
local autoSettings = {
	name = "Auto drug minigame", description = "Clicks the active glowing box",
	color = Color3.fromRGB(100, 200, 255), enabled = false,
	status = inspectConnections and "OFF — open a buyer minigame to use." or "Unavailable: this runner does not support getconnections.",
}
local function setAutoEnabled(enabled, status)
	autoSettings.enabled = enabled == true and inspectConnections ~= nil
	autoSettings.status = status or (not inspectConnections and "Unavailable: this runner does not support getconnections."
		or (autoSettings.enabled and "ON — waiting for a buyer minigame." or "OFF"))
	if updatePanel then updatePanel(hubVisible) end
end

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
	if entry.goldenBox then entry.goldenBox:Destroy() end
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
	label.RichText = true
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

-- Native visual controls; automation capability is checked separately.
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
	local panel = new("Frame", {Position = UDim2.fromOffset(18, 72), Size = UDim2.fromOffset(490, 350), BackgroundColor3 = Color3.fromRGB(14, 20, 35), BackgroundTransparency = .04, Active = true}, gui)
	corner(panel, 14); new("UIStroke", {Color = Color3.fromRGB(55, 72, 103), Thickness = 1, Transparency = .2}, panel)
	local scale = new("UIScale", {Scale = 1}, panel); new("UISizeConstraint", {MinSize = Vector2.new(490, 350), MaxSize = Vector2.new(520, 400)}, panel)
	local header = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 52), Position = UDim2.fromOffset(12, 8), Active = true}, panel)
	local title = label(header, "BigTig Lineage Hub", 17, Color3.fromRGB(245, 248, 255), Enum.Font.GothamBold); title.Size = UDim2.new(1, -42, 0, 24)
	local subtitle = label(header, "VISUALS", 10, Color3.fromRGB(127, 145, 178)); subtitle.Position = UDim2.fromOffset(0, 26); subtitle.Size = UDim2.new(1, -42, 0, 18)
	local hide = new("TextButton", {BackgroundTransparency = 1, Text = "×", TextColor3 = Color3.fromRGB(150, 166, 198), Font = Enum.Font.GothamBold, TextSize = 22, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -30, 0, 0), AutoButtonColor = false}, header)
	keep(hide.Activated:Connect(function() setHubVisible(false) end))

	local sidebar = new("Frame", {Name = "Tabs", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 64), Size = UDim2.new(0, 102, 1, -108)}, panel)
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
	local pages, tabs = {}, {}
	local function selectTab(selected)
		for name, page in pairs(pages) do
			local active = name == selected
			page.Visible = active
			tabs[name].BackgroundColor3 = active and Color3.fromRGB(47, 67, 105) or Color3.fromRGB(23, 31, 50)
			tabs[name].TextColor3 = active and Color3.fromRGB(245, 248, 255) or Color3.fromRGB(127, 145, 178)
		end
		subtitle.Text = selected
	end
	for index, name in ipairs({"VISUALS", "AUTO", "STOCK"}) do
		pages[name] = new("Frame", {Name = name, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(126, 64), Size = UDim2.new(1, -138, 1, -108),
			Visible = false}, panel)
		local button = new("TextButton", {Name = name, LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 38), Text = name, Font = Enum.Font.GothamBold,
			TextSize = 12, AutoButtonColor = false}, sidebar)
		corner(button, 9)
		tabs[name] = button
		keep(button.Activated:Connect(function() selectTab(name) end))
	end
	selectTab("VISUALS")
	local cards = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 180)}, pages.VISUALS)
	new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, cards)
	local autoStatus = label(pages.AUTO, autoSettings.status, 12, Color3.fromRGB(150, 166, 198))
	autoStatus.Position = UDim2.fromOffset(0, 128)
	autoStatus.Size = UDim2.new(1, 0, 0, 44)
	autoStatus.TextWrapped = true
 local aimStatus = label(pages.AUTO, aimSettings.status, 12, Color3.fromRGB(150, 166, 198))
 aimStatus.Position = UDim2.fromOffset(0, 178)
 aimStatus.Size = UDim2.new(1, 0, 0, 50)
 aimStatus.TextWrapped = true

	local switches, order = {}, {"buyers", "merchant", "doors", "auto", "aim"}
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
		local category = key == "auto" and autoSettings or (key == "aim" and aimSettings or categories[key])
		local accent = category.color
		local rowParent = (key == "auto" or key == "aim") and pages.AUTO or cards
		local row = new("TextButton", {LayoutOrder = index, Size = UDim2.new(1, 0, 0, 55), BackgroundColor3 = Color3.fromRGB(23, 31, 50), AutoButtonColor = false, Text = "", Active = true}, rowParent); corner(row, 9); new("UIStroke", {Color = Color3.fromRGB(44, 57, 82), Thickness = 1, Transparency = .35}, row)
		if key == "aim" then row.Position = UDim2.fromOffset(0, 62) end
		local name = label(row, category.name, 13, Color3.fromRGB(230, 235, 246), Enum.Font.GothamMedium); name.Position = UDim2.fromOffset(13, 9); name.Size = UDim2.new(1, -105, 0, 20)
		local hint = label(row, category.description or category.label or "World marker", 10, Color3.fromRGB(126, 143, 173), Enum.Font.Gotham); hint.Position = UDim2.fromOffset(13, 29); hint.Size = UDim2.new(1, -105, 0, 16)
		local track = new("Frame", {Size = UDim2.fromOffset(48, 24), Position = UDim2.new(1, -63, .5, -12), BackgroundColor3 = Color3.fromRGB(44, 53, 72)}, row); corner(track, 12)
		local thumb = new("Frame", {Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 3, .5, -9), BackgroundColor3 = Color3.fromRGB(248, 250, 255)}, track); corner(thumb, 9)
		local state = label(row, "OFF", 9, Color3.fromRGB(120, 134, 160), Enum.Font.GothamBold); state.TextXAlignment = Enum.TextXAlignment.Center; state.Position = UDim2.new(1, -62, 0, 38); state.Size = UDim2.fromOffset(48, 12)
		switches[key] = {track = track, thumb = thumb, state = state, accent = accent, tweens = {}}
		keep(row.Activated:Connect(function()
			if key == "auto" then setAutoEnabled(not autoSettings.enabled)
			elseif key == "aim" then setAimEnabled(not aimSettings.enabled)
			else setCategory(key, not categories[key].enabled) end
		end))
		setSwitch(key, category.enabled == true, true)
	end

	local stockCard = new("Frame", {
		Name = "DrugStock", Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 125), BackgroundColor3 = Color3.fromRGB(23, 31, 50),
	}, pages.STOCK)
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
	loadingText.Size = UDim2.new(1, 0, 0, 65)
	loadingText.TextXAlignment = Enum.TextXAlignment.Center
	loadingText.TextScaled = true
	new("UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 36}, loadingText)
	local loadingStatus = label(splash, "SCRIPT IS LOADING.", 14, Color3.new(1, 1, 1))
	loadingStatus.Position = UDim2.fromOffset(0, 65)
	loadingStatus.Size = UDim2.new(1, 0, 0, 25)
	loadingStatus.TextXAlignment = Enum.TextXAlignment.Center
	task.spawn(function()
		local messages = {"SCRIPT IS LOADING.", "SCRIPT IS LOADING..", "SCRIPT IS LOADING..."}
		local index = 1
		while alive and loading and splash.Parent do
			loadingStatus.Text = messages[index]
			index = index % #messages + 1
			task.wait(0.6)
		end
	end)
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
		scale.Scale = math.clamp(math.min(viewport.X / 530, viewport.Y / 390), .4, 1)
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
		setSwitch("auto", autoSettings.enabled, false)
		autoStatus.Text = autoSettings.status
		setSwitch("aim", aimSettings.enabled, false)
		aimStatus.Text = aimSettings.status
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
	-- Golden event markers remain visible without an equipped bucket.
	if prompt:GetAttribute("Golden") == true then
		local halloween = ReplicatedStorage:FindFirstChild("Halloween")
		local id = halloween and halloween:GetAttribute("GoldenId")
		return not (type(id) == "string" and id ~= "" and player:GetAttribute("GoldClaimed") == id)
	end
	if not prompt.Enabled or prompt:GetAttribute("Busy") then return false end
	local readyAt = prompt:GetAttribute("ReadyAt")
	return type(readyAt) ~= "number" or readyAt <= now
end


local function updateGoldenBox(entry, visible)
	if not visible then
		if entry.goldenBox then entry.goldenBox.Visible = false end
		return
	end
	local box = entry.goldenBox
	if not box or not box.Parent then
		box = Instance.new("BoxHandleAdornment")
		box.Name = "LocalGoldenDoorBox"
		box.AlwaysOnTop = true
		box.ZIndex = 10
		box.Color3 = Color3.fromRGB(255, 235, 40)
		box.Transparency = 0.55
		box.Parent = controller
		entry.goldenBox = box
	end
	local bounds, size
	if entry.target:IsA("Model") then
		bounds, size = entry.target:GetBoundingBox()
	else
		bounds, size = entry.target.CFrame, entry.target.Size
	end
	box.Adornee = entry.anchor
	box.CFrame = entry.anchor.CFrame:ToObjectSpace(bounds)
	box.Size = size + Vector3.new(0.12, 0.12, 0.12)
	box.Visible = true
end

local function renderEntry(prompt, entry, root, now)
	local category = categories[entry.category]
	local golden = entry.category == "doors" and prompt:GetAttribute("Golden") == true
	local styleChanged = entry.golden ~= golden
	if styleChanged then
		entry.golden = golden
		local color = golden and Color3.fromRGB(255, 235, 40) or category.color
		entry.highlight.FillColor = color
		entry.highlight.OutlineColor = golden and Color3.fromRGB(255, 255, 190) or color
		entry.highlight.FillTransparency = golden and 0.3 or 0.65
		entry.label.TextColor3 = color
		entry.billboard.Size = golden and UDim2.fromOffset(240, 72) or UDim2.fromOffset(160, 32)
		entry.billboard.StudsOffsetWorldSpace = Vector3.new(0, golden and 4 or 2.8, 0)
	end
	local enabled = category.enabled
	if entry.category == "doors" then
		enabled = enabled and doorAvailable(prompt, now)
	else
		enabled = enabled and prompt.Enabled
	end
	updateGoldenBox(entry, enabled and golden)
	local showHighlight = enabled and not golden
	if entry.highlight.Enabled ~= showHighlight then entry.highlight.Enabled = showHighlight end
	if entry.billboard.Enabled ~= enabled then entry.billboard.Enabled = enabled end
	local distance = enabled and root and math.floor((root.Position - entry.anchor.Position).Magnitude) or nil
	if styleChanged or (enabled and distance ~= entry.lastDistance) then
		entry.lastDistance = distance
		local heading = golden and '<font size="26"><b>5X GOLDEN</b></font>\n' or ""
		entry.label.Text = heading .. category.label .. (distance and string.format("\n%d studs", distance) or "\n-- studs")
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

local function activeSaleButton(sale)
	if not sale or not sale.Enabled then return nil end
	local card = sale:FindFirstChild("Card")
	if not card or not card.Visible then return nil end
	local area = card:FindFirstChild("GameArea")
	if not area or not area.Visible then return nil end
	local result = area:FindFirstChild("Result")
	if result and result.Visible then return nil end
	for _, button in ipairs(area:GetChildren()) do
		if button:IsA("TextButton") and button.Visible then
			local icon = button:FindFirstChildOfClass("TextLabel")
			if icon and icon.Text == "💊" then
				for _, child in ipairs(button:GetChildren()) do
					if child:IsA("Frame") and child.ZIndex == 12 and child.Visible then
						return button
					end
				end
			end
		end
	end
	return nil
end

local function scheduleSaleClick(button, onError)
	local success, handler = pcall(function()
		local callback
		for _, connection in ipairs(inspectConnections(button.MouseButton1Click)) do
			if connection.Enabled ~= false and connection.ForeignState ~= true
				and type(connection.Function) == "function" then
				if callback then error("More than one sale click handler found") end
				callback = connection.Function
			end
		end
		assert(callback, "No callable sale click handler found")
		return callback
	end)
	if not success then return false, tostring(handler) end
	-- The game's handler yields before advancing. Let Roblox schedule those waits.
	task.spawn(function()
		local ok, message = pcall(handler)
		if not ok then onError(tostring(message)) end
	end)
	return true
end

task.spawn(function()
	local lastClicked
	while alive do
		if not autoSettings.enabled then
			task.wait(0.25)
		else
			local sale = playerGui:FindFirstChild("SaleUI")
			local button = activeSaleButton(sale)
			if button and button ~= lastClicked and not UserInputService:GetFocusedTextBox() then
				-- The game arms the active box 0.1 seconds after revealing it.
				task.wait(0.18)
				if alive and autoSettings.enabled and activeSaleButton(sale) == button
					and not UserInputService:GetFocusedTextBox() then
					lastClicked = button
					local function reportError(message)
						if not alive then return end
						setAutoEnabled(false, "AUTO stopped: " .. message:sub(1, 160))
						warn("Lineage Hub auto minigame: " .. message)
					end
					local success, message = scheduleSaleClick(button, reportError)
					if not success then reportError(message) end
				end
			end
			task.wait(0.05)
		end
	end
end)

-- Keep the FOV in viewport pixels, independent of hub scaling and visibility.
aimGui = Instance.new("ScreenGui")
aimGui.Name = "LineageAimFOV"
aimGui.IgnoreGuiInset = true
aimGui.ResetOnSpawn = false
aimGui.DisplayOrder = 29
aimGui.Enabled = false
aimGui.Parent = playerGui
local circle = Instance.new("Frame")
circle.Name = "FOV90"
circle.AnchorPoint = Vector2.new(0.5, 0.5)
circle.Position = UDim2.fromScale(0.5, 0.5)
circle.Size = UDim2.fromOffset(180, 180)
circle.BackgroundTransparency = 1
circle.BorderSizePixel = 0
circle.Parent = aimGui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(1, 0)
round.Parent = circle
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(220, 235, 255)
outline.Thickness = 1.5
outline.Transparency = 0.15
outline.Parent = circle
local restoreProjectile
connect(controller.Destroying, function()
 aimSettings.enabled = false
 aimGui:Destroy()
 if restoreProjectile then restoreProjectile() end
end)

local function selectAimPart()
 local camera = Workspace.CurrentCamera
 if not camera then return nil end
 local center = camera.ViewportSize * 0.5
 local best, bestDistance = nil, 90 * 90
 for _, candidate in ipairs(Players:GetPlayers()) do
  if candidate ~= player then
   local character = candidate.Character
   local humanoid = character and character:FindFirstChildOfClass("Humanoid")
   local part = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
   if humanoid and humanoid.Health > 0 and part and part:IsA("BasePart") then
    local point, visible = camera:WorldToViewportPoint(part.Position)
    if visible and point.Z > 0 then
     local distance = (point.X - center.X)^2 + (point.Y - center.Y)^2
     if distance <= bestDistance then best, bestDistance = part, distance end
    end
   end
  end
 end
 return best
end

local function redirectDirections(directions, origin, position)
 if type(directions) ~= "table" or typeof(origin) ~= "Vector3" then return directions end
 local offset = position - origin
 if offset.Magnitude < 0.001 then return directions end
 local result = table.clone(directions)
 for index, direction in pairs(directions) do
  if typeof(direction) == "Vector3" then result[index] = offset.Unit * direction.Magnitude end
 end
 return result
end

task.spawn(function()
 local modules = ReplicatedStorage:WaitForChild("Modules", 10)
 local module = modules and modules:WaitForChild("ProjectileHandler", 10)
 if not alive then return end
 local success, handler = pcall(function() return module and require(module) end)
 if not alive then return end
 if not success or type(handler) ~= "table" or type(handler.SimulateProjectile) ~= "function" then
  aimSettings.status = "Silent aim unavailable: projectile module could not load."
  setAimEnabled(false)
  return
 end
 local original = handler.SimulateProjectile
 local function wrapped(self, ...)
  local args = table.pack(...)
  -- The inspected module uses argument 14 only for locally fired, damaging bullets.
  if alive and aimSettings.enabled and args[14] ~= nil then
   local character = player.Character
   local owned = character and args[3] == character
   for index = 1, 2 do
    local object = args[index]
    if character and typeof(object) == "Instance" and object:IsDescendantOf(character) then owned = true end
   end
   if owned then
    local part = selectAimPart()
    local muzzle = args[7]
    if part and typeof(muzzle) == "Instance" and muzzle:IsA("Attachment") then
     local visualOrigin = muzzle.WorldPosition
     local origin = visualOrigin
     if typeof(args[4]) == "Instance" then
      local alternate = args[4]:FindFirstChild("GunFirePoint")
      if alternate and alternate:IsA("Attachment") then origin = alternate.WorldPosition end
     end
     args[5] = redirectDirections(args[5], origin, part.Position)
     args[6] = redirectDirections(args[6], visualOrigin, part.Position)
    end
   end
  end
  return original(self, table.unpack(args, 1, args.n))
 end
 local installed = pcall(function() handler.SimulateProjectile = wrapped end)
 if not installed then
  aimSettings.status = "Silent aim unavailable: projectile module is read-only."
  setAimEnabled(false)
  return
 end
 restoreProjectile = function()
  if handler.SimulateProjectile == wrapped then handler.SimulateProjectile = original end
 end
 aimSettings.ready = true
 setAimEnabled(false)
end)
