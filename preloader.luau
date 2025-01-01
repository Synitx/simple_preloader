local ContentProvider = game:GetService("ContentProvider")
local core = {}
core.__index = core
core.PriorityType = {
	HIGH = 1;
	LOW = 2;
}

local priorities = {}

local DEBUG_FAILED = false

function core.new()
	local self = setmetatable(core,{}) 
	self.prioritiesStatus = {
		High = {
			Failed = {};
			Loaded = {};
		};
		Low = {
			Failed = {};
			Loaded = {};
		}
	}
	return self
end

function core:Add(asset : string | Folder, priority:number)
	if not priority then
		priority = core.PriorityType.LOW
	end
	if not priorities[priority] then
		priorities[priority] = {}
	end
	
	local function insert(content)
		table.insert(priorities[priority], content)
	end
	
	if typeof(asset) == "Instance" and asset:IsA("Folder") then
		for _, item in asset:GetDescendants() do
			if item:IsA("Animation") and item.AnimationId ~= "" then
				insert(item.AnimationId)
			elseif (item:IsA("ImageLabel") or item:IsA("ImageButton")) and item.Image ~= "" then
				insert(item.Image)
			elseif (item:IsA("Decal") or item:IsA("Texture")) and item.Texture ~= "" then
				insert(item.Texture)
			elseif item:IsA("Sound") and item.SoundId ~= "" then
				insert(item.SoundId)
			elseif item:IsA("SurfaceAppearance") then
				if item.ColorMap ~= "" then insert(item.ColorMap) end
				if item.MetalnessMap ~= "" then insert(item.MetalnessMap) end
				if item.NormalMap ~= "" then insert(item.NormalMap) end
				if item.RoughnessMap ~= "" then insert(item.RoughnessMap) end
			elseif item:IsA("MeshPart") then
				if item.MeshId ~= "" then insert(item.MeshId) end
				if item.TextureID ~= "" then insert(item.TextureID) end
			end
		end
	elseif typeof(asset) == "string" then
		insert(asset)
	end
	return self
end

function core:GetItemsToLoad(priority : number)
	if priority then
		if not priorities[priority] then return {} end
		return priorities[priority]
	else
		local raw = {}
		for priority, content in priorities do
			for i,v in content do
				table.insert(raw, v)
			end
		end
		return raw
	end
end

function core:Load()	
	for priority, items : {string} in priorities do
		ContentProvider:PreloadAsync(items, function(contentId : string, fetchStatus : Enum.AssetFetchStatus)
			if fetchStatus == Enum.AssetFetchStatus.Failure then
				if DEBUG_FAILED then
					warn(`Unable to load {contentId}, reason: failed to load.`)
					warn(`Make sure you own the rights for this content or the content id must be right.`)
				end

				if priority == self.PriorityType.HIGH then
					table.insert(self.prioritiesStatus.High.Failed, contentId)
				else
					table.insert(self.prioritiesStatus.Low.Failed, contentId)
				end

			elseif fetchStatus == Enum.AssetFetchStatus.TimedOut then
				if priority == self.PriorityType.HIGH then
					local retries = 0
					while retries < 5 or ContentProvider:GetAssetFetchStatus(contentId) == Enum.AssetFetchStatus.TimedOut do
						retries += 1
						ContentProvider:PreloadAsync({contentId})
						task.wait(1)
					end
					if retries >= 5 and ContentProvider:GetAssetFetchStatus(contentId) ~= Enum.AssetFetchStatus.Success then
						table.insert(self.prioritiesStatus.High.Failed, contentId)
					else
						table.insert(self.prioritiesStatus.High.Loaded, contentId)
					end
				end

			elseif fetchStatus == Enum.AssetFetchStatus.Success then
				if priority == self.PriorityType.HIGH then
					table.insert(self.prioritiesStatus.High.Loaded, contentId)
				else
					table.insert(self.prioritiesStatus.Low.Loaded, contentId)
				end
			end
		end)
	end
end

return core
