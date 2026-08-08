exports('AddPoint', function(data)
  local owner = GetInvokingResource()
  if not owner then return false, 'missing_owner' end
  return MZInteract.AddPoint(data, owner)
end)

exports('UpdatePoint', function(id, patch)
  local owner = GetInvokingResource()
  if not owner then return false, 'missing_owner' end
  return MZInteract.UpdatePoint(id, patch, owner)
end)

exports('RemovePoint', function(id)
  local owner = GetInvokingResource()
  if not owner then return false, 'missing_owner' end
  return MZInteract.RemovePoint(id, owner)
end)

exports('ClearPoints', function()
  local owner = GetInvokingResource()
  if not owner then return false, 'missing_owner' end
  return MZInteract.ClearPoints(owner)
end)

exports('RemovePointsByOwner', function()
  local owner = GetInvokingResource()
  if not owner then return 0 end
  return MZInteract.RemovePointsByOwner(owner)
end)

exports('GetPoint', function(id)
  return MZInteract.GetPoint(id)
end)

exports('GetClosestPoint', function(coords, maxDistance, activeOnly)
  return MZInteract.GetClosestPoint(coords, maxDistance, activeOnly)
end)

exports('SetPointActive', function(id, active)
  local owner = GetInvokingResource()
  if not owner then return false, 'missing_owner' end
  return MZInteract.SetPointActive(id, active, owner)
end)

exports('RefreshBlips', function()
  return MZInteract.RefreshBlips()
end)
