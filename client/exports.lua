exports('AddPoint', function(data)
  return MZInteract.AddPoint(data)
end)

exports('RemovePoint', function(id)
  return MZInteract.RemovePoint(id)
end)

exports('ClearPoints', function()
  return MZInteract.ClearPoints()
end)

exports('GetPoint', function(id)
  return MZInteract.GetPoint(id)
end)

exports('SetPointActive', function(id, active)
  return MZInteract.SetPointActive(id, active)
end)

exports('RefreshBlips', function()
  return MZInteract.RefreshBlips()
end)
