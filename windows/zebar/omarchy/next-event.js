// Next calendar event, Omarchy's tobiasz-p.next-event plugin on Zebar (main.html only).
// The plugin's Model.js (ICS parsing, recurrence, timezones, labels) is reused as is: the
// setup script copies it here as next-event-model.js, and main.html loads it as a classic
// script, so its functions are globals. The feeds are fetched in WSL by
// bin/next-event-feeds, which also reads the private feed list (~/.config/next-event/feeds).
//
// Left click joins the next meeting (or opens it in Google Calendar), in the Chrome profile
// set for its feed; right click refreshes. The tooltip is the agenda, in place of the panel.
import * as zebar from 'https://esm.sh/zebar@3.0';

const SCRIPT = '/home/daniel/.omarchy-overrides/bin/next-event-feeds';
const WSL = ['-d', 'Arch', '-e', SCRIPT];
const REFRESH_MS = 5 * 60 * 1000;
const TICK_MS = 30 * 1000;
const LOOKAHEAD_DAYS = 3;
const MAX_TITLE = 28;
// The plugin's excludeKeywords: events whose title contains any of these (any case) are hidden.
const EXCLUDE = 'block,blocked,lunch,OOO';
const HEADER = '#NEXT-EVENT-FEED\t';

const el = document.getElementById('next-event');
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

let events = [];
let feeds = [];
let profiles = new Map();
let failed = [];
let allFailed = false;
let updated = null;
let state = null;

// fetch output: per feed a "#NEXT-EVENT-FEED<TAB>label<TAB>profile<TAB>ok|failed" line, then its ICS.
export function splitFeeds(text) {
  return text.split(/^(?=#NEXT-EVENT-FEED\t)/m)
    .filter(chunk => chunk.startsWith(HEADER))
    .map(chunk => {
      const nl = chunk.indexOf('\n');
      const [, label, profile, status] = (nl < 0 ? chunk : chunk.slice(0, nl)).trim().split('\t');
      return { label, profile, ok: status === 'ok', ics: nl < 0 ? '' : chunk.slice(nl + 1) };
    });
}

async function refresh() {
  el.classList.add('updating');
  try {
    const { stdout, stderr } = await zebar.shellExec('wsl', [...WSL, 'fetch']);
    const parsed = splitFeeds(stdout);
    const now = new Date();
    const fresh = parsed.flatMap((f, i) => {
      if (!f.ok) return [];
      const color = pickCalendarColor(f.label, i);
      return parseIcs(f.ics, { lookaheadDays: LOOKAHEAD_DAYS + 1, maxEvents: 80, now, calendarColor: color, feedLabel: f.label })
        .map(e => Object.assign(e, { feedLabel: f.label, calendarColor: color }));
    });
    feeds = parsed.map((f, i) => ({ label: f.label, url: f.label, color: pickCalendarColor(f.label, i) }));
    profiles = new Map(parsed.map(f => [f.label, f.profile]));
    failed = parsed.filter(f => !f.ok).map(f => f.label);
    if (!parsed.length && stderr) failed = [stderr.trim()];
    allFailed = failed.length > 0 && failed.length >= parsed.length;
    // Every feed down: keep showing what we had.
    if (fresh.length || failed.length < parsed.length) {
      events = dedupeEvents(fresh);
      updated = now;
    }
  } catch (err) {
    failed = [String(err?.message ?? err)];
    allFailed = true;
  }
  el.classList.remove('updating');
  render();
}

function agenda(now) {
  const lines = [];
  for (const group of state.scheduleGroups) {
    lines.push(group.title);
    for (const e of group.items) {
      const when = e.allDay ? 'all day' : timeRange(new Date(e.start), new Date(e.end), e.allDay, false);
      lines.push(`  ${when}  ${e.title}${e.feedLabel ? `  (${e.feedLabel})` : ''}`);
    }
  }
  return lines.join('\n');
}

function render() {
  const now = new Date();
  const configured = feeds.length > 0;
  state = computeScheduleState(events, now, {
    lookaheadDays: LOOKAHEAD_DAYS,
    maxMeetingRows: 8,
    maxScheduleRows: 20,
    excludeKeywords: EXCLUDE,
    feeds,
  });
  const next = state.nextMeeting;
  const label = barLabel(configured || events.length > 0, next, now, MAX_TITLE, false);
  const live = next && !next.allDay && now >= next.start && now < next.end;

  el.hidden = false;
  el.className = `next-event${live ? ' live' : ''}${label ? '' : ' empty'}${allFailed ? ' stale' : ''}`;
  el.innerHTML = label ? esc(label) : `<i class="nf nf-md-calendar_blank"></i>`;

  const status = [
    updated ? `Updated ${updated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })}` : '',
    failed.length ? `offline: ${failed.join(', ')}` : '',
  ].filter(Boolean).join(' · ');
  el.title = !configured && !events.length
    ? 'No calendars: add "label|chrome profile|ics url" lines to ~/.config/next-event/feeds in WSL.\nRight click to refresh.'
    : [
        tooltipLine(true, next, now, { showCalendarLabel: true, use12Hour: false, lastFetchFailed: allFailed, offlineFeedCount: allFailed ? 0 : failed.length }),
        state.scheduleGroups.length ? agenda(now) : '',
        status,
        `Click: ${next?.meetUrl ? 'join meeting' : 'open in Calendar'} · Right click: refresh`,
      ].filter(Boolean).join('\n\n');
}

function open(event) {
  if (!event) return;
  const url = event.meetUrl || eventCalendarUrl(event, DEFAULT_CALENDAR_URL_BASE);
  if (!/^https:\/\/\S+$/.test(url)) return;
  zebar.shellExec('wsl', [...WSL, 'open', profiles.get(event.feedLabel) || 'Default', url]);
}

el.addEventListener('click', () => open(state?.nextMeeting));
el.addEventListener('contextmenu', e => {
  e.preventDefault();
  refresh();
});

refresh();
setInterval(refresh, REFRESH_MS);
setInterval(render, TICK_MS);
