from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("stations", "0002_station_address_station_tank_capacities_stocklevel"),
    ]

    operations = [
        migrations.AddField(
            model_name="station",
            name="ml_station_id",
            field=models.PositiveIntegerField(blank=True, null=True, unique=True),
        ),
    ]
