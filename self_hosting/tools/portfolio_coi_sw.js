// The portfolio's service worker (written to portfolio/coi-sw.js by
// build_portfolio.patlang). It makes the pages it controls cross-origin
// isolated, as v2's WebAssembly programs need (their memory is a
// SharedArrayBuffer), on a host that does not send the headers itself: each
// response it passes on gains Cross-Origin-Opener-Policy: same-origin and
// Cross-Origin-Embedder-Policy: credentialless, which still lets a page load
// cross-origin fonts and styles.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (e) => {
  const r = e.request;
  if (r.cache === 'only-if-cached' && r.mode !== 'same-origin') return;
  e.respondWith(fetch(r).then((res) => {
    if (res.status === 0) return res;
    const h = new Headers(res.headers);
    h.set('Cross-Origin-Opener-Policy', 'same-origin');
    h.set('Cross-Origin-Embedder-Policy', 'credentialless');
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
  }));
});
