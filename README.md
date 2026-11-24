# mz_interact

Camada client-side para markers, texto 3D e ações próximas.

## Contrato

- o resource consumidor continua dono da regra de negócio;
- autorização real é sempre revalidada no servidor consumidor;
- somente um ponto elegível recebe input; pontos próximos usam uma pequena margem para evitar alternância visual;
- IDs pertencem ao resource que registrou o ponto;
- parar um resource remove automaticamente os pontos que ele registrou;
- `blip` é independente de `marker` e permanece desabilitado quando não solicitado.
- `marker.hideWhenNear = true` faz o marcador desaparecer gradualmente quando o texto da interação aparece.
- `text.ui = true` usa o TextUI existente do `mz_lib` quando disponível, com fallback para texto 3D; `text.keyLabel` define a tecla exibida.
- Com `text.discovery = true`, a NUI mostra um círculo no ponto dentro de `drawDistance` e revela a ação no alcance de interação.
- Para acompanhar uma entidade, `follow = { entity = handle, bone = 'boot', offset = vec3(...) }` atualiza a posição do ponto enquanto ela existir; o deslocamento é usado quando o osso não existe.

## API

```lua
exports['mz_interact']:AddPoint(data)
exports['mz_interact']:UpdatePoint(id, patch)
exports['mz_interact']:RemovePoint(id)
exports['mz_interact']:SetPointActive(id, active)
exports['mz_interact']:GetPoint(id)
exports['mz_interact']:GetClosestPoint(coords, maxDistance, activeOnly)
exports['mz_interact']:ClearPoints()
```

`ClearPoints` remove somente pontos pertencentes ao resource chamador.

## Permissões

O campo legado `permission` não é uma barreira de segurança. Permissões oficiais do
`mz_core` são server-side. Para ocultar um ponto, o servidor consumidor deve enviar
somente pontos visíveis ou mandar o client usar `active = false`/`visible = false`.

## Atualização dinâmica

```lua
exports['mz_interact']:UpdatePoint('mz_doors:mrpd_main', {
  text = { enabled = true, label = '[E] Destrancar' },
  marker = { enabled = true }
})
```

## Ações múltiplas

```lua
exports['mz_interact']:AddPoint({
  id = 'example:door',
  coords = vec3(1.0, 2.0, 3.0),
  actions = {
    {
      id = 'toggle',
      key = 38,
      event = { type = 'server', name = 'example:toggle', args = { 'main' } }
    },
    {
      id = 'knock',
      key = 47,
      event = { type = 'server', name = 'example:knock', args = { 'main' } }
    }
  },
  text = { label = '[E] Destrancar  |  [G] Bater' }
})
```
