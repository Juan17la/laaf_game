// Scales every .screen (the game's 640×360 base canvas) to the width of its .stage, like the game's viewport stretch.
function fitScreens() {
  document.querySelectorAll('.stage').forEach(stage => {
    const screen = stage.querySelector('.screen');
    if (!screen) return;
    const s = stage.clientWidth / 640;
    screen.style.transform = `scale(${s})`;
    stage.style.height = `${360 * s}px`;
  });
}
addEventListener('resize', fitScreens);
addEventListener('DOMContentLoaded', () => {
  fitScreens();
  const t = document.getElementById('toggle-callouts');
  if (t) t.addEventListener('change', () => document.body.classList.toggle('hide-callouts', !t.checked));
});
// fonts change nothing in the scale, but re-fit once everything has loaded in case a scrollbar appeared
addEventListener('load', fitScreens);
