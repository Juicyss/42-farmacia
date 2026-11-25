// app.js — La interfaz SOLO pregunta al gemelo (Prolog) y muestra lo que responde.
// No hay umbrales, reglas ni decisiones aquí: todo viene de /api/* (reglas.pl).
'use strict';

const $ = (s, r = document) => r.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const api = async (url) => {
  const r = await fetch(url);
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error || r.statusText);
  return j;
};

const ESTADO_LOTE = {
  disponible: ['ok', 'Disponible'], por_caducar: ['info', 'Caduca pronto'], vencido: ['bad', 'Vencido'],
  retirado: ['bad', 'Retirado'], agotado: ['mute', 'Agotado'],
};
const VEREDICTO = { surtir: 'SURTIR', surtir_parcial: 'SURTIR PARCIAL', rechazar: 'RECHAZAR', suspender: 'SUSPENDER · NO SE SABE' };
const TIPO = {
  decision: 'Decisión', bloqueo: 'Bloquea', duda: 'No se sabe', dilema: 'Dilema', contraintuitivo: 'Contra la intuición',
  lote: 'Lotes', advertencia: 'Advertencia', apoyo: 'Evidencia',
};
const ORDEN = ['decision', 'bloqueo', 'duda', 'dilema', 'contraintuitivo', 'lote', 'advertencia'];

const st = { escenarios: [], esc: null, hip: 'ninguna', alt: 1 };

// ------------------------------------------------------------- arranque
async function init() {
  document.querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => show(t.dataset.view)));
  const [estado, escenarios] = await Promise.all([api('/api/estado'), api('/api/escenarios')]);
  pintarEstado(estado);
  st.escenarios = escenarios;
  pintarEscenarios();
  const inicial = new URLSearchParams(location.search).get('escenario') || 's31';
  elegir(inicial);
  $('#formSit').addEventListener('submit', e => { e.preventDefault(); consultar(); });
}

function show(view) {
  document.querySelectorAll('.tab').forEach(t => t.setAttribute('aria-selected', t.dataset.view === view));
  document.querySelectorAll('.view').forEach(v => (v.hidden = v.id !== 'view-' + view));
  if (view === 'existencias' && !$('#lotes').dataset.ok) cargarLotes();
  if (view === 'recetas' && !$('#recetas').dataset.ok) cargarRecetas();
  if (view === 'retiro' && !$('#retiro').dataset.ok) cargarRetiro('l_omep_a');
  if (view === 'consultas' && !$('#sitRes').dataset.ok) consultar();
  window.scrollTo({ top: 0 });
}

function pintarEstado(e) {
  const py = e.python === 'janus' ? ['ok', 'Python vía Janus'] : e.python === 'proceso' ? ['info', 'Python vía proceso'] : ['mute', 'Python no disponible'];
  $('#topPills').innerHTML = `<span class="pill ok"><span class="dot"></span>Día ${e.ahora} del modelo</span>
    <span class="pill ${py[0]}">${py[1]}</span>
    <button class="theme-btn" id="tema" aria-label="Cambiar tema claro/oscuro">${document.documentElement.dataset.tema === 'oscuro' ? '☀️ Claro' : '🌙 Oscuro'}</button>`;
  $('#tema').onclick = () => {
    const t = document.documentElement.dataset.tema === 'oscuro' ? 'claro' : 'oscuro';
    document.documentElement.dataset.tema = t; localStorage.setItem('tema42', t);
    $('#tema').textContent = t === 'oscuro' ? '☀️ Claro' : '🌙 Oscuro';
  };
  const sin = e.sucursales.filter(s => s.sin_reporte);
  $('#banner').innerHTML = sin.map(s => `<div class="banner" role="status"><span>⚠️</span><div><b>${esc(s.nombre)} no reporta desde el día ${s.ultimo_reporte}.</b>
    Lo que pudo pasar ahí cuenta como <b>«no se sabe»</b>, nunca como «no».</div></div>`).join('');
  const k = e.indicadores;
  const tiles = [
    ['bad', k.vencidos, 'Lotes vencidos'], ['bad', k.retirados, 'Lotes retirados'], ['info', k.por_caducar, `Caducan en ≤ ${e.caducidad_cercana} días`],
    ['ok', k.recetas_abiertas, 'Recetas abiertas'], ['info', k.recetas_dudosas, 'Recetas «no se sabe»'], ['warn', k.ventas_sin_rastro, 'Ventas sin rastro'],
  ];
  $('#kpis').innerHTML = tiles.map(([c, n, l]) => `<div class="kpi ${c}"><div class="n">${n}</div><div class="l">${l}</div></div>`).join('');
}

// ------------------------------------------------------------- situaciones
const NOMBRE_SIT = {
  1: '1 · La receta que parece buena', 2: '2 · Medio tratamiento hoy', 3: '3 · El último blíster',
  4: '4 · El lote retirado', 5: '5 · Con receta, pero no para esta persona',
};

function pintarEscenarios() {
  let h = '', g = 0;
  for (const e of st.escenarios) {
    if (e.situacion !== g) { g = e.situacion; h += `<div class="esc-group">Situación ${esc(NOMBRE_SIT[g])}</div>`; }
    h += `<button class="esc" data-id="${e.id}" aria-current="${st.esc === e.id}"><b>${esc(e.titulo)}</b><small>${esc(e.id)}</small></button>`;
  }
  $('#escenarios').innerHTML = h;
  document.querySelectorAll('.esc').forEach(b => b.addEventListener('click', () => elegir(b.dataset.id)));
}

function elegir(id) {
  const e = st.escenarios.find(x => x.id === id) || st.escenarios[0];
  st.esc = e.id; st.hip = 'ninguna'; st.alt = 1;
  document.querySelectorAll('.esc').forEach(b => b.setAttribute('aria-current', b.dataset.id === e.id));
  if (e.tipo === 'retiro') { $('#decision').innerHTML = `<div class="card"><h2>${esc(e.titulo)}</h2><p class="sub">${esc(e.descripcion)}</p>
      <button class="btn" id="irRetiro">Ver el informe de retiro de ${esc(e.lote)}</button></div>`;
    $('#irRetiro').onclick = () => show('retiro'); return; }
  decidir();
}

async function decidir() {
  const e = st.escenarios.find(x => x.id === st.esc);
  $('#decision').innerHTML = `<div class="card empty">Preguntando al gemelo…</div>`;
  let d;
  try { d = await api(`/api/decide?escenario=${st.esc}&hipotesis=${st.hip}&alternativa=${st.alt}`); }
  catch (err) { $('#decision').innerHTML = `<div class="card empty">${esc(err.message)}</div>`; return; }

  const sol = d.escenario.solicitudes;
  const hips = [{ id: 'ninguna', pregunta: 'Sin hipótesis (estado actual)' }, ...e.hipotesis];
  const global = d.explicacion.filter(x => x.solicitud === 'todas');

  $('#decision').innerHTML = `
    <div class="card">
      <span class="pill mute">Situación ${d.escenario.situacion}</span>
      <h2 style="margin-top:8px">${esc(d.escenario.titulo)}</h2>
      <p class="sub">${esc(d.escenario.descripcion)}</p>
      <div class="scroll-x"><table class="table">
        <thead><tr><th>Hora</th><th>Mostrador</th><th>Paciente</th><th>Medicamento</th><th>Receta</th><th>Pide</th><th>Tratamiento</th></tr></thead>
        <tbody>${sol.map(s => `<tr><td>${s.hora}</td><td>${s.mostrador}</td><td>${esc(s.paciente)}</td><td>${esc(s.nombre)}</td>
          <td><code>${s.receta}</code></td><td>${s.cantidad}</td><td>${s.dias} días</td></tr>`).join('')}</tbody></table></div>

      ${hips.length > 1 ? `<h3>¿Qué pasaría si…?</h3><div class="chips">${hips.map(h =>
        `<button class="chip" data-hip="${h.id}" aria-pressed="${st.hip === h.id}">${esc(h.pregunta)}</button>`).join('')}</div>` : ''}
      ${d.hipotesis ? `<p class="sub" style="margin-top:8px">Hipótesis aplicada con <code>hipotesis/2</code>: ${d.hipotesis.cambios.map(c => `<code>${esc(c)}</code>`).join(' ')} (se deshace al terminar).</p>` : ''}

      <div class="res-head" style="margin-top:16px;justify-content:space-between">
        <h3 style="margin:0">Decisión del gemelo</h3>
        <div class="pager" aria-label="Alternativas">
          <button id="altPrev" ${d.alternativa <= 1 ? 'disabled' : ''} aria-label="Alternativa anterior">‹</button>
          <span>Alternativa <b>${d.alternativa}</b> de ${d.total}</span>
          <button id="altNext" ${d.alternativa >= d.total ? 'disabled' : ''} aria-label="Siguiente alternativa">›</button>
        </div>
      </div>
      <ul class="why" style="margin-top:10px">${global.map(item).join('')}</ul>
      ${d.resultados.map(r => resultado(r, sol.find(s => s.id === r.id), d)).join('')}
      <div class="how">Cómo se hizo: <code class="pl">decide/4</code>→<code class="pl">que_falta/2</code>${d.hipotesis ? '→<code class="pl">hipotesis/2</code>' : ''} · alternativas por <i>backtracking</i></div>
    </div>`;

  document.querySelectorAll('[data-hip]').forEach(b => b.addEventListener('click', () => { st.hip = b.dataset.hip; st.alt = 1; decidir(); }));
  const p = $('#altPrev'), n = $('#altNext');
  if (p) p.onclick = () => { st.alt--; decidir(); };
  if (n) n.onclick = () => { st.alt++; decidir(); };
}

function item(x) {
  return `<li class="w-${x.tipo}"><span class="tag">${TIPO[x.tipo] || x.tipo}</span><div class="t">${esc(x.texto)}</div>
    ${x.hechos.length ? `<div class="facts">${x.hechos.map(h => `<code>${esc(h)}</code>`).join('')}</div>` : ''}</li>`;
}

function resultado(r, s, d) {
  const xs = d.explicacion.filter(x => x.solicitud === r.id);
  const visibles = xs.filter(x => ORDEN.includes(x.tipo)).sort((a, b) => ORDEN.indexOf(a.tipo) - ORDEN.indexOf(b.tipo));
  const apoyo = xs.filter(x => x.tipo === 'apoyo');
  const decision = visibles.find(x => x.tipo === 'decision');
  const faltas = (d.faltas && d.faltas[r.id]) || [];
  return `<div class="res">
    <div class="res-head"><span class="verdict v-${r.veredicto}">${VEREDICTO[r.veredicto]}</span>
      <span class="who">${esc(s.paciente)} · ${esc(s.nombre)}</span><span class="pill mute">${s.mostrador} · ${s.hora}</span></div>
    ${decision ? `<div class="res-text">${esc(decision.texto)}</div>` : ''}
    ${r.entregas.length ? `<div class="lotes">${r.entregas.map(e => `<div class="lote"><b>${e.lote}</b> · ${e.unidades} u<br>caduca día ${e.caducidad} · estante ${e.estante}</div>`).join('')}</div>` : ''}
    <div class="cols">
      <div><h3>Qué se hace con la receta</h3>${r.acciones.length ? `<ul class="list">${r.acciones.map(a => `<li>${esc(a)}</li>`).join('')}</ul>` : '<p class="sub">Sin receta que registrar.</p>'}</div>
      <div><h3>A quién se avisa</h3>${r.avisos.length ? `<ul class="list">${r.avisos.map(a => `<li>🔔 ${esc(a)}</li>`).join('')}</ul>` : '<p class="sub">A nadie.</p>'}</div>
    </div>
    <h3>Por qué</h3>
    <ul class="why">${visibles.filter(x => x.tipo !== 'decision').map(item).join('')}</ul>
    ${apoyo.length ? `<details class="evid"><summary>Evidencia que se cumple (${apoyo.length})</summary><ul class="why">${apoyo.map(item).join('')}</ul></details>` : ''}
    ${faltas.length ? `<h3>¿Qué falta para que cambie?</h3>${faltas.map(f => `<div class="falta"><span class="pill ${f.valor === 'no' ? 'bad' : 'info'}">${f.valor === 'no' ? 'no se cumple' : 'no se sabe'}</span><div><code>${esc(f.condicion)}</code><br>${esc(f.accion)}</div></div>`).join('')}` : ''}
  </div>`;
}

// ------------------------------------------------------------- existencias
async function cargarLotes() {
  const ls = await api('/api/existencias');
  $('#lotes').dataset.ok = 1;
  $('#lotes').innerHTML = ls.map(l => {
    const [c, t] = ESTADO_LOTE[l.estado] || ['mute', l.estado];
    return `<div class="lot-card"><span class="id">${l.lote}</span><span class="pill ${c}"><span class="dot"></span>${t}</span>
      <div class="meta">${esc(l.nombre)} · <b>${l.unidades} u</b> · caduca día ${l.caducidad} (${l.dias >= 0 ? `faltan ${l.dias} días` : `hace ${-l.dias} días`}) · estante ${l.estante} · ${l.requisito}</div></div>`;
  }).join('');
  imagen('#chartCad', '/grafica/caducidades', 'Días para caducar por lote');
}

// ------------------------------------------------------------- recetas
const ESTADO_REC = { valida: ['ok', 'Válida'], invalida: ['bad', 'No surtible'], dudosa: ['info', 'No se sabe'] };
async function cargarRecetas() {
  const rs = await api('/api/recetas');
  $('#recetas').dataset.ok = 1;
  $('#recetas').innerHTML = rs.map(r => {
    const [c, t] = ESTADO_REC[r.estado];
    const pct = Math.round(100 * r.surtido / Math.max(1, r.prescrito));
    return `<div class="lot-card" style="display:block">
      <div class="res-head"><span class="id">${r.receta}</span><span class="pill ${c}">${t}</span><span class="pill mute">${r.tipo}</span></div>
      <div style="margin-top:6px"><b>${esc(r.paciente)}</b> · ${esc(r.nombre)} · ${esc(r.medico)}</div>
      <div class="bar" title="${r.surtido} de ${r.prescrito}"><span style="width:${pct}%"></span></div>
      <div class="sub" style="margin:0">Surtido ${r.surtido} de ${r.prescrito} · pendiente ${r.pendiente}</div>
      <ul class="timeline">${r.historial.map(h => `<li>día ${h.dia} · ${esc(h.evento)} · ${h.sucursal}</li>`).join('')}</ul>
      ${r.faltas.length ? `<details class="evid"><summary>¿Qué le falta? (${r.faltas.length})</summary>${r.faltas.map(f => `<div class="falta"><span class="pill ${f.valor === 'no' ? 'bad' : 'info'}">${f.valor === 'no' ? 'no' : 'no se sabe'}</span><div>${esc(f.accion)}</div></div>`).join('')}</details>` : ''}
    </div>`;
  }).join('');
  imagen('#chartRec', '/grafica/recetas', 'Recetas: surtido vs. pendiente');
}

// ------------------------------------------------------------- retiro
async function cargarRetiro(lote) {
  const r = await api('/api/retiro?lote=' + lote);
  $('#retiro').dataset.ok = 1;
  const DEST = { cuarentena: ['info', 'Cuarentena'], regresa_al_inventario: ['ok', 'Regresa al inventario'], merma: ['mute', 'Merma'], retiro_al_proveedor: ['bad', 'Al proveedor'] };
  $('#retiro').innerHTML = `
    <div class="card retiro-head">
      <span class="pill bad">Alerta sanitaria · día ${r.dia_retiro}</span>
      <h2 style="margin-top:8px">Lote ${r.lote} retirado · ${esc(r.medicamento)}</h2>
      <p class="sub">${esc(r.alerta || '')}. Cadena que sigue el gemelo: <code>lote → venta → receta → paciente → aviso</code>.</p>
      <div class="kpis" style="grid-template-columns:repeat(3,minmax(0,1fr));margin:0">
        <div class="kpi ok"><div class="n">${r.avisar.length}</div><div class="l">Pacientes por avisar</div></div>
        <div class="kpi bad"><div class="n">${r.sin_rastro.reduce((a, s) => a + s.unidades, 0)}</div><div class="l">Unidades: no se sabe a quién</div></div>
        <div class="kpi info"><div class="n">${r.estante.unidades}</div><div class="l">En estante ${r.estante.estante}: sacar hoy</div></div>
      </div>
    </div>
    <div class="grid-2" style="margin-top:16px">
      <div class="card"><h2>A quién avisar</h2><p class="sub">Con el medio que la cadena permite.</p>
        ${r.avisar.map(a => `<div class="res"><div class="res-head"><span class="who">${esc(a.paciente)}</span>
          <span class="pill ${a.medio === 'teléfono' ? 'ok' : 'info'}">${esc(a.medio)}: ${esc(a.detalle)}</span></div>
          <p class="sub" style="margin:6px 0">Venta ${a.venta}: ${a.unidades} u en ${a.sucursal}, día ${a.dia}</p>
          <div class="why"><div class="facts">${a.cadena.map(c => `<code>${esc(c)}</code>`).join('')}</div></div></div>`).join('')}
      </div>
      <div class="card"><h2>Ventas sin rastro</h2><p class="sub">El dato que falta no se rellena: se declara desconocido.</p>
        <div class="scroll-x"><table class="table"><thead><tr><th>Venta</th><th>Unidades</th><th>Sucursal</th><th>Día</th><th>¿A quién?</th></tr></thead>
        <tbody>${r.sin_rastro.map(s => `<tr><td>${s.venta}</td><td>${s.unidades}</td><td>${s.sucursal}</td><td>${s.dia}</td><td class="unknown">${esc(s.a_quien)}</td></tr>`).join('')}</tbody></table></div>
        ${r.incidentes.length ? `<p class="unknown">Ventas posteriores a la alerta: ${r.incidentes.map(i => i.venta).join(', ')}</p>` : '<p class="sub" style="margin-top:12px">Ninguna venta posterior a la alerta.</p>'}
      </div>
    </div>
    <div class="card"><h2>Devoluciones: ¿regresan al inventario?</h2><p class="sub">El gemelo dice de qué depende.</p>
      ${r.devoluciones.map(d => { const [c, t] = DEST[d.destino] || ['mute', d.destino];
        return `<div class="falta"><span class="pill ${c}">${t}</span><div><b>${d.devolucion}</b> · ${d.medicamento} · lote <code>${d.lote}</code> · empaque ${d.empaque}<br>${esc(d.depende)}</div></div>`; }).join('')}
    </div>
    <div class="card"><h2>¿Dónde están sus unidades?</h2><div id="chartRet"></div>
      <div class="how"><code class="pl">grafica_retiro/2</code>→<code class="py">graficas.retiro</code></div></div>`;
  imagen('#chartRet', '/grafica/retiro?lote=' + lote, 'Destino de las unidades del lote retirado');
}

// ------------------------------------------------------------- consultas
async function consultar() {
  const ent = $('#qEnt').value.trim(), tipo = $('#qTipo').value;
  const rs = await api(`/api/situaciones?entidad=${encodeURIComponent(ent)}&tipo=${encodeURIComponent(tipo)}`);
  $('#sitRes').dataset.ok = 1;
  $('#sitRes').innerHTML = `<p class="sub"><code>?- situacion(${esc(ent || 'E')}, ${esc(tipo ? tipo + '(…)' : 'S')}, Ev).</code> → ${rs.length} respuesta(s)</p>` +
    (rs.length ? `<div class="scroll-x"><table class="table"><thead><tr><th>Entidad</th><th>Situación</th><th>Evidencia</th></tr></thead><tbody>${rs.map(r =>
      `<tr><td><code>${esc(r.entidad)}</code></td><td><code>${esc(r.situacion)}</code></td><td><div class="why"><div class="facts">${r.evidencia.map(e => `<code>${esc(e)}</code>`).join('')}</div></div></td></tr>`).join('')}</tbody></table></div>`
      : '<p class="empty">false.</p>');
}

// ------------------------------------------------------------- gráficas
function imagen(sel, url, alt) {
  const img = new Image();
  img.className = 'chart'; img.alt = alt; img.loading = 'lazy';
  img.onerror = () => { $(sel).innerHTML = `<div class="chart-msg">No se pudo dibujar: el servidor no encontró Python con matplotlib. Las decisiones no dependen de esto.</div>`; };
  img.src = url + (url.includes('?') ? '&' : '?') + 't=' + Date.now();
  $(sel).replaceChildren(img);
}

init().catch(err => { document.querySelector('main').insertAdjacentHTML('afterbegin', `<div class="banner">No se pudo conectar con el gemelo: ${esc(err.message)}. ¿Está corriendo <code>swipl servidor.pl</code>?</div>`); });
