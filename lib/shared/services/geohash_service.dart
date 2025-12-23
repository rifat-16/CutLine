class GeohashService {
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  String geohashFor({
    required double latitude,
    required double longitude,
    int precision = 10,
  }) {
    var latMin = -90.0;
    var latMax = 90.0;
    var lonMin = -180.0;
    var lonMax = 180.0;

    var isEvenBit = true;
    var bit = 0;
    var ch = 0;
    final buffer = StringBuffer();

    const bits = [16, 8, 4, 2, 1];
    while (buffer.length < precision) {
      if (isEvenBit) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          ch |= bits[bit];
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch |= bits[bit];
          latMin = mid;
        } else {
          latMax = mid;
        }
      }

      isEvenBit = !isEvenBit;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }
}
