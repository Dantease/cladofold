export function setupFeaturePreviews(onChange) {
  const blur = document.querySelector('#demo-blur');
  const border = document.querySelector('#demo-border');
  const sample = document.querySelector('.effect-sample');
  const presets = { Duo: [48,.12], Subtle: [18,.10], Balanced: [36,.20], Dreamy: [64,.32] };
  const buttons = document.querySelectorAll('[data-preset]');
  function paint() {
    document.querySelector('#blur-value').textContent = `${blur.value} pt`;
    document.querySelector('#border-value').textContent = `${border.value}%`;
    sample.style.setProperty('--sample-blur', `${Number(blur.value)/8}px`);
    sample.style.setProperty('--sample-border', `${Number(border.value)*.28}px`);
  }
  for (const input of [blur,border]) {
    input.addEventListener('input', () => { buttons.forEach(button => button.setAttribute('aria-pressed','false')); paint(); });
    input.addEventListener('change', onChange);
  }
  buttons.forEach(button => button.addEventListener('click', () => {
    const [radius,shade] = presets[button.dataset.preset];
    blur.value = radius;
    if (button.dataset.preset === 'Duo') border.value = 100;
    sample.style.setProperty('--sample-shade', shade);
    buttons.forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    paint();onChange();
  }));
  function response() {
    const start = document.querySelector('#demo-start').checked;
    const hold = document.querySelector('#demo-hold').checked;
    document.querySelector('#response-note').textContent = `${start ? 'Starts with your movement.' : 'Choose a starting angle in the app.'} ${hold ? 'Holds until you reopen.' : 'Clears after half a second of stillness.'}`;
    onChange();
  }
  document.querySelector('#demo-start').addEventListener('change', response);
  document.querySelector('#demo-hold').addEventListener('change', response);
  paint();
}
