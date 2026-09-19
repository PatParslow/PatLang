#!/usr/bin/env node
// Loads demo pages in a real headless Chrome/Edge, clicks every onclick button and
// reports uncaught page errors, buttons that never finish, and failed page-specific
// checks. Nothing here needs a browser extension or any npm package (Node 22+).
//
//   node tools/browser_test/check_pages.mjs <dir> [--checks page_checks.json] [--json] <page.html ... | --all>
//
// <dir> is served over http on 127.0.0.1 with the Cross-Origin-Opener-Policy /
// Cross-Origin-Embedder-Policy headers parslow.net sets, so the threaded demos work.
// A file that is a bare fragment (no <html>/<!doctype>, like portfolio/demos/*.html)
// is served wrapped in a minimal document, so the same tool tests generated
// fragments and built site pages (`publish/`).
//
// A page passes when every button click finishes without an exception, no page
// error is thrown, and its page-specific check (if page_checks.json has one) is ok.
// A page-specific check is a JavaScript expression that resolves to a JSON string
// {"ok": bool, "detail": "..."}; page_checks.json maps "name|other-name" (matched
// against the file name without .html) to that expression, for apps whose result is
// not visible text (canvas, cells, tables).
//
// Environment: CHROME (browser executable), HTTP_PORT (8766), CDP_PORT (9333).
// A separate temporary profile is always used, so a running browser is left alone.
// Exit code: 0 if every page passed, 1 otherwise.

import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFileSync, readdirSync, mkdtempSync, existsSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); if (i < 0) return null; const v = args[i + 1]; args.splice(i, 2); return v; };
const checksFile = flag('--checks');
const asJson = args.includes('--json') && (args.splice(args.indexOf('--json'), 1), true);
const dir = args.shift();
let names = args;
if (!dir) { console.error('usage: check_pages.mjs <dir> [--checks file] [--json] <page.html ...|--all>'); process.exit(2); }
if (names[0] === '--all') {
  names = [];
  const walk = (d, rel) => { for (const f of readdirSync(d)) { const p = path.join(d, f), r = rel ? rel + '/' + f : f; if (statSync(p).isDirectory()) walk(p, r); else if (f.endsWith('.html')) names.push(r); } };
  walk(dir, '');
}
const HTTP_PORT = Number(process.env.HTTP_PORT || 8766);
const CDP_PORT = Number(process.env.CDP_PORT || 9333);
const PAGE_MS = 240000;
const checks = checksFile ? JSON.parse(readFileSync(checksFile, 'utf8')) : {};

function findBrowser() {
  const c = [process.env.CHROME,
    'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
    '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  const hit = c.find((p) => p && existsSync(p));
  if (!hit) { console.error('no Chrome/Edge found; set CHROME'); process.exit(2); }
  return hit;
}

const server = http.createServer((req, res) => {
  const p = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  if (!existsSync(p) || statSync(p).isDirectory()) { res.writeHead(404); res.end('not found'); return; }
  let body = readFileSync(p);
  const isHtml = p.endsWith('.html');
  if (isHtml && !/<html|<!doctype/i.test(body.toString('utf8', 0, 2000))) {
    body = Buffer.from('<!doctype html><html><head><meta charset="utf-8"><title>t</title></head><body>' + body.toString('utf8') + '</body></html>');
  }
  res.writeHead(200, {
    'Content-Type': isHtml ? 'text/html; charset=utf-8' : 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  res.end(body);
});
await new Promise((r) => server.listen(HTTP_PORT, '127.0.0.1', r));

const profile = mkdtempSync(path.join(tmpdir(), 'check-pages-'));
const browser = spawn(findBrowser(), [
  '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  `--remote-debugging-port=${CDP_PORT}`, '--user-data-dir=' + profile, 'about:blank',
], { stdio: 'ignore' });
const browserExited = new Promise((r) => browser.once('exit', r));

async function waitJson(url, tries = 60) {
  for (let i = 0; i < tries; i++) {
    try { return await (await fetch(url)).json(); } catch { await new Promise((r) => setTimeout(r, 500)); }
  }
  throw new Error('the browser did not start');
}
await waitJson(`http://127.0.0.1:${CDP_PORT}/json/version`);

const clickAll = `(async () => {
  const errors = [];
  window.addEventListener('error', (e) => errors.push('error: ' + e.message));
  window.addEventListener('unhandledrejection', (e) => errors.push('rejection: ' + String(e.reason && e.reason.message || e.reason)));
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  await sleep(1500);
  const text = () => document.body.innerText + '\\u0000' + Array.from(document.querySelectorAll('textarea,input')).map((e) => e.value).join('\\u0001');
  const buttons = Array.from(document.querySelectorAll('button')).filter((b) => b.getAttribute('onclick'));
  const results = [];
  for (const b of buttons) {
    const before = text();
    const label = (b.textContent || '').trim().slice(0, 40);
    let err = null;
    try { b.click(); } catch (e) { err = String(e.message); }
    let after = before, waited = 0;
    while (waited < 60000) {
      await sleep(500); waited += 500;
      after = text();
      if (after !== before && !/running\\.\\.\\./.test(after) && waited >= 1000) break;
    }
    results.push({ label, err, changed: after !== before, running: /running\\.\\.\\./.test(after) });
  }
  return JSON.stringify({ isolated: self.crossOriginIsolated, nbuttons: buttons.length, results, errors: errors.slice(0, 8) });
})()`;

function checkFor(name) {
  const base = path.basename(name).replace(/\.html$/, '');
  const key = Object.keys(checks).find((k) => k.split('|').includes(base));
  return key ? checks[key] : null;
}

async function testPage(name) {
  const target = await (await fetch(`http://127.0.0.1:${CDP_PORT}/json/new?about:blank`, { method: 'PUT' })).json();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  let id = 0; const pending = new Map(); const consoleErrs = []; let onLoad = () => {};
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
    else if (msg.method === 'Page.loadEventFired') onLoad();
    else if (msg.method === 'Runtime.exceptionThrown') consoleErrs.push('exception: ' + (msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text).split('\n')[0].slice(0, 160));
    else if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') consoleErrs.push('console.error: ' + msg.params.args.map((a) => a.value || a.description || '').join(' ').slice(0, 160));
  };
  const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
  const evaluate = (expression, ms) => Promise.race([
    send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }),
    new Promise((_, j) => setTimeout(() => j(new Error('timeout')), ms)),
  ]);
  await send('Page.enable'); await send('Runtime.enable');
  const loaded = new Promise((r) => { onLoad = r; });
  await send('Page.navigate', { url: `http://127.0.0.1:${HTTP_PORT}/${name}` });
  await Promise.race([loaded, new Promise((r) => setTimeout(r, 60000))]);

  const out = { name, problems: [] };
  try {
    const r = await evaluate(clickAll, PAGE_MS);
    const v = r.result?.result?.value;
    if (typeof v !== 'string') throw new Error(JSON.stringify(r.result).slice(0, 200));
    Object.assign(out, JSON.parse(v));
  } catch (e) { out.problems.push('page did not run: ' + e.message); }
  for (const b of out.results || []) {
    if (b.err) out.problems.push(`click error on "${b.label}": ${b.err}`);
    if (b.running) out.problems.push(`"${b.label}" is still running`);
  }
  for (const e of [...(out.errors || []), ...consoleErrs]) out.problems.push('page: ' + e.replace(/\s+/g, ' '));
  const expr = checkFor(name);
  if (expr) {
    try {
      const r = await evaluate(expr, 120000);
      const v = r.result?.result?.value;
      out.check = typeof v === 'string' ? JSON.parse(v) : { ok: false, detail: JSON.stringify(r.exceptionDetails || r.result).slice(0, 240) };
    } catch (e) { out.check = { ok: false, detail: e.message }; }
    if (!out.check.ok) out.problems.push('page check failed: ' + String(out.check.detail).slice(0, 200));
  }
  ws.close();
  await fetch(`http://127.0.0.1:${CDP_PORT}/json/close/${target.id}`).catch(() => {});
  return out;
}

const all = [];
for (const n of names) {
  const r = await testPage(n);
  all.push(r);
  if (asJson) console.log(JSON.stringify(r));
  else {
    console.log(`${r.problems.length ? 'PROBLEM' : 'ok     '} ${n}  (${r.nbuttons ?? '?'} buttons${r.check ? ', check: ' + String(r.check.detail).slice(0, 70) : ''})`);
    for (const p of r.problems) console.log('         - ' + p);
  }
}
const bad = all.filter((r) => r.problems.length).length;
if (!asJson) console.log(`\n${all.length - bad} of ${all.length} pages clean`);

browser.kill();
await Promise.race([browserExited, new Promise((r) => setTimeout(r, 5000))]);
server.close();
try { rmSync(profile, { recursive: true, force: true }); } catch {}
await new Promise((r) => setTimeout(r, 300));
process.exit(bad ? 1 : 0);
