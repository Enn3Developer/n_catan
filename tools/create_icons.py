"""Original scalable UI symbols, shared by the HUD, costs, ports and trade dialogs."""
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/icons'
resources={
 'timber':'''<g stroke="#593e2c" stroke-width="2.4" stroke-linejoin="round">
  <path fill="#805638" d="M12 31 34 18c12 0 12 23 0 23L12 54Z"/>
  <path fill="none" stroke="#b37c4c" stroke-width="3" stroke-linecap="round" d="m22 32 15-9m-13 19 14-8"/>
  <ellipse cx="12" cy="42.5" rx="9" ry="11.5" fill="#d9b17a"/>
  <ellipse cx="12" cy="42.5" rx="4.2" ry="6.2" fill="none" stroke="#966538" stroke-width="2"/>
  <path fill="#92613d" d="m33 37 20-12c12 0 12 23 0 23L33 60Z"/>
  <path fill="none" stroke="#be8751" stroke-width="3" stroke-linecap="round" d="m44 36 11-6m-13 17 13-8"/>
  <ellipse cx="33" cy="48.5" rx="9" ry="11.5" fill="#edca90"/>
  <ellipse cx="33" cy="48.5" rx="4.2" ry="6.2" fill="none" stroke="#a67640" stroke-width="2"/>
  <path fill="#91613d" d="m23 15 21-12c12 0 12 23 0 23L23 38Z"/>
  <path fill="none" stroke="#c48b53" stroke-width="3" stroke-linecap="round" d="m33 15 12-7m-10 16 12-7"/>
  <ellipse cx="23" cy="26.5" rx="9" ry="11.5" fill="#f1d399"/>
  <ellipse cx="23" cy="26.5" rx="4.2" ry="6.2" fill="none" stroke="#a67640" stroke-width="2"/>
  <path fill="none" stroke="#a67640" stroke-width="2" stroke-linecap="round" d="m23 16 1 4m-13 28-1 4m25 1 2 4"/>
</g>''',
 'brick':'<path fill="#ad593f" d="M6 33 31 20 58 33v17L32 62 6 48Z"/><path fill="#db9067" d="m6 33 26 13 26-13-27-13Z"/><path fill="#7f4436" d="M32 46v16L6 48V33Z"/><path fill="#ce7755" d="M12 14 34 4l23 12v14L35 40 12 28Z"/><path fill="#eeab7c" d="m12 14 23 12 22-10L34 4Z"/><path fill="none" stroke="#f5c593" stroke-width="2" d="m17 14 18 9 15-7"/>',
 'wool':'<path fill="#c3c1ad" d="M12 46C1 38 6 25 15 23 14 9 29 5 37 13c12-4 22 6 19 17 10 15-2 25-13 22-10 11-22 6-25-1Z"/><path fill="#f4efda" d="M12 37C3 28 12 19 21 21c-3-11 13-15 17-5 12-1 19 12 12 19 3 12-14 17-20 10-9 6-19 1-18-8Z"/><path fill="none" stroke="#b6b6a0" stroke-width="3" stroke-linecap="round" d="M21 21c7-3 12 3 8 8m9-13c-5 3-3 9 2 10m-22 5c-6 6 0 13 7 10m13 1c9-1 11-7 6-11"/>',
 'grain':'''<g transform="rotate(-22 20 42)" stroke-linecap="round" stroke-linejoin="round">
  <path fill="none" stroke="#b98536" stroke-width="2.8" d="M20 59V22"/>
  <path fill="#d5a44d" stroke="#a47730" stroke-width="1.2" d="M20 25c-5-3-5-8 0-13 5 5 5 10 0 13Z M19 33c-7-1-11-6-10-12 7 1 10 5 10 12Z M21 33c7-1 11-6 10-12-7 1-10 5-10 12Z M19 42c-7-1-11-6-10-12 7 1 10 5 10 12Z M21 42c7-1 11-6 10-12-7 1-10 5-10 12Z"/>
</g>
<g transform="rotate(14 37 33)" stroke-linecap="round" stroke-linejoin="round">
  <path fill="none" stroke="#c29441" stroke-width="3.2" d="M37 60V12"/>
  <path fill="none" stroke="#e7bf69" stroke-width="1.6" d="M37 7V2m-8 15-5-9m21 9 5-9M27 27l-5-10m25 10 5-10M27 37l-5-10m25 10 5-10"/>
  <path fill="#ffe1a0" stroke="#b98837" stroke-width="1.2" d="M37 19c-7-4-7-11 0-17 7 6 7 13 0 17Z"/>
  <g fill="#efc76f" stroke="#b98837" stroke-width="1.2">
    <path d="M35.5 26c-8-1-13-7-12-14 8 1 12 6 12 14Z M35.5 36c-8-1-13-7-12-14 8 1 12 6 12 14Z M35.5 46c-8-1-13-7-12-14 8 1 12 6 12 14Z"/>
  </g>
  <g fill="#ffdb8a" stroke="#b98837" stroke-width="1.2">
    <path d="M38.5 26c8-1 13-7 12-14-8 1-12 6-12 14Z M38.5 36c8-1 13-7 12-14-8 1-12 6-12 14Z M38.5 46c8-1 13-7 12-14-8 1-12 6-12 14Z"/>
  </g>
</g>''',
 'ore':'<path fill="#667d89" d="m5 49 8-26L32 7l17 8 11 35-28 11Z"/><path fill="#a8bac0" d="M13 23 32 7l6 24-19 7Z"/><path fill="#d0d8d3" d="m32 7 17 8-11 16Z"/><path fill="#829ca7" d="m38 31 11-16 11 35-16 2Z"/><path fill="#4b606e" d="m19 38 19-7 6 21-12 9Z"/><path fill="#90a4aa" d="m5 49 14-11 13 23Z"/>'}
for name,art in resources.items():
 (out/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{art}</svg>\n')
paths={'music': 'M19 34V10l21-5v24 M19 13l21-5 M19 34c0 7-13 9-13 3s13-9 13-3 M40 29c0 7-13 9-13 3s13-9 13-3', 'play': 'm15 9 25 15-25 15Z', 'pause': 'M16 10v28 M32 10v28', 'previous': 'M10 9v30 M38 9 17 24l21 15Z', 'next': 'M38 9v30 M10 9l21 15-21 15Z', 'volume': 'M6 18h9L27 8v32L15 30H6Z M33 15c7 5 7 13 0 18 M38 9c11 9 11 21 0 30', 'muted': 'M6 18h9L27 8v32L15 30H6Z M33 18l10 12 M43 18 33 30'} | {
 'road':'M8 38 32 10M16 42 40 14M12 27l13 11M20 18l13 11M28 9l13 11',
 'settlement':'m6 23 18-15 18 15M12 21v20h24V21M21 41V29h8v12',
 'city':'M6 41V17h13v24M6 17V9h5v5h3V9h5v8M22 41V24l10-9 10 9v17M28 41V29h8v12M4 41h40',
 'trade':'M7 16h32l-8-8M41 32H9l8 8',
 'cards':'M13 8h26v32H13Z M8 14H5v31h25v-2 M22 19l4-5 4 5-4 5Z',
 'dice':'M12 6h24a6 6 0 0 1 6 6v24a6 6 0 0 1-6 6H12a6 6 0 0 1-6-6V12a6 6 0 0 1 6-6Z M16 15v2 M32 15v2 M24 23v2 M16 31v2 M32 31v2',
 'settings':'M18 8l2-4h8l2 4 5 3 5-1 4 7-3 4v6l3 4-4 7-5-1-5 3-2 4h-8l-2-4-5-3-5 1-4-7 3-4v-6l-3-4 4-7 5 1Z M31 24a7 7 0 1 1-14 0 7 7 0 0 1 14 0',
 'help':'M42 24a18 18 0 1 1-36 0 18 18 0 0 1 36 0 M18 17c0-8 15-8 13 0-1 5-7 4-7 11 M24 34v1',
 'inspect':'M3 24s8-14 21-14 21 14 21 14-8 14-21 14S3 24 3 24 M31 24a7 7 0 1 1-14 0 7 7 0 0 1 14 0',
 'leave':'M21 8H8v32h13 M21 24h22l-9-9 M43 24l-9 9',
 'journal':'M11 7h28v35H11Z M6 15h9 M6 24h9 M6 33h9 M21 17h11 M21 25h11 M21 33h7',
 'star':'m24 5 6 12 14 2-10 10 2 14-12-7-12 7 2-14L4 19l14-2Z',
 'hand':'M10 23v-5a3 3 0 0 1 6 0v8-17a3 3 0 0 1 6 0v15-18a3 3 0 0 1 6 0v19-14a3 3 0 0 1 6 0v20l6-7c4-2 6 1 4 4L32 42H18L10 30Z',
 'arrow':'M8 24h32L27 11 M40 24 27 37',
 'close':'M12 12 36 36 M36 12 12 36'}
for name,path in paths.items():
 (out/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="{path}" fill="none" stroke="#efdfbf" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>\n')

# Knight silhouette used for played-army counts and development cards.
(out / "knight.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M12 41h27v-5H12zm4-8 4-10-8 3-3-6L22 8l-1-5 9 6c9 4 10 14 7 24z" fill="#eddbb3" stroke="#a78045" stroke-width="2" stroke-linejoin="round"/><circle cx="24" cy="15" r="2" fill="#102938"/></svg>')
