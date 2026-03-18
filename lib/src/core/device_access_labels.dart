String deviceAccessRoleLabel(String? linkRole) {
  switch (linkRole?.trim().toLowerCase()) {
    case 'owner':
      return 'Chu thiet bi';
    case 'viewer':
    case 'caregiver':
      return 'Nguoi xem';
    default:
      return 'Chua cap nhat';
  }
}
