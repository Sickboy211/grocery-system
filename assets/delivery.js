// Leaflet maps render only coordinates saved from actual rider GPS or customer address input.
document.addEventListener('DOMContentLoaded', () => {
  const csrf = document.querySelector('input[name="csrf"]')?.value || '';
  const GPS_UPDATE_INTERVAL_MS = Number(document.querySelector('[data-gps-interval]')?.dataset.gpsInterval) || 15000;
  const maps = new Map();

  function mapInstance(frame, centerPoint) {
    if (!window.L) {
      frame.innerHTML = '<div class="map-empty">Map library unavailable. Check the internet connection for Leaflet and OpenStreetMap tiles.</div>';
      return null;
    }
    if (maps.has(frame)) return maps.get(frame);
    const map = L.map(frame, { scrollWheelZoom: false, zoomControl: true }).setView(centerPoint, 13);
    frame.querySelector('.map-empty')?.remove();
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);
    const layers = { map, current: null, destination: null, connector: null };
    maps.set(frame, layers);
    return layers;
  }

  function validPoint(lat, lon) {
    const a = Number(lat), b = Number(lon);
    return Number.isFinite(a) && Number.isFinite(b) && Math.abs(a) <= 90 && Math.abs(b) <= 180 && (a !== 0 || b !== 0) ? [a, b] : null;
  }

  function draw(frame, delivery) {
    const current = validPoint(delivery.current_latitude, delivery.current_longitude);
    const destination = validPoint(delivery.destination_latitude, delivery.destination_longitude);
    if (!current && !destination) {
      if (maps.has(frame)) {
        const old = maps.get(frame); old.map.remove(); maps.delete(frame);
      }
      if (!frame.querySelector('.map-empty')) frame.innerHTML = '<div class="map-empty">No real rider or customer coordinates are available yet. GPS and map tracking will appear here when the rider starts the active delivery.</div>';
      return;
    }
    const layers = mapInstance(frame, current || destination);
    if (!layers) return;
    if (layers.current) layers.map.removeLayer(layers.current);
    if (layers.destination) layers.map.removeLayer(layers.destination);
    if (layers.connector) layers.map.removeLayer(layers.connector);
    const points = [];
    if (current) {
      layers.current = L.marker(current).addTo(layers.map).bindPopup('Rider location · updated ' + (delivery.last_location_at || 'just now'));
      points.push(current);
    }
    if (destination) {
      layers.destination = L.marker(destination).addTo(layers.map).bindPopup('Customer destination');
      points.push(destination);
    }
    if (points.length === 2) {
      // This is a straight-line connector, not a road route. No route is shown when points are missing.
      layers.connector = L.polyline(points, { color: '#2864df', weight: 3, dashArray: '7 7', opacity: .8 }).addTo(layers.map);
      layers.map.fitBounds(L.latLngBounds(points), { padding: [24, 24], maxZoom: 15 });
    } else if (points.length === 1) layers.map.setView(points[0], 14);
    else layers.map.setView(points[0], 14);
    setTimeout(() => layers.map.invalidateSize(), 50);
  }

  async function refreshMap(frame) {
    const mode = frame.dataset.mode;
    const url = mode === 'public'
      ? '?api=track&token=' + encodeURIComponent(frame.dataset.trackToken || '')
      : '?api=delivery_snapshot&id=' + encodeURIComponent(frame.dataset.deliveryId || '0');
    try {
      const response = await fetch(url, { credentials: 'same-origin', headers: { 'Accept': 'application/json' } });
      if (!response.ok) return;
      const data = await response.json();
      const d = data.delivery;
      if (!data.ok || !d) return;
      draw(frame, d);
      const panel = frame.closest('.live-panel, .dashboard-delivery, .tracking-card');
      if (!panel) return;
      const status = panel.querySelector('.tracking-state, .delivery-meta .status-tag');
      if (status) status.textContent = d.status.replaceAll('_', ' ').replace(/\b\w/g, c => c.toUpperCase());
      const time = panel.querySelector('.last-updated');
      if (time) time.textContent = 'Last location update: ' + (d.last_location_at || 'No GPS update received');
    } catch (_) { /* Keep the last received position visible during a temporary network outage. */ }
  }

  document.querySelectorAll('.map-frame').forEach(frame => {
    const initial = { current_latitude: frame.dataset.lat, current_longitude: frame.dataset.lon, destination_latitude: frame.dataset.destLat, destination_longitude: frame.dataset.destLon };
    if (validPoint(initial.current_latitude, initial.current_longitude) || validPoint(initial.destination_latitude, initial.destination_longitude)) draw(frame, initial);
    if (frame.dataset.mode === 'public' || frame.dataset.deliveryId) {
      refreshMap(frame);
      window.setInterval(() => refreshMap(frame), GPS_UPDATE_INTERVAL_MS);
    }
  });

  const orderLines = document.querySelector('#order-lines');
  orderLines?.addEventListener('change', event => {
    if (!event.target.matches('.order-product')) return;
    const option = event.target.selectedOptions[0];
    const price = event.target.closest('.order-line')?.querySelector('.order-price');
    if (option?.dataset.price && price) price.value = option.dataset.price;
  });
  document.querySelector('#add-order-line')?.addEventListener('click', () => {
    const template = document.querySelector('#order-line-template');
    if (template && orderLines) orderLines.insertBefore(template.content.cloneNode(true), document.querySelector('#add-order-line'));
  });
  orderLines?.addEventListener('click', event => {
    if (!event.target.matches('.remove-order-line')) return;
    const lines = orderLines.querySelectorAll('.order-line');
    if (lines.length > 1) event.target.closest('.order-line')?.remove();
  });

  const watchIds = new Set();
  document.querySelectorAll('.gps-controls').forEach(control => {
    const start = control.querySelector('.gps-start'), stop = control.querySelector('.gps-stop'), state = control.querySelector('.gps-state');
    const deliveryId = control.dataset.gpsDelivery;
    let watchId = null, lastSent = 0;
    if (control.dataset.gpsAllowed !== '1') {
      start.disabled = true;
      state.textContent = 'GPS can start only after the delivery is marked Out for Delivery.';
    }
    const stopTracking = () => {
      if (watchId !== null && navigator.geolocation) navigator.geolocation.clearWatch(watchId);
      watchIds.delete(watchId); watchId = null;
      start.hidden = false; stop.hidden = true;
      state.textContent = 'GPS sharing stopped. Location is no longer collected.';
    };
    start?.addEventListener('click', () => {
      if (!navigator.geolocation) { state.textContent = 'This browser does not provide GPS location.'; return; }
      state.textContent = 'Waiting for location permission and GPS fix…';
      watchId = navigator.geolocation.watchPosition(async position => {
        if (Date.now() - lastSent < GPS_UPDATE_INTERVAL_MS) return;
        lastSent = Date.now();
        const body = new URLSearchParams({ action: 'gps_update', csrf, delivery_id: deliveryId, latitude: String(position.coords.latitude), longitude: String(position.coords.longitude) });
        try {
          const response = await fetch(location.pathname + location.search.split('&')[0], { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' }, body });
          const data = await response.json();
          state.textContent = data.ok ? 'Location shared at ' + new Date(data.updated_at).toLocaleTimeString() + (data.eta ? ' · estimated arrival ' + data.eta : ' · ETA unavailable until destination coordinates are saved') : (data.message || 'Location update rejected.');
        } catch (_) { state.textContent = 'Could not send location. Last known location is retained.'; }
      }, error => {
        state.textContent = error.code === 1 ? 'Location permission denied. Enable it to share an active delivery position.' : 'GPS unavailable; the last known location remains on file.';
      }, { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 });
      watchIds.add(watchId); start.hidden = true; stop.hidden = false;
    });
    stop?.addEventListener('click', stopTracking);
  });
  window.addEventListener('beforeunload', () => { if (navigator.geolocation) watchIds.forEach(id => navigator.geolocation.clearWatch(id)); });
});
