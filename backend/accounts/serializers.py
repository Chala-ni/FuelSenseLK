from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("id", "email", "username", "password", "first_name", "last_name")
        read_only_fields = ("id",)

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data, role=User.Role.DRIVER)
        user.set_password(password)
        user.save()
        return user


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "username",
            "first_name",
            "last_name",
            "role",
            "station",
            "fcm_token",
            "notification_preferences",
            "is_active",
            "date_joined",
        )
        read_only_fields = ("id", "role", "date_joined")


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("first_name", "last_name", "fcm_token", "notification_preferences")


class AdminUserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    role = serializers.ChoiceField(choices=User.Role.choices)

    class Meta:
        model = User
        fields = ("id", "email", "username", "password", "role", "station", "first_name", "last_name")
        read_only_fields = ("id",)

    def validate(self, attrs):
        role = attrs.get("role")
        station = attrs.get("station")
        request = self.context["request"]
        creator = request.user

        if role == User.Role.SUPER_ADMIN and creator.role != User.Role.SUPER_ADMIN:
            raise serializers.ValidationError("Only super admins can create super admin accounts.")
        if role == User.Role.ADMIN and creator.role not in (User.Role.ADMIN, User.Role.SUPER_ADMIN):
            raise serializers.ValidationError("Insufficient permission to create admin accounts.")
        if role in (User.Role.ATTENDANT, User.Role.STATION_MANAGER) and not station:
            raise serializers.ValidationError("Station is required for attendant and station manager accounts.")
        if creator.role == User.Role.STATION_MANAGER:
            if role != User.Role.ATTENDANT:
                raise serializers.ValidationError("Managers can only create attendant accounts.")
            if station != creator.station:
                raise serializers.ValidationError("Managers can only create staff for their own station.")
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user
