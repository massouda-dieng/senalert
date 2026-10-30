import { Link } from 'react-router-dom';
import { CREDITS, PHOTOS } from '../../lib/photos';

export default function Credits() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-10">
      <Link to="/" className="lien text-sm">← Retour</Link>
      <h1 className="mt-3 text-3xl font-extrabold">Crédits photos</h1>
      <p className="mt-2 text-texte-doux">Les photos utilisées sont des images d’illustration sous licence libre (Wikimedia Commons). Elles ne représentent aucun incident réel signalé sur SenAlert.</p>
      <ul className="mt-6 grid gap-4 sm:grid-cols-2">
        {CREDITS.map((c) => (
          <li key={c.fichier} className="carte overflow-hidden">
            <img src={PHOTOS[c.fichier.replace('.jpg', '')].url} alt="" className="h-40 w-full object-cover" loading="lazy" />
            <div className="p-4 text-sm">
              <p className="font-semibold">{c.titre}</p>
              <p className="text-texte-doux">Auteur : {c.auteur || 'non précisé'}</p>
              <p className="text-texte-doux">Licence : {c.licence_url ? <a className="lien" href={c.licence_url} target="_blank" rel="noreferrer">{c.licence}</a> : c.licence}</p>
              <a className="lien" href={c.source} target="_blank" rel="noreferrer">Source Wikimedia Commons</a>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
