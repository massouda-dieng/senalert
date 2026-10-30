from django.db import migrations


class Migration(migrations.Migration):
    """Renommage sans perte : AlerteSOS.user devient AlerteSOS.citoyen."""

    dependencies = [('alerts', '0002_alter_alertesos_user')]

    operations = [
        migrations.RenameField(model_name='alertesos', old_name='user', new_name='citoyen'),
    ]
