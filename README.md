# Pally Wrath

Indicador de cargas de Unsealed Wrath para paladines Reprensión en WoW Forever, por ApocSteel.

- Abre el menú con /pw. En Apariencia, elige Media luna, Arma fija o Arma equipada. Arma equipada carga el modelo de tu mano principal y se actualiza al cambiar de arma. La espada clásica y la Hoja rúnica del Barón Rivendare están en Armas de Reprensión → Espadas.
- A tres cargas, las armas 3D de la galería encienden un contorno animado del color del sello con el encuadre predeterminado. En Arma equipada, los modelos sin un contorno propio usan las llamas del cliente en el tono más cercano al sello. También se usan esos efectos si ajustas la cámara y el contorno deja de encajar.
- En Vista previa, elige un sello y entre 0 y 3 cargas. «Probar en pantalla» reproduce la secuencia fuera de combate.
- En Posición, configura el tamaño, la opacidad, la dirección y la copia simétrica. En Avanzado, ajusta el encuadre 3D de la espada principal o de la copia. El encuadre se guarda por arma y dirección.
- Mantén activado el Gestor de reutilizaciones de Blizzard y el icono de Unsealed Wrath en Beneficios rastreados para que se puedan contar las cargas en combate.
- Desde la versión 1.2.4, Pally Wrath intercambia el número de versión con otras copias del grupo, banda o hermandad. Si alguna anuncia una versión más reciente, verás un aviso privado en tu chat una vez por sesión. La actualización se descarga en CurseForge.
- La versión 1.1 conserva los ajustes de Pally Wrath. Si también probaste Studio, deja una sola versión activa para evitar avisos duplicados.

Crematoria (13262) y Crematoria corrupta (22691) usan sus modelos 3D y un recorte local regulable para revelar el sello a tres cargas. Trueno Furioso (19019), Sulfuras (17182) y la Hoja rúnica (13505) también son 3D. Los modelos pasan de mate a color y, con tres cargas, encienden sus efectos. Sulfuras concentra el fuego en la cabeza de la maza. La espada clásica, El’druin, Ira celeste, Agonía de Sombras y Fyr’alath iluminan un tramo por carga y tienen un aura que sigue el contorno de su ilustración. Con cero cargas se oculta el arma. Con tres suena el aviso si está activado. Puedes probar otro modelo del cliente con /pw objeto <ID>.

## English

Unsealed Wrath stack indicator for Retribution Paladins in WoW Forever, by ApocSteel.

- Open the menu with /pw. In Appearance, choose Crescent, Fixed weapon, or Equipped weapon. Equipped weapon loads your main-hand model and updates when you switch weapons. The classic sword and the Runeblade of Baron Rivendare are listed under Retribution weapons → Swords.
- At three stacks, gallery 3D weapons use an animated outline tinted to the seal color with default framing. Equipped models without a dedicated outline use the closest in-game flame color, as do custom camera angles where a gallery outline no longer fits.
- In Preview, select a seal and 0–3 stacks. Test on screen plays the sequence outside combat.
- In Position, adjust size, opacity, fill direction, and the mirrored copy. Use Advanced to frame the main weapon or its mirrored copy. Framing is saved by weapon and fill direction.
- Keep Blizzard's Cooldown Manager enabled and the Unsealed Wrath icon in Tracked Buffs for combat stack tracking.
- Starting with version 1.2.4, Pally Wrath exchanges version numbers with other copies in your party, raid, or guild. If a newer version is reported, you see a private chat notice once per session. Updates are available on CurseForge.
- Version 1.1 keeps your Pally Wrath settings. If you also tested Studio, keep one version active to avoid duplicate alerts.

Ashbringer (13262) and Corrupted Ashbringer (22691) use their 3D models and an adjustable local cutout to reveal the blade’s seal at three stacks. Thunderfury (19019), Sulfuras (17182), and the Runeblade (13505) also use 3D models. Models progress from matte to colored and activate their effects at three stacks. Sulfuras concentrates its fire around the mace head. Classic Sword, El’druin, Azurewrath, Shadowmourne, and Fyr’alath light up one section per stack and have an aura that follows the artwork’s silhouette. Zero stacks hides the weapon. At three stacks the alert plays if enabled. To try another model from the client, use /pw item <ID>.

Para añadir arte 2D nuevo, genera el fuego a partir de su transparencia. For new 2D artwork, generate the fire from its transparency with `node tools/build_weapon_aura.cjs <art-basename>`.
