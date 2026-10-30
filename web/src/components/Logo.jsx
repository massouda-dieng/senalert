export function Logo({ className }) {
  return (
    <svg viewBox="0 0 64 64" className={className} role="img" aria-label="SenAlert">
      <rect width="64" height="64" rx="16" fill="#0B1F4D" />
      <path d="M32 12 50 20v12c0 11-7.6 18.6-18 21-10.4-2.4-18-10-18-21V20z" fill="none" stroke="#fff" strokeWidth="4" strokeLinejoin="round" />
      <path d="M32 23v12" stroke="#E11D48" strokeWidth="5" strokeLinecap="round" />
      <circle cx="32" cy="42" r="3" fill="#E11D48" />
    </svg>
  );
}
