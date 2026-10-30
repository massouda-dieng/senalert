import clsx from 'clsx';
import { PHOTOS, creditCourt } from '../lib/photos';

/** Image d'illustration avec crédit de licence (obligatoire pour CC BY / CC BY-SA). */
export default function Photo({ nom, className, imgClassName, alt = '', credit = true, children, priorite = false }) {
  const p = PHOTOS[nom];
  if (!p) return null;
  return (
    <figure className={clsx('overflow-hidden', !/\b(absolute|fixed)\b/.test(className || '') && 'relative', className)}>
      <img src={p.url} alt={alt} loading={priorite ? 'eager' : 'lazy'} decoding="async" className={clsx('h-full w-full object-cover', imgClassName)} />
      {children}
      {credit && (
        <figcaption className="absolute bottom-1.5 right-2 max-w-[90%] truncate rounded bg-black/45 px-1.5 py-0.5 text-[10px] text-white/85">
          <a href={p.source} target="_blank" rel="noreferrer" className="hover:underline">{creditCourt(p)}</a>
        </figcaption>
      )}
    </figure>
  );
}
