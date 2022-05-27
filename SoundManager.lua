--!strict
--[[
This client script handles the playback of all music/sfx in the game.
]]--

--[[
==========================Private Variables==========================
]]--

--other stuff
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game.SoundService
local IndexGenerator = Random.new()

--types
export type SFXConfig = {
	--true to allow only one instance of the sound to be played; otherwise false;
	Debounce: boolean?;
	--true if it should yield until the sound effect finishes playing; otherwise false;
	YieldForEnd: boolean?;
	--custom playback speed in range (0, 5]; (ideal range, other values may not hard error);
	CustomSpeed: number?;
	--what part to play the sound from; otherwise plays globally;
	SoundLocation: BasePart?;
	--true if it should play forever (stop with StopSFX); otherwise false;
	Looped: boolean?;
}

--constants
local SFX_DEFAULT_CONFIG: SFXConfig = {
	Debounce = false;
	YieldForEnd = false;
}

--sound groups
local MusicGroup = SoundService.MusicGroup
local SFXGroup = SoundService.SFXGroup

--sound objects
local ActiveSong = Instance.new("Sound")
ActiveSong.Name = "_ActiveSong"
ActiveSong.Volume = 1
ActiveSong.Looped = true
ActiveSong.Parent = MusicGroup

--[Instance soundKey] = Sound if playing; otherwise nil;
local SoundsPlaying: {[Instance]: Sound?} = {}

--[[
==========================Private Functions==========================
]]--

--plays the given music object globally; if no music object is given then no music plays;
local function SetActiveMusic(musicObject: Sound?)
	ActiveSong:Stop()
	if musicObject then
		ActiveSong.Volume = musicObject.Volume
		ActiveSong.SoundId = musicObject.SoundId
		ActiveSong:Play()
	end
end

--returns a random child sound of the given folder;
local function GetRandomChildSound(sfxFolder: Instance): Sound?
	local sfxChildren = sfxFolder:GetChildren()
	local randomSound = sfxChildren[IndexGenerator:NextInteger(1, #sfxChildren)]

	if randomSound:IsA("Sound") then
		return randomSound
	else
		return nil
	end
end

--immediately stop the given sfx and dereference it;
local function StopSFX(sfxKey: Instance)
	local soundToStop = SoundsPlaying[sfxKey]
	if soundToStop then
		--Sound:Stop() only triggers .Stopped;
		soundToStop:Stop()
		--remove the sound from SoundsPlaying
		SoundsPlaying[sfxKey] = nil
		--destroy the cloned sound instance
		soundToStop:Destroy()
	end
end

local function PlaySFX(sfxKey: Instance, config: SFXConfig?)
	if not config then
		--set default config if one is not given;
		config = SFX_DEFAULT_CONFIG
	end
	
	--temporary... any linter should be smart enough to detect that a config will always exist;
	if config then
		if config.Debounce and SoundsPlaying[sfxKey] then
			--the sound is already playing; do nothing;
			return
		end
		
		local newSFX: Sound? = nil
		if sfxKey:IsA("Folder") then
			newSFX = GetRandomChildSound(sfxKey)
		elseif sfxKey:IsA("Sound") then
			newSFX = sfxKey
		end

		if newSFX then
			newSFX = newSFX:Clone()

			--enable the song to be played faster without changing its pitch;
			local customPlayRate = config.CustomSpeed
			if customPlayRate then
				local pitchShifter = newSFX:FindFirstChild("PitchShifter")
				if pitchShifter and pitchShifter:IsA("PitchShiftSoundEffect") then
					--if the playrate is 2, the octave should be 0.5;
					--if the playrate is 0.5, the octave should be 2;
					--Octave's range is [0.5, 2]
					pitchShifter.Octave = 1 / customPlayRate
				end
				newSFX.PlaybackSpeed = customPlayRate
			end
			
			if config.Looped then	
				newSFX.Looped = true
			end

			newSFX.Ended:Connect(function()
				SoundsPlaying[sfxKey] = nil
				newSFX:Destroy()
			end)

			SoundsPlaying[sfxKey] = newSFX
			newSFX.Parent = config.SoundLocation or SFXGroup
			newSFX:Play()

			if config.YieldForEnd then
				newSFX.Ended:Wait()
			end
		else
			warn("PlaySFX: Missing sound")
		end
	end
end

local function OnCharacterAdded(newChar: Model)
	local charHRP = newChar:WaitForChild("HumanoidRootPart", 1)
	if charHRP then
		charHRP.ChildAdded:Connect(function(newChild)
			if newChild:IsA("Sound") then
				--add character sounds to the sfx group to fix their volume
				newChild.SoundGroup = SFXGroup
			end
		end)

		for _, obj in ipairs(charHRP:GetChildren()) do
			if obj:IsA("Sound") then
				--add character sounds to the sfx group to fix their volume
				obj.SoundGroup = SFXGroup
			end
		end
	end
end

local function OnPlayerAdded(newPlayer: Player)
	newPlayer.CharacterAdded:Connect(OnCharacterAdded)

	local plyrChar = newPlayer.Character
	if plyrChar then
		OnCharacterAdded(plyrChar)
	end
end

local function Init()
	--automatically assign all sound object a sound group and preload them;
	local soundsFound: {Sound} = {}
	for _, obj in ipairs(SoundService:GetDescendants()) do
		if obj:IsA("Sound") then
			table.insert(soundsFound, obj)

			if obj.Parent:IsA("Folder") then
				obj.SoundGroup = obj.Parent.Parent
			else
				obj.SoundGroup = obj.Parent
			end
		end
	end
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, soundsFound)

	--fix all player's sound's SoundGroups
	game.Players.PlayerAdded:Connect(OnPlayerAdded)
	for _, plyr in ipairs(game.Players:GetPlayers()) do
		OnPlayerAdded(plyr)
	end
end

Init()

--[[
==========================Public Interface==========================
]]--

local SoundController = {
	--objects
	MusicGroup = MusicGroup;
	SFXGroup = SFXGroup;
	--functions
	SetActiveMusic = SetActiveMusic;
	PlaySFX = PlaySFX;
	StopSFX = StopSFX;
}

return SoundController
