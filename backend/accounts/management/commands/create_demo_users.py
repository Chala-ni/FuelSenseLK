from django.core.management.base import BaseCommand

from accounts.models import User
from stations.models import Station


class Command(BaseCommand):
    help = "Create demo accounts for each role (password: DemoPass123)"

    DEMO_PASSWORD = "DemoPass123"

    def handle(self, *args, **options):
        station = Station.objects.order_by("id").first()
        if not station:
            self.stderr.write("No stations found. Run seed_stations first.")
            return

        demos = [
            ("driver@demo.fuelsense.lk", "demo_driver", User.Role.DRIVER, None),
            ("attendant@demo.fuelsense.lk", "demo_attendant", User.Role.ATTENDANT, station),
            ("manager@demo.fuelsense.lk", "demo_manager", User.Role.STATION_MANAGER, station),
            ("admin@demo.fuelsense.lk", "demo_admin", User.Role.ADMIN, None),
            ("superadmin@demo.fuelsense.lk", "demo_superadmin", User.Role.SUPER_ADMIN, None),
        ]

        for email, username, role, user_station in demos:
            user, created = User.objects.get_or_create(
                email=email,
                defaults={
                    "username": username,
                    "role": role,
                    "station": user_station,
                    "is_staff": role in (User.Role.ADMIN, User.Role.SUPER_ADMIN),
                    "is_superuser": role == User.Role.SUPER_ADMIN,
                },
            )
            if created:
                user.set_password(self.DEMO_PASSWORD)
                user.save()
                self.stdout.write(f"  Created {email} ({role})")
            else:
                user.role = role
                user.station = user_station
                user.set_password(self.DEMO_PASSWORD)
                user.save()
                self.stdout.write(f"  Updated {email} ({role})")

        self.stdout.write(self.style.SUCCESS(f"Demo users ready. Password: {self.DEMO_PASSWORD}"))
