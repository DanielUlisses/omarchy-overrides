// Shared by bar.html (secondary monitors) and main.html (the primary, central monitor).
// Laid out like the stock Zebar starter: Windows button and workspaces on the left, clock
// (and on main, the next event) in the centre, stats on the right. Only main.html sets
// window.SHOW_CLAUDE / SHOW_TRAY / SHOW_WEATHER: the usage endpoint rate-limits (HTTP 429)
// and tray icons belong in one place, so those run on one bar, not one per monitor.
import * as zebar from 'https://esm.sh/zebar@3.3';

const providers = zebar.createProviderGroup({
  glazewm: { type: 'glazewm' },
  cpu: { type: 'cpu' },
  memory: { type: 'memory' },
  battery: { type: 'battery' },
  date: { type: 'date', formatting: 'EEE d MMM  HH:mm' },
  ...(window.SHOW_WEATHER ? { weather: { type: 'weather', refreshInterval: 30 * 60 * 1000 } } : {}),
});

const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

const WEATHER_ICONS = {
  clear_day: 'day_sunny', clear_night: 'night_clear',
  cloudy_day: 'day_cloudy', cloudy_night: 'night_alt_cloudy',
  light_rain_day: 'day_sprinkle', light_rain_night: 'night_alt_sprinkle',
  heavy_rain_day: 'day_rain', heavy_rain_night: 'night_alt_rain',
  snow_day: 'day_snow', snow_night: 'night_alt_snow',
  thunder_day: 'day_thunderstorm', thunder_night: 'night_alt_thunderstorm',
};
const batteryIcon = b => (b.isCharging ? 'nf-md-battery_charging' : `nf-fa-battery_${Math.min(4, Math.round(b.chargePercent / 25))}`);
const stat = (icon, value, title) => `<i class="nf ${icon}" title="${title}"></i>${value}`;

function render(o) {
  if (o.glazewm) {
    $('workspaces').innerHTML = o.glazewm.currentWorkspaces
      .map(w => `<button class="workspace ${w.hasFocus ? 'focused' : ''} ${w.isDisplayed ? 'displayed' : ''}" data-ws="${esc(w.name)}">${esc(w.displayName ?? w.name)}</button>`)
      .join('');
  }
  if (o.date) $('date').textContent = o.date.formatted;
  if (o.memory) $('memory').innerHTML = stat('nf-fae-chip', `${Math.round(o.memory.usage)}%`, 'Memory');
  if (o.cpu) $('cpu').innerHTML = stat('nf-oct-cpu', `${Math.round(o.cpu.usage)}%`, 'CPU');
  if (o.battery) $('battery').innerHTML = stat(batteryIcon(o.battery), `${Math.round(o.battery.chargePercent)}%`, 'Battery');
  if (o.weather && $('weather')) {
    $('weather').hidden = false;
    $('weather').innerHTML = stat(`nf-weather-${WEATHER_ICONS[o.weather.status] ?? 'na'}`, `${Math.round(o.weather.celsiusTemp)}°`, `Weather, wind ${Math.round(o.weather.windSpeed)} km/h`);
  }
}

$('workspaces').addEventListener('click', e => {
  const ws = e.target.closest('[data-ws]')?.dataset.ws;
  if (ws) providers.outputMap.glazewm?.runCommand(`focus --workspace ${ws}`);
});

// The Windows button opens PowerToys Command Palette, as Win+Space does (allow-listed in zpack.json).
$('launcher').addEventListener('click', () => zebar.shellExec('explorer', ['x-cmdpal:']));

render(providers.outputMap);
providers.onOutput(() => render(providers.outputMap));

// --- Claude subscription usage -------------------------------------------------------
// claude-acc lives in WSL; `claude-acc usage` prints, per account:
//   ★ pythian  <dsilva@pythian.com>          (★ marks the default account)
//       5h  [████░░░░]   19%  resets in 2d 15h
//       7d  [██░░░░░░]    8%
// or "token present, but API unreachable" when the endpoint refuses (it rate-limits).
// The command is allow-listed exactly in zpack.json.
const CLAUDE_ACC = ['-d', 'Arch', '-e', '/home/daniel/.claude-switch/bin/claude-acc', 'usage'];
const REFRESH_MS = 10 * 60 * 1000;

export function parseUsage(text) {
  const accounts = [];
  for (const raw of text.replace(/\x1b\[[0-9;]*m/g, '').split(/\r?\n/)) {
    const header = raw.match(/^ {2}[★ ] (\S+)(?:\s+<([^>]+)>|\s+\(standard\))?\s*$/);
    if (header) {
      accounts.push({ name: header[1] === '~/.claude/' ? 'default' : header[1], email: header[2] ?? '', windows: {} });
      continue;
    }
    const win = raw.match(/^\s+(5h|7d)\s+\[[^\]]*\]\s+(\d+)%\s*(?:resets in (.+))?/);
    if (win && accounts.length) accounts.at(-1).windows[win[1]] = { pct: +win[2], resets: win[3]?.trim() };
  }
  return accounts;
}

// Last reading that had numbers, per account: a refused refresh shows these, dimmed.
const lastGood = new Map();
let claudeOpen = false;
let lastShown = null;

const level = pct => (pct >= 90 ? 'crit' : pct >= 70 ? 'warn' : '');
const cell = (label, w) => (w ? `<span class="label">${label}</span><span class="${level(w.pct)}">${w.pct}%</span> ` : '');

async function refreshClaude() {
  let accounts = [];
  let error = '';
  try {
    const { stdout, stderr, code } = await zebar.shellExec('wsl', CLAUDE_ACC);
    accounts = parseUsage(stdout);
    if (!accounts.length) error = stderr || `claude-acc exited ${code}`;
  } catch (err) {
    error = String(err?.message ?? err);
  }

  const shown = accounts.map(a => {
    if (Object.keys(a.windows).length) {
      lastGood.set(a.name, { ...a, at: new Date() });
      return { ...a, stale: false };
    }
    const prev = lastGood.get(a.name);
    return prev ? { ...prev, stale: true } : { ...a, stale: true };
  });

  lastShown = { shown, error };
  renderClaude();
}

function renderClaude() {
  const { shown, error } = lastShown;
  const el = $('claude');
  if (!shown.length) {
    el.innerHTML = `<i class="nf nf-md-robot"></i><span class="error">usage unavailable</span>`;
    el.title = error;
    return;
  }
  // Collapsed it is just the icon, coloured by the busiest limit of any account; a click
  // opens the per-account numbers (claudeOpen), like the tray chevron.
  const worst = Math.max(0, ...shown.flatMap(a => Object.values(a.windows).map(w => w.pct)));
  el.innerHTML = `<i class="nf nf-md-robot ${level(worst)}"></i>` + (claudeOpen ? shown
    .map(a => `<span class="account ${a.stale ? 'stale' : ''}">${esc(a.name)} ${Object.keys(a.windows).length ? cell('5h', a.windows['5h']) + cell('7d', a.windows['7d']) : '<span class="label">n/a</span>'}</span>`)
    .join('') : '');
  el.title = shown
    .map(a => `${a.name}${a.email ? ` <${a.email}>` : ''}${a.stale ? (a.at ? ` (API refused; reading from ${a.at.toLocaleTimeString()})` : ' (API refused, no reading yet)') : ''}\n` +
      ['5h', '7d']
        .filter(k => a.windows[k])
        .map(k => `  ${k}: ${a.windows[k].pct}%${a.windows[k].resets ? `, resets in ${a.windows[k].resets}` : ''}`)
        .join('\n'))
    .join('\n') + '\nClick to show/hide, right click to refresh.';
}

if (window.SHOW_CLAUDE) {
  $('claude').hidden = false;
  refreshClaude();
  setInterval(refreshClaude, REFRESH_MS);
  $('claude').addEventListener('click', () => {
    claudeOpen = !claudeOpen;
    if (lastShown) renderClaude();
  });
  $('claude').addEventListener('contextmenu', e => {
    e.preventDefault();
    refreshClaude();
  });
}

// --- System tray ---------------------------------------------------------------------
// omarchy.ahk hides the Windows taskbar, so its tray icons (1Password, Logi Options+,
// Teams, ...) live here instead, on the main bar only, collapsed until the chevron is
// clicked. Clicks on an icon go back to the owning app.
if (window.SHOW_TRAY) {
  const tray = zebar.createProvider({ type: 'systray' });
  const el = $('tray');
  // Collapsed behind a chevron, like the Windows overflow menu.
  const toggle = $('tray-toggle');
  toggle.hidden = false;
  toggle.addEventListener('click', () => {
    el.hidden = !el.hidden;
    toggle.classList.toggle('open', !el.hidden);
  });
  const draw = out => {
    el.innerHTML = (out?.icons ?? [])
      .map(i => `<img class="tray-icon" src="${esc(i.iconUrl)}" title="${esc(i.tooltip)}" data-id="${esc(i.id)}" />`)
      .join('');
  };
  draw(tray.output);
  tray.onOutput(draw);
  const on = (event, action) => el.addEventListener(event, e => {
    const id = e.target.closest('[data-id]')?.dataset.id;
    if (!id || !tray.output) return;
    if (event === 'contextmenu') e.preventDefault();
    if (event === 'auxclick' && e.button !== 1) return;
    tray.output[action](id);
  });
  on('click', 'onLeftClick');
  on('dblclick', 'onLeftDoubleClick');
  on('contextmenu', 'onRightClick');
  on('auxclick', 'onMiddleClick');
  on('mouseover', 'onHoverEnter');
  on('mouseout', 'onHoverLeave');
}
