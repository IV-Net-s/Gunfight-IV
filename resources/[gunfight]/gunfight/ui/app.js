const $ = (id) => document.getElementById(id);

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function row(cells, className) {
  const tr = el("tr", className);
  for (const cell of cells) {
    const td = el("td", cell && cell.className, cell && typeof cell === "object" ? cell.text : cell);
    if (cell && cell.color) td.style.color = cell.color;
    tr.appendChild(td);
  }
  return tr;
}

const clock = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

/* Son des touches, sans fichier : un clic court */
let audio;
function tick(frequency, length) {
  try {
    audio = audio || new AudioContext();
    const osc = audio.createOscillator();
    const gain = audio.createGain();
    osc.frequency.value = frequency;
    gain.gain.setValueAtTime(0.12, audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + length);
    osc.connect(gain).connect(audio.destination);
    osc.start();
    osc.stop(audio.currentTime + length);
  } catch (_) {}
}

/* HUD du match */
function roster(target, team, you) {
  target.replaceChildren();
  for (const p of team.players) {
    const pill = el("div", "pill" + (p.alive ? "" : " dead") + (you && you.id === p.id ? " you" : ""));
    pill.appendChild(el("div", null, `${p.name}${p.kills ? "  ·  " + p.kills : ""}`));
    const hp = el("div", "hp");
    const fill = el("div");
    fill.style.width = `${Math.round(p.hp * 100)}%`;
    fill.style.background = team.color;
    hp.appendChild(fill);
    pill.appendChild(hp);
    target.appendChild(pill);
  }
}

axora.on("match", (m) => {
  $("hud").hidden = !m.show;
  if (!m.show) {
    $("board").hidden = true;
    $("results").hidden = true;
    return;
  }
  const [a, b] = m.teams;
  document.documentElement.style.setProperty("--a", a.color);
  document.documentElement.style.setProperty("--b", b.color);
  $("name-a").textContent = a.name;
  $("name-b").textContent = b.name;
  $("score-a").textContent = a.score;
  $("score-b").textContent = b.score;
  const timer = $("timer");
  timer.textContent = clock(m.remaining);
  timer.className = "timer" + (m.phase === "overtime" ? " overtime" : m.phase === "live" && m.remaining <= 10 ? " low" : "");
  const phase = { countdown: "Preparation", live: `Manche ${m.round}`, overtime: "Prolongation", round_end: "Fin de manche", results: "Fin du match" };
  $("round").textContent = `${phase[m.phase] || ""} · ${m.mode} · ${m.arena}`;
  $("loadout").textContent = m.loadout;
  roster($("roster-a"), a, m.you);
  roster($("roster-b"), b, m.you);
  const flag = $("flag");
  flag.hidden = !m.flag;
  if (m.flag) {
    const owner = m.flag.team ? m.teams[m.flag.team - 1] : null;
    $("flag-label").textContent = m.flag.contested ? "Drapeau conteste" : owner ? `${owner.name} capture` : "Drapeau au centre";
    $("flag-fill").style.width = `${Math.round((m.flag.ratio || 0) * 100)}%`;
    $("flag-fill").style.background = owner ? owner.color : "var(--accent)";
  }
});

axora.on("kill", (k) => {
  const line = el("div", "kill");
  if (k.killer) {
    const killer = el("span", null, k.killer);
    killer.style.color = k.killer_color;
    line.appendChild(killer);
  }
  line.appendChild(el("span", "weapon", k.weapon ? `[${k.weapon}]` : "✕"));
  const victim = el("span", null, k.victim);
  victim.style.color = k.victim_color;
  line.appendChild(victim);
  if (k.headshot) line.appendChild(el("span", "hs", "HEADSHOT"));
  const feed = $("feed");
  feed.prepend(line);
  while (feed.children.length > 6) feed.lastChild.remove();
  setTimeout(() => line.remove(), 7000);
});

axora.on("feed", (f) => {
  const line = el("div", "kill", f.text);
  $("feed").prepend(line);
  setTimeout(() => line.remove(), 6000);
});

let bannerTimer;
axora.on("banner", (b) => {
  const banner = $("banner");
  $("banner-title").textContent = b.title;
  $("banner-title").style.color = b.color;
  $("banner-sub").textContent = b.subtitle;
  banner.hidden = false;
  banner.style.animation = "none";
  void banner.offsetWidth;
  banner.style.animation = "";
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => (banner.hidden = true), b.ms);
});

let warningTimer;
axora.on("warning", (w) => {
  const warning = $("warning");
  warning.textContent = w.text;
  warning.hidden = !w.text;
  clearTimeout(warningTimer);
  if (w.text && w.ms) warningTimer = setTimeout(() => (warning.textContent = "Tu perds de la vie !"), w.ms);
});

axora.on("hit", (h) => {
  const marker = $("hitmarker");
  marker.className = "";
  void marker.offsetWidth;
  marker.className = "show" + (h.kill ? " kill" : h.headshot ? " head" : "");
  tick(h.kill ? 520 : h.headshot ? 1400 : 1000, h.kill ? 0.25 : 0.06);
});

let hurtTimer;
axora.on("hurt", (h) => {
  const vignette = $("vignette");
  vignette.style.opacity = Math.min(1, 0.35 + h.amount / 60);
  clearTimeout(hurtTimer);
  hurtTimer = setTimeout(() => (vignette.style.opacity = 0), 250);
});

axora.on("board", (b) => {
  $("board").hidden = !b.show;
  if (!b.show) return;
  const body = $("board-rows");
  body.replaceChildren();
  let team = 0;
  for (const r of b.rows) {
    if (r.team !== team) {
      team = r.team;
      body.appendChild(row([{ text: b.teams[team - 1], color: b.colors[team - 1] }, "", "", "", "", "", ""], "sep"));
    }
    body.appendChild(row([{ text: r.name + (r.alive ? "" : "  ✕"), color: r.alive ? null : "#777" }, r.kills, r.deaths, r.damage, r.headshots, r.elo, r.ping]));
  }
});

axora.on("results", (r) => {
  $("board").hidden = true;
  $("results").hidden = false;
  $("results-title").textContent = r.winner ? `${r.winner} gagne` : "Match nul";
  $("results-title").style.color = r.color;
  $("results-score").textContent = `${r.score[0]} - ${r.score[1]}`;
  $("results-mvp").textContent = (r.mvp ? `MVP : ${r.mvp}` : "") + (r.reason ? `  ·  ${r.reason}` : "");
  const body = $("results-rows");
  body.replaceChildren();
  for (const p of r.rows.sort((x, y) => x.team - y.team || y.kills - x.kills)) {
    const change = p.elo_change > 0 ? `+${p.elo_change}` : `${p.elo_change}`;
    body.appendChild(row([p.name, p.kills, p.deaths, p.damage, p.headshots,
      { text: `${p.elo} (${change})`, className: p.elo_change > 0 ? "up" : p.elo_change < 0 ? "down" : "" }]));
  }
  setTimeout(() => ($("results").hidden = true), r.ms);
});

/* Menu du lobby */
function showTab(name) {
  for (const button of document.querySelectorAll("#tabs button")) button.classList.toggle("active", button.dataset.tab === name);
  for (const tab of document.querySelectorAll(".tab")) tab.hidden = tab.id !== `tab-${name}`;
}
for (const button of document.querySelectorAll("#tabs button")) button.onclick = () => showTab(button.dataset.tab);

function renderLobby(v) {
  $("lobby").hidden = false;
  $("lobby-player").textContent = `${v.player} · Elo ${v.stats.elo}`;

  const modes = $("modes");
  modes.replaceChildren();
  for (const key of ["1v1", "2v2", "3v3", "4v4"]) {
    const q = v.queues[key];
    if (!q) continue;
    const card = el("div", "mode" + (v.queued === key ? " queued" : ""));
    card.appendChild(el("strong", null, q.label));
    card.appendChild(el("span", null, `${q.queued} / ${q.needed} en file`));
    const button = el("button", v.queued === key ? "leave" : null, v.queued === key ? "Quitter" : "Rejoindre");
    button.onclick = () => (v.queued === key ? call("leave_queue") : call("queue", { mode: key }));
    card.appendChild(button);
    modes.appendChild(card);
  }

  const live = $("live");
  live.replaceChildren();
  if (!v.matches.length) live.appendChild(el("p", "empty", "Aucun match en cours."));
  for (const m of v.matches) {
    const line = el("div", "live");
    line.appendChild(el("span", null, `#${m.id} · ${m.mode} · ${m.arena}`));
    line.appendChild(el("b", null, `${m.teams[0]} ${m.score[0]} - ${m.score[1]} ${m.teams[1]} · manche ${m.round}`));
    live.appendChild(line);
  }

  const me = $("me");
  me.replaceChildren();
  const s = v.stats;
  for (const [label, value] of [["Elo", s.elo], ["K/D", s.kd], ["Kills", s.kills], ["Morts", s.deaths],
    ["Headshots", s.headshots], ["Victoires", s.wins], ["Defaites", s.losses], ["Serie max", s.best_streak]]) {
    const stat = el("div", "stat");
    stat.appendChild(el("b", null, value));
    stat.appendChild(el("span", null, label));
    me.appendChild(stat);
  }

  const top = $("top-rows");
  top.replaceChildren();
  for (const r of v.top) top.appendChild(row([r.rank, r.name, r.elo, r.kd, r.wins, r.matches]));
  renderTraining(v.training);
}

function message(text, ok) {
  for (const id of ["lobby-message", "train-message"]) {
    $(id).textContent = text;
    $(id).style.color = ok ? "var(--good)" : "var(--bad)";
  }
}

async function call(name, data) {
  try {
    const answer = await axora.post(name, data || {});
    if (answer && answer.view) renderLobby(answer.view);
    if (answer && answer.message) message(answer.message, answer.ok);
    if (answer && answer.ok && name === "train") $("lobby").hidden = true;
  } catch (error) {
    message(error.message, false);
  }
}

/* Entrainement */
const trainChoice = { level: "facile", challenge: false, loadout: 0, arena: "" };

function chips(target, items, selected, pick) {
  target.replaceChildren();
  for (const item of items) {
    const chip = el("button", "chip" + (item.value === selected ? " selected" : ""), item.label);
    chip.onclick = () => pick(item.value);
    target.appendChild(chip);
  }
}

function renderTraining(t) {
  if (!t) return;
  const rerender = () => renderTraining(t);
  const levels = $("train-levels");
  levels.replaceChildren();
  for (const level of t.levels) {
    const card = el("button", "level" + (trainChoice.level === level.key ? " selected" : ""));
    card.appendChild(el("strong", null, level.label));
    card.appendChild(el("span", null, level.description));
    card.appendChild(el("em", null, `Record : ${t.records[level.key] || 0}`));
    card.onclick = () => { trainChoice.level = level.key; rerender(); };
    levels.appendChild(card);
  }
  chips($("train-modes"), [{ value: false, label: "Libre" }, { value: true, label: `Defi ${t.challenge_time} s` }], trainChoice.challenge,
    (value) => { trainChoice.challenge = value; rerender(); });
  chips($("train-arenas"), [{ value: "", label: "Au hasard" }, ...t.arenas.map((name) => ({ value: name, label: name }))], trainChoice.arena,
    (value) => { trainChoice.arena = value; rerender(); });
  chips($("train-loadouts"), [{ value: 0, label: "Toutes les armes" }, ...t.loadouts.map((l) => ({ value: l.index, label: l.name }))],
    trainChoice.loadout, (value) => { trainChoice.loadout = value; rerender(); });
  $("train-stop").hidden = !t.active;
  $("train-start").textContent = t.active ? "Relancer avec ces reglages" : "Lancer l'entrainement";
}

$("train-start").onclick = () => call("train", trainChoice);
$("train-stop").onclick = () => call("train_stop");

let trainingActive = false;
axora.on("training", (t) => {
  $("training-hud").hidden = !t.show;
  if (!t.show) {
    trainingActive = false;
    return;
  }
  if (!trainingActive) $("lobby").hidden = true;
  trainingActive = true;
  $("train-level").textContent = `${t.level} · ${t.loadout} · ${t.arena}`;
  const clock = $("train-clock");
  const seconds = t.challenge ? t.remaining : t.elapsed;
  clock.textContent = t.finished ? "termine" : clock_text(seconds);
  clock.className = "clock" + (t.challenge && !t.finished && t.remaining <= 10 ? " low" : "");
  $("train-kills").textContent = t.kills;
  $("train-heads").textContent = t.headshots;
  $("train-acc").textContent = `${t.accuracy} %`;
  $("train-best").textContent = t.best;
  $("train-hint").textContent = t.finished ? "Defi termine : /gf pour relancer · /train stop pour arreter"
    : `${t.shots} tirs, ${t.hits} touches, ${t.deaths} mort(s) · /gf pour changer · /train stop pour arreter`;
});

function clock_text(seconds) {
  return clock(Math.max(0, seconds || 0));
}

axora.on("lobby", (v) => {
  if (!v.open) return ($("lobby").hidden = true);
  renderLobby(v);
});

function closeLobby() {
  if ($("lobby").hidden) return;
  $("lobby").hidden = true;
  axora.post("close").catch(() => {});
}
$("lobby-close").onclick = closeLobby;
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeLobby();
});
