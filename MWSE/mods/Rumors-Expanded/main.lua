local config = {}
local QUEST_COMPLETED_INDEX = 100
local RESPONSE_CACHE_MAX_SIZE = 20
local responsesPoolPerNpcCache = {}
local currentCacheIndex = 1
local cachedNpcIds = {}
local invalidateCache = false

local prevResponseGlobalVarName = nil

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

local function getQuestRumor(questId, filters) 
  local responsesPool = config.responses[questId]
  local rumor = {}
  
  for responseIndex,responseMeta in pairs(responsesPool) do
    local responseMatches = true
    for index,condition in pairs(responseMeta.conditions) do
      local conditionMatches = false
      if (condition.type == 'cell') then
        conditionMatches = checkCell(filters.actorCell, condition)
        print("cell check: " .. to_string(conditionMatches))
      elseif (condition.type == 'faction') then
        conditionMatches = checkFaction(filters.actorFaction, condition)
        print("faction check: " .. to_string(conditionMatches))
      elseif (condition.type == 'dead') then
        conditionMatches = checkDead(condition)
        print("dead check: " .. to_string(conditionMatches))
      elseif (condition.type == 'questCompleted') then
        conditionMatches = checkQuestCompleted(condition)
        print("quest completed check: " .. to_string(conditionMatches))
      else
      end
      responseMatches = responseMatches and conditionMatches
    end
    print(responseMeta.id .. " responseMatches " .. to_string(responseMatches))
    if (responseMatches == true) then
      return responseIndex
    end
  end

  return nil
end
  
function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, key .. " = {\n");
        table.insert(sb, table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.format(
            "%s = \"%s\"\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end
 
local function getGlobalVarName(questId)
  return "RE_" .. questId .. "_Response"
end

local function randomizeResponse(responseCandidates)
  print("randomizeResponse")
  print(to_string(responseCandidates))
  if (not responseCandidates) then
    return nil
  end
  -- local index = math.random(table.size(responseCandidates) * 2)
  local index = math.random(table.size(responseCandidates))
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

local function storeResponsesPoolInCache(actorId, responseCandidates)
  if (currentCacheIndex >= RESPONSE_CACHE_MAX_SIZE) then
    currentCacheIndex = 1
    local staleNpcId = cachedNpcIds[currentCacheIndex]
    responsesPoolPerNpcCache[staleNpcId] = nil
  else
    currentCacheIndex = currentCacheIndex + 1
  end

  cachedNpcIds[currentCacheIndex] = actorId
  responsesPoolPerNpcCache[actorId] = table.deepcopy(responseCandidates)
end

local function showMessageOnMenuEnter(e)
	if (not e.newlyCreated) then
		return
  end

  if (prevResponseGlobalVarName) then
    tes3.setGlobal(prevResponseGlobalVarName, 0)
    prevResponseGlobalVarName = nil
  end

  if (invalidateCache) then
    responsesPoolPerNpcCache = {}
    currentCacheIndex = 1
    cachedNpcIds = {}
    invalidateCache = false
  end

  local menuDialog = e.element
  local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor")
  local actorId = mobileActor.object.id

  local selectedResponse = nil

  if (responsesPoolPerNpcCache[actorId] ~= nil) then
    selectedResponse = randomizeResponse(responsesPoolPerNpcCache[actorId])
  else
    local responseCandidates = getResponseCandidates(mobileActor)
    
    storeResponsesPoolInCache(actorId, responseCandidates)
  
    selectedResponse = randomizeResponse(responsesPoolPerNpcCache[actorId])
  end

  print("Cached responses for NPC:")
  print(to_string(responsesPoolPerNpcCache[actorId]))
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

local function onJournalUpdate(e)
  if (e.index >= QUEST_COMPLETED_INDEX) then
    invalidateCache = true
  end
end

local function resetGlobals()
  for questId,questResponses in pairs(config.responses) do
    tes3.setGlobal(getGlobalVarName(questId), 0)
  end
end

local function initialized()
  event.register("journal", onJournalUpdate)
  event.register("uiActivated", showMessageOnMenuEnter, { filter = "MenuDialog" })
  
  print("[MWSE Rumors Expanded: INFO] Initializing...")
  config = json.loadfile("mods/Rumors-Expanded/config")

  resetGlobals()
  invalidateCache = true
  print(to_string(config))
  print("[MWSE Rumors Expanded: INFO] Initialized")
end

event.register("initialized", initialized)
