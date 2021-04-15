local this = {}
local QUEST_COMPLETED_INDEX = 100

local function checkCell(actorCell, condition)
  if (condition.comparator == '!=') then
    return not string.startswith(actorCell, condition.value)
  else
    return string.startswith(actorCell, condition.value)
  end
end

local function checkFaction(actorFaction, condition)
  if (condition.value == 'NOT_GREAT_HOUSE') then
    return (actorFaction ~= 'Telvanni') and (actorFaction ~= 'Redoran') and (actorFaction ~= 'Hlaalu')
  else
    return actorFaction == condition.value
  end
end

local function checkDead(condition)
  local actor = tes3.getReference(condition.value).mobile
  return actor and (not actor.health.current or actor.health.current == 0)
end

local function checkQuestCompleted(condition)
  local isCompleted = tes3.getJournalIndex({ id = condition.value }) >= QUEST_COMPLETED_INDEX
  if (condition.comparator == "not_completed") then
    return not isCompleted
  else
    return isCompleted
  end
end

local function checkJournalStage(condition)
  local questStage = tes3.getJournalIndex({ id = condition.questId })
  return questStage == condition.value
end

this.checkCell = checkCell
this.checkFaction = checkFaction
this.checkDead = checkDead
this.checkQuestCompleted = checkQuestCompleted
this.checkJournalStage = checkJournalStage

return this
