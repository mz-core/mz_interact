MZInteractLogic = MZInteractLogic or {}

function MZInteractLogic.FadeByDistance(distance, limit, range)
  local progress = math.max(0.0, math.min(1.0, (limit - distance) / range))
  return progress * progress * (3.0 - 2.0 * progress)
end

function MZInteractLogic.Approach(value, target, elapsed, duration)
  local step = math.max(0, elapsed) / duration
  if value < target then return math.min(target, value + step) end
  return math.max(target, value - step)
end

function MZInteractLogic.KeepSelection(selected, closest)
  return selected and closest and selected.distance <= closest.distance + 0.15
end

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
