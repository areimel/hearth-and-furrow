"use strict";
(function () {
  var FPS = 30, TOTAL = 640;
  var COUNTS = Object.assign({ storm: 90, plants: 90, wheat: 60, village: 90, herd: 70, night: 90 }, window.CLIP_COUNTS || {});
  var PHCOL = { storm: "#3d4a5a", plants: "#5d8a3a", wheat: "#a88a3a", village: "#6b4423", herd: "#4f7a4a", night: "#1c2a44",
    title: "#6f9bb8", thresh: "#5d8a3a", quern: "#4f7a4a", oven: "#6b4423", alewife: "#5d8a3a", mayday: "#8a3a1c", shop: "#8f6234" };
  var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };
  var prog = function (f, a, b) { return clamp((f - a) / (b - a), 0, 1); };
  var easeOut = function (t) { return 1 - Math.pow(1 - t, 3); };
  var easeIO = function (t) { return t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
  var backOut = function (t) { var c = 1.9; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };
  var pad = function (n) { return ("000" + n).slice(-4); };
  var $ = function (id) { return document.getElementById(id); };

  // ---- media: wrapper with placeholder + img ----
  var medias = [];
  function mkMedia(parent, label, w, h, cls) {
    var d = document.createElement("div"); d.className = "media" + (cls ? " " + cls : "");
    d.style.width = w + "px"; d.style.height = h + "px";
    var ph = document.createElement("div"); ph.className = "ph"; ph.style.background = PHCOL[label] || "#555";
    var t = document.createElement("div"); t.textContent = label; var s = document.createElement("div"); ph.appendChild(t); ph.appendChild(s);
    var img = document.createElement("img"); img.alt = ""; img.style.display = "none";
    d.appendChild(ph); d.appendChild(img); parent.appendChild(d);
    var m = { el: d, img: img, ph: ph, sub: s, src: null, ok: false, label: label };
    medias.push(m); return m;
  }
  var pending = [];
  function load(m, src, tag) {
    m.sub.textContent = tag || "";
    if (m.src === src) { return; }
    m.src = src; m.ok = false;
    var img = m.img;
    img.src = src;
  }
  function track(m) {
    var src = m.src;
    return m.img.decode().then(function () { if (m.src === src) { m.img.style.display = "block"; m.ph.style.display = "none"; } },
      function () { if (m.src === src) { m.img.style.display = "none"; m.ph.style.display = "flex"; } });
  }
  function clipFrame(name, local) {
    var n = COUNTS[name] || 1; return clamp(Math.floor(local), 0, n - 1) + 1; // hold last frame
  }

  // ---- DOM ----
  var S = {};
  function scene(id) { var d = document.createElement("div"); d.className = "scene"; d.style.display = "none"; document.body.appendChild(d); S[id] = d; return d; }
  var M = {};
  function build() {
    ["hook", "turn", "reveal", "craft", "village", "alewife", "mayday", "herd", "shop", "outro"].forEach(scene);
    M.storm = mkMedia(S.hook, "storm", 1920, 1080); M.grade = document.createElement("div"); M.grade.id = "grade"; S.hook.appendChild(M.grade); M.plants = mkMedia(S.turn, "plants", 1920, 1080);
    M.title = mkMedia(S.reveal, "plants", 1920, 1080);
    M.shade = document.createElement("div"); M.shade.id = "shade"; S.reveal.appendChild(M.shade);
    M.wheat = mkMedia(S.craft, "wheat", 1920, 1080);
    M.village = mkMedia(S.village, "village", 1920, 1080);
    M.alewife = mkMedia(S.alewife, "alewife", 1920, 1080);
    M.mayday = mkMedia(S.mayday, "mayday", 1600, 900, "framed");
    M.herd = mkMedia(S.herd, "herd", 1600, 900, "framed");
    M.shop = mkMedia(S.shop, "shop", 1600, 900, "framed");
    M.night = mkMedia(S.outro, "plants", 1920, 1080);
    // cards
    M.cards = ["thresh", "quern", "oven"].map(function (n, i) {
      var c = document.createElement("div"); c.className = "card"; c.style.width = "1008px"; c.style.height = "588px";
      var inn = document.createElement("div"); inn.className = "in"; c.appendChild(inn);
      var m = mkMedia(inn, n, 960, 540); S.craft.appendChild(c); m.card = c; m.x = 24 + i * 432; m.y = 24 + i * 84; m.t0 = 280 + i * 20; return m;
    });
    // hook text
    var full = "A storm is coming…";
    M.hook = plaque(S.hook, "", 0); M.hook.style.left = "0"; M.hook.style.width = "1920px"; M.hook.style.background = "none"; M.hook.style.border = "0"; M.hook.style.boxShadow = "none"; M.hook.style.padding = "0";
    M.hookInner = document.createElement("div"); M.hookInner.className = "plaque"; M.hookInner.style.position = "relative"; M.hookInner.style.display = "inline-block";
    M.hookT = document.createElement("span"); M.hookR = document.createElement("span"); M.hookR.className = "hide";
    M.hookInner.appendChild(M.hookT); M.hookInner.appendChild(M.hookR); M.hook.appendChild(M.hookInner); M.hook.style.top = "810px"; M.hookFull = full;
    // turn text
    M.relax = plaque(S.turn, "Relax.", 0, "big"); M.relax.style.top = "560px";
    M.relax2 = plaque(S.turn, "Nothing here can kill your farm.", 0); M.relax2.style.top = "820px";
    // reveal
    M.logo = plaque(S.reveal, "Hearth & Furrow", 0, "logo"); M.logo.style.top = "336px";
    M.tag = plaque(S.reveal, "A cozy Tudor farming sim · c.1530", 0); M.tag.style.top = "600px";
    // craft caption
    M.cap4 = plaque(S.craft, "", 0); M.cap4.style.top = "828px";
    M.cap4g = ["Sow it.", "Thresh it.", "Grind it.", "Bake it."].map(function (t, i) {
      var s = document.createElement("span"); s.textContent = t; s.style.marginLeft = i ? "27px" : "0"; M.cap4.appendChild(s); return s;
    });
    M.cap4starts = [240, 280, 300, 320];
    // global captions
    M.caps = [
      { text: "Six neighbours on daily schedules", a: 368, b: 374, top: 36, dx: -180, host: "village", end: 440 },
      { text: "Keep the feast days.", a: 440, b: 443, bottom: 24, end: 480 },
      { text: "Bread, butter, cheese, ale, linen.", a: 480, b: 488, bottom: 24, end: 560 }
    ];
    M.capEl = document.createElement("div"); M.capEl.className = "plaque"; M.capEl.style.zIndex = "30"; document.body.appendChild(M.capEl);
    // outro
    var p = document.createElement("div"); p.className = "panel"; p.style.left = "360px"; p.style.top = "300px"; p.style.width = "1200px";
    p.innerHTML = '<div class="in"><div style="font-size:108px;line-height:108px;color:var(--wood-dark)">Hearth &amp; Furrow</div><div style="font-size:54px;line-height:54px;color:var(--wood)">In development · Godot 4.6</div></div>';
    S.outro.appendChild(p); M.panel = p;
    M.dip = $("dip") || (function () { var d = document.createElement("div"); d.id = "dip"; document.body.appendChild(d); return d; })();
    M.band = document.createElement("div"); M.band.id = "band"; M.band.style.display = "none"; document.body.appendChild(M.band);
  }
  function plaque(parent, text, _x, cls) {
    var d = document.createElement("div"); d.className = "plaque" + (cls ? " " + cls : ""); d.textContent = text; d.style.left = "0"; d.style.right = "0"; d.style.margin = "0 auto"; d.style.width = "fit-content";
    parent.appendChild(d); return d;
  }
  function tf(el, x, y, s) { el.style.transform = "translate(" + Math.round(x) + "px," + Math.round(y) + "px) scale(" + s + ")"; }

  // ---- seek ----
  window.seek = async function (f) {
    f = clamp(Math.round(f), 0, TOTAL - 1);
    if (!M.dip) build();
    var vis = {}, active = [];
    var show = function (id) { vis[id] = true; };
    // scene selection (wipe at 360-370 keeps craft underneath)
    var sc;
    if (f < 80) sc = "hook"; else if (f < 160) sc = "turn"; else if (f < 240) sc = "reveal"; else if (f < 360) sc = "craft";
    else if (f < 400) sc = "village"; else if (f < 440) sc = "alewife"; else if (f < 480) sc = "mayday";
    else if (f < 520) sc = "herd"; else if (f < 560) sc = "shop"; else sc = "outro";
    show(sc);
    var wipe = f >= 360 && f < 370;
    if (wipe) show("craft");
    Object.keys(S).forEach(function (k) { S[k].style.display = vis[k] ? "block" : "none"; S[k].style.zIndex = k === "village" && wipe ? 5 : 1; S[k].style.clipPath = "none"; });
    M.band.style.display = "none";
    if (wipe) {
      var x = Math.round((1 - easeIO(prog(f, 360, 370))) * 1980 / 6) * 6; // leading edge moves right-to-left
      S.village.style.clipPath = "inset(0 0 0 " + x + "px)";
      M.band.style.display = "block"; M.band.style.left = (x - 60) + "px";
    }
    var use = function (m, src, tag) { load(m, src, tag); active.push(m); };
    var clip = function (m, name, local) { var n = clipFrame(name, local); use(m, "clips/" + name + "/" + pad(n) + ".png", "frame " + n); };
    var still = function (m, name) { use(m, "stills/" + name + ".png", ""); };

    // 1 hook
    if (sc === "hook") {
      clip(M.storm, "storm", f);
      tf(M.storm.el, 0, 0, 1 + 0.05 * (f / 80));
      var n = clamp(f - 4, 0, M.hookFull.length);
      M.hookT.textContent = M.hookFull.slice(0, n); M.hookR.textContent = M.hookFull.slice(n);
      M.hookInner.style.display = f >= 3 ? "inline-block" : "none";
    }
    // 2 turn
    if (sc === "turn") {
      clip(M.plants, "plants", f - 80);
      var t = prog(f, 80, 88); tf(M.relax, 0, 0, 0.5 + 0.5 * backOut(t));
      var t2 = prog(f, 84, 90); M.relax2.style.display = f >= 84 ? "block" : "none"; tf(M.relax2, 0, (1 - easeOut(t2)) * 30, 1);
    }
    // 3 reveal
    if (sc === "reveal") {
      clip(M.title, "plants", f - 80);
      tf(M.title.el, 0, 0, 1.06 + 0.04 * (1 - easeOut(prog(f, 160, 200))));
      M.shade.style.opacity = "0.45"; M.title.el.style.filter = "blur(6px)";
      var tl = prog(f, 164, 170); M.logo.style.display = f >= 164 ? "block" : "none"; tf(M.logo, 0, 0, 0.8 + 0.2 * backOut(tl));
      var tg = prog(f, 172, 180); M.tag.style.display = f >= 172 ? "block" : "none"; tf(M.tag, 0, (1 - easeOut(tg)) * 40, 1);
      var ex = prog(f, 233, 239); M.logo.style.opacity = M.tag.style.opacity = String(1 - ex);
    }
    // 4 craft (also underneath the wipe)
    if (sc === "craft" || wipe) {
      clip(M.wheat, "wheat", f - 240); M.wheat.el.style.filter = "brightness(" + (1 - 0.45 * easeOut(prog(f, 280, 288))) + ")";
      M.cards.forEach(function (m) {
        var t = easeOut(prog(f, m.t0, m.t0 + 8)); m.card.style.display = f >= m.t0 ? "block" : "none";
        m.card.style.left = m.x + "px"; m.card.style.top = Math.round(m.y + (1 - t) * 1000) + "px"; still(m, m.label);
      });
      M.cap4starts.forEach(function (s, i) { M.cap4g[i].style.display = f >= s ? "inline" : "none"; });
      M.cap4.style.display = f >= 240 ? "block" : "none";
      var ce = easeIO(prog(f, 354, 360)), cin = easeOut(prog(f, 240, 244));
      tf(M.cap4, 0, (1 - cin) * 12, 1); M.cap4.style.opacity = String(cin * (1 - ce));
    }
    // 5-7 stills and clips
    if (sc === "village") clip(M.village, "village", f - 360);
    if (wipe) clip(M.village, "village", f - 360);
    if (sc === "alewife") still(M.alewife, "alewife");
    if (sc === "mayday") still(M.mayday, "mayday");
    if (sc === "herd") clip(M.herd, "herd", f - 480);
    if (sc === "shop") still(M.shop, "shop");
    // global captions
    var cap = null;
    M.caps.forEach(function (c) { if (f >= c.a && f < c.end) cap = c; });
    if (cap) {
      var ti = easeOut(prog(f, cap.a, cap.b));
      M.capEl.style.display = "block"; M.capEl.textContent = cap.text;
      M.capEl.style.left = "0"; M.capEl.style.right = "0"; M.capEl.style.margin = "0 auto"; M.capEl.style.width = "fit-content";
      M.capEl.style.top = cap.top !== undefined ? cap.top + "px" : "auto"; M.capEl.style.bottom = cap.bottom !== undefined ? cap.bottom + "px" : "auto";
      tf(M.capEl, cap.dx || 0, (1 - ti) * (cap.top !== undefined ? -12 : 12), 1); M.capEl.style.opacity = String(ti);
    } else M.capEl.style.display = "none";
    // 8 outro
    if (sc === "outro") {
      clip(M.night, "plants", f - 560); tf(M.night.el, 0, 0, 1 + 0.03 * prog(f, 560, 640)); M.night.el.style.filter = "brightness(0.8)";
      var po = easeIO(prog(f, 560, 572)); tf(M.panel, 0, 0, 0.9 + 0.1 * po);
      M.panel.style.left = "360px"; M.panel.style.top = "300px"; M.panel.style.transformOrigin = "50% 50%";
    }
    // dip through wood-dark 154-166
    var d = f < 160 ? prog(f, 154, 160) : 1 - prog(f, 160, 166);
    M.dip.style.opacity = (f >= 154 && f <= 166) ? d : 0; M.dip.style.display = (f >= 154 && f <= 166) ? "block" : "none";
    M.dip.style.zIndex = 50;

    await document.fonts.ready;
    active = active.filter(function (m) { return m.el.offsetParent !== null || m.card; });
    await Promise.all(active.map(track));
    await new Promise(function (r) { requestAnimationFrame(function () { requestAnimationFrame(r); }); });
    return f;
  };

  // ---- dev mode ----
  var q = new URLSearchParams(location.search);
  function boot() {
    if (!document.body) return;
    window.seek(q.has("f") ? parseInt(q.get("f"), 10) : 0).then(function () {
      if (q.has("play")) {
        var t0 = performance.now(), busy = false;
        (function tick(now) {
          var f = Math.floor((now - t0) / (1000 / FPS)) % TOTAL;
          if (!busy) { busy = true; window.seek(f).then(function () { busy = false; }); }
          requestAnimationFrame(tick);
        })(t0);
      }
    });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();
  window.__TOTAL = TOTAL;
})();
