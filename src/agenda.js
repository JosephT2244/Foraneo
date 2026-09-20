export function localDate(date = new Date()) { return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`; }
export function weekDates(anchor = localDate()) {
  const date = new Date(`${anchor}T12:00:00`); date.setDate(date.getDate() - (date.getDay() + 6) % 7);
  return Array.from({ length: 7 }, (_, index) => { const next = new Date(date); next.setDate(date.getDate() + index); return localDate(next); });
}
export function taskDate(task) { return task.date || localDate(); }
export function calendarUrl(task) {
  const start = new Date(`${taskDate(task)}T${task.time || '09:00'}:00`);
  if (!Number.isFinite(start.getTime())) return '';
  const stamp = date => date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const params = new URLSearchParams({ action: 'TEMPLATE', text: task.title, details: `${task.notes || ''}\nCreado en Foráneo`, dates: `${stamp(start)}/${stamp(new Date(start.getTime() + 3600000))}` });
  return `https://calendar.google.com/calendar/render?${params}`;
}
export function calendarIcs(tasks) {
  const escape = value => String(value || '').replace(/\\/g, '\\\\').replace(/\r?\n/g, '\\n').replace(/[,;]/g, '\\$&');
  const rows = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Foraneo//Agenda//ES', 'CALSCALE:GREGORIAN'];
  tasks.forEach(task => { const date = taskDate(task).replaceAll('-', ''); const time = (task.time || '09:00').replace(':', '') + '00'; rows.push('BEGIN:VEVENT', `UID:${escape(task.id)}@foraneo.local`, `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')}`, `DTSTART:${date}T${time}`, 'DURATION:PT1H', `SUMMARY:${escape(task.title)}`, `DESCRIPTION:${escape(task.notes)}`, 'END:VEVENT'); });
  rows.push('END:VCALENDAR'); return rows.join('\r\n') + '\r\n';
}
