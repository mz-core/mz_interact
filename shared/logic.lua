MZInteractLogic = MZInteractLogic or {}

function MZInteractLogic.ResolveBoolean(value, defaultValue)
  if value == nil then return defaultValue == true end
  return value == true
end

function MZInteractLogic.IsBetterCandidate(candidate, current)
  if type(candidate) ~= 'table' then return false end
  if type(current) ~= 'table' then return true end

  local candidateDistance = tonumber(candidate.distance) or math.huge
  local currentDistance = tonumber(current.distance) or math.huge
  if math.abs(candidateDistance - currentDistance) > 0.001 then
    return candidateDistance < currentDistance
  end

  local candidatePriority = tonumber(candidate.priority) or 0
  local currentPriority = tonumber(current.priority) or 0
  if candidatePriority ~= currentPriority then
    return candidatePriority > currentPriority
  end

  return tostring(candidate.id or '') < tostring(current.id or '')
end
