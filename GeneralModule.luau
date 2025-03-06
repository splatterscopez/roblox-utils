--!strict

local GeneralModule = {}

local CachedFolders = {}

local ClientVars = {}
local ServerVars = {}

local DefaultPrint = print
local DefaultWarn = warn
local ScriptName = script.Name

local print = function(...: string)
	DefaultPrint("[".. ScriptName .."] @ Line: ".. debug.info(2, "l"), ...)
end

local warn = function(...: string)
	DefaultWarn("[".. ScriptName .."] @ Line: ".. debug.info(2, "l"), ...)
end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGUI = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local DebrisFolder = workspace.Debris

local Storage = ReplicatedStorage.Storage
local Modules = ReplicatedStorage.Modules

local SharedStorage = Storage.Shared
local Util = Modules.Util

local WorldToGui = require(Util.WorldToGui)

local Rand = Random.new()

local IsClient = RunService:IsClient()

if IsClient then
	ClientVars.LocalPlayer = Players.LocalPlayer
	ClientVars.Camera = workspace.CurrentCamera

	ClientVars.Events = ReplicatedStorage.Events
	ClientVars.ClientEvents = ClientVars.Events.ClientEvents
else
	ServerVars.ServerScriptService = game:GetService("ServerScriptService")
	ServerVars.ServerStorage = game:GetService("ServerStorage")

	ServerVars.ServerEvents = ServerVars.ServerScriptService.ServerEvents
end

local RayParams = RaycastParams.new()
RayParams.FilterDescendantsInstances = { DebrisFolder }
RayParams.FilterType = Enum.RaycastFilterType.Exclude

function GeneralModule:PickRandomItemFromCachedFolders(Folder: Folder)
	if not Folder then warn("Cache Function: No folder was passed in!", debug.traceback()) return end
	if not CachedFolders[Folder] then CachedFolders[Folder] = Folder:GetChildren() end

	return CachedFolders[Folder][math.random(1, #CachedFolders[Folder])]
end

function GeneralModule:CloneRandomItemFromCachedFolders(Folder: Folder)
	local NewItem: Instance? = GeneralModule:PickRandomItemFromCachedFolders(Folder)

	task.synchronize()

	return NewItem and NewItem:Clone()
end

function GeneralModule:GetRandomCFrameInPart(Part: BasePart)
	return Part.CFrame * CFrame.new(Rand:NextNumber(-Part.Size.X / 2, Part.Size.X / 2), Rand:NextNumber(-Part.Size.Y / 2, Part.Size.Y / 2), Rand:NextNumber(-Part.Size.Z / 2, Part.Size.Z / 2))
end

function GeneralModule:RecursiveTableFind(Table: {}, KeyToFind: any)
	for Index, Key: any in Table do
		if Key == KeyToFind then return true end

		if typeof(Key) == "table" then return GeneralModule:RecursiveTableFind(Key, KeyToFind) end
	end

	return false
end

function GeneralModule:FindDistance(Vect1: Vector3 | BasePart, Vect2: Vector3 | BasePart)
	if not Vect1 or not Vect2 then return -1 end

	if typeof(Vect1) == "Instance" then Vect1 = Vect1.Position end
	if typeof(Vect2) == "Instance" then Vect2 = Vect2.Position end

	return (Vect1:: Vector3 - Vect2:: Vector3).Magnitude
end

function GeneralModule:DistanceFromCharacter(Player: Player | Model | Actor, Vector: Vector3 | BasePart)
	if not Vector then return -1 end

	if Player:IsA("Player") then Player = Player.Character:: Model end
	if not Player then return -1 end

	local Root: BasePart = Player:FindFirstChild("HumanoidRootPart"):: BasePart
	if not Root then return -1 end

	return GeneralModule:FindDistance(Root.Position, Vector)
end

function GeneralModule:DistanceFromLocalPlayer(Vector: Vector3 | BasePart)
	if not RunService:IsClient() then warn("Wth are U doing ?") return -1 end
	if not ClientVars.LocalPlayer.Character then return -1 end

	return GeneralModule:DistanceFromCharacter(ClientVars.LocalPlayer.Character, Vector)
end

function GeneralModule:DistanceFromCamera(Vector: Vector3 | BasePart)
	if not RunService:IsClient() then warn("Wth are U doing ?") return -1 end
	if not ClientVars.Camera then return -1 end

	return GeneralModule:FindDistance(ClientVars.Camera.CFrame.Position, Vector)
end

function GeneralModule:SafeSetCoreGUI(CoreGUI: Enum.CoreGuiType, Enabled: boolean)
	repeat
		pcall(function()
			StarterGUI:SetCoreGuiEnabled(CoreGUI, Enabled)
		end)

		task.wait()
	until StarterGUI:GetCoreGuiEnabled(CoreGUI) == Enabled
end

function GeneralModule:CreateEmptyPart(Parent: Instance?)
	task.synchronize()

	local EmptyPart = SharedStorage.EmptyPart:Clone()
	
	if Parent then EmptyPart.Parent = Parent end

	task.desynchronize()

	return EmptyPart
end

function GeneralModule:CreateEmptyPartAtPosition(Position: Vector3, Parent: Instance)
	task.synchronize()

	local EmptyPart = GeneralModule:CreateEmptyPart(nil)

	EmptyPart.Position = Position
	EmptyPart.Parent = Parent

	task.desynchronize()

	return EmptyPart
end

function GeneralModule:MarkInstanceForDeletion(Object: Instance | { Object: any }, Time: number) -- silence stupid strict mode error because it wont recognise my tables
	task.synchronize()

	if typeof(Object) == "Instance" then
		Object:SetAttribute("DebrisTime", Time)
		Object:AddTag("Debris")
	else
		for _, TabledObject: Instance in Object:: any do -- same deal here (fine, i guess i dont get autocomplete for my 2 lines of code)
			TabledObject:SetAttribute("DebrisTime", Time)
			TabledObject:AddTag("Debris")
		end
	end

	task.desynchronize()
end

function GeneralModule:CreateTemporaryPartAtPosition(Position: Vector3, Parent: Instance, Time: number)
	local EmptyPart = GeneralModule:CreateEmptyPartAtPosition(Position, Parent)

	GeneralModule:MarkInstanceForDeletion(EmptyPart, Time)

	return EmptyPart
end

function GeneralModule:PlayTemporarySoundAtPosition(Sound: Sound, Position: Vector3)
	task.spawn(function()
		task.synchronize()

		local NewSound = Sound:Clone()
		local SoundPart = GeneralModule:CreateEmptyPartAtPosition(Position, if IsClient then DebrisFolder.Client.Temporary else DebrisFolder.Server.Temporary)

		task.synchronize()

		NewSound.Parent = SoundPart

		NewSound:Play()

		task.desynchronize()

		GeneralModule:MarkInstanceForDeletion(SoundPart, NewSound.TimeLength + 0.1)
	end)
end

function GeneralModule:PlayTemporarySound(Sound: Sound, Settings: { PlaybackSpeed: number?, Volume: number?, TimePosition: number? }?)
	task.spawn(function()
		task.synchronize()

		local NewSound = Sound:Clone()

		if Settings then
			if Settings.PlaybackSpeed then
				NewSound.PlaybackSpeed = Settings.PlaybackSpeed
			end

			if Settings.Volume then
				NewSound.Volume = Settings.Volume
			end

			if Settings.TimePosition then
				NewSound.TimePosition = Settings.TimePosition
			end
		end

		NewSound.Parent = SoundService.TempSounds

		NewSound:Play()

		task.desynchronize()

		GeneralModule:MarkInstanceForDeletion(NewSound, NewSound.TimeLength + 0.1)
	end)
end

function GeneralModule:CreateClippedWorldDecal(Part: BasePart, Position: Vector3, Texture: string, Size: Vector2, CustomRenderLayer: string?)
	local Surface, Width, Height, RelativeWidth, RelativeHeight = WorldToGui:WorldPositionToGuiPosition(Part, Position)

	if not Surface then return end

	local FaceGUI = Part:FindFirstChild("FaceGUI".. Surface.Name ..(if CustomRenderLayer ~= nil then CustomRenderLayer else ""))

	if not FaceGUI then
		local NewFaceGUI = Instance.new("SurfaceGui")

		FaceGUI = NewFaceGUI -- STUPID STRICT MODE 🤬
		
		NewFaceGUI.CanvasSize = Vector2.new(Width * 128, Height * 128)
		NewFaceGUI.LightInfluence = 1
		NewFaceGUI.Face = Surface
		NewFaceGUI.ClipsDescendants = true
		NewFaceGUI.MaxDistance = 500
		NewFaceGUI.Name = "FaceGUI".. Surface.Name ..(if CustomRenderLayer ~= nil then CustomRenderLayer else "")

		NewFaceGUI.Parent = Part
	end
	
	local Decal = Instance.new("ImageLabel")
	
	Decal.Name = "Decal"
	Decal.Image = Texture
	Decal.BorderSizePixel = 0
	Decal.BackgroundTransparency = 1
	Decal.Size = UDim2.fromOffset(128 * Size.X, 128 * Size.Y)
	Decal.AnchorPoint = Vector2.new(0.5, 0.5)
	Decal.Position = UDim2.fromScale(RelativeWidth, RelativeHeight)
	
	Decal.Parent = FaceGUI
	
	return Decal
end

local function RaycastDebug(Origin: Vector3, EndPosition: Vector3, ResultPosition: Vector3)
	local DebugBeam = script.RaycastDebug:Clone()
	local Attachment0 = Instance.new("Attachment")
	local Attachment1 = Instance.new("Attachment")
	
	DebugBeam.Color = ColorSequence.new(if ResultPosition then Color3.fromRGB(0, 255, 0) else Color3.fromRGB(255, 0, 0))
	DebugBeam.Attachment0 = Attachment0
	DebugBeam.Attachment1 = Attachment1
	
	Attachment0.WorldPosition = Origin
	Attachment1.WorldPosition = if ResultPosition then ResultPosition else EndPosition

	Attachment0.Parent = workspace.Terrain
	Attachment1.Parent = workspace.Terrain
	DebugBeam.Parent = DebrisFolder.Client.Temporary

	GeneralModule:MarkInstanceForDeletion({DebugBeam, Attachment0, Attachment1}, 1)
end

function GeneralModule:Raycast(Origin: BasePart? | Vector3?, Target: BasePart? | Vector3?, MaxDistance: number, Params: RaycastParams, NoDirectionCalculation: boolean, AddToFilter: Instance | { Instance }, Debug: boolean?)
	if not Origin or not Target then warn("Raycast recieved either no Origin or Target! Dumped arguments:", tostring(Origin), tostring(Target)) return nil end
	if typeof(Origin) == "Instance" then Origin = Origin.Position end
	if typeof(Target) == "Instance" then Target = Target.Position end
	if not MaxDistance then MaxDistance = 15000 end
	if not Params then Params = RayParams end
	if AddToFilter then Params:AddToFilter(AddToFilter) end

	local Direction = (not NoDirectionCalculation and (Target:: Vector3 - Origin:: Vector3).Unit or Target:: Vector3) * MaxDistance

	local Raycast = workspace:Raycast(Origin, Direction, Params)

	if Debug then
		RaycastDebug(Origin:: Vector3, Origin:: Vector3 + Direction:: Vector3, Raycast and Raycast.Position)
	end

	return Raycast
end

function GeneralModule:RemoveCyclic(Table: { }, Table2: { { } })
	local Table1 = { }

	for Key in Table do
		if table.find(Table2, Table[Key]) then 
			continue
		end

		if typeof(Table[Key]) ~= "table" then
			Table1[Key] = Table[Key]
		else
			table.insert(Table2, Table[Key])

			Table1[Key] = Table[Key]

			local NonCyclic = GeneralModule:RemoveCyclic(Table[Key], Table2)

			for Key1 in Table1[Key] do
				if not NonCyclic[Key1] then
					Table1[Key][Key1] = nil
				end
			end
		end
	end

	return Table1
end

function GeneralModule:AddObjectToTableIfUnique(Table: { }, Object: any)
	local FoundObject: any = table.find(Table, Object)

	if not FoundObject then table.insert(Table, FoundObject) end
end

function GeneralModule:RemoveObjectFromTable(Table: { }, Object: any)
	local FoundObject: any = table.find(Table, Object)
	
	if FoundObject then table.remove(Table, FoundObject) end
end

function GeneralModule:ClearAllChildrenExceptFor(Object: Instance, ExceptedInstance: Instance | { Instance })
	local IsTable = typeof(ExceptedInstance) == "table"
	
	if not IsTable then
		for _, Child: Instance in Object:GetChildren() do
			if Child == ExceptedInstance then continue else Child:Destroy() end
		end
	else
		for _, Child: Instance in Object:GetChildren() do
			if table.find(ExceptedInstance:: { Instance }, Child) then continue else Child:Destroy() end
		end
	end
end

function GeneralModule:GetAverage(NumberTable: { number })
	local Total = 0
	
	for _, Number: number in NumberTable do Total += Number end
	
	return Total / #NumberTable
end

function GeneralModule:RepeatFunctionForXSecond(Seconds: number, Function: thread, Parameters: { any }, OverrideSafetyWait: boolean?)
    local StartTime = os.clock()
              
    while StartTime + Seconds <= os.clock() do
        local TickTime = os.clock()
                
        Function(table.unpack(Parameters))
                  
        if not OverrideSafetyWait and TickTime + (1 / 100) <= os.clock() then
            -- Likely no task.wait was added to the function.
            task.wait()
        end
    end
end

return GeneralModule
