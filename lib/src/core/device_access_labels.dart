String deviceAccessRoleLabel(String? linkRole) {
  switch (linkRole?.trim().toLowerCase()) {
    case 'owner':
      return 'Chủ thiết bị';
    case 'viewer':
      return 'Người xem';
    default:
      return 'Chưa cập nhật';
  }
}
