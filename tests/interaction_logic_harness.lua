local failures = {}

local function expect(label, condition)
  if not condition then failures[#failures + 1] = label end
end

dofile('mz_interact/shared/logic.lua')

expect('explicit false overrides true default', MZInteractLogic.ResolveBoolean(false, true) == false)
expect('explicit true overrides false default', MZInteractLogic.ResolveBoolean(true, false) == true)
expect('nil inherits true default', MZInteractLogic.ResolveBoolean(nil, true) == true)
expect('nil inherits false default', MZInteractLogic.ResolveBoolean(nil, false) == false)

local closest = { id = 'far', distance = 2.0, priority = 100 }
expect('distance wins before priority', MZInteractLogic.IsBetterCandidate({
  id = 'near', distance = 1.0, priority = 0
}, closest) == true)

closest = { id = 'same_low', distance = 1.0, priority = 1 }
expect('priority breaks equal-distance tie', MZInteractLogic.IsBetterCandidate({
  id = 'same_high', distance = 1.0, priority = 2
}, closest) == true)

closest = { id = 'b', distance = 1.0, priority = 1 }
expect('id deterministically breaks final tie', MZInteractLogic.IsBetterCandidate({
  id = 'a', distance = 1.0, priority = 1
}, closest) == true)

expect('invalid candidate never wins', MZInteractLogic.IsBetterCandidate(nil, closest) == false)
expect('first valid candidate wins', MZInteractLogic.IsBetterCandidate({
  id = 'first', distance = 5.0
}, nil) == true)

if #failures > 0 then
  error(('mz_interact logic harness failed:\n- %s'):format(table.concat(failures, '\n- ')))
end

print('mz_interact interaction logic harness: ok')
