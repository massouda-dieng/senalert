from django.db import migrations


class Migration(migrations.Migration):
    """Le modèle Autorite est remplacé par AgentProfil (données copiées en 0005)."""

    dependencies = [('accounts', '0005_migration_roles_et_agents')]
    operations = [
        migrations.RemoveField(model_name='autorite', name='user'),
        migrations.DeleteModel(name='Autorite'),
    ]
