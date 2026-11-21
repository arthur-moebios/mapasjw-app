/// Modelos de consulta do carrinho (calendário de turnos e minhas inscrições).
/// Somente leitura: o servidor (Laravel) é a fonte dos dados.
library;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(Map<String, dynamic>.from)
    .toList(growable: false);

class CartSpot {
  const CartSpot({required this.id, this.name = '', this.type});

  factory CartSpot.fromJson(Map<String, dynamic> json) => CartSpot(
    id: _int(json['id']),
    name: _text(json['name']) ?? 'Ponto',
    type: _text(json['type']),
  );

  final int id;
  final String name;
  final String? type;
}

class CartPerson {
  const CartPerson({
    this.firstName,
    this.role,
    this.freeTime = false,
    this.start,
    this.end,
  });

  factory CartPerson.fromJson(Map<String, dynamic> json) => CartPerson(
    firstName: _text(json['first_name']),
    role: _text(json['role']),
    freeTime: json['free_time'] == true,
    start: _text(json['start']),
    end: _text(json['end']),
  );

  final String? firstName;
  final String? role;
  final bool freeTime;
  final String? start;
  final String? end;
}

class CartShift {
  const CartShift({
    required this.key,
    this.spotId,
    this.spot = '',
    this.type,
    this.weekday,
    this.date,
    this.start,
    this.end,
    this.capacity = 0,
    this.occupied = 0,
    this.openSlots = 0,
    this.state = 'livre',
    this.pending = 0,
    this.people = const [],
  });

  factory CartShift.fromJson(Map<String, dynamic> json) => CartShift(
    key: _text(json['key']) ?? '',
    spotId: _intOrNull(json['spot_id']),
    spot: _text(json['spot']) ?? '',
    type: _text(json['type']),
    weekday: _text(json['weekday']) ?? (json['weekday'] is num ? '${json['weekday']}' : null),
    date: _text(json['date']),
    start: _text(json['start']),
    end: _text(json['end']),
    capacity: _int(json['capacity']),
    occupied: _int(json['occupied']),
    openSlots: _int(json['open_slots']),
    state: _text(json['state']) ?? 'livre',
    pending: _int(json['pending']),
    people: _maps(
      json['people'],
    ).map(CartPerson.fromJson).toList(growable: false),
  );

  final String key;
  final int? spotId;
  final String spot;

  /// `tpl` ou `tpe`.
  final String? type;
  final String? weekday;
  final String? date;
  final String? start;
  final String? end;
  final int capacity;
  final int occupied;
  final int openSlots;

  /// `livre`, `parcial`, `cheio` ou `buraco`.
  final String state;
  final int pending;
  final List<CartPerson> people;
}

class CartDay {
  const CartDay({
    required this.date,
    this.inMonth = true,
    this.today = false,
    this.past = false,
    this.openSlots = 0,
    this.shifts = const [],
  });

  factory CartDay.fromJson(Map<String, dynamic> json) => CartDay(
    date: _text(json['date']) ?? '',
    inMonth: json['in_month'] != false,
    today: json['today'] == true,
    past: json['past'] == true,
    openSlots: _int(json['open_slots']),
    shifts: _maps(
      json['shifts'],
    ).map(CartShift.fromJson).toList(growable: false),
  );

  final String date;
  final bool inMonth;
  final bool today;
  final bool past;
  final int openSlots;
  final List<CartShift> shifts;
}

class CartCalendar {
  const CartCalendar({
    required this.month,
    this.previousMonth,
    this.nextMonth,
    this.isCurrentMonth = false,
    this.filteredSpotId,
    this.hasShifts = false,
    this.spots = const [],
    this.days = const [],
  });

  factory CartCalendar.fromJson(Map<String, dynamic> json) => CartCalendar(
    month: _text(json['month']) ?? '',
    previousMonth: _text(json['previous_month']),
    nextMonth: _text(json['next_month']),
    isCurrentMonth: json['is_current_month'] == true,
    filteredSpotId: _intOrNull(json['filtered_spot_id']),
    hasShifts: json['has_shifts'] == true,
    spots: _maps(
      json['spots'],
    ).map(CartSpot.fromJson).toList(growable: false),
    days: _maps(json['days']).map(CartDay.fromJson).toList(growable: false),
  );

  final String month;
  final String? previousMonth;
  final String? nextMonth;
  final bool isCurrentMonth;
  final int? filteredSpotId;
  final bool hasShifts;
  final List<CartSpot> spots;
  final List<CartDay> days;
}

class CartSignup {
  const CartSignup({
    required this.id,
    this.status = 'pendente',
    this.role,
    this.weekly = false,
    this.date,
    this.weekday,
    this.start,
    this.end,
    this.spot,
  });

  factory CartSignup.fromJson(Map<String, dynamic> json) {
    final spot = json['spot'];
    return CartSignup(
      id: _int(json['id']),
      status: _text(json['status']) ?? 'pendente',
      role: _text(json['role']),
      weekly: json['weekly'] == true,
      date: _text(json['date']),
      weekday: _text(json['weekday']) ??
          (json['weekday'] is num ? '${json['weekday']}' : null),
      start: _text(json['start']),
      end: _text(json['end']),
      spot: spot is Map ? CartSignupSpot.fromJson(Map<String, dynamic>.from(spot)) : null,
    );
  }

  final int id;

  /// `pendente`, `aprovada` ou `recusada`.
  final String status;
  final String? role;
  final bool weekly;
  final String? date;
  final String? weekday;
  final String? start;
  final String? end;
  final CartSignupSpot? spot;
}

class CartSignupSpot {
  const CartSignupSpot({
    required this.id,
    this.name = '',
    this.address,
    this.type,
  });

  factory CartSignupSpot.fromJson(Map<String, dynamic> json) => CartSignupSpot(
    id: _int(json['id']),
    name: _text(json['name']) ?? 'Ponto',
    address: _text(json['address']),
    type: _text(json['type']),
  );

  final int id;
  final String name;
  final String? address;
  final String? type;
}

class CartMySignups {
  const CartMySignups({this.linked = false, this.signups = const []});

  factory CartMySignups.fromJson(Map<String, dynamic> json) => CartMySignups(
    linked: json['linked'] == true,
    signups: _maps(
      json['signups'],
    ).map(CartSignup.fromJson).toList(growable: false),
  );

  final bool linked;
  final List<CartSignup> signups;
}
