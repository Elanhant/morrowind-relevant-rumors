local config = {}
local cache = require("Rumors-Expanded.cache")
local checks = require("Rumors-Expanded.checks")
local debug = require("Rumors-Expanded.debug")

local QUEST_COMPLETED_INDEX = 100
local RUMOR_CHANCE = 100
local shouldInvalidateCache = false

local prevResponseGlobalVarName = nil

local function getQuestRumor(questId, filters) 
  local responsesPool = config.responses[questId]
  local rumor = {}
  
  for responseIndex,responseMeta in pairs(responsesPool) do
    local responseMatches = true
    for index,condition in pairs(responseMeta.conditions) do
      local conditionMatches = false
      if (condition.type == 'cell') then
        conditionMatches = checks.checkCell(filters.actorCell, condition)
        print("cell check: " .. debug.to_string(conditionMatches))
      elseif (condition.type == 'faction') then
        conditionMatches = checks.checkFaction(filters.actorFaction, condition)
        print("faction check: " .. debug.to_string(conditionMatches))
      elseif (condition.type == 'dead') then
        conditionMatches = checks.checkDead(condition)
        print("dead check: " .. debug.to_string(conditionMatches))
      elseif (condition.type == 'questCompleted') then
        conditionMatches = checks.checkQuestCompleted(condition)
        print("quest completed check: " .. debug.to_string(conditionMatches))
      else
      end
      responseMatches = responseMatches and conditionMatches
    end
    print(responseMeta.id .. " responseMatches " .. debug.to_string(responseMatches))
    if (responseMatches == true) then
      return responseIndex
    end
  end

  return nil
end
 
local function getGlobalVarName(questId)
  return "RE_" .. questId .. "_Response"
end

local function randomizeResponse(responseCandidates)
  print("randomizeResponse")
  print(debug.to_string(responseCandidates))
  if (not responseCandidates) then
    return nil
  end
  -- local index = math.random(table.size(responseCandidates) * 2)
  local index = math.random(table.size(responseCandidates) * (100 / RUMOR_CHANCE))
  return responseCandidates[index]
end

local function getResponseCandidates(mobileActor)
  local responseCandidates = {}
  local responseCandidatesCount = 1
  local actorCell = mobileActor.cell.id
  local actorClass = mobileActor.object.class.id
  local actorFaction = nil
  
  if (mobileActor.object.faction) then
    actorFaction = mobileActor.object.faction.id
  end

  for questId,questResponses in pairs(config.responses) do
    local isCompleted = tes3.getJournalIndex({ id = questId }) >= QUEST_COMPLETED_INDEX
    
    if (isCompleted) then
      local questRumorIndex = getQuestRumor(questId, { actorCell = actorCell, actorFaction = actorFaction, actorClass = actorClass })
      if (questRumorIndex) then
        responseCandidates[responseCandidatesCount] = {}
        responseCandidates[responseCandidatesCount].index = questRumorIndex
        responseCandidates[responseCandidatesCount].questId = questId
        responseCandidatesCount = responseCandidatesCount + 1
      end
    end
  end

  return responseCandidates
end

local function onLoaded(e)
  resetGlobals()
  shouldInvalidateCache = true
end

local function onJournalUpdate(e)
  if (e.index >= QUEST_COMPLETED_INDEX) then
    shouldInvalidateCache = true
  end
end

local function resetGlobals()
  for questId,questResponses in pairs(config.responses) do
    tes3.messageBox("resetting " .. getGlobalVarName(questId))

    tes3.setGlobal(getGlobalVarName(questId), 0)
  end
end

local function pickRandomRumor(e)
	if (not e.newlyCreated) then
		return
  end

  if (prevResponseGlobalVarName) then
    tes3.setGlobal(prevResponseGlobalVarName, 0)
    prevResponseGlobalVarName = nil
  end

  if (shouldInvalidateCache) then
    cache.invalidate()
    shouldInvalidateCache = false
  end

  local menuDialog = e.element
  local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor")
  local actorId = mobileActor.object.id

  local selectedResponse = nil

  if (cache.getResponsesPoolFromCache(actorId) == nil) then
    local responseCandidates = getResponseCandidates(mobileActor)
    
    cache.storeResponsesPoolInCache(actorId, responseCandidates)
  end

  selectedResponse = randomizeResponse(cache.getResponsesPoolFromCache(actorId))

  print("Cached responses for NPC:")
  print(debug.to_string(cache.getResponsesPoolFromCache(actorId)))
  print("=========================")
  
  print("FINAL:")
  print(selectedResponse)
  if (selectedResponse) then
    local globalVarName = getGlobalVarName(selectedResponse.questId)
    prevResponseGlobalVarName = globalVarName
    tes3.setGlobal(globalVarName, selectedResponse.index)
    tes3.messageBox(globalVarName .. ": " .. selectedResponse.index)
  end
end

local function initialized()
  event.register("loaded", onLoaded)
  event.register("journal", onJournalUpdate)
  event.register("uiActivated", pickRandomRumor, { filter = "MenuDialog" })
  
  print("[MWSE Rumors Expanded: INFO] Initializing...")
  config = json.loadfile("mods/Rumors-Expanded/config")

  print(debug.to_string(config))
  print("[MWSE Rumors Expanded: INFO] Initialized")
end

event.register("initialized", initialized)
