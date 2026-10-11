# Jugabilidad — LAAF

Género: **acción / survival horror 3D en tercera persona** (Godot 4.7, física Jolt).
El juego **no** es un ciclo de "recoger objetos buenos / evitar objetos malos". El núcleo es: **explorar → ser cazado → esconderse o escapar → pelear cuando no hay opción → decidir el destino de cada cazador.**

## 1. Ciclo principal

```
 Día (explorar, minijuegos, tienda)
        │
        ▼
 Entrar a una zona ──► Sigilo (evitar al dueño) ──► ¿Visto? ──► Persecución ──► Escapar / esconderse / aturdir
        │                                                              │
        ▼                                                              ▼
 Objetivos (parte de llave, evidencia, debilidad)               Atrapado → daño / Marca ↑
        │
        ▼
 Arena del jefe ──► Pelea ──► Cazador derrotado ──► PERDONAR o MATAR
        │
        └──► HUIR (la salida se abre durante la pelea) ──► el cazador sigue vivo y vaga después
        │
        ▼
 Volver al hub (refugio) ──► gastar fichas ──► siguiente zona
```

Objetivo por sesión: 1 zona ≈ 30–45 min con jefe. Juego completo ≈ 5–7 horas.

## 2. Controles

| Acción | Teclado / Ratón | Mando |
|---|---|---|
| Moverse | WASD | Stick izquierdo |
| Cámara | Ratón | Stick derecho |
| Correr | Shift | L3 |
| Saltar / trepar muro bajo | Espacio (tiempo coyote + buffer) | A / Equis |
| Rodar (i‑frames: flechas y golpes te atraviesan) | Ctrl | LB / L1 |
| Agacharse / sigilo (esconderse en pasto alto) | C | B / Círculo |
| Deslizarse (agacharse corriendo; saltar desde el deslizamiento conserva el impulso) | C mientras corres | B mientras corres |
| Interactuar / esconderse | E | X / Cuadrado |
| Apuntar | Mantener clic der. | LT |
| Disparar (también saltando, rodando o deslizándote, con más dispersión) | Clic izq. | RT |
| Recargar | R | RB / R1 |
| Cambiar arma | Q / rueda / 1‑6 (el HUD muestra lo que llevas) | Y / Triángulo |
| Golpear (puños, culata, hacha, bate; disparar también golpea si no hay nada que disparar) | B / clic central | RT con arma vacía / cuerpo a cuerpo |
| Tensar el arco | Mantener clic der. (disparar suelta; tensado completo pega más) | LT |
| **Doble disparo** | Dispara, cambia y vuelve a disparar en menos de 0,45 s: el cambio es instantáneo y ese disparo hace +50% | igual |
| Linterna | F | Cruceta arriba |
| Cambiar de hombro | V | R3 |
| Saltar línea de diálogo (cinemáticas) | Enter / E | A / X |
| Menú de pausa (continuar · guardar · menú principal) | Esc | Start |

> Implementado en `player/player.gd` + `player/weapons.gd`: revólver, pistola de bengalas, escopeta (de Tom, en el cobertizo, cap. 2), el arco de Owen (tras su pelea), hacha de bombero (patio del aserradero), bate con clavos (dentro de la escuela) y los puños (golpes alternos; cada tercer golpe acertado es un gancho más fuerte). El hacha y el bate aturden. Los brazos sujetan cada arma por sus empuñaduras reales (IK). Curación rápida, tecla de radio y diario aún no están implementados.

Cámara: sobre el hombro, cambia de hombro con una tecla (V / R3). Se acerca al esconderse y tiembla cuando un cazador está cerca.

## 3. Estadísticas del jugador

| Estadística | Base | Mejorable | Notas |
|---|---|---|---|
| Vida | 100 | +20 por nivel (3 niveles) | Solo se regenera sola hasta 30%; curar con vendas/botiquines |
| Estamina | 100 | +15 por nivel (3 niveles) | Correr, rodar, ataque pesado. Se recupera caminando |
| Sigilo | 1 | 3 niveles | Reduce el radio de ruido de los pasos (−15% por nivel) |
| Resistencia a la Marca | 1 | 3 niveles | La Marca crece −10% más lento por nivel |
| Cuerpo a cuerpo | 10 daño | 3 niveles | Las modificaciones de arma suman daño |
| Puntería | 1 | se entrena en la galería de tiro | Reduce el balanceo y la apertura de la mira |
| Capacidad de munición | 6 | +3 por nivel (3 niveles) | La munición es escasa a propósito |
| Espacios de inventario | 6 | +2 por nivel (2 niveles) | Arrojables y curas comparten espacios |

## 4. Sigilo

- **Ruido:** cada acción tiene un radio (caminar 4 m, correr 12 m, agachado 1,5 m, rodar 6 m, disparo 40 m, minijuegos con sonido 8–15 m). Las superficies lo modifican (madera cruje, hierba silenciosa, agua salpica).
- **Visibilidad:** nivel de luz + movimiento + distancia + cobertura. Un **ojo de visibilidad** en el HUD muestra cuán visible es el jugador.
- **Escondites:** taquillas/armarios, bajo camas/mesas, hierba alta, sombras, mausoleos, cámaras frigoríficas. Los cazadores pueden revisar escondites donde **vieron** entrar al jugador (Julian siempre lo hace).
- **Distracciones:** lanzar botellas/ladrillos, señuelos de ruido, encender radios, romper ventanas.
- **Huellas:** en barro/nieve (zona del bosque), Owen puede seguirlas. El agua las borra.

## 5. Cazadores (IA enemiga)

Los cazadores son **persistentes** — uno por zona, no se pueden matar hasta su pelea de jefe.

**Máquina de estados:**

| Estado | Comportamiento | Condición de salida |
|---|---|---|
| Patrulla | Sigue la ruta de la zona, habla solo | Oye ruido / ve algo → Sospecha |
| Sospecha | Va al último ruido, mira alrededor, "¿Quién anda ahí?" | Confirma jugador → Persecución; nada en 10 s → Patrulla |
| Caza | (noche/apagón) Busca activamente en el área probable del jugador, revisa escondites | Ve al jugador → Persecución |
| Persecución | Corre hacia el jugador, ataca, llama a otros (campana de Marcus / silbido de Owen) | Pierde visión 8 s → Búsqueda; aturdido → Aturdido |
| Búsqueda | Revisa escondites cercanos, recuerda la última posición | 30 s sin nada → Patrulla / Caza |
| Aturdido | Debilidad activada o golpe pesado; 3–8 s | Termina el tiempo → Búsqueda |

- **Atrapado:** un cazador que alcanza al jugador hace mucho daño y sube la Marca +15%. No es muerte instantánea, salvo en el apagón con la Marca al 100%.
- **Director:** un "director de tensión" ligero limita cuántas veces un cazador encuentra al jugador (evitar frustración): tras un escape, el cazador va a la zona equivocada un rato.
- **Tras el Acto III:** todos los cazadores vivos pueden aparecer en cualquier zona (errantes), de uno en uno.

## 6. Combate

- **Cuerpo a cuerpo:** ligero (rápido, poca estamina), pesado (lento, aturde enemigos comunes, abre a los cazadores para contraatacar), esquiva con invulnerabilidad.
- **Armas:** encontradas o compradas: tubo, hacha de mano, palanca (cuerpo a cuerpo); revólver, pistola de bengalas, escopeta (tarde). Munición escasa.
- **Arrojables:** botella (ruido), ladrillo (aturde poco), bengala (luz + fuego, debilidad de Owen), señuelo de ruido (distracción), bote de humo (corta la visión).
- **Enemigos comunes:** **Los Marcados** — habitantes reclutados con máscaras, rellenan peleas y patrullas. Se pueden matar o noquear libremente; sueltan fichas y suministros.
- **Jefes cazadores:** 2–3 fases; la debilidad de cada cazador es la mecánica clave. Una **salida de escape** visible se abre tras la fase 1 (opción de huir).

## 7. Resolución de jefes — Perdonar / Matar / Huir

Cuando la vida de un cazador llega a 0 cae de rodillas. Aparece una opción:

- **Perdonar** (mantener interactuar): el cazador se rinde. Requiere haber encontrado su **objeto personal** (dibujo de Lily, expediente de Sam, foto de Clara, farol de los padres de Owen) para la escena completa de "redención"; si no, sobrevive pero sigue roto (cuenta como perdonado, sin aliado en el final).
- **Matar** (pulsar ataque): escena de ejecución; el cazador sale del juego.
- **Huir** (durante la pelea, por la salida de escape): sin resolución; el cazador sigue siendo una amenaza errante. Los objetos clave se pueden robar de su escondite con sigilo.

Ninguna opción se marca como "correcta". Las consecuencias aparecen en el mundo: frases de Grady, grafitis, cómo hablan del jugador los cazadores restantes ("Mataste a Owen. Ahora eres uno de nosotros.").

## 8. Medidor de Marca

- Rango 0–100%. Sin indicador permanente: cuando sube, un pequeño aviso rojo "MARK +N%" parpadea bajo el reloj y se desvanece (las subidas seguidas se suman en un solo aviso); el valor exacto está en el menú de pausa.
- **Sube:** +1% por minuto de juego de noche, +15% al ser atrapado, +5% al ser visto, más rápido tras el Acto III.
- **Baja:** descansar en un cuarto seguro (−30%, una vez por noche), consumibles (té de Elena −15%), dormir en el motel (vuelve a 20% cada mañana).
- **Efectos:**
  - 25%: susurros.
  - 50%: los cazadores intuyen la dirección aproximada del jugador cuando están cerca.
  - 75%: viñeta en la visión, figuras alucinadas (falsos cazadores).
  - 100%: en el apagón, el jugador es llevado → **secuencia "Llevado"** (despierta en las celdas de la cantera, tramo de escape, pierde 50% de las fichas que lleva). En Difícil = fin del juego.

## 9. Día / noche y apagón

- **Día (06:00–19:00):** los cazadores patrullan menos (solo en su zona, más lentos). Tienda y minijuegos disponibles.
- **Noche (19:00–06:00):** cazadores en estado Caza, más Marcados.
- **Apagón (03:00–04:00):** se corta la luz en todo el pueblo; solo linterna y fuegos. Se recoge a los marcados. Los cuartos seguros siguen funcionando.
- El tiempo pasa en tiempo real (1 hora de juego = 2,5 minutos reales) y al dormir en el motel (salta a la mañana).

## 10. HUD

- Barras de vida y estamina (abajo a la izquierda), mínimas.
- Marca: un breve aviso "MARK +N%" bajo el reloj cuando sube (arriba a la derecha); el valor exacto en el menú de pausa.
- Ojo de visibilidad y anillo de ruido alrededor del personaje (opcional).
- Contador de fichas (solo en el hub/al cambiar).
- Reloj (hora del juego, arriba al centro, se vuelve rojo cerca de las 03:00).
- Pista de objetivo (se puede desactivar).
- Radio diegética: subtítulos de las llamadas de Elena/El Pastor.

## 11. Menús y pantallas

- Menú principal, ajustes (gráficos, audio, reasignar controles, subtítulos, idioma EN/ES, accesibilidad).
- Menú de pausa: diario (notas, evidencias 0/12, personajes, recuerdos), mapa con zonas y dueños, inventario.
- **Pantalla de tienda** (Grady): pestañas Suministros, Armas, Mejoras, Historia. Muestra precio, nivel actual y efecto del siguiente nivel.
- **UI de minijuegos:** cada minijuego tiene su propia capa (ver [minijuegos.md](minijuegos.md)), con botón de salir claro y el ruido que genera.
- Opción de jefe (Perdonar / Matar), sin temporizador.
- Pantalla de final con estadísticas (fichas ganadas, miembros perdonados/muertos/huidos, evidencias, tiempo).

## 12. Guardado

- Guardado manual en cuartos seguros y en la tienda de Grady; autoguardado al entrar a una zona y tras los jefes.
- 3 ranuras. Se guarda: posición, hora, Marca, estadísticas/mejoras, inventario, fichas, flags (ver [progresion.md](progresion.md)).

## 13. Dificultad

| Ajuste | Historia | Normal | Difícil |
|---|---|---|---|
| Detección de cazadores | −40% | base | +25% |
| Crecimiento de la Marca | −50% | base | +30% |
| Marca 100% en el apagón | Llevado, conserva fichas | Llevado, −50% fichas | Fin del juego |
| Munición encontrada | +50% | base | −30% |
| Premios de minijuegos | +25% | base | base |
