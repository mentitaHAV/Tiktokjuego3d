// Puente TikTok LIVE -> Casa de Sobrevivientes.
//   node tiktok.js              conecta con el directo de config.json ("tiktok")
//   node tiktok.js otro_usuario conecta con ese usuario
//   node tiktok.js --simular    escribe eventos falsos (para probar sin estar en directo)
//   --debug                     imprime cada evento recibido
// Escribe una linea JSON por evento en eventos.jsonl, que el juego lee cada medio segundo:
//   {"usuario":"juanito","regalo":"like","cantidad":12}                  12 likes  -> 12 zombis
//   {"usuario":"ana","regalo":"Rose","cantidad":1,"monedas":1}           1 moneda  -> 5 zombis
//   {"usuario":"pepe","regalo":"Lion","cantidad":1,"monedas":29999}      cada moneda -> 5 zombis
//   {"usuario":"luis","regalo":"GG","cantidad":1,"monedas":1}            GG        -> persona / suministros
// El puente solo informa de lo que paso; las reglas (x1 like, x5 moneda...) viven en scripts/sim.gd.
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const DEBUG = args.includes('--debug');
const SIMULAR = args.includes('--simular');
const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
const USER = ((args.find((a) => !a.startsWith('--')) || cfg.tiktok || '') + '').replace(/^@/, '');
const FILE = path.resolve(__dirname, cfg.eventos || '../eventos.jsonl');

// Se empieza con el archivo vacio: lo que quedo de otro directo no se repite.
fs.writeFileSync(FILE, '');
const emit = (o) => {
  fs.appendFileSync(FILE, JSON.stringify(o) + '\n');
  console.log(new Date().toLocaleTimeString(), JSON.stringify(o));
};

if (SIMULAR) {
  console.log('MODO SIMULACION: escribiendo eventos falsos en ' + FILE + '  (Ctrl+C para parar)');
  const nombres = ['ana', 'luis', 'marta', 'pepe', 'sofi', 'rafa', 'lola'];
  const regalos = [['Rose', 1], ['Heart Me', 1], ['TikTok', 1], ['Finger Heart', 5], ['Doughnut', 30]];
  setInterval(() => {
    const u = nombres[Math.floor(Math.random() * nombres.length)];
    const r = Math.random();
    if (r < 0.7) emit({ usuario: u, regalo: 'like', cantidad: 1 + Math.floor(Math.random() * 12) });
    else if (r < 0.9) { const g = regalos[Math.floor(Math.random() * regalos.length)]; emit({ usuario: u, regalo: g[0], cantidad: 1, monedas: g[1] }); }
    else emit({ usuario: u, regalo: 'GG', cantidad: 1, monedas: 1 });
  }, 1500);
  return;
}

if (!USER) { console.error('Falta el usuario de TikTok (config.json o argumento).'); process.exit(1); }
const { TikTokLiveConnection, WebcastEvent, ControlEvent } = require('tiktok-live-connector');
const conn = new TikTokLiveConnection(USER, {});
const on = (ev, fn) => conn.on(ev, (d) => { if (DEBUG) console.log(ev, JSON.stringify(d, (k, v) => (typeof v === 'bigint' ? String(v) : v)).slice(0, 400)); try { fn(d); } catch (e) { console.error(e); } });
// Usuario estable y legible (handle de TikTok); el apodo suele traer emojis que el juego no dibuja.
const who = (d) => { const u = d.user || d; return String(u.uniqueId || u.nickname || u.userId || 'anonimo'); };

// TikTok NO manda un mensaje por cada toque de like y a veces ni trae el total. Se combinan los eventos con
// el contador de likes de la sala (cada 2 s) y se emiten siempre los likes que faltan para igualar el total.
const findNum = (o, re, depth = 0, p = '') => {
  if (!o || typeof o !== 'object' || depth > 4) return null;
  for (const k of Object.keys(o)) { const v = o[k]; if (typeof v === 'number' && re.test(k) && v > 0) return { path: p + k, v }; }
  for (const k of Object.keys(o)) { const r = findNum(o[k], re, depth + 1, p + k + '.'); if (r) return r; }
  return null;
};
let base = null, emitted = 0, ultimo = 'publico', pollKey = '';
const sync = (T, from) => {
  if (!T) return;
  if (base === null) { base = T - emitted; return; }
  const debe = (T - base) - emitted;
  if (debe > 0) { emitted += debe; emit({ usuario: ultimo, regalo: 'like', cantidad: debe }); }
};
on(WebcastEvent.LIKE, (d) => {
  const u = who(d); if (u !== 'anonimo') ultimo = u;
  const n = Number(d.count) || Number(d.likeCount) || 1;
  emitted += n; emit({ usuario: u, regalo: 'like', cantidad: n });
  sync(Number(d.total) || Number(d.totalLikeCount) || 0, 'evento');
});
setInterval(async () => {
  try {
    const info = await conn.fetchRoomInfo();
    const r = findNum(info, /^(like.?count|likes?|total.?like.?count)$/i);
    if (r) { if (!pollKey) { pollKey = r.path; console.log('contador de likes de la sala: ' + r.path); } sync(r.v, 'sala'); }
  } catch (e) { /* aun sin conexion */ }
}, 2000);

on(WebcastEvent.GIFT, (d) => {
  if (d.giftType === 1 && d.repeatEnd === false) return; // en una racha solo cuenta al terminar
  const g = d.giftDetails || d.gift || {};
  const rep = Number(d.repeatCount) || 1;
  const monedas = Math.max(1, Number(d.diamondCount || g.diamondCount || 1) * rep);
  emit({ usuario: who(d), regalo: d.giftName || g.giftName || g.name || 'Regalo', cantidad: rep, monedas });
});

conn.on(ControlEvent.CONNECTED, () => console.log('Conectado al directo de @' + USER));
conn.on(ControlEvent.DISCONNECTED, () => { console.log('Desconectado, reintento en 5 s'); setTimeout(connect, 5000); });
conn.on(ControlEvent.ERROR, (e) => console.error('Error:', e && e.message ? e.message : e));
const connect = () => conn.connect().catch((e) => {
  console.error('No se pudo conectar (¿estas en directo? ¿usuario bien escrito?):', e.message || e);
  setTimeout(connect, 10000);
});
connect();
console.log('Esperando el directo de @' + USER + ' ...  eventos -> ' + FILE);
