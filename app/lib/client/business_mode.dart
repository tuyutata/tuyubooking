/// Business capabilities that can be enabled in a TuyuBooking client.
enum BusinessMode {
  hotel('hotel'),
  restaurant('restaurant'),
  tour('tour'),
  ticket('ticket');

  const BusinessMode(this.code);

  final String code;

  static BusinessMode? tryParse(String code) {
    for (final mode in values) {
      if (mode.code == code) {
        return mode;
      }
    }
    return null;
  }
}
