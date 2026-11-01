import { COULEURS } from '../lib/couleurs';

/** Logo SenAlert : bouclier et étoile, rappel de l'étoile du drapeau sénégalais. */
export function Logo({ className, clair = false }) {
  return (
    <svg viewBox="0 0 64 64" className={className} role="img" aria-label="SenAlert">
      <rect width="64" height="64" rx="16" fill={clair ? COULEURS.blanc : COULEURS.marine} />
      <path d="M32 11 50 19v13c0 11-7.6 18.6-18 21-10.4-2.4-18-10-18-21V19z" fill={clair ? COULEURS.marine : COULEURS.blanc} />
      <path d="m32 22 3 8.6h9l-7.3 5.4 2.8 8.7L32 39.4l-7.5 5.3 2.8-8.7-7.3-5.4h9z" fill={clair ? COULEURS.blanc : COULEURS.bleu} />
    </svg>
  );
}

/** Fine bande dégradée, signature visuelle. */
export function BandeDrapeau({ className = 'h-1' }) {
  return <div className={`${className} bg-drapeau`} aria-hidden />;
}
