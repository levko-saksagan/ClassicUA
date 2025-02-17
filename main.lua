local _, addonTable = ...

-- [ debug ]

local print_table = function (table, title)
    print(title .. " {")
    for k, v in pairs(table) do print("[" .. k .. "]=" .. tostring(v)) end
    print("} " .. title)
end

-- [ entries ]

local get_stats = function ()
    local stats = {}
    for _, v in ipairs({ "quest_a", "quest_h", "quest_n", "book", "item", "spell", "npc" }) do
        stats[v] = 0
        for _, _ in pairs(addonTable[v]) do stats[v] = stats[v] + 1 end
    end
    return stats
end

local prepare_quests = function (is_alliance)
    -- init faction quests reference
    addonTable.quest_f = is_alliance and addonTable.quest_a or addonTable.quest_h
    -- drop opposite faction quests
    addonTable[ is_alliance and "quest_h" or "quest_a" ] = nil
end

local prepare_codes = function (name, race, class, is_male)
    -- print("preparing codes for: " .. name .. " / " .. race .. " / " .. class .. " / " .. (is_male and "male" or "famale"))
    local at = addonTable
    local sex = is_male and 1 or 2
    local cases = { "н", "р", "д", "з", "о", "м", "к" }

    local codes = {
        ["{ім'я}"] = name,
        ["{Ім'я}"] = name,
        ["{ІМ'Я}"] = string.upper(name),
    }

    -- race

    for _, c in ipairs(cases) do
        codes["{раса:" .. c .. "}"] = at.race[race][c][sex]
        codes["{Раса:" .. c .. "}"] = at.race[race][c][sex]:gsub("^%l", string.upper)
        codes["{РАСА:" .. c .. "}"] = string.upper(at.race[race][c][sex])
        if c == "н" then -- "н" is default grammatical case
            codes["{раса}"] = codes["{раса:н}"]
            codes["{Раса}"] = codes["{Раса:н}"]
            codes["{РАСА}"] = codes["{РАСА:н}"]
        end
    end

    -- class

    for _, c in ipairs(cases) do
        codes["{клас:" .. c .. "}"] = at.class[class][c][sex]
        codes["{Клас:" .. c .. "}"] = at.class[class][c][sex]:gsub("^%l", string.upper)
        codes["{КЛАС:" .. c .. "}"] = string.upper(at.class[class][c][sex])
        if c == "н" then -- "н" is default grammatical case
            codes["{клас}"] = codes["{клас:н}"]
            codes["{Клас}"] = codes["{Клас:н}"]
            codes["{КЛАС}"] = codes["{КЛАС:н}"]
        end
    end

    -- sex

    codes["{стать:(.-):(.-)}"] = function (a, b)
        return is_male and a or b
    end

    -- print_table(codes, "codes")
    at.codes = codes
end

local make_text = function (text)
    if not text then
        return nil
    end

    for k, v in pairs(addonTable.codes) do
        text = text:gsub(k, v)
    end

    return text
end

local get_entry = function (type, id)
    id = tonumber(id)

    if type and id then
        if type == "quest" then
            local quest = nil

            if addonTable.quest_f[id] then
                quest = addonTable.quest_f[id]
            elseif addonTable.quest_n[id] then
                quest = addonTable.quest_n[id]
            end

            if quest then
                local result = {}
                for i = 1, #quest do
                    result[i] = make_text(quest[i])
                end
                return result
            end
        end

        if addonTable[type] and addonTable[type][id] then
            return addonTable[type][id]
        end
    end

    return false
end

-- [ tooltips ]

local tooltip_item_id = false

-- content_index: default is 2 (description)
local add_entry_to_tooltip = function (tooltip, type, id, content_index)
    if tooltip_item_id then
        return
    end

    local entry = get_entry(type, id)

    if not entry then -- todo: add config "Show debug info" and check it here, so player can choose to hide stuff like "item#1234" and see only existing translations
        entry = { type .. "|cff999999#|r" .. id }
    end

    if entry then
        tooltip:AddLine(" ")
        tooltip:AddLine("|TInterface\\AddOns\\ClassicUA\\ua:0|t " .. entry[1], 1, 1, 1)

        local content = entry[content_index or 2]
        if content then
            tooltip:AddLine(content, 1, 1, 1, true)
        end

        if tooltip:IsShown() then -- if tooltip already shown, we re-show it to recalculate its backdrop
            tooltip:Show()
        end
    end

    if type == "item" then
        tooltip_item_id = id
    end
end

local tooltip_set_item = function (self)
    local _, link = self:GetItem()
    if link then
        local _, _, id = link:find("Hitem:(%d+):")
        add_entry_to_tooltip(self, "item", id)
    end
end

local tooltip_set_spell = function (self)
    local _, id = self:GetSpell()
    if id then
        add_entry_to_tooltip(self, "spell", id)
    end
end

local tooltip_set_unit = function (self)
    local _, unit = self:GetUnit()
    if unit then
        local guid = UnitGUID(unit)
        local _, _, _, _, _, id, _ = strsplit("-", guid)
        if id then
            add_entry_to_tooltip(self, "npc", id)
        end
    end
end

local tooltip_cleared = function (self)
    tooltip_item_id = false
end

for _, tt in pairs { GameTooltip, ItemRefTooltip } do
    tt:HookScript("OnTooltipSetItem", tooltip_set_item)
    tt:HookScript("OnTooltipSetSpell", tooltip_set_spell)
    tt:HookScript("OnTooltipSetUnit", tooltip_set_unit)
    tt:HookScript("OnTooltipCleared", tooltip_cleared)
end

hooksecurefunc(GameTooltip, "SetUnitAura", function (self, unit, index, filter)
    local id = select(10, UnitAura(unit, index, filter))
    if id then
        add_entry_to_tooltip(self, "spell", id, 3)
    end
end)

hooksecurefunc(GameTooltip, "SetUnitBuff", function (self, unit, index)
    local id = select(10, UnitAura(unit, index, "HELPFUL"))
    if id then
        add_entry_to_tooltip(self, "spell", id, 3)
    end
end)

hooksecurefunc(GameTooltip, "SetUnitDebuff", function (self, unit, index)
    local id = select(10, UnitAura(unit, index, "HARMFUL"))
    if id then
        add_entry_to_tooltip(self, "spell", id, 3)
    end
end)

-- [ frames ]

local setup_frame_background_and_border = function (frame)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\QuestFrame\\QuestBG")
    texture:SetTexCoord(0.0, 0.58, 0.0, 0.65)
    texture:SetPoint("TOPLEFT", 4, -8)
    texture:SetPoint("BOTTOMRIGHT", -4, 8)

    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24
    })
end

-- areas: { area1 = { font, size }, ... }
local setup_frame_scrollbar_and_content = function (frame, areas)
    local scrollframe = CreateFrame("ScrollFrame", nil, frame)
    scrollframe:SetPoint("TOPLEFT", 8, -9)
    scrollframe:SetPoint("BOTTOMRIGHT", -8, 9)
    frame.scrollframe = scrollframe

    local content = CreateFrame("Frame", nil, scrollframe)
    content:SetSize(scrollframe:GetWidth() - 60, 0)
    scrollframe:SetScrollChild(content)
    frame.content = content

    for k, v in pairs(areas) do
        local a = content:CreateFontString(nil, "OVERLAY")
        a:SetWidth(frame:GetWidth() - 60)
        a:SetJustifyH("LEFT")
        a:SetJustifyV("TOP")
        a:SetTextColor(0, 0, 0)
        if type(v) == "table" and #v == 2 then
            a:SetFont(v[1], v[2])
        end
        frame[k] = a
    end

    local scrollbar = CreateFrame("Slider", nil, scrollframe, "UIPanelScrollBarTemplate")
    scrollbar:SetPoint("TOPLEFT", frame, "TOPRIGHT", -26, -27)
    scrollbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 26)
    scrollbar:SetValueStep(40)
    scrollbar.scrollStep = 100
    scrollbar:SetValue(1)
    scrollbar:SetWidth(16)
    scrollbar:SetScript("OnValueChanged", function (self, value)
        self:GetParent():SetVerticalScroll(value)
    end)
    frame.scrollbar = scrollbar

    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local v = scrollbar:GetValue()
        scrollbar:SetValue(v - delta * self.scrollbar.scrollStep)
    end)
end

local setup_frame_scrollbar_values = function (frame, height)
    local delta = height - frame:GetHeight() + 24
    if delta > 0 then
        frame.scrollbar:SetMinMaxValues(1, delta)
    else
        frame.scrollbar:SetMinMaxValues(1, 1)
    end

    frame.scrollbar:SetValue(1)
    frame.content:SetSize(frame.content:GetWidth(), height)
end

-- [ quests ]

local quest_objectives_title = "Доручення"
local quest_description_title = "Опис"
local quest_title_font = "Fonts\\FRIZQT___CYR.TTF" -- todo: get nice custom font for quest title; path should be like "Interface\\AddOns\\ClassicUA\\font.ttf"
local quest_text_font = "Fonts\\FRIZQT___CYR.TTF"

local quest_frame = nil
local get_quest_frame = function ()
    if quest_frame then
        return quest_frame
    end

    local width, height = QuestFrame:GetSize()
    local frame = CreateFrame("frame", nil, QuestFrame)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(width - 64, height - 160)
    frame:SetPoint("TOP", 0, -72)
    frame:SetPoint("RIGHT", frame:GetWidth() - 37, 0)

    setup_frame_background_and_border(frame)

    setup_frame_scrollbar_and_content(frame, { -- todo: take quest font sizes from config
        title = { quest_title_font, 18 },
        text = { quest_text_font, 13 },
        more_title = { quest_title_font, 18 },
        more_text = { quest_text_font, 13 }
    })

    frame:Show()

    quest_frame = frame
    return quest_frame
end

-- frame must have properties: title, text, more_title, more_text
local set_quest_content = function (frame, title, text, more_title, more_text)
    local h = 16

    frame.title:SetPoint("TOPLEFT", frame.content, 12, -h)
    frame.title:SetText(title)
    h = h + frame.title:GetHeight() + 12

    if text then
        frame.text:SetPoint("TOPLEFT", frame.content, 12, -h)
        frame.text:SetText(text)
        h = h + frame.text:GetHeight() + 12
    else
        frame.text:SetText("")
    end

    if more_title and more_text then
        frame.more_title:SetPoint("TOPLEFT", frame.content, 12, -h)
        frame.more_title:SetText(more_title)
        h = h + frame.more_title:GetHeight() + 12

        frame.more_text:SetPoint("TOPLEFT", frame.content, 12, -h)
        frame.more_text:SetText(more_text)
        h = h + frame.more_text:GetHeight() + 12
    else
        frame.more_title:SetText("")
        frame.more_text:SetText("")
    end

    setup_frame_scrollbar_values(frame, h)
end

QuestFrameDetailPanel:HookScript("OnShow", function (event)
    local frame = get_quest_frame()
    local entry = get_entry("quest", GetQuestID())
    if entry then
        set_quest_content(frame, entry[1], entry[2], quest_objectives_title, entry[3])
        frame:Show()
    else
        frame:Hide()
    end
end)

QuestFrameProgressPanel:HookScript("OnShow", function (event)
    local frame = get_quest_frame()
    local entry = get_entry("quest", GetQuestID())
    if entry then
        set_quest_content(frame, entry[1], entry[4])
        frame:Show()
    else
        frame:Hide()
    end
end)

QuestFrameRewardPanel:HookScript("OnShow", function (event)
    local frame = get_quest_frame()
    local entry = get_entry("quest", GetQuestID())
    if entry then
        set_quest_content(frame, entry[1], entry[5])
        frame:Show()
    else
        frame:Hide()
    end
end)

local questlog_frame = nil
local get_questlog_frame = function ()
    if questlog_frame then
        return questlog_frame
    end

    local width, height = QuestLogFrame:GetSize()
    local frame = CreateFrame("frame", nil, QuestLogFrame)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(width - 64, height - 234)
    frame:SetPoint("TOP", 0, -166)
    frame:SetPoint("RIGHT", frame:GetWidth() - 41, 0)

    setup_frame_background_and_border(frame)

    setup_frame_scrollbar_and_content(frame, { -- todo: take quest font sizes from config
        title = { quest_title_font, 18 },
        text = { quest_text_font, 13 },
        more_title = { quest_title_font, 18 },
        more_text = { quest_text_font, 13 }
    })

    frame:Show()

    questlog_frame = frame
    return questlog_frame
end

hooksecurefunc("SelectQuestLogEntry", function ()
    if not addonTable.quest_f then -- need to test quest_f, as prepare_quests() might not be called just yet
        return
    end

    local frame = get_questlog_frame()
    local selection = GetQuestLogSelection()
    if selection > 0 then
        local id = select(8, GetQuestLogTitle(selection))
        local entry = get_entry("quest", id)
        if entry then
            set_quest_content(frame, entry[1], entry[3], quest_description_title, entry[2])
            frame:Show()
        else
            frame:Hide()
        end
    else
        frame:Hide()
    end
end)

-- [[ books ]]

local book_item_id = false
local book_text_font = "Fonts\\FRIZQT___CYR.TTF"

local book_frame = nil
local get_book_frame = function ()
    if book_frame then
        return book_frame
    end

    local width, height = ItemTextFrame:GetSize()
    local frame = CreateFrame("frame", nil, ItemTextFrame)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(width - 64, height - 160)
    frame:SetPoint("TOP", 0, -72)
    frame:SetPoint("RIGHT", frame:GetWidth() - 37, 0)

    setup_frame_background_and_border(frame)

    setup_frame_scrollbar_and_content(frame, { -- todo: take book font size from config
        text = { book_text_font, 13 }
    })

    frame:Show()

    book_frame = frame
    return book_frame
end

local set_book_content = function (text)
    local f = get_book_frame()
    local h = 16

    f.text:SetPoint("TOPLEFT", f.content, 12, -h)
    f.text:SetText(text)
    h = h + f.text:GetHeight() + 12

    setup_frame_scrollbar_values(f, h)
end

local show_book = function (text)
    local book = get_entry("book", book_item_id)
    if book then
        local page = ItemTextGetPage()
        if not book[page] and book[1] then
            book[page] = book[1]
        end
        set_book_content(book[page])
        get_book_frame():Show()
    end
end

local hide_book = function ()
    get_book_frame():Hide()
    book_item_id = false
end

-- [[ events ]]

local event_frame = CreateFrame("frame")

event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
event_frame:RegisterEvent("ITEM_TEXT_BEGIN")
event_frame:RegisterEvent("ITEM_TEXT_READY")
event_frame:RegisterEvent("ITEM_TEXT_CLOSED")

event_frame:SetScript("OnEvent", function (self, event, ...)
    if event == "ADDON_LOADED" then
        local s = get_stats()
        local v = GetAddOnMetadata("ClassicUA", "Version")
        print("|TInterface\\AddOns\\ClassicUA\\ua:0|t ClassicUA v" .. v .. " loaded: "
            .. s.quest_a .. " Alliance quests, "
            .. s.quest_h .. " Horde quests, "
            .. s.quest_n .. " neutral quests, "
            .. s.book .. " books, "
            .. s.item .. " items, "
            .. s.spell .. " spells, "
            .. s.npc .. " NPCs"
        )
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        local name = UnitName("player")
        local guid = UnitGUID("player")
        local _, class, _, race, sex = GetPlayerInfoByGUID(guid)
        local faction = UnitFactionGroup("player")

        prepare_quests(faction == "Alliance")
        prepare_codes(name, race, class, sex == 2) -- 2 for male
    elseif event == "ITEM_TEXT_BEGIN" then
        book_item_id = tooltip_item_id
    elseif event == "ITEM_TEXT_READY" then
        show_book()
    elseif event == "ITEM_TEXT_CLOSED" then
        hide_book()
    end
end)
