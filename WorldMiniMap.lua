local MAP_COORD_BASE = 51200 / 3
local MAP_SIZE = MAP_COORD_BASE * 2
local TILE_GRID_OVERHANG = 16
local TILE_GRID_SIZE = TILE_GRID_OVERHANG * 2 + 1
local TILE_GRID_PIXEL_SIZE = 256 * TILE_GRID_SIZE

local centrumTilePos = { x = 31, y = 31 } --Middle of the continent
local tiles = {}
local continent = "kalimdor"

local mouse_down = false
local mouse_start_pos_x, mouse_start_pos_y = 0, 0
local center_x, center_y = 0, 0
local scale = 2

local follow_player = true

local function refreshTiles()
	local tileXInt = math.floor(centrumTilePos.x)
	local tileYInt = math.floor(centrumTilePos.y)

	for y = -TILE_GRID_OVERHANG, TILE_GRID_OVERHANG do
		for x = -TILE_GRID_OVERHANG, TILE_GRID_OVERHANG do
			local tile = tiles[x .. "," .. y]
			tile.texture:SetTexture("Interface\\AddOns\\WorldMiniMap\\world\\minimaps\\" ..
				continent .. "\\map" .. (tileYInt + y) .. "_" .. (tileXInt + x))
		end
	end
end

-- Returns the tile coordinates the player is on
local function getPlayerWorldPos()
	local mapId = C_Map.GetBestMapForUnit("player")
	if mapId == nil then
		return 0, 0
	end

	local playerPos = C_Map.GetPlayerMapPosition(mapId, "player")
	if playerPos == nil then
		return 0, 0
	end

	local continentId, playerWorldPos = C_Map.GetWorldPosFromMapPos(mapId, playerPos)
	if continentId == 1414 then
		continent = "kalimdor"
	elseif continentId == 1415 then
		continent = "azeroth"
	end

	return playerWorldPos.x, playerWorldPos.y
end

-- create parent frame to hold tiles
---@class WorldMiniMap: Frame { TitleText }
WorldMiniMap = CreateFrame("Frame", "WorldMiniMap", UIParent, "BaseBasicFrameTemplate")
WorldMiniMap:SetSize(256 * 3 + 32, 256 * 3 + 64)
--set max size of WorldMiniMap
WorldMiniMap:SetResizeBounds(192, 192, TILE_GRID_PIXEL_SIZE - 512, TILE_GRID_PIXEL_SIZE - 512)
WorldMiniMap:SetPoint("CENTER", 0, 0)

--make WorldMiniMap draggable in title bar
WorldMiniMap:SetMovable(true)
WorldMiniMap:EnableMouse(true)
WorldMiniMap:RegisterForDrag("LeftButton")
WorldMiniMap:SetScript("OnDragStart", WorldMiniMap.StartMoving)
WorldMiniMap:SetScript("OnDragStop", WorldMiniMap.StopMovingOrSizing)

--set parent title to "World Mini Map"
WorldMiniMap.TitleText:SetText("World Mini Map")
WorldMiniMap:SetClipsChildren(true)

-- make WorldMiniMap sizable
WorldMiniMap:SetResizable(true)

-- add resize grip
WorldMiniMap.resize = CreateFrame("Frame", nil, WorldMiniMap)
WorldMiniMap.resize:SetPoint("BOTTOMRIGHT", WorldMiniMap, "BOTTOMRIGHT", 0, 0)
WorldMiniMap.resize:SetSize(16, 16)
WorldMiniMap.resize:EnableMouse(true)
WorldMiniMap.resize:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" then
		WorldMiniMap:StartSizing("BOTTOMRIGHT")
	end
end)
WorldMiniMap.resize:SetScript("OnMouseUp", function(self, button)
	WorldMiniMap:StopMovingOrSizing()
end)
WorldMiniMap.resize.texture = WorldMiniMap.resize:CreateTexture()
WorldMiniMap.resize.texture:SetAllPoints(WorldMiniMap.resize)
WorldMiniMap.resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

-- set background of WorldMiniMap to default BasicFrameTemplate background texture
WorldMiniMap.texture = WorldMiniMap:CreateTexture()
WorldMiniMap.texture:SetAllPoints(WorldMiniMap)
WorldMiniMap.texture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
WorldMiniMap.texture:SetTexCoord(0, 1, 0, 1)
WorldMiniMap.texture:SetVertexColor(0.5, 0.5, 0.5, 0.5)


-- create frame in WorldMiniMap to hold tiles_frame
local tiles_container = CreateFrame("Frame", "WorldMiniMapTilesContainer", WorldMiniMap)
tiles_container:SetFrameStrata("MEDIUM")
tiles_container:SetFrameLevel(1)
tiles_container:SetClipsChildren(true)
tiles_container:ClearAllPoints()
tiles_container:SetPoint("TOPLEFT", 0, -23)
tiles_container:SetPoint("TOPRIGHT", 0, -23)
tiles_container:SetPoint("BOTTOMLEFT", 0, 0)
tiles_container:SetPoint("BOTTOMRIGHT", 0, 0)

local tiles_frame = CreateFrame("Frame", "WorldMiniMapTilesFrame", tiles_container)
tiles_frame:ClearAllPoints()
tiles_frame:SetSize(256 * TILE_GRID_SIZE, 256 * TILE_GRID_SIZE)
tiles_frame:SetPoint("CENTER", tiles_container, "CENTER", 0, 0)
tiles_frame:EnableMouse(true)
tiles_frame:SetScale(scale)

-- Coordinate conversion

local function worldToTilePos(worldX, worldY)
	local worldPercentX = (MAP_COORD_BASE - worldX) / MAP_SIZE
	local worldPercentY = (MAP_COORD_BASE - worldY) / MAP_SIZE

	local tileX = worldPercentX * 64
	local tileY = worldPercentY * 64
	return tileX, tileY
end

local function tilePosToTilesFramePos(tileX, tileY)
	local relative_tile_x = tileX - centrumTilePos.x
	local relative_tile_y = tileY - centrumTilePos.y
	local relative_pixel_x = relative_tile_y * 256
	local relative_pixel_y = relative_tile_x * 256

	local offseted_x = relative_pixel_x - 128
	local offseted_y = 128 - relative_pixel_y

	return offseted_x, offseted_y
end

local function worldPosToTilesFramePos(worldX, worldY)
	return tilePosToTilesFramePos(worldToTilePos(worldX, worldY))
end

-----------------

local function centerMapOn(worldX, worldY)
	local tile_x, tile_y = worldToTilePos(worldX, worldY)
	centrumTilePos.x = math.floor(tile_x)
	centrumTilePos.y = math.floor(tile_y)

	local px, py = tilePosToTilesFramePos(tile_x, tile_y)
	tiles_frame:SetPoint("CENTER", tiles_container, "CENTER", -px, -py)

	refreshTiles()
end

local function getScaledMousePosition()
	local uiScale, x, y = UIParent:GetEffectiveScale(), GetCursorPosition()
	return x / uiScale / scale, y / uiScale / scale
end

local function resetMouseDelta()
	mouse_start_pos_x, mouse_start_pos_y = getScaledMousePosition()
	_, _, _, center_x, center_y = tiles_frame:GetPointByName("CENTER")
end

tiles_frame:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" then
		mouse_down = true
		follow_player = false
		resetMouseDelta()
	end
end)
tiles_frame:SetScript("OnMouseUp", function(self, button)
	if button == "LeftButton" then
		mouse_down = false
	end
end)

-- create tiles
for y = -TILE_GRID_OVERHANG, TILE_GRID_OVERHANG do
	for x = -TILE_GRID_OVERHANG, TILE_GRID_OVERHANG do
		---@class Frame { texture }
		local tile = CreateFrame("Frame", nil, tiles_frame)
		tile:SetSize(256, 256)
		tile:SetPoint("CENTER", tiles_frame, "CENTER", 256 * y, -256 * x)

		-- set frame background
		tile.texture = tile:CreateTexture()
		tile.texture:SetAllPoints(tile)
		tile.texture:SetTexCoord(0, 1, 0, 1)

		tiles[x .. "," .. y] = tile
	end
end

-- create player arrow
local player_arrow = CreateFrame("Frame", nil, tiles_frame)
player_arrow:SetFrameStrata("HIGH")
player_arrow:SetSize(32 / scale, 32 / scale)
player_arrow.texture = player_arrow:CreateTexture()
player_arrow.texture:SetAllPoints(player_arrow)
player_arrow.texture:SetTexture("Interface\\Minimap\\MinimapArrow")
player_arrow.texture:SetTexCoord(0, 1, 0, 1)
player_arrow:SetPoint("CENTER", tiles_frame, "CENTER", 0, 0)

-- zoom
tiles_frame:SetScript("OnMouseWheel", function(self, delta)
	if delta > 0 then
		scale = scale + 0.2
	else
		scale = scale - 0.2
		if scale <= 0.2 then
			scale = 0.2
		end
	end
	tiles_frame:SetScale(scale)
	player_arrow:SetSize(32 / scale, 32 / scale)
end)

WorldMiniMap:SetScript("OnUpdate", function(self, elapsed)
	player_arrow:RotateTextures(GetPlayerFacing(), 0.5, 0.5)

	local px, py = getPlayerWorldPos()
	if follow_player then
		centerMapOn(px, py)
	end
	local tx, ty = worldPosToTilesFramePos(px, py)
	player_arrow:SetPoint("CENTER", tiles_frame, "CENTER", tx, ty)

	if mouse_down then
		local mouse_pos_x, mouse_pos_y = getScaledMousePosition()
		local dx = mouse_pos_x - mouse_start_pos_x
		local dy = mouse_pos_y - mouse_start_pos_y

		local do_refresh = true

		if center_x + dx <= -256 then
			tiles_frame:SetPoint("CENTER", tiles_container, "CENTER", center_x + dx + 256, center_y + dy)
			centrumTilePos.y = centrumTilePos.y + 1
		elseif center_x + dx >= 256 then
			tiles_frame:SetPoint("CENTER", tiles_container, "CENTER", center_x + dx - 256, center_y + dy)
			centrumTilePos.y = centrumTilePos.y - 1
		elseif center_y + dy <= -256 then
			tiles_frame:SetPoint("CENTER", tiles_container, "CENTER", center_x + dx, center_y + dy + 256)
			centrumTilePos.x = centrumTilePos.x - 1
		elseif center_y + dy >= 256 then
			tiles_frame:SetPoint("CENTER", tiles_container, "CENTER", center_x + dx, center_y + dy - 256)
			centrumTilePos.x = centrumTilePos.x + 1
		else
			do_refresh = false
			tiles_frame:SetPoint("CENTER", center_x + dx, center_y + dy)
		end

		if do_refresh then
			resetMouseDelta()
			refreshTiles()
		end
	end
end)

-- Dropdown

local continent_options = {
	{
		text = "Kalimdor",
		value = "kalimdor"
	},
	{
		text = "Eastern Kingdoms",
		value = "azeroth"
	}
}

function WPDropDownDemo_Menu(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo()

	for c, _ in pairs(continent_options) do
		info.text, info.checked = continent_options[c].text, continent_options[c].value == continent
		info.value = continent_options[c].value
		info.func = function(self)
			continent = self.value
			UIDropDownMenu_SetSelectedID(frame, self:GetID())
			refreshTiles()
		end
		UIDropDownMenu_AddButton(info)
	end
end

local WPDropDownDemo = CreateFrame("Frame", "WPDropDownDemo", WorldMiniMap, "UIDropDownMenuTemplate")
WPDropDownDemo:SetPoint("TOPRIGHT", WorldMiniMap, "TOPRIGHT", 8, -22)
UIDropDownMenu_SetWidth(WPDropDownDemo, 100)
UIDropDownMenu_SetButtonWidth(WPDropDownDemo, 124)
UIDropDownMenu_JustifyText(WPDropDownDemo, "LEFT")
UIDropDownMenu_Initialize(WPDropDownDemo, WPDropDownDemo_Menu)
UIDropDownMenu_SetSelectedID(WPDropDownDemo, 1)

-- Event handling

local events = {
	PLAYER_ENTERING_WORLD = function()
		print("World Mini Map")
		centerMapOn(getPlayerWorldPos())
		refreshTiles()
	end,
	ZONE_CHANGED_NEW_AREA = function()
		refreshTiles()
	end
}
for e, f in pairs(events) do
	WorldMiniMap:RegisterEvent(e)
end
WorldMiniMap:SetScript("OnEvent", function(self, event, ...)
	for e, f in pairs(events) do
		if e == event then
			f(...)
			break
		end
	end
end)
