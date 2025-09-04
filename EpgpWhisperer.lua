local data = {}

local matchTable = {
    ["ms low"] = "MS LOW", ["low"] = "MS LOW", ["min"] = "MS LOW", ["ms min"] = "MS LOW",
    ["ms mid"] = "MS MID", ["mid"] = "MS MID", ["medium"] = "MS MID", ["med"] = "MS MID", ["ms med"] = "MS MID",
    ["ms high"] = "MS HIGH", ["high"] = "MS HIGH", ["max"] = "MS HIGH", ["ms max"] = "MS HIGH",
    ["os low"] = "OS LOW", ["os min"] = "OS LOW",
    ["os mid"] = "OS MID", ["os medium"] = "OS MID",
    ["os high"] = "OS HIGH", ["os max"] = "OS HIGH",
}

-- Define custom priority order
local priorityOrder = {
    ["MS HIGH"] = 1,
    ["MS MID"] = 2,
    ["MS LOW"] = 3,
    ["OS HIGH"] = 4,
    ["OS MID"] = 5,
    ["OS LOW"] = 6,
}


function EpgpWhisperer_OnEvent(message, sender)
    if not message or not sender then return end

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
    for player, priority in pairs(data) do
        table.insert(sortedEntries, {name = player, priority = priority})
    end

    -- Sort based on custom order
    table.sort(sortedEntries, function(a, b)
        return priorityOrder[a.priority] < priorityOrder[b.priority]
    end)

    -- Update window text with sorted entries
    local text = ""
    for _, entry in ipairs(sortedEntries) do
        text = text .. entry.name .. ": " .. entry.priority .. "\n"
    end
    EpgpWhispererText:SetText(text)
    EpgpWhispererFrame:Show()
end

function EpgpWhisperer_ClearEntries()
    data = {}
    EpgpWhispererText:SetText("")
    EpgpWhispererFrame:Hide()
end
