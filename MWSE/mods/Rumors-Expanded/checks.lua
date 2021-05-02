local this = {}
local QUEST_COMPLETED_INDEX = 100

local function checkCell(condition, actorCell)
    if (condition.comparator == '!=') then
        return not string.startswith(actorCell, condition.value)
    else
        return string.startswith(actorCell, condition.value)
    end
end

local function isGreatHouse(actorFaction)
    return (actorFaction == 'Telvanni') or (actorFaction == 'Redoran') or (actorFaction == 'Hlaalu')
end

local function checkFaction(condition, actorFaction)
    if (condition.comparator == '!=') then
        if (condition.value == 'NOT_GREAT_HOUSE') then
            return isGreatHouse(actorFaction)
        end

        return actorFaction ~= condition.value
    else
        if (condition.value == 'NOT_GREAT_HOUSE') then
            return not isGreatHouse(actorFaction)
        end

        return actorFaction == condition.value
    end
end

local function checkDead(condition)
    local actor = tes3.getReference(condition.value).mobile
    return actor and (not actor.health.current or actor.health.current == 0)
end

local function checkQuestCompleted(condition)
    local isCompleted = tes3.getJournalIndex({
        id = condition.value
    }) >= QUEST_COMPLETED_INDEX
    if (condition.comparator == "not_completed") then
        return not isCompleted
    else
        return isCompleted
    end
end

local function checkJournalStage(condition)
    local questStage = tes3.getJournalIndex({
        id = condition.questId
    })
    return questStage == condition.value
end

local function checkPCSex(condition)
    return tes3.mobilePlayer.firstPerson.female == condition.value
end

local function checkPCRank(condition)
    local faction = tes3.getFaction(condition.faction)

    if (condition.comparator == '<') then
        return faction.playerRank < condition.value
    elseif (condition.comparator == '>') then
        return faction.playerRank > condition.value
    else
        return faction.playerRank == condition.value
    end
end

local function checkPCRankDifference(condition, actor)
    local faction = actor.faction

    if (not faction or not faction.playerJoined or faction.playerExpelled) then
        return false
    end

    local playerRank = faction.playerRank
    local actorRank = actor.baseObject.factionRank
    local difference = condition.value

    if (condition.comparator == '<') then
        return playerRank - actorRank < difference
    elseif (condition.comparator == '>') then
        return playerRank - actorRank > difference
    else
    end
end

this.checkCell = checkCell
this.checkFaction = checkFaction
this.checkDead = checkDead
this.checkQuestCompleted = checkQuestCompleted
this.checkJournalStage = checkJournalStage
this.checkPCSex = checkPCSex
this.checkPCRank = checkPCRank
this.checkPCRankDifference = checkPCRankDifference

return this
