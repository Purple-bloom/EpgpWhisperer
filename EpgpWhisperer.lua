local data = {}
local importResult = {}

-- hehe prio import = pimp
local ParseString = function(input)
    importResult = {}
    local count = 0
    string.gsub(input, "([^;]+)", function(segment)
        local _, _, namesPart, prioPart = string.find(segment, "(.-):(.+)")

        if namesPart and prioPart then
            string.gsub(namesPart, "([^,]+)", function(name)
                local cleanName = string.gsub(name, "%s+", "")
                importResult[cleanName] = tonumber(prioPart)
                count = count + 1
            end)
        end
    end)
    print("|cff00ff00Prio Import Complete!|r")
    SendChatMessage("New prios imported. Whisper \"prio\" to get a reply with your prio!", "RAID" ,nil , nil);
end

local ShowImportField = function()
    StaticPopupDialogs["IMPORT_PRIO_INPUT"] = {
        text = "Paste the Prio String below:",
        button1 = "Import",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 10000,

        OnAccept = function()
            local dialog = this:GetParent()
            local editBox = getglobal(dialog:GetName().."EditBox")

            if editBox then
                local text = editBox:GetText()
                ParseString(text)
            end
        end,

        EditBoxOnEnterPressed = function()
            -- In this context, 'this' IS the EditBox itself
            local text = this:GetText()
            ParseString(text)
            this:GetParent():Hide()
        end,

        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("IMPORT_PRIO_INPUT")
end


SLASH_PRIOIMPORT1 = "/pimp"
SlashCmdList.PRIOIMPORT = ShowImportField

-- prio import end


local matchTable = {
    ["ms low"] = "MS LOW", ["low"] = "MS LOW", ["min"] = "MS LOW", ["ms min"] = "MS LOW",
    ["ms mid"] = "MS MID", ["mid"] = "MS MID", ["medium"] = "MS MID", ["med"] = "MS MID", ["ms med"] = "MS MID",
    ["ms high"] = "MS HIGH", ["high"] = "MS HIGH", ["max"] = "MS HIGH", ["ms max"] = "MS HIGH",
    ["os low"] = "OS LOW", ["os min"] = "OS LOW",
    ["os mid"] = "OS MID", ["os medium"] = "OS MID",
    ["os high"] = "OS HIGH", ["os max"] = "OS HIGH",
}

-- custom priority order
local bidPriorityOrder = {
    ["MS HIGH"] = 1,
    ["MS MID"] = 2,
    ["MS LOW"] = 3,
    ["OS HIGH"] = 4,
    ["OS MID"] = 5,
    ["OS LOW"] = 6,
}

function EpgpWhisperer_OnEvent(message, sender)
    if not message or not sender then return end
    local prioNotNil = importResult[sender]
    if prioNotNil == nil then
        prioNotNil = 0
    end
    if string.lower(message) == "prio" then
        SendChatMessage("Prio for "..sender..": "..prioNotNil, "WHISPER" ,nil ,sender);
        return
    end

    local lowerMessage = string.lower(message)
    for k, v in pairs(matchTable) do
        if string.find(lowerMessage, "^" .. k) then
            data[sender] = v
            EpgpWhisperer_UpdateWindow()
            return
        end
    end
end

function EpgpWhisperer_UpdateWindow()
    local sortedEntries = {}
    for player, bidPriority in pairs(data) do
        local importedPrio = importResult[player]
        if importedPrio == nil then
            importedPrio = 0
        end
        table.insert(sortedEntries, {name = player, bidPriority = bidPriority, prio = importedPrio})
    end

    -- Sort based on custom order
    table.sort(sortedEntries, function(a, b)
        if a.bidPriority == b.bidPriority then
            return a.prio > b.prio
        end
        return bidPriorityOrder[a.bidPriority] < bidPriorityOrder[b.bidPriority]
    end)

    -- Update window text with sorted entries
    local text = ""
    for _, character in ipairs(sortedEntries) do
        text = text .. character.name .. " - " .. character.bidPriority .. " - " .. character.prio .. "\n"
    end
    EpgpWhispererText:SetText(text)
    EpgpWhispererFrame:Show()
end

function EpgpWhisperer_ClearEntries()
    data = {}
    EpgpWhispererText:SetText("")
    EpgpWhispererFrame:Hide()
end
