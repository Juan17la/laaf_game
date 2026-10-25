# LAAF — Spanish glossary (es)

The Spanish text lives in `locale/es.po` (gettext). The message ids are the English text in the code, and
`tools/l10n.py` extracts them into `locale/laaf.pot`, merges them into `es.po` and checks it (`python tools/l10n.py
check`; `tests/l10n_test.gd` checks the same from inside Godot). This file fixes the terms so they read the same
everywhere. Decide a new term here first, then use it.

**Register:** neutral Latin-American Spanish, readable in Colombia. **Tú** for everything said to the player
(objectives, prompts, notes, menus) and between characters unless one is plainly formal. The horror tone: short,
tense, unsettling lines. Meaning over word-for-word. No vosotros, no Spain-only slang ("vale", "coger", "ordenador").

**Alex** is a man (the docs: Alex Moreno, "salir vivo"): masculine agreement where it can't be avoided
("estás marcado"); phrased around it where it can.

## Names that never change

Characters: Alex, Lucía, Elena, Owen, Nora, Julian, Julian Marsh, Marcus, Grady, Silas, Old Tom, Caleb, Tomás,
Clara, Lily, Sam, Tom. Places: Hollowmere, Lakeview Motel, St. Agnes, St. Brendan, Maple Ave, Elm St, Lake Rd, the
bar's and shops' names on their signs (THE DROWNED LANTERN, GRADY'S GENERAL STORE, DINER...). "Old Tom" stays
"Old Tom" (the catfish and the old fisherman), never "Viejo Tom".

## Codenames and titles

| English | Spanish | Note |
|---|---|---|
| Moth (Elena's codename, speaker "MOTH") | **Polilla** | Translated, as in the design docs (`maps/docs/es`): it's a radio handle, "Aquí Polilla" reads naturally. The arcade cabinet keeps its own brand: **Moth Run** (in-world title, never translated). |
| the Shepherd (speaker "SHEPHERD") | **el Pastor** (speaker "PASTOR") | As in the docs. Capital P as a title. |
| the Harvester (final boss) | **el Segador** | As in the docs. Boss bar: EL SEGADOR. |
| the Harvest | **la Cosecha** | Chapter III's name on the menu, the ritual. |
| the Veil | **el Velo** | The cult. "the Veil's Chapel" = **la Capilla del Velo**. |
| the Veil's Eye | **el Ojo del Velo** | |
| the Mark | **la Marca** | HUD "MARK +2%" = "MARCA +2%". "marked" = marcado. |
| the Marked Ones / a Marked One | **los Marcados** / **un Marcado** | Speaker "MARKED ONE" = "MARCADO". |
| the Taken | **los Llevados** | |
| the blackout (03:00) | **el apagón** | |
| Lantern Festival | **el Festival de los Faroles** | lantern = **farol** (the festival's, the burnt ones). A plain lamp is a lámpara; a flashlight, **linterna**. |
| Empty Chairs (side mission, achievement) | **Sillas vacías** | |
| Lantern Tokens / tokens | **fichas** | "+25 TOKENS" = "+25 FICHAS". |
| the gate key / key part | **la llave de la reja** / **parte de la llave** | "KEY PART 1 / 3" = "PARTE DE LA LLAVE 1 / 3". |
| the tunnel gate, Old Pass tunnel | **la reja del túnel**, **el túnel del Paso Viejo** | The tunnel's own sign (OLD PASS TUNNEL) stays English. |
| evidence #N | **evidencia #N** | |
| the hunters (the five friends) | **los cazadores** | |
| outsider | **forastero** | Owen's word for Alex. |
| channel 7 | **canal 7** / "canal siete" when spoken | |

## Chapters

| English | Spanish |
|---|---|
| I · THE MARK / I — The Mark | I · LA MARCA / I — La Marca |
| II · MOTH / II — Moth | II · POLILLA / II — Polilla |
| III · THE VEIL | III · EL VELO |
| III — The Harvest (menu) | III — La Cosecha |
| Chapter %s | Capítulo %s |
| Ch.%s (load rows) | Cap. %s |

## Endings

| English | Spanish |
|---|---|
| Run | **Huida** (RUN = HUIDA) |
| Signal | **Señal** |
| Unveiled | **Sin velo** |
| The New Eye | **El Nuevo Ojo** |
| Mixed | **Mixto** |

## Bosses

| English | Spanish |
|---|---|
| OWEN CLARKE — THE WOODSMAN | OWEN CLARKE — EL LEÑADOR |
| NORA VANCE — THE TEACHER | NORA VANCE — LA MAESTRA |
| JULIAN MARSH — THE MEDIC | JULIAN MARSH — EL MÉDICO |
| MARCUS HALE — THE DEACON | MARCUS HALE — EL DIÁCONO |
| THE HARVESTER | EL SEGADOR |
| Spare / Kill / Flee | Perdonar / Matar / Huir |
| spared / killed / fled | perdonado(a) / muerto(a) / huyó (agrees with the character) |

## Weapons and items

| English | Spanish | HUD card |
|---|---|---|
| Revolver | Revólver | REVÓLVER |
| Flare gun | Pistola de bengalas | BENGALAS |
| Shotgun | Escopeta | ESCOPETA |
| Hunting bow | Arco de caza | ARCO |
| Fire axe | Hacha de bombero | HACHA |
| Nail bat | Bate con clavos | BATE |
| Fists | Puños | PUÑOS |
| Bash (pistol-whip) | Culatazo | |
| rounds / shells / arrows / flares | balas / cartuchos / flechas / bengalas | |
| Bandage / Medkit | Venda / Botiquín | |
| Bottle | Botella | |
| Smoke can | Bote de humo (belt: Humo) | |
| Elena's Tea | Té de Elena (belt: Té) | |
| Gas mask / filter | Máscara de gas / filtro | |
| car battery | batería del carro | |
| flashlight | linterna | |

## Achievements

| English | Spanish |
|---|---|
| The Woodsman | El Leñador |
| Moth | Polilla |
| Pop. 1413 | Pob. 1413 |
| Paper Trail | Rastro de papel |
| Three Pieces | Tres piezas |
| Untouched | Intacto |
| Mercy | Piedad |
| Nightmare | Pesadilla |
| Arsenal | Arsenal |
| Old Tom | Old Tom |
| Empty Chairs | Sillas vacías |
| House Always Loses | La casa siempre pierde |
| Hands On | Cuerpo a cuerpo |

## Zones (HUD titles, map)

| English | Spanish |
|---|---|
| Town Square | Plaza del pueblo |
| Lakeview Motel / Lakeview Motel — Room 6 | Lakeview Motel / Lakeview Motel — Habitación 6 |
| Pinewood Forest & Sawmill | Bosque de Pinos y Aserradero |
| Church & Cemetery | Iglesia y Cementerio |
| St. Agnes Clinic | Clínica St. Agnes |
| Hollowmere Elementary | Escuela Primaria de Hollowmere |
| Harbor & Lighthouse | Puerto y Faro |
| Collapsed Bridge | Puente derrumbado |
| Quarry & Veil's Chapel | Cantera y Capilla del Velo |

## World signs

Translated (notices the player must read; Label3D + scripts/sign_label.gd, sized for each language): BRIDGE OUT =
PUENTE CAÍDO · HOLLOWMERE  POP. 1413 = HOLLOWMERE  POB. 1413 · DANGER = PELIGRO · KEEP OUT = NO PASAR · PRIVATE LAND =
PROPIEDAD PRIVADA · FOR THE NINE / WHO NEVER / CAME HOME = POR LOS NUEVE / QUE NUNCA / VOLVIERON · the park rules
board's CLOSED AT DUSK = CERRADO AL ANOCHECER (the park's name stays).

Kept in the town's English (shop, street and brand names, commercial signage): GRADY'S GENERAL STORE, THE DROWNED
LANTERN, LAKEVIEW MOTEL, VACANCY, DINER, ST. AGNES CLINIC, HOLLOWMERE ELEMENTARY, OLD PASS TUNNEL, REFRESHMENTS,
HOLLOWMERE MEMORIAL PARK, HOLLOWMERE ARMS, LAUNDROMAT 24H, PAWN & LOAN, GAS - FOOD - ICE, the street blades.

## UI words

| English | Spanish |
|---|---|
| PRESS ANY KEY | PULSA CUALQUIER TECLA |
| Continue / New / Load / Extra / Options / Dev / Quit (tabs) | CONTINUAR / NUEVA / CARGAR / EXTRA / OPCIONES / DEV / SALIR |
| case (the dossier: "No case open", "New case") | caso |
| Resume / Save game / Main menu / Back | Continuar / Guardar partida / Menú principal / Volver |
| Autosave / Manual save / Saved. | Autoguardado / Guardado manual / Guardado. |
| Easy / Normal / Hard | Fácil / Normal / Difícil |
| Locked | Bloqueado |
| ON / OFF | SÍ / NO |
| Achievement | Logro |
| objective (map panel) | objetivo |
| Takedown | Derribo |
| HIDE | ESCÓNDETE |
| THEY ADAPT | SE ADAPTAN |
| click / Space / Esc / Shift | clic / Espacio / Esc / Shift (key letters W A S D E F C G T H X R B M stay) |

## Sounds written as text

Onomatopoeia stay the same or close (BONG., CLANG, Click., Tsssss…, Kshhh...). The sound they play is looked up from
the English id (scripts/audio.gd CAPTIONS), so the Spanish wording never has to contain the keyword.

## Kept as they are, on purpose

- Moth Run's high-score names (LILY V., TOMAS R., SAM K., LUCIA M., OWEN B., NORA H., GRADY) and its marquee. The
  cabinet's other screen text is Spanish, and Elena's hidden messages are written like the table, in capitals
  without accents (an arcade's character set), as the English does with "LUCIA" and "TOMAS".
- The radio set's printed faceplate (LANTERN RADIO CO., MODEL 7 · SHORT WAVE, SW/MW, MHz, S-METER, SIGNAL, WAVE,
  LOCK, VOL, TUNING): the hardware's own English. Its status line and help are Spanish.
- Card ranks A J Q K, compass N (the compass's W is O: NESO).
- Dev Mode's step names (Intro, Room, Hunt...): the internal step ids that `--step=` takes. Their help text is Spanish.
