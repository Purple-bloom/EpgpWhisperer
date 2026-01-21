local data = {}
local importResult = {}
local blockChatImport = false

local GetRaidMembers = function()
    local raidMembers = {};
    for i = 1, GetNumRaidMembers(), 1 do
        local name = UnitName("raid" .. i);
        if name and UnitIsConnected("raid"..i) then
            table.insert(raidMembers, name);
        end
    end
    table.sort(raidMembers, function(a, b)
        local prioA = importResult[a] or 0
        local prioB = importResult[b] or 0
        return prioA > prioB
    end)
    return raidMembers
end

local PropagatePrios = function()
    local raidMembers = GetRaidMembers()
    local priosToSend = {}
    for i, character in pairs(raidMembers) do
        priosToSend[character] = importResult[character] or 0
    end

    local msgToSend = ""
    for character, prio in pairs(priosToSend) do
        msgToSend = msgToSend..character..":"..prio..";"
    end

    local maxMsgLen = 256
    local bufferLen = 30
    local msg = ""
    for i=0, string.len(msgToSend), 1 do
        local currentChar = string.sub(msgToSend, i, i)
        msg = msg..currentChar
        if((string.len(msg)>200 and currentChar == ';') or string.len(msg) >= string.len(msgToSend)) then
            print("Sending addon message")
            SendAddonMessage("CYDEPGP", msg, "RAID", nil)
            msg = ""
        end
    end
end

local ImportPriosFromString = function(input)
    importResult = {}
    string.gsub(input, "([^;]+)", function(segment)
        local _, _, namesPart, prioPart = string.find(segment, "(.-):(.+)")

        if namesPart and prioPart then
            string.gsub(namesPart, "([^,]+)", function(name)
                local cleanName = string.gsub(name, "%s+", "")
                importResult[cleanName] = tonumber(prioPart)
            end)
        end
    end)
    print("|cff00ff00Prio Import Complete!|r")
    SendChatMessage("New prios imported. Whisper \"prio\" to get a reply with your prio. Whisper \"howto\" to see how to bid after an item is posted.", "RAID" ,GetDefaultLanguage() , nil);
    PropagatePrios()
end

local ImportPriosFromChat = function(input)
    string.gsub(input, "([^;]+)", function(segment)
        local _, _, namesPart, prioPart = string.find(segment, "(.-):(.+)")
        if namesPart and prioPart then
            importResult[namesPart] = tonumber(prioPart)
        end
    end)
    print("|cff00ff00New (partial) prio update received and imported.|r")
end

local ShowImportField = function()
    StaticPopupDialogs["IMPORT_PRIO_INPUT"] = {
        text = "Paste the Prio String below:",
        button1 = "Import",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 50000,

        OnAccept = function()
            local dialog = this:GetParent()
            local editBox = getglobal(dialog:GetName().."EditBox")

            if editBox then
                local text = editBox:GetText()
                ImportPriosFromString(text)
                editBox:SetText("")
            end
        end,

        EditBoxOnEnterPressed = function()
            local text = this:GetText()
            ImportPriosFromString(text)
            this:SetText("")
            this:GetParent():Hide()
        end,

        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("IMPORT_PRIO_INPUT")
end

local PrintAllPrios = function()
    local raidMembers = GetRaidMembers()

    local printString = ""
    local maxMsgLen = 256
    local bufferLen = 30 -- to ensure we dont hit char limit with next string (dont judge me im lazy)
    for i, character in pairs(raidMembers) do
        local prioNotNil = importResult[character] or 0
        printString = printString.."<"..character..":"..prioNotNil.."> "
        if string.len(printString) >= maxMsgLen-bufferLen then
            SendChatMessage(printString, "RAID" ,GetDefaultLanguage() ,nil);
            printString = ""
        end
    end
    if not (printString == "") then
        SendChatMessage(printString, "RAID" ,GetDefaultLanguage() ,nil);
    end
end

local ShowRaidMembers = function()
    local raidMembers = GetRaidMembers()
    table.sort(raidMembers)
    StaticPopupDialogs["RAIDMEMBERS_OUTPUT"] = {
        text = "All currently logged in raid members:",
        button1 = "Okay",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 2000,
        OnAccept = function()
            local dialog = this:GetParent()
            local editBox = getglobal(dialog:GetName().."EditBox")
            editBox:SetText("")
        end,
        EditBoxOnEnterPressed = function()
            this:SetText("")
            this:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    local dialog = StaticPopup_Show("RAIDMEMBERS_OUTPUT")
    dialog.data = table.concat(raidMembers, ", ")
    local editBox = getglobal(dialog:GetName().."EditBox")
    editBox:SetText(table.concat(raidMembers, ", "))
end

local ShowPrio = function()
    local raidMembers = GetRaidMembers()

    local text = ""
    for i, character in pairs(raidMembers) do
        local prioNotNil = importResult[character] or 0
        text = text..character..": "..prioNotNil.."\n"
    end
    PrioText:SetText(text)
    PrioFrame:Show()
end

function Prio_Hide()
    PrioFrame:Hide()
end

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

function EpgpWhisperer_OnLoad()
    this:RegisterEvent("CHAT_MSG_ADDON")
    this:RegisterEvent("CHAT_MSG_WHISPER")
end


function EpgpWhisperer_OnEvent(event)
    if (arg1 == "CYDEPGP" and not (arg4 == UnitName("player")) and not blockChatImport) then
        ImportPriosFromChat(arg2)
        return
    end

    local message = arg1
    local sender = arg2

    if string.lower(message) == "prio" then
        local prioNotNil = importResult[sender] or 0
        SendChatMessage("Prio for "..sender..": "..prioNotNil, "WHISPER" ,GetDefaultLanguage() ,sender);
        return
    end

    if string.lower(message) == "howto" then
        SendChatMessage("In order to bid you need to whisper MS LOW, MS MID or MS HIGH to me. The highest prio in the highest bid category wins, so an MS HIGH will win vs an MS MID even when the player doing the high bid has lower prio.", "WHISPER" ,GetDefaultLanguage() ,sender);
        SendChatMessage("Prio is calculated by dividing your Effort Points (EP) by your Gear Points (GP) - GP increases for gear you get and EP increases for bosskills, using consumes, being on time etc.", "WHISPER" ,GetDefaultLanguage() ,sender);
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

    -- Sort based on bid and then prio
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

function disableReceive()
    blockChatImport = not blockChatImport
    print("Raid Import is now "..blockChatImport)
end

SLASH_PRIOIMPORT1 = "/pimp"
SlashCmdList.PRIOIMPORT = ShowImportField

SLASH_PRIOPRINT1 = "/pap"
SlashCmdList.PRIOPRINT = PrintAllPrios

SLASH_GETRAID1 = "/getRaidMembers"
SlashCmdList.GETRAID = ShowRaidMembers

SLASH_SHOWPRIO1 = "/prio"
SlashCmdList.SHOWPRIO = ShowPrio

SLASH_DISABLERECEIVE1 = "/blockChatImport"
SlashCmdList.DISABLERECEIVE = disableReceive