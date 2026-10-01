// Shared by bar.html (secondary monitors) and main.html (the primary, central monitor).
// Only main.html sets window.SHOW_CLAUDE: the usage endpoint rate-limits (HTTP 429),
// so it is polled from one bar, not one per monitor.
import * as zebar from 'https://esm.sh/zebar@3.0';

const providers = zebar.createProviderGroup({
  glazewm: { type: 'glazewm' },
  cpu: { type: 'cpu' },
  memory: { type: 'memory' },
  battery: { type: 'battery' },
  date: { type: 'date', formatting: 'EEE d MMM HH:mm' },
});

const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

function render(o) {
  if (o.glazewm) {
    $('workspaces').innerHTML = o.glazewm.currentWorkspaces
      .map(w => `<button class="workspace ${w.hasFocus ? 'focused' : ''} ${w.isDisplayed ? 'displayed' : ''}" data-ws="${esc(w.name)}">${esc(w.displayName ?? w.name)}</button>`)
      .join('');
  }
  if (o.date) $('date').textContent = o.date.formatted;
  if (o.cpu) $('cpu').innerHTML = `<i class="nf nf-oct-cpu"></i>${Math.round(o.cpu.usage)}%`;
  if (o.memory) $('memory').innerHTML = `<i class="nf nf-fae-chip"></i>${Math.round(o.memory.usage)}%`;
  if (o.battery) $('battery').innerHTML = `<i class="nf nf-fa-battery_3"></i>${Math.round(o.battery.chargePercent)}%${o.battery.isCharging ? '+' : ''}`;
}

$('workspaces').addEventListener('click', e => {
  const ws = e.target.closest('[data-ws]')?.dataset.ws;
  if (ws) providers.outputMap.glazewm?.runCommand(`focus --workspace ${ws}`);
});

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

  const el = $('claude');
  if (!shown.length) {
    el.innerHTML = `<i class="nf nf-md-robot"></i><span class="error">usage unavailable</span>`;
    el.title = error;
    return;
  }
  el.innerHTML = '<i class="nf nf-md-robot"></i>' + shown
    .map(a => `<span class="account ${a.stale ? 'stale' : ''}">${esc(a.name)} ${Object.keys(a.windows).length ? cell('5h', a.windows['5h']) + cell('7d', a.windows['7d']) : '<span class="label">n/a</span>'}</span>`)
    .join('');
  el.title = shown
    .map(a => `${a.name}${a.email ? ` <${a.email}>` : ''}${a.stale ? (a.at ? ` (API refused; reading from ${a.at.toLocaleTimeString()})` : ' (API refused, no reading yet)') : ''}\n` +
      ['5h', '7d']
        .filter(k => a.windows[k])
        .map(k => `  ${k}: ${a.windows[k].pct}%${a.windows[k].resets ? `, resets in ${a.windows[k].resets}` : ''}`)
        .join('\n'))
    .join('\n') + '\nClick to refresh.';
}

if (window.SHOW_CLAUDE) {
  $('claude').hidden = false;
  refreshClaude();
  setInterval(refreshClaude, REFRESH_MS);
  $('claude').addEventListener('click', refreshClaude);
}
