import logging
import re

_MOTIFS = [
    (re.compile(r'(?i)bearer\s+[a-z0-9._\-]+'), 'Bearer [masqué]'),
    (re.compile(r'(?i)(password|mot_de_passe|token|secret|api[_-]?key|authorization)(["\']?\s*[:=]\s*["\']?)([^"\'\s,}]+)'), r'\1\2[masqué]'),
    (re.compile(r'gsk_[A-Za-z0-9]+'), 'gsk_[masqué]'),
]


def masquer(texte: str) -> str:
    for motif, remplacement in _MOTIFS:
        texte = motif.sub(remplacement, texte)
    return texte


class RedactionSecrets(logging.Filter):
    """Masque les mots de passe, jetons et clés avant l'écriture d'un log."""

    def filter(self, record):
        try:
            message = record.getMessage()
        except Exception:
            return True
        nettoye = masquer(message)
        if nettoye != message:
            record.msg = nettoye
            record.args = ()
        return True
