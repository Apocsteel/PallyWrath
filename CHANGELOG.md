# Pally Wrath — Changelog

## 1.0.3

**English**
- Fixed: after the latest game update, when a new echo started in combat the first stack could be missed, so it showed 2 stacks when you had 3.

**Español**
- Corregido: tras la última actualización del juego, al empezar un eco nuevo en combate se podía perder la primera carga y marcaba 2 teniendo 3.

## 1.0.2

**English**
- Options menu: "Opacity" label now translated; the seal icon hint no longer overlaps the "Reset icon" button.
- More detailed debug log (/pw debug) to fine-tune stack counting in combat.

**Español**
- Menú de opciones: la etiqueta "Opacidad" ya se traduce; el aviso del icono del sello ya no tapa el botón "Recolocar icono".
- Registro de depuración más detallado (/pw debug) para afinar el conteo de cargas en combate.

## 1.0.1

**English**
- Fixed: after switching seals out of combat, the new echo kept adding to the old echo's stacks (it could show 3 when you had 1).
- The Cooldown Manager is turned on automatically if it was off (Pally Wrath needs it to count stacks in combat).
- New option (on by default): hide Blizzard's buff tracker while keeping it active. Also /pw tracker.
- Chat warning if the Unsealed Wrath icon can't be found during combat.
- Added the IDs of all six echoes.

**Español**
- Corregido: al cambiar de sello fuera de combate, el eco nuevo seguía sumando sobre las cargas del anterior (podía marcar 3 teniendo 1).
- El Cooldown Manager se activa solo si estaba apagado (Pally Wrath lo necesita para contar cargas en combate).
- Opción nueva (activada de base): ocultar el visor de buffs de Blizzard sin desactivarlo. También /pw visor.
- Aviso en el chat si en combate no encuentra el icono de Unsealed Wrath.
- Añadidos los IDs de los seis ecos.

## 1.0.0 (first public release)

**English**
- Unsealed Wrath echo tracker for Retribution Paladins in WoW Forever.
- Three styles: golden crescent, sword and 3D model (the model uses the game's own item model).
- Fills in thirds with each stack, takes the color of the stored seal and bursts into flames at 3 stacks with a timer and sound.
- Works in combat by reading Blizzard's buff tracker (Cooldown Manager) icon for Unsealed Wrath.
- Four fill directions (up, down, right, left), each with its own 3D framing.
- Optional mirrored copy on the other side of the character.
- Options menu (/pw), adjustable opacity, size, colors per seal, seal icon and draggable position.
- English and Spanish.

**Español**
- Indicador de los ecos de Unsealed Wrath para paladines de Reprensión en WoW Forever.
- Tres estilos: media luna dorada, espada y modelo 3D (el modelo usa el del propio juego).
- Se rellena por tercios con cada carga, toma el color del sello y arde con 3 cargas, con temporizador y sonido.
- Funciona en combate leyendo el icono de Unsealed Wrath del visor de buffs de Blizzard.
- Cuatro direcciones de carga (arriba, abajo, derecha, izquierda), cada una con su encuadre 3D.
- Copia simétrica opcional al otro lado del personaje.
- Menú de opciones (/pw), opacidad, tamaño, colores por sello, icono del sello y posición arrastrable.
- Inglés y castellano.
