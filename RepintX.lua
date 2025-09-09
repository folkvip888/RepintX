--[[
  One-file Client Script — Server Hop + Rejoin + Auto-Hop (cap 1–10)
  วิธีใช้: Execute/Command Bar/LocalScript ก็ได้ (ต้องกด Play ใน Studio เพื่อให้ LocalPlayer มีค่า)
  หมายเหตุ:
    • สคริปต์นี้เรียก API รายชื่อเซิร์ฟเวอร์ของ Roblox: games.roblox.com (ถ้าเกมปิด HTTP อาจดึงลิสต์ไม่ได้)
    • ถ้าดึงไม่ได้ ยังสามารถใช้ปุ่ม Rejoin (กลับเข้าห้องใหม่อัตโนมัติ) ได้ตามปกติ
--]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local placeId = game.PlaceId
local thisJobId = game.JobId

-- ============ UI ============

local function createRound(obj, r)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, r or 12)
	ui.Parent = obj
	return ui
end

local gui = Instance.new("ScreenGui")
gui.Name = "ServerHopUI"
gui.ResetOnSpawn = false
pcall(function()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end)

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.fromOffset(360, 220)
frame.Position = UDim2.fromScale(0.08, 0.2)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
frame.BorderSizePixel = 0
frame.Parent = gui
createRound(frame, 16)

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.BackgroundTransparency = 1
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.fromScale(0.5, 0.5)
shadow.Size = UDim2.fromScale(1, 1)
shadow.ZIndex = 0
shadow.Image = "rbxassetid://5028857084"
shadow.ImageTransparency = 0.35
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24,24,276,276)
shadow.Parent = frame

local header = Instance.new("TextLabel")
header.Text = "Server Hop"
header.Font = Enum.Font.GothamBold
header.TextSize = 20
header.TextColor3 = Color3.fromRGB(240,240,255)
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, -16, 0, 40)
header.Position = UDim2.fromOffset(16, 8)
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
closeBtn.AutoButtonColor = true
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
closeBtn.Parent = frame
createRound(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- Drag
do
	local dragging, dragStart, startPos
	frame.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = i.Position
			startPos = frame.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	frame.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = i.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Slider (1–10)
local sliderLabel = Instance.new("TextLabel")
sliderLabel.Text = "Max players (≤): 5"
sliderLabel.Font = Enum.Font.GothamMedium
sliderLabel.TextSize = 15
sliderLabel.TextColor3 = Color3.fromRGB(210,215,230)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Position = UDim2.fromOffset(16, 56)
sliderLabel.Size = UDim2.fromOffset(300, 18)
sliderLabel.Parent = frame

local slider = Instance.new("Frame")
slider.BackgroundColor3 = Color3.fromRGB(34,34,46)
slider.Size = UDim2.fromOffset(300, 6)
slider.Position = UDim2.fromOffset(16, 80)
slider.Parent = frame
createRound(slider, 6)

local fill = Instance.new("Frame")
fill.BackgroundColor3 = Color3.fromRGB(88,128,255)
fill.Size = UDim2.fromOffset(150, 6)
fill.Parent = slider
createRound(fill, 6)

local knob = Instance.new("Frame")
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.fromOffset(fill.Size.X.Offset, 3)
knob.Size = UDim2.fromOffset(18,18)
knob.BackgroundColor3 = Color3.fromRGB(120,160,255)
knob.Parent = slider
createRound(knob, 9)

local sliderValue = 5
local sliding = false

local function setSliderFromX(x)
	local rel = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
	local px = math.floor(rel * slider.AbsoluteSize.X + 0.5)
	fill.Size = UDim2.fromOffset(px, 6)
	knob.Position = UDim2.fromOffset(px, 3)
	-- map 0..1 -> 1..10 (step 1)
	local v = math.clamp(math.floor(rel * 9 + 1 + 0.5), 1, 10)
	sliderValue = v
	sliderLabel.Text = ("Max players (≤): %d"):format(v)
end

slider.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		sliding = true
		setSliderFromX(i.Position.X)
	end
end)
slider.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		sliding = false
	end
end)
slider.InputChanged:Connect(function(i)
	if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
		setSliderFromX(i.Position.X)
	end
end)

-- Buttons
local function makeBtn(text, x, y, w)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 15
	b.TextColor3 = Color3.fromRGB(235,238,255)
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(40,40,56)
	b.Size = UDim2.fromOffset(w or 150, 34)
	b.Position = UDim2.fromOffset(x, y)
	b.Parent = frame
	createRound(b, 10)
	return b
end

local btnRefresh = makeBtn("Refresh Servers", 16, 110, 150)
local btnHop = makeBtn("Hop Now", 186, 110, 150)
local btnRejoin = makeBtn("Rejoin", 16, 154, 150)
local btnAuto = makeBtn("Auto-Hop: OFF", 186, 154, 150)

local statusLabel = Instance.new("TextLabel")
statusLabel.Text = "Ready"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(180,185,205)
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(16, 194)
statusLabel.Size = UDim2.fromOffset(320, 20)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local function setStatus(t)
	statusLabel.Text = t
end

-- ============ Logic ============

local function httpGet(url)
	-- ใช้ HttpService โดยตรง (ถ้าเกมอนุญาต)
	local ok, res = pcall(function() return HttpService:GetAsync(url) end)
	if ok then return res end
	return nil, res
end

local function fetchServersPage(cursor)
	local base = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(placeId)
	local url = cursor and (base .. "&cursor=" .. HttpService:UrlEncode(cursor)) or base
	return httpGet(url)
end

local function chooseServer(cap)
	local cursor = nil
	local best = nil
	repeat
		local body, err = fetchServersPage(cursor)
		if not body then
			return nil, ("Fetch failed: %s"):format(tostring(err))
		end
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if not ok or not data or not data.data then
			return nil, "Parse JSON failed."
		end
		for _, srv in ipairs(data.data) do
			local id = srv.id
			local playing = tonumber(srv.playing) or 0
			local maxPlayers = tonumber(srv.maxPlayers) or 0
			local hasSlot = playing < maxPlayers
			if hasSlot and id ~= thisJobId and playing <= cap then
				if not best or playing < (best.playing or 1/0) then
					best = { id = id, playing = playing, maxPlayers = maxPlayers }
				end
			end
		end
		cursor = data.nextPageCursor
	until not cursor
	if not best then
		return nil, ("No server found with ≤ %d players."):format(cap)
	end
	return best
end

local isAuto = false
local autoConn

local function teleportToJob(jobId)
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, jobId, localPlayer)
	end)
	if not ok then
		setStatus("Teleport failed: ".. tostring(err))
	end
end

local function rejoin()
	local ok, err = pcall(function()
		TeleportService:Teleport(placeId, localPlayer)
	end)
	if not ok then
		setStatus("Rejoin failed: ".. tostring(err))
	end
end

-- Anim feedback
local function pulse(btn)
	pcall(function()
		local t1 = TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(60,60,90)})
		local t2 = TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(40,40,56)})
		t1:Play(); t1.Completed:Wait(); t2:Play()
	end)
end

-- Handlers
btnRefresh.MouseButton1Click:Connect(function()
	pulse(btnRefresh)
	setStatus("Scanning servers (≤ "..sliderValue..") ...")
	local srv, err = chooseServer(sliderValue)
	if srv then
		setStatus(("Found: %s players %d/%d"):format(srv.id, srv.playing, srv.maxPlayers))
	else
		setStatus(err or "No server.")
	end
end)

btnHop.MouseButton1Click:Connect(function()
	pulse(btnHop)
	setStatus("Finding server to hop ...")
	local srv, err = chooseServer(sliderValue)
	if srv then
		setStatus(("Teleporting to %s (%d/%d)") :format(srv.id, srv.playing, srv.maxPlayers))
		teleportToJob(srv.id)
	else
		setStatus(err or "No server.")
	end
end)

btnRejoin.MouseButton1Click:Connect(function()
	pulse(btnRejoin)
	setStatus("Rejoining ...")
	rejoin()
end)

btnAuto.MouseButton1Click:Connect(function()
	isAuto = not isAuto
	btnAuto.Text = isAuto and "Auto-Hop: ON" or "Auto-Hop: OFF"
	pulse(btnAuto)
	if autoConn then autoConn:Disconnect() autoConn = nil end
	if isAuto then
		setStatus("Auto-Hop running (scan every ~20s).")
		local lastTry = 0
		autoConn = RunService.Heartbeat:Connect(function(_dt)
			if time() - lastTry < 20 then return end
			lastTry = time()
			task.spawn(function()
				local srv, err = chooseServer(sliderValue)
				if srv then
					setStatus(("Auto-Hop -> %s (%d/%d)"):format(srv.id, srv.playing, srv.maxPlayers))
					teleportToJob(srv.id)
				else
					setStatus("Auto-Hop: " .. (err or "no server"))
				end
			end)
		end)
	else
		setStatus("Auto-Hop stopped.")
	end
end)

-- Toast start
pcall(function()
	StarterGui:SetCore("SendNotification", {
		Title = "Server Hop";
		Text = "UI loaded — choose cap 1–10, then Hop/Rejoin";
		Duration = 5;
	})
end)
