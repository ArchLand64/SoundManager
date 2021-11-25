--!strict
--[[
This client script handles playback of all music/sfx in the game.
]]--

--[[
==========================Private Variables==========================
]]--
--mods
local SettingsManager = require(game.ReplicatedStorage.ClientMods.SettingsManager)
local SettingsInfo = require(game.ReplicatedStorage.SharedMods.SettingsInfo)

--other stuff
local SettingKeys = SettingsInfo.SettingKeys
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
local ActiveSong = Instance.new("Sound", MusicGroup)
ActiveSong.Name = "_ActiveSong"
ActiveSong.Volume = 1
ActiveSong.Looped = true

local MusicKeys = {
	LobbyMusic = MusicGroup.LobbyMusic;
	GlassSong = MusicGroup.GlassSong;
	FinalSong = MusicGroup.FinalSong;
}

--[SFXName] = sound object OR folder with sound objects in it;
local SFXKeys = {
	--sound instances that can only play a single sound;
	Click = SFXGroup.Click;
	Switch = SFXGroup.Switch;
	Error = SFXGroup.Error;
	Success = SFXGroup.Success;
	DollSpin = SFXGroup.DollSpin;
	DollTalk = SFXGroup.DollTalk;
	LightGunShot = SFXGroup.LightGunShot;
	HeavyGunShot = SFXGroup.HeavyGunShot;
	ClockTick = SFXGroup.ClockTick;
	--sound folders that can play one of multiple sound effects randomly;
	KnifeSwing = SFXGroup.KnifeSwing;
	GlassShatter = SFXGroup.GlassShatter;
	MaleScream = SFXGroup.MaleScream;
	FemaleScream = SFXGroup.FemaleScream;
}

--[Instance object] = bool playing;
local SFXPlaying: {[Instance]: boolean} = {}


--[[
==========================Private Functions==========================
]]--

--init playing map
for _, sfxKey in pairs(SFXKeys) do
	SFXPlaying[sfxKey] = false
end

--automatically assign all sound object a sound group;
for _, obj in ipairs(SoundService:GetDescendants()) do
	if obj:IsA("Sound") then
		if obj.Parent:IsA("Folder") then
			obj.SoundGroup = obj.Parent.Parent
		else
			obj.SoundGroup = obj.Parent
		end
	end
end

--connect to settings; newVolume range is [0, 1]
SettingsManager.AddSettingCallback(SettingKeys.MusicVolume, function(newVolume: number)
	MusicGroup.Volume = newVolume / 2
end)
SettingsManager.AddSettingCallback(SettingKeys.SFXVolume, function(newVolume: number)
	SFXGroup.Volume = newVolume / 2
end)

--plays the given music object globally; if no music object is given then no music plays;
local function SetActiveMusic(musicObject: Sound?)
	ActiveSong:Stop()
	if musicObject then
		ActiveSong.Volume = musicObject.Volume
		ActiveSong.SoundId = musicObject.SoundId
		ActiveSong:Play()
	end
end

local function GetRandomChildSFX(sfxFolder: Instance): Sound?
	local sfxChildren = sfxFolder:GetChildren()
	local randomSound = sfxChildren[IndexGenerator:NextInteger(1, #sfxChildren)]

	if randomSound:IsA("Sound") then
		return randomSound
	else
		return nil
	end
end

local function PlaySFX(sfxKey: Instance, config: SFXConfig?)
	if not config then
		--set default config if one is not given;
		config = SFX_DEFAULT_CONFIG
	end
	
	--temporary... roblox linter should be smart enough to detect config will always exist;
	if config then
		if config.Debounce and SFXPlaying[sfxKey] then
			--the sound is already playing; do nothing;
			return
		end

		local newSFX: Sound? = nil
		if sfxKey:IsA("Folder") then
			newSFX = GetRandomChildSFX(sfxKey)
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

			newSFX.Ended:Connect(function()
				SFXPlaying[sfxKey] = false
				newSFX:Destroy()
			end)

			SFXPlaying[sfxKey] = true
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

--[[
==========================Public Interface==========================
]]--

local SoundManager = {
	MusicKeys = MusicKeys;
	SFXKeys = SFXKeys;
	SetActiveMusic = SetActiveMusic;
	PlaySFX = PlaySFX;
}

return SoundManager
