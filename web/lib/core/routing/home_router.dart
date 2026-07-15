import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/manager/manager_shell.dart';

bool isAdminRole(String? role) => role == 'admin' || role == 'super_admin';

bool isManagerWebRole(String? role) =>
    role == 'station_manager' || role == 'admin' || role == 'super_admin';

Widget homeForRole(ApiClient api, String? role) {
  if (isAdminRole(role)) return AdminShell(api: api);
  return ManagerShell(api: api);
}
