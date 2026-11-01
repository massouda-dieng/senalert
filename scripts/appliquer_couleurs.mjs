#!/usr/bin/env node
/**
 * Propage design/couleurs.json vers ce qui ne peut pas lire le JSON directement.
 *   node scripts/appliquer_couleurs.mjs
 * Le web (Tailwind, web/src/lib/couleurs.js) lit le JSON sans passer par ce script.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const racine = join(dirname(fileURLToPath(import.meta.url)), '..');
const J = JSON.parse(readFileSync(join(racine, 'design/couleurs.json'), 'utf8'));

const dart = (hex) => `Color(0xFF${hex.slice(1).toUpperCase()})`;
const nom = (s) => s.replace(/_(\w)/g, (_, c) => c.toUpperCase());
const ligne = (n, hex) => `  static const Color ${n} = ${dart(hex)};`;
const lignes = [
  '// Fichier GÉNÉRÉ par scripts/appliquer_couleurs.mjs depuis design/couleurs.json. Ne pas modifier à la main.',
  "import 'package:flutter/material.dart';",
  '',
  'class Jetons {',
  ...Object.entries(J.marque).map(([k, v]) => ligne(`marine${k}`, v)),
  ligne('rouge', J.sos.DEFAULT), ligne('rougeFonce', J.sos.fonce), ligne('rougeSombre', J.sos.sombre), ligne('rougeClair', J.sos.clair),
  ligne('orange', J.or.DEFAULT), ligne('orangeFonce', J.or.fonce), ligne('orangeClair', J.or.clair),
  ligne('vert', J.succes.vif), ligne('vertFonce', J.succes.DEFAULT), ligne('vertClair', J.succes.clair),
  ligne('gris', J.neutre.gris), ligne('grisClair', J.neutre.grisClair), ligne('grisFonce', J.neutre.grisFonce),
  ...Object.entries(J.surfaces.clair).map(([k, v]) => ligne(`${k}Clair`, v)),
  ...Object.entries(J.surfaces.sombre).map(([k, v]) => ligne(`${k}Sombre`, v)),
  ...Object.entries(J.statuts).flatMap(([k, v]) => [ligne(`statut${nom(`_${k}`)}`, v.DEFAULT), ligne(`statut${nom(`_${k}`)}Fond`, v.fond)]),
  ...Object.entries(J.gravites).map(([k, v]) => ligne(`gravite${nom(`_${k}`)}`, v)),
  ...Object.entries(J.services).map(([k, v]) => ligne(`service${nom(`_${k}`)}`, v)),
  ...Object.entries(J.surSombre).map(([k, v]) => ligne(`surSombre${nom(`_${k}`)}`, v)),
  // Voiles posés sur les photos (alpha + couleur)
  `  static const Color voileFort = Color(0xF2${J.marque[950].slice(1).toUpperCase()});`,
  `  static const Color voileMoyen = Color(0xCC${J.marque[800].slice(1).toUpperCase()});`,
  `  static const Color voileLeger = Color(0x80${J.marque[600].slice(1).toUpperCase()});`,
  '}',
  '',
];
writeFileSync(join(racine, 'mobile/lib/core/constants/jetons.g.dart'), lignes.join('\n'));

const marine = J.marque[800];
const logo = (fond, bouclier, etoile) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="16" fill="${fond}"/><path d="M32 11 50 19v13c0 11-7.6 18.6-18 21-10.4-2.4-18-10-18-21V19z" fill="${bouclier}"/><path d="m32 22 3 8.6h9l-7.3 5.4 2.8 8.7L32 39.4l-7.5 5.3 2.8-8.7-7.3-5.4h9z" fill="${etoile}"/></svg>\n`;
writeFileSync(join(racine, 'web/public/favicon.svg'), logo(marine, '#fff', J.marque[600]));

for (const [fichier, motif, valeur] of [
  ['web/index.html', /(name="theme-color" content=")#[0-9A-Fa-f]{6}/, `$1${marine}`],
  ['web/public/manifest.webmanifest', /("theme_color": ")#[0-9A-Fa-f]{6}/, `$1${marine}`],
  ['web/public/manifest.webmanifest', /("background_color": ")#[0-9A-Fa-f]{6}/, `$1${marine}`],
  ['mobile/web/manifest.json', /("theme_color": ")#[0-9A-Fa-f]{6}/, `$1${marine}`],
  ['mobile/web/manifest.json', /("background_color": ")#[0-9A-Fa-f]{6}/, `$1${marine}`],
]) {
  const chemin = join(racine, fichier);
  writeFileSync(chemin, readFileSync(chemin, 'utf8').replace(motif, valeur));
}
console.log('Couleurs propagées : Flutter (jetons.g.dart), favicon, manifestes.');
