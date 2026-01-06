-- ConditionReports.lua
-- Display time, session, and weather information for Assetto Corsa (CSP/CM required)

local sim = ac.getSim()

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------
local UPDATE_INTERVAL = 1.0           -- Seconds between data updates
local LABEL_VALUE_GAP_FACTOR = 0.3    -- Gap between label and value as fraction of font size
local SETTINGS_SECTION_SPACING = 12   -- Vertical spacing between settings sections
local FONT_NAME_TABLE_MAX = 8192      -- Max bytes to read from font name table
local FONT_NAME_RECORD_MAX = 500      -- Max name records to parse in font file
local FONT_SCALE_MIN = 0.5            -- Minimum font scale factor (relative to base size)
local FONT_SCALE_MAX = 4.0            -- Maximum font scale factor (relative to base size)

---------------------------------------------------------------------------
-- INTERNATIONALIZATION
-- Loads strings from i18n/*.ini with built-in fallbacks
-- Language can be selected via dropdown in settings
---------------------------------------------------------------------------
local scriptDir = ac.getFolder(ac.FolderID.ACApps) .. "/lua/ConditionReports/"
local i18nDir = scriptDir .. "i18n/"

-- Built-in default strings (used if language.ini is missing or incomplete)
local defaultStrings = {
    -- General settings
    TemperatureUnit = "C",
    WindSpeedUnit = "kmh",
    DateFormat = "YYYY-MM-DD",
    DecimalSeparator = ".",
    
    -- Labels
    Labels = {
        GameDate = "Game date",
        GameTime = "Game time",
        ClockSpeed = "Clock speed",
        RealTime = "Real time",
        RealUTC = "Real (UTC)",
        Session = "Session",
        Remaining = "Remaining",
        Laps = "laps",
        Weather = "Weather",
        Transition = "Transition",
        Forecast = "Forecast",
        Temperature = "Temp",
        Wind = "Wind",
        RainIntensity = "Rain",
        TrackWetness = "Wetness",
        StandingWater = "Puddles",
        Grip = "Grip",
        Air = "Air",
        Road = "Road",
        Unknown = "Unknown",
    },
    
    -- Time periods
    TimePeriods = {
        AM = "a.m.",
        PM = "p.m.",
    },
    
    -- Clock speed display
    ClockSpeeds = {
        TimeFixed = "Locked",
        Multiplier = "x",
    },
    
    -- Sessions
    Sessions = {
        Undefined = "UKN",
        Practice = "PRC",
        Qualify = "QUA",
        Race = "RAC",
        Hotlap = "HOT",
        TimeAttack = "TIM",
        Drift = "DFT",
        Drag = "DRG",
    },
    
    -- Wind directions (indexed 1-16)
    WindDirections = {"N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"},
    
    -- Month names
    MonthNames = {"January","February","March","April","May","June","July","August","September","October","November","December"},
    MonthAbbreviations = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"},
    
    -- Weather types (indexed 0-32)
    WeatherTypes = {
        [0] = "Light Thunderstorm", [1] = "Thunderstorm", [2] = "Heavy Thunderstorm",
        [3] = "Light Drizzle", [4] = "Drizzle", [5] = "Heavy Drizzle",
        [6] = "Light Rain", [7] = "Rain", [8] = "Heavy Rain",
        [9] = "Light Snow", [10] = "Snow", [11] = "Heavy Snow",
        [12] = "Light Sleet", [13] = "Sleet", [14] = "Heavy Sleet",
        [15] = "Clear", [16] = "Few Clouds", [17] = "Scattered Clouds",
        [18] = "Broken Clouds", [19] = "Overcast Clouds",
        [20] = "Fog", [21] = "Mist", [22] = "Smoke", [23] = "Haze",
        [24] = "Sand", [25] = "Dust", [26] = "Squalls",
        [27] = "Tornado", [28] = "Hurricane",
        [29] = "Cold", [30] = "Hot", [31] = "Windy", [32] = "Hail",
    },
}

-- Loaded strings (populated from language.ini or defaults)
local lang = {}

-- Simple INI parser
local function parseIniFile(filepath)
    local sections = {}
    local currentSection = nil
    
    local file = io.open(filepath, "r")
    if not file then return nil end
    
    for line in file:lines() do
        -- Remove BOM if present
        line = line:gsub("^\239\187\191", "")
        -- Trim whitespace
        line = line:match("^%s*(.-)%s*$")
        
        -- Skip empty lines and comments
        if line ~= "" and not line:match("^;") and not line:match("^#") then
            -- Check for section header
            local section = line:match("^%[([^%]]+)%]$")
            if section then
                currentSection = section
                sections[currentSection] = sections[currentSection] or {}
            elseif currentSection then
                -- Parse key=value
                local key, value = line:match("^([^=]+)=(.*)$")
                if key and value then
                    key = key:match("^%s*(.-)%s*$")
                    value = value:match("^%s*(.-)%s*$")
                    sections[currentSection][key] = value
                end
            end
        end
    end
    
    file:close()
    return sections
end

-- Load language strings from INI file with fallbacks
local function loadLanguage(filepath)
    -- Start with defaults
    lang.TemperatureUnit = defaultStrings.TemperatureUnit
    lang.WindSpeedUnit = defaultStrings.WindSpeedUnit
    lang.DateFormat = defaultStrings.DateFormat
    lang.Labels = {}
    for k, v in pairs(defaultStrings.Labels) do lang.Labels[k] = v end
    lang.TimePeriods = {}
    for k, v in pairs(defaultStrings.TimePeriods) do lang.TimePeriods[k] = v end
    lang.ClockSpeeds = {}
    for k, v in pairs(defaultStrings.ClockSpeeds) do lang.ClockSpeeds[k] = v end
    lang.Sessions = {}
    for k, v in pairs(defaultStrings.Sessions) do lang.Sessions[k] = v end
    lang.WindDirections = {}
    for i, v in ipairs(defaultStrings.WindDirections) do lang.WindDirections[i] = v end
    lang.MonthNames = {}
    for i, v in ipairs(defaultStrings.MonthNames) do lang.MonthNames[i] = v end
    lang.MonthAbbreviations = {}
    for i, v in ipairs(defaultStrings.MonthAbbreviations) do lang.MonthAbbreviations[i] = v end
    lang.WeatherTypes = {}
    for k, v in pairs(defaultStrings.WeatherTypes) do lang.WeatherTypes[k] = v end
    
    -- Determine file to load
    local fileToLoad = filepath or (i18nDir .. "EN_GB.ini")
    
    -- Try to load from file
    local ini = parseIniFile(fileToLoad)
    if not ini then
        ac.log("ConditionReports: Language file not found: " .. fileToLoad .. ", using defaults")
        return
    end
    
    -- General section
    if ini.General then
        if ini.General.TemperatureUnit then
            local unit = ini.General.TemperatureUnit:upper()
            if unit == "C" or unit == "F" then
                lang.TemperatureUnit = unit
            end
        end
        if ini.General.WindSpeedUnit then
            local unit = ini.General.WindSpeedUnit:lower()
            if unit == "kmh" or unit == "mph" then
                lang.WindSpeedUnit = unit
            end
        end
        if ini.General.DateFormat and #ini.General.DateFormat > 0 then
            lang.DateFormat = ini.General.DateFormat
        end
    end
    
    -- Labels section
    if ini.Labels then
        for key, value in pairs(ini.Labels) do
            if defaultStrings.Labels[key] then
                lang.Labels[key] = value
            end
        end
    end
    
    -- TimePeriods section
    if ini.TimePeriods then
        if ini.TimePeriods.AM then lang.TimePeriods.AM = ini.TimePeriods.AM end
        if ini.TimePeriods.PM then lang.TimePeriods.PM = ini.TimePeriods.PM end
    end
    
    -- ClockSpeeds section
    if ini.ClockSpeeds then
        if ini.ClockSpeeds.TimeFixed then lang.ClockSpeeds.TimeFixed = ini.ClockSpeeds.TimeFixed end
        if ini.ClockSpeeds.Multiplier then lang.ClockSpeeds.Multiplier = ini.ClockSpeeds.Multiplier end
    end
    
    -- Sessions section
    if ini.Sessions then
        for key, value in pairs(ini.Sessions) do
            if defaultStrings.Sessions[key] then
                lang.Sessions[key] = value
            end
        end
    end
    
    -- WindDirections section
    if ini.WindDirections then
        local dirKeys = {"N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"}
        for i, key in ipairs(dirKeys) do
            if ini.WindDirections[key] then
                lang.WindDirections[i] = ini.WindDirections[key]
            end
        end
    end
    
    -- MonthNames section
    if ini.MonthNames then
        for i = 1, 12 do
            if ini.MonthNames[tostring(i)] then
                lang.MonthNames[i] = ini.MonthNames[tostring(i)]
            end
        end
    end
    
    -- MonthAbbreviations section
    if ini.MonthAbbreviations then
        for i = 1, 12 do
            if ini.MonthAbbreviations[tostring(i)] then
                lang.MonthAbbreviations[i] = ini.MonthAbbreviations[tostring(i)]
            end
        end
    end
    
    -- WeatherTypes section
    if ini.WeatherTypes then
        for i = 0, 32 do
            if ini.WeatherTypes[tostring(i)] then
                lang.WeatherTypes[i] = ini.WeatherTypes[tostring(i)]
            end
        end
    end
    
    ac.log("ConditionReports: Loaded language from " .. fileToLoad)
end

---------------------------------------------------------------------------
-- LANGUAGE SCANNING
-- Dynamically scans i18n/ folder for .ini files to build language list.
-- Lazy loading: languages are only scanned when settings panel is first opened.
-- Display names are read from [Meta] DisplayName with filename fallback.
---------------------------------------------------------------------------

-- Lazy-loaded language list (nil until first settings access)
local languageList = nil
local languageNames = {}
local languageNamesNeedRefresh = true

-- Scan i18n/ folder for .ini files and build language list
local function scanLanguages()
    local languages = {}
    local files = io.scanDir(i18nDir, "*.ini")
    if files then
        for _, file in ipairs(files) do
            local fullPath = i18nDir .. file
            -- Extract code from filename (e.g., "EN_GB" from "EN_GB.ini")
            local code = file:lower():gsub("%.ini$", "")
            code = file:sub(1, #code)  -- Use original casing
            
            -- Try to read display name from [Meta] section
            local displayName = code
            local ini = parseIniFile(fullPath)
            if ini and ini.Meta and ini.Meta.DisplayName and #ini.Meta.DisplayName > 0 then
                displayName = ini.Meta.DisplayName
            end
            
            table.insert(languages, {
                code = code,
                name = displayName,
                path = fullPath
            })
        end
    end
    -- Sort alphabetically by display name
    table.sort(languages, function(a, b) return a.name < b.name end)
    return languages
end

local function ensureLanguagesLoaded()
    if languageList == nil then
        languageList = scanLanguages()
        languageNamesNeedRefresh = true
    end
end

local function refreshLanguageNames()
    ensureLanguagesLoaded()
    languageNames = {}
    for i, l in ipairs(languageList) do
        languageNames[i] = l.name
    end
    languageNamesNeedRefresh = false
end

-- Get index of current language in the list
local function getLanguageIndex(code)
    ensureLanguagesLoaded()
    for i, l in ipairs(languageList) do
        if l.code == code then
            return i
        end
    end
    return 1  -- Default to first if not found
end

-- Get language path by index
local function getLanguagePath(index)
    ensureLanguagesLoaded()
    return languageList[index] and languageList[index].path or nil
end

-- Get language code by index
local function getLanguageCode(index)
    ensureLanguagesLoaded()
    return languageList[index] and languageList[index].code or "EN_GB"
end

-- Rescan languages (can be called from settings to pick up new language files)
local function rescanLanguages()
    languageList = scanLanguages()
    languageNamesNeedRefresh = true
end

---------------------------------------------------------------------------
-- COLOR UTILITIES
-- Store colors as hex strings for ac.storage compatibility
-- Cache rgbm objects for color picker (it modifies in-place)
---------------------------------------------------------------------------
local defaultLabelColor = "#B0B0B0FF"  -- Light gray for labels
local defaultValueColor = "#FFFFFFFF"  -- White for values
local defaultBgColor = "#000000FF"     -- Black for background

local colorCache = {}  -- Cache of rgbm objects keyed by config key
local renderColorCache = {}  -- Separate cache for render colors (not modified by picker)

local function rgbmToHex(c)
    local r = math.floor(c.r * 255 + 0.5)
    local g = math.floor(c.g * 255 + 0.5)
    local b = math.floor(c.b * 255 + 0.5)
    local a = math.floor((c.mult or 1) * 255 + 0.5)
    return string.format("#%02X%02X%02X%02X", r, g, b, a)
end

local function hexToRgbm(hex)
    if not hex or #hex < 7 then return rgbm(1, 1, 1, 1) end
    local r = tonumber(hex:sub(2, 3), 16) or 255
    local g = tonumber(hex:sub(4, 5), 16) or 255
    local b = tonumber(hex:sub(6, 7), 16) or 255
    local a = 255
    if #hex >= 9 then
        a = tonumber(hex:sub(8, 9), 16) or 255
    end
    return rgbm(r / 255, g / 255, b / 255, a / 255)
end

-- Get or create a cached rgbm for a config key
-- Only recreates if cache doesn't exist (not if hex changes, since we update hex from cache)
local function getCachedColor(configKey, hexValue)
    if not colorCache[configKey] then
        colorCache[configKey] = hexToRgbm(hexValue)
    end
    return colorCache[configKey]
end

-- Reset a cached color (e.g., if we want to reload from config)
local function resetCachedColor(configKey, hexValue)
    colorCache[configKey] = hexToRgbm(hexValue)
    return colorCache[configKey]
end

-- Get or create a cached rgbm for rendering (separate from picker cache)
-- Invalidates when hex value changes
local function getRenderColor(configKey, hexValue)
    local cached = renderColorCache[configKey]
    if not cached or cached.hex ~= hexValue then
        renderColorCache[configKey] = {
            hex = hexValue,
            color = hexToRgbm(hexValue)
        }
    end
    return renderColorCache[configKey].color
end

---------------------------------------------------------------------------
-- TIME FIELDS
---------------------------------------------------------------------------
local timeFieldDefs = {
    { id = "GameDate",         name = "Game Date",        defaultShow = true,  defaultLabel = true,  defaultInline = false },
    { id = "GameTime",         name = "In-game time",     defaultShow = true,  defaultLabel = true,  defaultInline = false },
    { id = "TimeRate",         name = "Time rate",        defaultShow = true,  defaultLabel = true,  defaultInline = false },
    { id = "LocalTime",        name = "Local time",       defaultShow = true,  defaultLabel = true,  defaultInline = false },
    { id = "UtcTime",          name = "UTC time",         defaultShow = true,  defaultLabel = true,  defaultInline = false },
    { id = "SessionType",      name = "Session type",     defaultShow = true,  defaultLabel = true,  defaultInline = false },
    { id = "SessionRemaining", name = "Session remaining",defaultShow = true,  defaultLabel = true,  defaultInline = false },
}

---------------------------------------------------------------------------
-- WEATHER FIELDS
---------------------------------------------------------------------------
local weatherFieldDefs = {
    { id = "Weather",       name = "Weather",        defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "Transition",    name = "Transition",     defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "Forecast",      name = "Forecast",       defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "Temperature",   name = "Temperature",    defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "Wind",          name = "Wind",           defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "RainIntensity", name = "Rain Intensity", defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "TrackWetness",  name = "Track Wetness",  defaultShow = true, defaultLabel = true, defaultInline = false },
    { id = "StandingWater", name = "Standing Water", defaultShow = true, defaultLabel = true, defaultInline = false },
}

---------------------------------------------------------------------------
-- GRIP FIELDS
---------------------------------------------------------------------------
local gripFieldDefs = {
    { id = "SurfaceGrip", name = "Surface Grip", defaultShow = true, defaultLabel = true, defaultInline = false },
}

---------------------------------------------------------------------------
-- BUILD CONFIG DEFAULTS
---------------------------------------------------------------------------
local function buildDefaultOrder(fieldDefs)
    local str = ""
    for i, f in ipairs(fieldDefs) do
        str = str .. f.id
        if i < #fieldDefs then str = str .. "," end
    end
    return str
end

local configDefaults = {
    -- Global settings
    languageCode = "EN_GB",
    -- Time window
    timeOpacity = 70,
    timeBgColor = defaultBgColor,
    timeFontIndex = 1,
    timeBaseFontSize = 14,
    timeScaleFont = false,
    timeUse24h = true,
    timeShowSeconds = true,
    timeFieldOrder = buildDefaultOrder(timeFieldDefs),
    timePaddingX = 0,
    timePaddingY = 0,
    timePaddingLinked = true,
    timeLineSpacing = 0,
    -- Weather window
    weatherOpacity = 70,
    weatherBgColor = defaultBgColor,
    weatherFontIndex = 1,
    weatherBaseFontSize = 14,
    weatherScaleFont = false,
    weatherFieldOrder = buildDefaultOrder(weatherFieldDefs),
    weatherPaddingX = 0,
    weatherPaddingY = 0,
    weatherPaddingLinked = true,
    weatherLineSpacing = 0,
    -- Grip window
    gripOpacity = 70,
    gripBgColor = defaultBgColor,
    gripFontIndex = 1,
    gripBaseFontSize = 14,
    gripScaleFont = false,
    gripDecimalPlaces = 0,
    gripFieldOrder = buildDefaultOrder(gripFieldDefs),
    gripPaddingX = 0,
    gripPaddingY = 0,
    gripPaddingLinked = true,
    gripLineSpacing = 0,
}

-- Add per-field settings for time
for _, f in ipairs(timeFieldDefs) do
    configDefaults["timeShow" .. f.id] = f.defaultShow
    configDefaults["timeLabel" .. f.id] = f.defaultLabel
    configDefaults["timeInline" .. f.id] = f.defaultInline
    configDefaults["timeLabelColor" .. f.id] = defaultLabelColor
    configDefaults["timeValueColor" .. f.id] = defaultValueColor
end

-- Add per-field settings for weather
for _, f in ipairs(weatherFieldDefs) do
    configDefaults["weatherShow" .. f.id] = f.defaultShow
    configDefaults["weatherLabel" .. f.id] = f.defaultLabel
    configDefaults["weatherInline" .. f.id] = f.defaultInline
    configDefaults["weatherLabelColor" .. f.id] = defaultLabelColor
    configDefaults["weatherValueColor" .. f.id] = defaultValueColor
end

-- Add per-field settings for grip
for _, f in ipairs(gripFieldDefs) do
    configDefaults["gripShow" .. f.id] = f.defaultShow
    configDefaults["gripLabel" .. f.id] = f.defaultLabel
    configDefaults["gripInline" .. f.id] = f.defaultInline
    configDefaults["gripLabelColor" .. f.id] = defaultLabelColor
    configDefaults["gripValueColor" .. f.id] = defaultValueColor
end

local config = ac.storage(configDefaults)

-- Load language from stored preference on startup
loadLanguage(i18nDir .. config.languageCode .. ".ini")

---------------------------------------------------------------------------
-- UTILITIES
---------------------------------------------------------------------------

-- Cached field order arrays
local fieldOrderCache = {}

local function getFieldOrder(orderStr, fieldDefs)
    -- Check cache first
    local cacheKey = orderStr or ""
    if fieldOrderCache[cacheKey] then
        return fieldOrderCache[cacheKey]
    end
    
    local order = {}
    for id in string.gmatch(orderStr or "", "([^,]+)") do
        for _, f in ipairs(fieldDefs) do
            if f.id == id then
                table.insert(order, id)
                break
            end
        end
    end
    -- Add missing fields
    for _, f in ipairs(fieldDefs) do
        local found = false
        for _, id in ipairs(order) do
            if id == f.id then found = true; break end
        end
        if not found then table.insert(order, f.id) end
    end
    
    fieldOrderCache[cacheKey] = order
    return order
end

-- Invalidate field order cache for a specific order string
local function invalidateFieldOrderCache(orderStr)
    fieldOrderCache[orderStr or ""] = nil
end

local function getFieldDef(fieldDefs, id)
    for _, f in ipairs(fieldDefs) do
        if f.id == id then return f end
    end
    return nil
end

---------------------------------------------------------------------------
-- FONTS
-- Dynamically scans content/fonts/ for TTF/OTF files.
-- Since CSP 0.1.80, just the path to a TTF file can be used directly.
-- Lazy loading: fonts are only scanned when settings panel is first opened.
-- Font names are read from TTF/OTF name tables with filename fallback.
-- Note: TTC/OTC collection files only use the first font (matches CSP behavior).
---------------------------------------------------------------------------
local acFontsPath = ac.getFolder(ac.FolderID.Root) .. "/content/fonts/"

-- Read big-endian unsigned integers from string at offset (1-indexed)
local function readU16BE(data, offset)
    local b1, b2 = data:byte(offset, offset + 1)
    if not b1 or not b2 then return nil end
    return b1 * 256 + b2
end

local function readU32BE(data, offset)
    local b1, b2, b3, b4 = data:byte(offset, offset + 3)
    if not b1 or not b4 then return nil end
    return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

-- Convert UTF-16BE string to ASCII (simple conversion, drops high bytes)
local function utf16BEtoAscii(data)
    local result = {}
    for i = 1, #data - 1, 2 do
        local high, low = data:byte(i, i + 1)
        if low and low >= 32 and low < 127 then
            table.insert(result, string.char(low))
        end
    end
    return table.concat(result)
end

-- Read font name from TTF/OTF file's name table
-- Returns nil on failure (caller should fall back to filename)
local function readFontName(filePath)
    local file = io.open(filePath, "rb")
    if not file then return nil end
    
    -- Read enough header to find tables (12 bytes header + up to 32 tables * 16 bytes)
    local header = file:read(524)
    if not header or #header < 12 then
        file:close()
        return nil
    end
    
    -- Check for TTC (collection) - still works, just uses first font's offset
    local tag = header:sub(1, 4)
    local tableOffset = 1
    if tag == "ttcf" then
        -- TTC: read offset to first font
        local firstFontOffset = readU32BE(header, 13)  -- offset at byte 12 (1-indexed = 13)
        if not firstFontOffset then
            file:close()
            return nil
        end
        tableOffset = firstFontOffset + 1  -- convert to 1-indexed
        -- Re-read header from font offset if needed
        if tableOffset > 1 then
            file:seek("set", firstFontOffset)
            header = file:read(524)
            if not header or #header < 12 then
                file:close()
                return nil
            end
            tableOffset = 1
        end
    end
    
    -- Parse offset table
    local numTables = readU16BE(header, tableOffset + 4)
    if not numTables or numTables > 100 then
        file:close()
        return nil
    end
    
    -- Find 'name' table in table directory
    local nameTableOffset, nameTableLength
    for i = 0, numTables - 1 do
        local entryOffset = tableOffset + 12 + (i * 16)
        if entryOffset + 15 > #header then break end
        
        local tableTag = header:sub(entryOffset, entryOffset + 3)
        if tableTag == "name" then
            nameTableOffset = readU32BE(header, entryOffset + 8)
            nameTableLength = readU32BE(header, entryOffset + 12)
            break
        end
    end
    
    if not nameTableOffset or not nameTableLength then
        file:close()
        return nil
    end
    
    -- Read name table
    file:seek("set", nameTableOffset)
    local nameTable = file:read(math.min(nameTableLength, FONT_NAME_TABLE_MAX))
    file:close()
    
    if not nameTable or #nameTable < 6 then
        return nil
    end
    
    -- Parse name table header (format field at offset 1 is unused)
    local count = readU16BE(nameTable, 3)
    local stringOffset = readU16BE(nameTable, 5)
    
    if not count or not stringOffset or count > FONT_NAME_RECORD_MAX then
        return nil
    end
    
    -- Search name records for Full Font Name (nameID 4) or Family Name (nameID 1)
    -- Priority: Windows Unicode (platform 3) > Mac Roman (platform 1)
    local bestName = nil
    local bestPriority = 0
    
    for i = 0, count - 1 do
        local recordOffset = 7 + (i * 12)  -- 6 byte header + 1 for 1-indexing
        if recordOffset + 11 > #nameTable then break end
        
        local platformID = readU16BE(nameTable, recordOffset)
        local encodingID = readU16BE(nameTable, recordOffset + 2)
        local languageID = readU16BE(nameTable, recordOffset + 4)
        local nameID = readU16BE(nameTable, recordOffset + 6)
        local length = readU16BE(nameTable, recordOffset + 8)
        local offset = readU16BE(nameTable, recordOffset + 10)
        
        if not nameID or not length or not offset then break end
        
        -- We want nameID 4 (Full Name) or 1 (Family Name)
        if nameID == 4 or nameID == 1 then
            local priority = 0
            
            -- Prefer Full Name (4) over Family Name (1)
            if nameID == 4 then priority = priority + 10 end
            
            -- Prefer Windows Unicode (3,1) over Mac Roman (1,0)
            if platformID == 3 and encodingID == 1 then
                priority = priority + 5  -- Windows Unicode
            elseif platformID == 1 and encodingID == 0 then
                priority = priority + 2  -- Mac Roman
            elseif platformID == 0 then
                priority = priority + 3  -- Unicode
            end
            
            -- Prefer English (language 0x0409 for Windows, 0 for Mac)
            if (platformID == 3 and languageID == 0x0409) or
               (platformID == 1 and languageID == 0) or
               (platformID == 0) then
                priority = priority + 1
            end
            
            if priority > bestPriority then
                local strStart = stringOffset + offset + 1  -- 1-indexed
                local strEnd = strStart + length - 1
                if strEnd <= #nameTable then
                    local rawName = nameTable:sub(strStart, strEnd)
                    local name
                    
                    -- Decode based on platform
                    if platformID == 3 or platformID == 0 then
                        -- UTF-16BE
                        name = utf16BEtoAscii(rawName)
                    else
                        -- Mac Roman / ASCII - use directly
                        name = rawName:gsub("%z", "")  -- Remove null bytes
                    end
                    
                    if name and #name > 0 then
                        bestName = name
                        bestPriority = priority
                    end
                end
            end
        end
    end
    
    return bestName
end

-- Convert filename to display name (fallback when metadata unavailable)
local function fileToDisplayName(filename)
    -- Case-insensitive extension removal (TTF only)
    local name = filename:lower():gsub("%.ttf$", ""):gsub("%.ttc$", "")
    -- But use original casing for the name portion
    name = filename:sub(1, #name)
    -- Replace common separators with spaces
    name = name:gsub("[-_]", " ")
    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$") or name
    -- Capitalize first letter of each word
    name = name:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest
    end)
    return name
end

-- Get display name for a font file (tries metadata first, falls back to filename)
local function getFontDisplayName(filePath, filename)
    local metaName = readFontName(filePath)
    if metaName and #metaName > 0 then
        return metaName
    end
    return fileToDisplayName(filename)
end

-- Scan content/fonts/ for TTF files and build font list
-- Note: OTF fonts are not supported by CSP's ui.pushDWriteFont()
local function scanFonts()
    local fonts = {}
    local files = io.scanDir(acFontsPath, "*.ttf")
    if files then
        for _, file in ipairs(files) do
            local fullPath = acFontsPath .. file
            local displayName = getFontDisplayName(fullPath, file)
            table.insert(fonts, {
                name = displayName,
                font = fullPath
            })
        end
    end
    -- Sort alphabetically by display name
    table.sort(fonts, function(a, b) return a.name < b.name end)
    return fonts
end

-- Lazy-loaded font list (nil until first settings access)
local fontList = nil
local fontNames = {}
local fontNamesNeedRefresh = true

local function ensureFontsLoaded()
    if fontList == nil then
        fontList = scanFonts()
        fontNamesNeedRefresh = true
    end
end

local function refreshFontNames()
    ensureFontsLoaded()
    fontNames = {}
    for i, f in ipairs(fontList) do
        fontNames[i] = f.name
    end
    fontNamesNeedRefresh = false
end

local function getFont(index)
    ensureFontsLoaded()
    return fontList[index] and fontList[index].font or (fontList[1] and fontList[1].font or "Segoe UI")
end

-- Rescan fonts (can be called from settings to pick up new fonts)
local function rescanFonts()
    fontList = scanFonts()
    fontNamesNeedRefresh = true
end

---------------------------------------------------------------------------
-- DATA LOOKUPS (using language strings)
---------------------------------------------------------------------------

-- Map session types to language keys
local sessionTypeKeys = {
    [ac.SessionType.Undefined] = "Undefined",
    [ac.SessionType.Practice] = "Practice",
    [ac.SessionType.Qualify] = "Qualify",
    [ac.SessionType.Race] = "Race",
    [ac.SessionType.Hotlap] = "Hotlap",
    [ac.SessionType.TimeAttack] = "TimeAttack",
    [ac.SessionType.Drift] = "Drift",
    [ac.SessionType.Drag] = "Drag"
}

local function getWeatherName(t)
    return lang.WeatherTypes[t] or lang.Labels.Unknown
end

local function getSessionName(t)
    local key = sessionTypeKeys[t]
    return key and lang.Sessions[key] or lang.Sessions.Undefined
end

local function getWindDir(deg)
    local idx = math.floor((deg / 22.5) + 0.5) + 1
    if idx > 16 then idx = 1 end
    return lang.WindDirections[idx] or "N"
end

local function formatSessionTime(ms)
    local totalSec = math.floor(ms / 1000)
    if totalSec < 0 then
        -- Negative means no limit or overtime
        return nil
    end
    local hours = math.floor(totalSec / 3600)
    local mins = math.floor((totalSec % 3600) / 60)
    local secs = totalSec % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Format date according to language DateFormat pattern
local function formatDate(year, month, day)
    local pattern = lang.DateFormat
    local result = ""
    local i = 1
    local len = #pattern
    
    while i <= len do
        local c = pattern:sub(i, i)
        local handled = false
        
        -- Check for 4-char tokens
        if i + 3 <= len then
            local s4 = pattern:sub(i, i+3)
            if s4 == "YYYY" then
                result = result .. string.format("%04d", year)
                i = i + 4
                handled = true
            elseif s4 == "MMMM" then
                result = result .. (lang.MonthNames[month] or "")
                i = i + 4
                handled = true
            end
        end
        
        -- Check for 3-char tokens
        if not handled and i + 2 <= len then
            local s3 = pattern:sub(i, i+2)
            if s3 == "MMM" then
                result = result .. (lang.MonthAbbreviations[month] or "")
                i = i + 3
                handled = true
            end
        end
        
        -- Check for 2-char tokens
        if not handled and i + 1 <= len then
            local s2 = pattern:sub(i, i+1)
            if s2 == "YY" then
                result = result .. string.format("%02d", year % 100)
                i = i + 2
                handled = true
            elseif s2 == "MM" then
                result = result .. string.format("%02d", month)
                i = i + 2
                handled = true
            elseif s2 == "DD" then
                result = result .. string.format("%02d", day)
                i = i + 2
                handled = true
            elseif s2 == "_D" then
                result = result .. string.format("%2d", day)
                i = i + 2
                handled = true
            end
        end
        
        -- Check for 1-char tokens
        if not handled then
            if c == "M" then
                result = result .. tostring(month)
                i = i + 1
                handled = true
            elseif c == "D" then
                result = result .. tostring(day)
                i = i + 1
                handled = true
            end
        end
        
        if not handled then
            result = result .. c
            i = i + 1
        end
    end
    
    return result
end

-- Format time as 24h (HH:MM:SS) or 12h (h:mm:ss AM/PM)
local function formatTime(hour, min, sec, use24h, showSeconds)
    if use24h then
        if showSeconds then
            return string.format("%02d:%02d:%02d", hour, min, sec)
        else
            return string.format("%02d:%02d", hour, min)
        end
    else
        local period = hour >= 12 and lang.TimePeriods.PM or lang.TimePeriods.AM
        local h12 = hour % 12
        if h12 == 0 then h12 = 12 end
        if showSeconds then
            return string.format("%d:%02d:%02d %s", h12, min, sec, period)
        else
            return string.format("%d:%02d %s", h12, min, period)
        end
    end
end

-- Convert Celsius to Fahrenheit
local function celsiusToFahrenheit(c)
    return math.floor(c * 9 / 5 + 32 + 0.5)
end

-- Convert km/h to mph
local function kmhToMph(kmh)
    return math.floor(kmh * 0.621371 + 0.5)
end

---------------------------------------------------------------------------
-- CACHED DATA
---------------------------------------------------------------------------
local data = {}
local lastUpdateTime = 0
local anyWindowVisible = false

local function computeData()
    -- sim is a live reference, no need to re-fetch
    local ts = sim.timestamp
    local mult = sim.timeMultiplier
    local gd = os.date("!*t", ts)
    local lt = os.date("*t")
    local ut = os.date("!*t")
    local use24h = config.timeUse24h
    local showSec = config.timeShowSeconds
    
    data.gameDate = formatDate(gd.year, gd.month, gd.day)
    data.gameTime = formatTime(gd.hour, gd.min, gd.sec, use24h, showSec)
    data.localTime = formatTime(lt.hour, lt.min, lt.sec, use24h, showSec)
    data.utcTime = formatTime(ut.hour, ut.min, ut.sec, use24h, showSec)
    data.sessionName = getSessionName(sim.raceSessionType)
    
    -- Session remaining: show time if available, otherwise try laps
    local sessionTimeStr = formatSessionTime(sim.sessionTimeLeft)
    if sessionTimeStr then
        data.sessionRemaining = sessionTimeStr
    else
        -- Try to get lap-based info from session
        local session = ac.getSession(sim.currentSessionIndex)
        if session and session.laps and session.laps > 0 then
            -- Lap-based session - find the race leader and compute laps remaining
            local leaderLapCount = 0
            for i = 0, sim.carsCount - 1 do
                local car = ac.getCar(i)
                if car and car.racePosition == 1 then
                    leaderLapCount = car.lapCount
                    break
                end
            end
            local lapsRemaining = session.laps - leaderLapCount
            if lapsRemaining >= 0 then
                data.sessionRemaining = string.format("%d %s", lapsRemaining, lang.Labels.Laps or "laps")
            else
                data.sessionRemaining = string.format("0 %s", lang.Labels.Laps or "laps")
            end
        else
            -- Unlimited session
            data.sessionRemaining = "--:--:--"
        end
    end
    
    -- Temperature with unit conversion
    if lang.TemperatureUnit == "F" then
        data.airTemp = celsiusToFahrenheit(sim.ambientTemperature)
        data.roadTemp = celsiusToFahrenheit(sim.roadTemperature)
        data.tempUnit = "°F"
    else
        data.airTemp = math.floor(sim.ambientTemperature + 0.5)
        data.roadTemp = math.floor(sim.roadTemperature + 0.5)
        data.tempUnit = "°"
    end
    
    -- Wind speed with unit conversion
    if lang.WindSpeedUnit == "mph" then
        data.windSpeed = kmhToMph(sim.windSpeedKmh)
        data.windUnit = "mph"
    else
        data.windSpeed = math.floor(sim.windSpeedKmh + 0.5)
        data.windUnit = "km/h"
    end
    
    data.windDir = getWindDir(sim.windDirectionDeg)
    data.weather = getWeatherName(sim.weatherType)
    data.forecast = getWeatherName(sim.weatherConditions.upcomingType)
    data.surfaceGrip = sim.roadGrip  -- 0 to 1
    
    -- Rain and wetness data (0-100%)
    data.transition = math.floor((sim.weatherConditions.transition or 0) * 100 + 0.5)
    data.rainIntensity = math.floor((sim.rainIntensity or 0) * 100 + 0.5)
    data.rainWetness = math.floor((sim.rainWetness or 0) * 100 + 0.5)
    data.rainWater = math.floor((sim.rainWater or 0) * 100 + 0.5)
    
    -- Clock speed / time multiplier display
    if mult < 0.01 then
        -- Time is effectively paused/locked
        data.rate = lang.ClockSpeeds.TimeFixed
    elseif math.abs(mult - 1.0) < 0.01 then
        data.rate = "1" .. lang.ClockSpeeds.Multiplier
    else
        data.rate = string.format("%d%s", math.floor(mult + 0.5), lang.ClockSpeeds.Multiplier)
    end
end

computeData()

---------------------------------------------------------------------------
-- FIELD TEXT
-- Returns (labelText, valueText) - label is empty string if showLabel is false
-- Uses language strings for all labels
---------------------------------------------------------------------------
local function getTimeFieldText(id, showLabel)
    if id == "GameDate" then
        return showLabel and lang.Labels.GameDate or "", data.gameDate
    elseif id == "GameTime" then
        return showLabel and lang.Labels.GameTime or "", data.gameTime
    elseif id == "TimeRate" then
        return showLabel and lang.Labels.ClockSpeed or "", data.rate
    elseif id == "LocalTime" then
        return showLabel and lang.Labels.RealTime or "", data.localTime
    elseif id == "UtcTime" then
        return showLabel and lang.Labels.RealUTC or "", data.utcTime
    elseif id == "SessionType" then
        return showLabel and lang.Labels.Session or "", data.sessionName
    elseif id == "SessionRemaining" then
        return showLabel and lang.Labels.Remaining or "", data.sessionRemaining
    end
    return "", ""
end

local function getWeatherFieldText(id, showLabel)
    if id == "Weather" then
        return showLabel and lang.Labels.Weather or "", data.weather
    elseif id == "Transition" then
        return showLabel and lang.Labels.Transition or "", string.format("%d%%", data.transition)
    elseif id == "Forecast" then
        return showLabel and lang.Labels.Forecast or "", data.forecast
    elseif id == "Temperature" then
        if showLabel then
            return lang.Labels.Temperature, string.format("%s %d%s  %s %d%s", 
                lang.Labels.Air, data.airTemp, data.tempUnit,
                lang.Labels.Road, data.roadTemp, data.tempUnit)
        else
            return "", string.format("%d%s/%d%s", data.airTemp, data.tempUnit, data.roadTemp, data.tempUnit)
        end
    elseif id == "Wind" then
        if showLabel then
            return lang.Labels.Wind, string.format("%s %d %s", data.windDir, data.windSpeed, data.windUnit)
        else
            return "", string.format("%s %d %s", data.windDir, data.windSpeed, data.windUnit)
        end
    elseif id == "RainIntensity" then
        return showLabel and lang.Labels.RainIntensity or "", string.format("%d%%", data.rainIntensity)
    elseif id == "TrackWetness" then
        return showLabel and lang.Labels.TrackWetness or "", string.format("%d%%", data.rainWetness)
    elseif id == "StandingWater" then
        return showLabel and lang.Labels.StandingWater or "", string.format("%d%%", data.rainWater)
    end
    return "", ""
end

local function getGripFieldText(id, showLabel)
    if id == "SurfaceGrip" then
        local decimals = config.gripDecimalPlaces or 0
        local pct = math.floor(data.surfaceGrip * 100 * (10 ^ decimals)) / (10 ^ decimals)
        local fmt = "%%.%df%%%%"
        local valueStr = string.format(fmt:format(decimals), pct)
        -- Apply locale-specific decimal separator
        local sep = lang.DecimalSeparator or "."
        if sep ~= "." then
            valueStr = valueStr:gsub("%.", sep)
        end
        return showLabel and lang.Labels.Grip or "", valueStr
    end
    return "", ""
end

---------------------------------------------------------------------------
-- GENERIC RENDER FUNCTION
---------------------------------------------------------------------------

-- Window control state for manual positioning
-- local windowControl = {} -- Positioning not available in API

local function getWindowControl(prefix)
    -- Stub or remove
    return nil
end

-- Measure the width of a single field (label + gap + value) at given font size
local function measureFieldWidth(labelText, valueText, fontSize, fontPath)
    local width = 0
    if labelText and labelText ~= "" then
        width = width + ui.measureDWriteText(labelText, fontSize, fontPath).x
        width = width + fontSize * LABEL_VALUE_GAP_FACTOR
    end
    if valueText and valueText ~= "" then
        width = width + ui.measureDWriteText(valueText, fontSize, fontPath).x
    end
    return width
end

-- Calculate font size to fit content to window width
-- Returns scaled font size based on measuring actual content rows
local function calculateFitToWidthFontSize(prefix, fieldDefs, getTextFn, baseFontSize, fontPath, windowWidth)
    local orderKey = prefix .. "FieldOrder"
    local order = getFieldOrder(config[orderKey], fieldDefs)
    
    local paddingX = config[prefix .. "PaddingX"] or 0

    -- Use a reference size for measuring (we'll scale proportionally)
    local refSize = 14
    local basePadding = refSize * 2  -- Horizontal padding (scaled later)
    
    -- Measure each row's width at reference size
    -- A "row" is a sequence of fields where all but the first have inline=true
    local maxRowWidth = 0
    local currentRowWidth = 0
    local isFirstInRow = true
    
    for _, id in ipairs(order) do
        local showKey = prefix .. "Show" .. id
        local labelKey = prefix .. "Label" .. id
        local inlineKey = prefix .. "Inline" .. id
        
        if config[showKey] then
            local showLabel = config[labelKey]
            local labelText, valueText = getTextFn(id, showLabel)
            local isInline = config[inlineKey]
            
            local fieldWidth = measureFieldWidth(labelText, valueText, refSize, fontPath)
            
            if isInline and not isFirstInRow then
                -- Add to current row with gap
                currentRowWidth = currentRowWidth + refSize + fieldWidth  -- gap + field
            else
                -- Start new row - finalize previous row first
                if currentRowWidth > maxRowWidth then
                    maxRowWidth = currentRowWidth
                end
                currentRowWidth = fieldWidth
            end
            isFirstInRow = false
        end
    end
    
    -- Don't forget the last row
    if currentRowWidth > maxRowWidth then
        maxRowWidth = currentRowWidth
    end
    
    -- If no content, return base size
    if maxRowWidth <= 0 then
        return baseFontSize
    end
    
    -- Calculate scale factor: how much we can grow refSize to fill windowWidth
    local availableWidth = windowWidth - basePadding - (paddingX * 2) 
    local scale = availableWidth / maxRowWidth
    
    -- Clamp scale to reasonable bounds
    local minScale = (baseFontSize * FONT_SCALE_MIN) / refSize
    local maxScale = (baseFontSize * FONT_SCALE_MAX) / refSize
    scale = math.max(minScale, math.min(maxScale, scale))
    
    return refSize * scale
end

local function renderWindow(prefix, fieldDefs, getTextFn, settingsWindowId, windowName)
    anyWindowVisible = true  -- Mark that at least one window was rendered this frame
    
    local opacityKey = prefix .. "Opacity"
    local bgColorKey = prefix .. "BgColor"
    local fontIndexKey = prefix .. "FontIndex"
    local baseSizeKey = prefix .. "BaseFontSize"
    local scaleFontKey = prefix .. "ScaleFont"
    local orderKey = prefix .. "FieldOrder"
    
    -- Background with configurable color and opacity
    local bgOpacity = (config[opacityKey] or 70) / 100
    local bgColor = getRenderColor(bgColorKey, config[bgColorKey] or defaultBgColor)
    local winSize = ui.windowSize()
    ui.drawRectFilled(vec2(0, 0), winSize, rgbm(bgColor.r, bgColor.g, bgColor.b, bgOpacity))
    
    -- Right-click to open separate settings window
    if settingsWindowId and ui.windowHovered() and ui.mouseClicked(ui.MouseButton.Right) then
        ui.openWindow(settingsWindowId)
    end

    local paddingX = config[prefix .. "PaddingX"] or 0
    local paddingY = config[prefix .. "PaddingY"] or 0
    local lineSpacing = config[prefix .. "LineSpacing"] or 0

    -- Get font path for measurements
    local fontPath = getFont(config[fontIndexKey] or 1)
    
    -- Font size calculation
    local fontSize = config[baseSizeKey] or 14
    if config[scaleFontKey] then
        -- Fit to width: measure content and scale to fill window
        fontSize = calculateFitToWidthFontSize(prefix, fieldDefs, getTextFn, fontSize, fontPath, winSize.x)
    end
    
    if paddingY ~= 0 then
        ui.offsetCursorY(paddingY)
    end
    if paddingX ~= 0 then
        ui.indent(paddingX)
    end

    ui.pushDWriteFont(fontPath)
    
    local order = getFieldOrder(config[orderKey], fieldDefs)
    local isFirst = true
    
    for _, id in ipairs(order) do
        local showKey = prefix .. "Show" .. id
        local labelKey = prefix .. "Label" .. id
        local inlineKey = prefix .. "Inline" .. id
        local labelColorKey = prefix .. "LabelColor" .. id
        local valueColorKey = prefix .. "ValueColor" .. id
        
        if config[showKey] then
            local showLabel = config[labelKey]
            local labelText, valueText = getTextFn(id, showLabel)
            local isInline = config[inlineKey]
            
            if isInline and not isFirst then
                ui.sameLine(0, fontSize)
            elseif not isFirst then
                if lineSpacing ~= 0 then
                    ui.offsetCursorY(lineSpacing)
                end
            end
            
            -- Draw label and value with separate colors (using render cache)
            if showLabel and labelText and labelText ~= "" then
                ui.dwriteText(labelText, fontSize, getRenderColor(labelColorKey, config[labelColorKey]))
                ui.sameLine(0, fontSize * LABEL_VALUE_GAP_FACTOR)
            end
            if valueText and valueText ~= "" then
                ui.dwriteText(valueText, fontSize, getRenderColor(valueColorKey, config[valueColorKey]))
            end
            isFirst = false
        end
    end
    
    ui.popDWriteFont()
    
    if paddingX ~= 0 then
        ui.unindent(paddingX)
    end
end

---------------------------------------------------------------------------
-- GENERIC SETTINGS FUNCTION
---------------------------------------------------------------------------

-- Pre-allocated refnumber objects for sliders (avoid allocations per frame)
local sliderRefs = {
    opacity = refnumber(0),
    size = refnumber(0),
    paddingX = refnumber(0),
    paddingY = refnumber(0),
    lineSpacing = refnumber(0)
}

-- Reset all settings for a specific window to defaults
-- extraKeys is an optional table of additional keys to reset (e.g., {"timeUse24h", "timeShowSeconds"})
local function resetWindowConfig(prefix, fieldDefs, extraKeys)
    -- Invalidate old field order cache
    local orderKey = prefix .. "FieldOrder"
    invalidateFieldOrderCache(config[orderKey])
    
    -- Reset common window settings
    config[prefix .. "Opacity"] = configDefaults[prefix .. "Opacity"]
    config[prefix .. "BgColor"] = configDefaults[prefix .. "BgColor"]
    config[prefix .. "FontIndex"] = configDefaults[prefix .. "FontIndex"]
    config[prefix .. "BaseFontSize"] = configDefaults[prefix .. "BaseFontSize"]
    config[prefix .. "ScaleFont"] = configDefaults[prefix .. "ScaleFont"]
    config[orderKey] = configDefaults[orderKey]
    config[prefix .. "PaddingX"] = configDefaults[prefix .. "PaddingX"]
    config[prefix .. "PaddingY"] = configDefaults[prefix .. "PaddingY"]
    config[prefix .. "PaddingLinked"] = configDefaults[prefix .. "PaddingLinked"]
    config[prefix .. "LineSpacing"] = configDefaults[prefix .. "LineSpacing"]
    
    -- Reset background color cache
    resetCachedColor(prefix .. "BgColor", configDefaults[prefix .. "BgColor"])
    
    -- Reset per-field settings
    for _, f in ipairs(fieldDefs) do
        local showKey = prefix .. "Show" .. f.id
        local labelKey = prefix .. "Label" .. f.id
        local inlineKey = prefix .. "Inline" .. f.id
        local labelColorKey = prefix .. "LabelColor" .. f.id
        local valueColorKey = prefix .. "ValueColor" .. f.id
        
        config[showKey] = configDefaults[showKey]
        config[labelKey] = configDefaults[labelKey]
        config[inlineKey] = configDefaults[inlineKey]
        config[labelColorKey] = configDefaults[labelColorKey]
        config[valueColorKey] = configDefaults[valueColorKey]
        
        -- Reset color caches so pickers reload from config
        resetCachedColor(labelColorKey, configDefaults[labelColorKey])
        resetCachedColor(valueColorKey, configDefaults[valueColorKey])
    end
    
    -- Reset any extra keys specific to this window
    if extraKeys then
        for _, key in ipairs(extraKeys) do
            config[key] = configDefaults[key]
        end
    end
end

local function renderSettings(prefix, fieldDefs)
    local opacityKey = prefix .. "Opacity"
    local bgColorKey = prefix .. "BgColor"
    local fontIndexKey = prefix .. "FontIndex"
    local baseSizeKey = prefix .. "BaseFontSize"
    local scaleFontKey = prefix .. "ScaleFont"
    local orderKey = prefix .. "FieldOrder"
    
    ui.header("Display Rows")
    
    local order = getFieldOrder(config[orderKey], fieldDefs)
    local orderChanged = false
    
    for i, id in ipairs(order) do
        local fieldDef = getFieldDef(fieldDefs, id)
        if fieldDef then
            local showKey = prefix .. "Show" .. id
            local labelKey = prefix .. "Label" .. id
            local inlineKey = prefix .. "Inline" .. id
            
            -- Move up
            if i > 1 then
                if ui.button("^##up" .. id) then
                    order[i], order[i-1] = order[i-1], order[i]
                    orderChanged = true
                end
            else
                ui.dummy(vec2(23, 0))
            end
            ui.sameLine()
            
            -- Move down
            if i < #order then
                if ui.button("v##dn" .. id) then
                    order[i], order[i+1] = order[i+1], order[i]
                    orderChanged = true
                end
            else
                ui.dummy(vec2(23, 0))
            end
            ui.sameLine()
            
            -- Show toggle
            if ui.checkbox("##show" .. id, config[showKey]) then
                config[showKey] = not config[showKey]
            end
            ui.sameLine()
            
            ui.text(fieldDef.name)
            
            if config[showKey] then
                local labelColorKey = prefix .. "LabelColor" .. id
                local valueColorKey = prefix .. "ValueColor" .. id
                
                ui.sameLine(250)
                if ui.checkbox("Label##" .. id, config[labelKey]) then
                    config[labelKey] = not config[labelKey]
                end
                
                ui.sameLine(330)
                if ui.checkbox("Inline##" .. id, config[inlineKey]) then
                    config[inlineKey] = not config[inlineKey]
                end
                
                -- Label color picker (uses cached rgbm that picker modifies in-place)
                ui.sameLine(410)
                local lblColor = getCachedColor(labelColorKey, config[labelColorKey])
                ui.colorButton("Lbl##lc" .. id, lblColor, 
                        ui.ColorPickerFlags.AlphaBar + ui.ColorPickerFlags.AlphaPreview + ui.ColorPickerFlags.PickerHueBar)
                -- Always sync cached color back to config (picker modifies in-place)
                config[labelColorKey] = rgbmToHex(lblColor)
                if ui.itemHovered() then ui.setTooltip("Label color") end
                
                -- Value color picker
                ui.sameLine()
                local valColor = getCachedColor(valueColorKey, config[valueColorKey])
                ui.colorButton("Val##vc" .. id, valColor, 
                        ui.ColorPickerFlags.AlphaBar + ui.ColorPickerFlags.AlphaPreview + ui.ColorPickerFlags.PickerHueBar)
                -- Always sync cached color back to config
                config[valueColorKey] = rgbmToHex(valColor)
                if ui.itemHovered() then ui.setTooltip("Value color") end
            end
        end
    end
    
    if orderChanged then
        local oldOrder = config[orderKey]
        config[orderKey] = table.concat(order, ",")
        invalidateFieldOrderCache(oldOrder)
    end
    
    ui.offsetCursorY(SETTINGS_SECTION_SPACING)
    ui.header("Window Options")
    
    ui.setNextItemWidth(150)
    sliderRefs.opacity.value = config[opacityKey]
    if ui.slider("Background Opacity", sliderRefs.opacity, 0, 100, "%.0f%%") then
        config[opacityKey] = sliderRefs.opacity.value
    end
    ui.sameLine()
    local bgColor = getCachedColor(bgColorKey, config[bgColorKey] or defaultBgColor)
    ui.colorButton("BG##bgc", bgColor,
            ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar)
    config[bgColorKey] = rgbmToHex(bgColor)
    if ui.itemHovered() then ui.setTooltip("Background color") end

    local paddingXKey = prefix .. "PaddingX"
    local paddingYKey = prefix .. "PaddingY"
    local linkedKey = prefix .. "PaddingLinked"

    ui.setNextItemWidth(150)
    sliderRefs.paddingX.value = config[paddingXKey] or 0
    if ui.slider("Padding X", sliderRefs.paddingX, 0, 60, "%.0f px") then
        config[paddingXKey] = sliderRefs.paddingX.value
        if config[linkedKey] then
            config[paddingYKey] = sliderRefs.paddingX.value
        end
    end
    
    ui.sameLine()
    if ui.checkbox("##link" .. prefix, config[linkedKey]) then
        config[linkedKey] = not config[linkedKey]
        if config[linkedKey] then
            config[paddingYKey] = config[paddingXKey]
        end
    end
    if ui.itemHovered() then ui.setTooltip("Link X and Y Padding") end

    ui.setNextItemWidth(150)
    if config[linkedKey] then
        ui.pushStyleVar(ui.StyleVar.Alpha, 0.5)
        local displayVal = refnumber(config[paddingXKey] or 0)
        ui.slider("Padding Y", displayVal, 0, 60, "%.0f px")
        ui.popStyleVar()
    else
        sliderRefs.paddingY.value = config[paddingYKey] or 0
        if ui.slider("Padding Y", sliderRefs.paddingY, 0, 60, "%.0f px") then
            config[paddingYKey] = sliderRefs.paddingY.value
        end
    end

    ui.setNextItemWidth(150)
    sliderRefs.lineSpacing.value = config[prefix .. "LineSpacing"] or 0
    if ui.slider("Line spacing", sliderRefs.lineSpacing, -100, 100, "%.0f px") then
        config[prefix .. "LineSpacing"] = sliderRefs.lineSpacing.value
    end
    
    ui.offsetCursorY(SETTINGS_SECTION_SPACING)
    ui.header("Font Options")
    
    -- Refresh font names if needed (lazy load happens here)
    if fontNamesNeedRefresh then
        refreshFontNames()
    end
    
    ui.setNextItemWidth(150)
    local newFontIndex = ui.combo("Font", config[fontIndexKey], ui.ComboFlags.None, fontNames)
    if newFontIndex ~= config[fontIndexKey] then
        config[fontIndexKey] = newFontIndex
    end
    ui.sameLine()
    if ui.button("Rescan") then
        rescanFonts()
        refreshFontNames()
    end
    if ui.itemHovered() then
        ui.setTooltip("Rescan content/fonts/ for TTF files (OTF not supported)")
    end
    
    ui.setNextItemWidth(150)
    sliderRefs.size.value = config[baseSizeKey]
    if ui.slider("Size", sliderRefs.size, 8, 32, "%.0f px") then
        config[baseSizeKey] = sliderRefs.size.value
    end
    
    if ui.checkbox("Scale with window size", config[scaleFontKey]) then
        config[scaleFontKey] = not config[scaleFontKey]
    end
end

---------------------------------------------------------------------------
-- LANGUAGE SELECTOR UI
-- Renders a dropdown to select the language, with a Rescan button.
-- Shown in each window's settings for easy access.
---------------------------------------------------------------------------
local function renderLanguageSelector()
    ui.header("Language")
    
    -- Refresh language names if needed (lazy load happens here)
    if languageNamesNeedRefresh then
        refreshLanguageNames()
    end
    
    local currentIndex = getLanguageIndex(config.languageCode)
    
    ui.setNextItemWidth(150)
    local newIndex = ui.combo("##lang", currentIndex, ui.ComboFlags.None, languageNames)
    if newIndex ~= currentIndex then
        local newCode = getLanguageCode(newIndex)
        local newPath = getLanguagePath(newIndex)
        config.languageCode = newCode
        loadLanguage(newPath)
    end
    
    ui.sameLine()
    if ui.button("Rescan##lang") then
        rescanLanguages()
        refreshLanguageNames()
    end
    if ui.itemHovered() then
        ui.setTooltip("Rescan i18n/ folder for new language files")
    end
    
    ui.offsetCursorY(SETTINGS_SECTION_SPACING)
end

---------------------------------------------------------------------------
-- TIME WINDOW
---------------------------------------------------------------------------
function script.windowTime(dt)
    renderWindow("time", timeFieldDefs, getTimeFieldText, "time_options", "ConditionReports Time")
end

function script.windowTimeSettings(dt)
    renderLanguageSelector()
    renderSettings("time", timeFieldDefs)
    
    -- Time-specific option
    ui.offsetCursorY(SETTINGS_SECTION_SPACING)
    ui.header("Time Format")
    
    if ui.checkbox("Use 24-hour format", config.timeUse24h) then
        config.timeUse24h = not config.timeUse24h
    end
    if ui.itemHovered() then
        ui.setTooltip("When disabled, times display as 12-hour with AM/PM")
    end
    
    if ui.checkbox("Show seconds", config.timeShowSeconds) then
        config.timeShowSeconds = not config.timeShowSeconds
    end
    if ui.itemHovered() then
        ui.setTooltip("When disabled, times display as HH:MM only")
    end
    
    -- Reset to defaults
    ui.offsetCursorY(SETTINGS_SECTION_SPACING * 2)
    if ui.button("Reset to Defaults") then
        resetWindowConfig("time", timeFieldDefs, {"timeUse24h", "timeShowSeconds"})
    end
end

---------------------------------------------------------------------------
-- WEATHER WINDOW
---------------------------------------------------------------------------
function script.windowWeather(dt)
    renderWindow("weather", weatherFieldDefs, getWeatherFieldText, "weather_options", "ConditionReports Weather")
end

function script.windowWeatherSettings(dt)
    renderLanguageSelector()
    renderSettings("weather", weatherFieldDefs)
    
    -- Reset to defaults
    ui.offsetCursorY(SETTINGS_SECTION_SPACING * 2)
    if ui.button("Reset to Defaults") then
        resetWindowConfig("weather", weatherFieldDefs)
    end
end

---------------------------------------------------------------------------
-- GRIP WINDOW
---------------------------------------------------------------------------
function script.windowGrip(dt)
    renderWindow("grip", gripFieldDefs, getGripFieldText, "grip_options", "ConditionReports Grip")
end

function script.windowGripSettings(dt)
    renderLanguageSelector()
    renderSettings("grip", gripFieldDefs)
    
    -- Grip-specific option
    ui.offsetCursorY(SETTINGS_SECTION_SPACING)
    ui.header("Grip Format")
    
    ui.text("Decimal places")
    ui.sameLine(120)
    ui.setNextItemWidth(80)
    local decimalOptions = {"0", "1", "2"}
    local currentDecimal = (config.gripDecimalPlaces or 0) + 1  -- combo is 1-indexed
    local newDecimal = ui.combo("##decimals", currentDecimal, ui.ComboFlags.None, decimalOptions)
    if newDecimal ~= currentDecimal then
        config.gripDecimalPlaces = newDecimal - 1  -- store as 0-indexed
    end
    
    -- Reset to defaults
    ui.offsetCursorY(SETTINGS_SECTION_SPACING * 2)
    if ui.button("Reset to Defaults") then
        resetWindowConfig("grip", gripFieldDefs, {"gripDecimalPlaces"})
    end
end

---------------------------------------------------------------------------
-- UPDATE
-- Throttled to once per second, only when at least one window is visible
---------------------------------------------------------------------------
function script.update(dt)
    -- Check if any window was rendered last frame
    if not anyWindowVisible then
        return  -- Skip update if no windows are visible
    end
    
    -- Reset visibility flag for next frame
    anyWindowVisible = false
    
    -- Throttle updates to once per second
    lastUpdateTime = lastUpdateTime + dt
    if lastUpdateTime >= UPDATE_INTERVAL then
        lastUpdateTime = 0
        computeData()
    end
end
