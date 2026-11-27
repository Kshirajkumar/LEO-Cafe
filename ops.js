const ops$ = s => document.querySelector(s);
const read = key => JSON.parse(localStorage.getItem(key) || '[]');
const write = (key, value) => localStorage.setItem(key, JSON.stringify(value));
const opsMoney = n => '₹' + Number(n).toLocaleString('en-IN');
const nextStatus = status => ({received:'confirmed', confirmed:'preparing', preparing:'ready', ready:'served', served:'completed'})[status] || 'received';

function renderFloor(){
  const host = ops$('#floorGrid'); if (!host) return;
  const orders = read('leo-orders'), calls = read('leo-calls');
  host.innerHTML = LEO_TABLES.map(table => {
    const order = orders.find(x => x.table === table.number && !['completed','cancelled'].includes(x.status));
    const call = calls.find(x => x.table === table.number && x.status !== 'resolved');
    return `<div class="floor-table ${call ? 'needs-help' : ''}"><span>TABLE ${table.number}</span><strong>${call ? 'Need you' : 'Ready'}</strong><small>${order ? `Order #${order.number} · ${order.status}` : 'No active order'}</small>${call ? `<em>“${call.message}”</em>` : ''}</div>`;
  }).join('');
}

function renderOps(){
  const orders = read('leo-orders'), calls = read('leo-calls');
  if (ops$('#metricOrders')) {
    ops$('#metricOrders').textContent = orders.length;
    ops$('#metricRevenue').textContent = opsMoney(orders.reduce((sum, order) => sum + order.total, 0));
    ops$('#metricCalls').textContent = calls.filter(x => x.status === 'open').length;
    ops$('#adminOrders').innerHTML = orders.length ? orders.map(order => `<div class="order-row"><div><h3>#${order.number} · Table ${order.table || 'walk-in'}</h3><p>${order.items.map(item => `${item.quantity}× ${item.name}`).join(', ')}<br>${order.name} · ${order.payment === 'pay_later' ? 'Pay after meal' : 'Demo paid'}</p></div><select class="status-select" data-order="${order.id}">${['received','confirmed','preparing','ready','served','completed','cancelled'].map(status => `<option ${status === order.status ? 'selected' : ''}>${status}</option>`).join('')}</select></div>`).join('') : '<p style="color:var(--muted)">No orders yet.</p>';
    ops$('#adminCalls').innerHTML = calls.filter(x => x.status !== 'resolved').map(call => `<div class="call-row"><div><h3>Table ${call.table}</h3><p>${call.message}</p></div><button class="button light" data-call="${call.id}">${call.status === 'open' ? 'Acknowledge' : 'Resolve'}</button></div>`).join('') || '<p style="color:var(--muted)">All quiet.</p>';
  }
  if (ops$('#waiterOrders')) ops$('#waiterOrders').innerHTML = orders.filter(x => !['completed','cancelled'].includes(x.status)).map(order => `<div class="order-row"><div><h3>#${order.number} · Table ${order.table || 'walk-in'}</h3><p>${order.items.map(item => `${item.quantity}× ${item.name}`).join(', ')}<br>Status: ${order.status}</p></div><button class="button orange" data-next="${order.id}">${nextStatus(order.status)}</button></div>`).join('') || '<p style="color:var(--muted)">No active orders.</p>';
  if (ops$('#waiterCalls')) ops$('#waiterCalls').innerHTML = calls.filter(x => x.status !== 'resolved').map(call => `<div class="call-row"><div><h3>Table ${call.table}</h3><p>${call.message}</p></div><button class="button light" data-call="${call.id}">${call.status === 'open' ? 'Acknowledge' : 'Resolve'}</button></div>`).join('') || '<p style="color:var(--muted)">No guest requests.</p>';
  document.querySelectorAll('[data-order]').forEach(select => select.onchange = () => { const rows = read('leo-orders'); rows.find(x => x.id === select.dataset.order).status = select.value; write('leo-orders', rows); renderOps(); renderFloor(); });
  document.querySelectorAll('[data-next]').forEach(button => button.onclick = () => { const rows = read('leo-orders'); const row = rows.find(x => x.id === button.dataset.next); row.status = nextStatus(row.status); write('leo-orders', rows); renderOps(); renderFloor(); });
  document.querySelectorAll('[data-call]').forEach(button => button.onclick = () => { const rows = read('leo-calls'); const row = rows.find(x => x.id === button.dataset.call); row.status = row.status === 'open' ? 'acknowledged' : 'resolved'; write('leo-calls', rows); renderOps(); renderFloor(); });
}

function renderQR(){
  const target = ops$('#qrGrid'); if (!target) return;
  target.innerHTML = LEO_TABLES.map(table => `<div class="qr-card"><canvas id="qr-${table.number}"></canvas><h3>Table ${table.number}</h3><p>${table.name}<br>${table.active ? table.code : 'Cancelled'}</p><button class="button light" data-qr="${table.number}">Download QR</button></div>`).join('');
  LEO_TABLES.forEach(table => { const url = `${location.origin}${location.pathname.replace(/admin\.html$/, '')}table.html?table=${table.code}`; if (window.QRCode) QRCode.toCanvas(document.querySelector(`#qr-${table.number}`), url, {width:160, margin:1, color:{dark:'#2b251f', light:'#fffdf8'}}); });
  document.querySelectorAll('[data-qr]').forEach(button => button.onclick = () => { const canvas = document.querySelector(`#qr-${button.dataset.qr}`); const link = document.createElement('a'); link.download = `leo-table-${button.dataset.qr}.png`; link.href = canvas.toDataURL(); link.click(); });
}

if (!ops$('#floorGrid') && ops$('.ops-grid')) { const section = document.createElement('section'); section.className = 'ops-panel floor-panel'; section.innerHTML = '<div class="section-bar"><div><p class="eyebrow">Live floor</p><h2>Five tables, one view.</h2></div><p>Table-specific orders and waiter calls at a glance.</p></div><div class="floor-grid" id="floorGrid"></div>'; ops$('.ops-grid').before(section); }
renderQR(); renderOps(); renderFloor(); setInterval(() => { renderOps(); renderFloor(); }, 3000);
