// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TrialsTable extends Trials with TableInfo<$TrialsTable, Trial> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _cropMeta = const VerificationMeta('crop');
  @override
  late final GeneratedColumn<String> crop = GeneratedColumn<String>(
      'crop', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
      'season', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, crop, location, season, status, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trials';
  @override
  VerificationContext validateIntegrity(Insertable<Trial> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('crop')) {
      context.handle(
          _cropMeta, crop.isAcceptableOrUnknown(data['crop']!, _cropMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('season')) {
      context.handle(_seasonMeta,
          season.isAcceptableOrUnknown(data['season']!, _seasonMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trial map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trial(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      crop: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}crop']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      season: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}season']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TrialsTable createAlias(String alias) {
    return $TrialsTable(attachedDatabase, alias);
  }
}

class Trial extends DataClass implements Insertable<Trial> {
  final int id;
  final String name;
  final String? crop;
  final String? location;
  final String? season;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Trial(
      {required this.id,
      required this.name,
      this.crop,
      this.location,
      this.season,
      required this.status,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || crop != null) {
      map['crop'] = Variable<String>(crop);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<String>(season);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrialsCompanion toCompanion(bool nullToAbsent) {
    return TrialsCompanion(
      id: Value(id),
      name: Value(name),
      crop: crop == null && nullToAbsent ? const Value.absent() : Value(crop),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      season:
          season == null && nullToAbsent ? const Value.absent() : Value(season),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Trial.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trial(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      crop: serializer.fromJson<String?>(json['crop']),
      location: serializer.fromJson<String?>(json['location']),
      season: serializer.fromJson<String?>(json['season']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'crop': serializer.toJson<String?>(crop),
      'location': serializer.toJson<String?>(location),
      'season': serializer.toJson<String?>(season),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Trial copyWith(
          {int? id,
          String? name,
          Value<String?> crop = const Value.absent(),
          Value<String?> location = const Value.absent(),
          Value<String?> season = const Value.absent(),
          String? status,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Trial(
        id: id ?? this.id,
        name: name ?? this.name,
        crop: crop.present ? crop.value : this.crop,
        location: location.present ? location.value : this.location,
        season: season.present ? season.value : this.season,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Trial copyWithCompanion(TrialsCompanion data) {
    return Trial(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      crop: data.crop.present ? data.crop.value : this.crop,
      location: data.location.present ? data.location.value : this.location,
      season: data.season.present ? data.season.value : this.season,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trial(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('crop: $crop, ')
          ..write('location: $location, ')
          ..write('season: $season, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, crop, location, season, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trial &&
          other.id == this.id &&
          other.name == this.name &&
          other.crop == this.crop &&
          other.location == this.location &&
          other.season == this.season &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TrialsCompanion extends UpdateCompanion<Trial> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> crop;
  final Value<String?> location;
  final Value<String?> season;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TrialsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.crop = const Value.absent(),
    this.location = const Value.absent(),
    this.season = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TrialsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.crop = const Value.absent(),
    this.location = const Value.absent(),
    this.season = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Trial> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? crop,
    Expression<String>? location,
    Expression<String>? season,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (crop != null) 'crop': crop,
      if (location != null) 'location': location,
      if (season != null) 'season': season,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TrialsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? crop,
      Value<String?>? location,
      Value<String?>? season,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return TrialsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      crop: crop ?? this.crop,
      location: location ?? this.location,
      season: season ?? this.season,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (crop.present) {
      map['crop'] = Variable<String>(crop.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrialsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('crop: $crop, ')
          ..write('location: $location, ')
          ..write('season: $season, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TreatmentsTable extends Treatments
    with TableInfo<$TreatmentsTable, Treatment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TreatmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, trialId, code, name, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'treatments';
  @override
  VerificationContext validateIntegrity(Insertable<Treatment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Treatment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Treatment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
    );
  }

  @override
  $TreatmentsTable createAlias(String alias) {
    return $TreatmentsTable(attachedDatabase, alias);
  }
}

class Treatment extends DataClass implements Insertable<Treatment> {
  final int id;
  final int trialId;
  final String code;
  final String name;
  final String? description;
  const Treatment(
      {required this.id,
      required this.trialId,
      required this.code,
      required this.name,
      this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  TreatmentsCompanion toCompanion(bool nullToAbsent) {
    return TreatmentsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      code: Value(code),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory Treatment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Treatment(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
    };
  }

  Treatment copyWith(
          {int? id,
          int? trialId,
          String? code,
          String? name,
          Value<String?> description = const Value.absent()}) =>
      Treatment(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        code: code ?? this.code,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
      );
  Treatment copyWithCompanion(TreatmentsCompanion data) {
    return Treatment(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Treatment(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, code, name, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Treatment &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.code == this.code &&
          other.name == this.name &&
          other.description == this.description);
}

class TreatmentsCompanion extends UpdateCompanion<Treatment> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> code;
  final Value<String> name;
  final Value<String?> description;
  const TreatmentsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
  });
  TreatmentsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String code,
    required String name,
    this.description = const Value.absent(),
  })  : trialId = Value(trialId),
        code = Value(code),
        name = Value(name);
  static Insertable<Treatment> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  TreatmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? code,
      Value<String>? name,
      Value<String?>? description}) {
    return TreatmentsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TreatmentsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $TreatmentComponentsTable extends TreatmentComponents
    with TableInfo<$TreatmentComponentsTable, TreatmentComponent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TreatmentComponentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _treatmentIdMeta =
      const VerificationMeta('treatmentId');
  @override
  late final GeneratedColumn<int> treatmentId = GeneratedColumn<int>(
      'treatment_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES treatments (id)'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
      'rate', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rateUnitMeta =
      const VerificationMeta('rateUnit');
  @override
  late final GeneratedColumn<String> rateUnit = GeneratedColumn<String>(
      'rate_unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _applicationTimingMeta =
      const VerificationMeta('applicationTiming');
  @override
  late final GeneratedColumn<String> applicationTiming =
      GeneratedColumn<String>('application_timing', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        treatmentId,
        trialId,
        productName,
        rate,
        rateUnit,
        applicationTiming,
        notes,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'treatment_components';
  @override
  VerificationContext validateIntegrity(Insertable<TreatmentComponent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('treatment_id')) {
      context.handle(
          _treatmentIdMeta,
          treatmentId.isAcceptableOrUnknown(
              data['treatment_id']!, _treatmentIdMeta));
    } else if (isInserting) {
      context.missing(_treatmentIdMeta);
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
          _rateMeta, rate.isAcceptableOrUnknown(data['rate']!, _rateMeta));
    }
    if (data.containsKey('rate_unit')) {
      context.handle(_rateUnitMeta,
          rateUnit.isAcceptableOrUnknown(data['rate_unit']!, _rateUnitMeta));
    }
    if (data.containsKey('application_timing')) {
      context.handle(
          _applicationTimingMeta,
          applicationTiming.isAcceptableOrUnknown(
              data['application_timing']!, _applicationTimingMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TreatmentComponent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TreatmentComponent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      treatmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}treatment_id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      rate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rate']),
      rateUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rate_unit']),
      applicationTiming: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}application_timing']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $TreatmentComponentsTable createAlias(String alias) {
    return $TreatmentComponentsTable(attachedDatabase, alias);
  }
}

class TreatmentComponent extends DataClass
    implements Insertable<TreatmentComponent> {
  final int id;
  final int treatmentId;
  final int trialId;
  final String productName;
  final String? rate;
  final String? rateUnit;
  final String? applicationTiming;
  final String? notes;
  final int sortOrder;
  const TreatmentComponent(
      {required this.id,
      required this.treatmentId,
      required this.trialId,
      required this.productName,
      this.rate,
      this.rateUnit,
      this.applicationTiming,
      this.notes,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['treatment_id'] = Variable<int>(treatmentId);
    map['trial_id'] = Variable<int>(trialId);
    map['product_name'] = Variable<String>(productName);
    if (!nullToAbsent || rate != null) {
      map['rate'] = Variable<String>(rate);
    }
    if (!nullToAbsent || rateUnit != null) {
      map['rate_unit'] = Variable<String>(rateUnit);
    }
    if (!nullToAbsent || applicationTiming != null) {
      map['application_timing'] = Variable<String>(applicationTiming);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TreatmentComponentsCompanion toCompanion(bool nullToAbsent) {
    return TreatmentComponentsCompanion(
      id: Value(id),
      treatmentId: Value(treatmentId),
      trialId: Value(trialId),
      productName: Value(productName),
      rate: rate == null && nullToAbsent ? const Value.absent() : Value(rate),
      rateUnit: rateUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(rateUnit),
      applicationTiming: applicationTiming == null && nullToAbsent
          ? const Value.absent()
          : Value(applicationTiming),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      sortOrder: Value(sortOrder),
    );
  }

  factory TreatmentComponent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TreatmentComponent(
      id: serializer.fromJson<int>(json['id']),
      treatmentId: serializer.fromJson<int>(json['treatmentId']),
      trialId: serializer.fromJson<int>(json['trialId']),
      productName: serializer.fromJson<String>(json['productName']),
      rate: serializer.fromJson<String?>(json['rate']),
      rateUnit: serializer.fromJson<String?>(json['rateUnit']),
      applicationTiming:
          serializer.fromJson<String?>(json['applicationTiming']),
      notes: serializer.fromJson<String?>(json['notes']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'treatmentId': serializer.toJson<int>(treatmentId),
      'trialId': serializer.toJson<int>(trialId),
      'productName': serializer.toJson<String>(productName),
      'rate': serializer.toJson<String?>(rate),
      'rateUnit': serializer.toJson<String?>(rateUnit),
      'applicationTiming': serializer.toJson<String?>(applicationTiming),
      'notes': serializer.toJson<String?>(notes),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TreatmentComponent copyWith(
          {int? id,
          int? treatmentId,
          int? trialId,
          String? productName,
          Value<String?> rate = const Value.absent(),
          Value<String?> rateUnit = const Value.absent(),
          Value<String?> applicationTiming = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          int? sortOrder}) =>
      TreatmentComponent(
        id: id ?? this.id,
        treatmentId: treatmentId ?? this.treatmentId,
        trialId: trialId ?? this.trialId,
        productName: productName ?? this.productName,
        rate: rate.present ? rate.value : this.rate,
        rateUnit: rateUnit.present ? rateUnit.value : this.rateUnit,
        applicationTiming: applicationTiming.present
            ? applicationTiming.value
            : this.applicationTiming,
        notes: notes.present ? notes.value : this.notes,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  TreatmentComponent copyWithCompanion(TreatmentComponentsCompanion data) {
    return TreatmentComponent(
      id: data.id.present ? data.id.value : this.id,
      treatmentId:
          data.treatmentId.present ? data.treatmentId.value : this.treatmentId,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      rate: data.rate.present ? data.rate.value : this.rate,
      rateUnit: data.rateUnit.present ? data.rateUnit.value : this.rateUnit,
      applicationTiming: data.applicationTiming.present
          ? data.applicationTiming.value
          : this.applicationTiming,
      notes: data.notes.present ? data.notes.value : this.notes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TreatmentComponent(')
          ..write('id: $id, ')
          ..write('treatmentId: $treatmentId, ')
          ..write('trialId: $trialId, ')
          ..write('productName: $productName, ')
          ..write('rate: $rate, ')
          ..write('rateUnit: $rateUnit, ')
          ..write('applicationTiming: $applicationTiming, ')
          ..write('notes: $notes, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, treatmentId, trialId, productName, rate,
      rateUnit, applicationTiming, notes, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TreatmentComponent &&
          other.id == this.id &&
          other.treatmentId == this.treatmentId &&
          other.trialId == this.trialId &&
          other.productName == this.productName &&
          other.rate == this.rate &&
          other.rateUnit == this.rateUnit &&
          other.applicationTiming == this.applicationTiming &&
          other.notes == this.notes &&
          other.sortOrder == this.sortOrder);
}

class TreatmentComponentsCompanion extends UpdateCompanion<TreatmentComponent> {
  final Value<int> id;
  final Value<int> treatmentId;
  final Value<int> trialId;
  final Value<String> productName;
  final Value<String?> rate;
  final Value<String?> rateUnit;
  final Value<String?> applicationTiming;
  final Value<String?> notes;
  final Value<int> sortOrder;
  const TreatmentComponentsCompanion({
    this.id = const Value.absent(),
    this.treatmentId = const Value.absent(),
    this.trialId = const Value.absent(),
    this.productName = const Value.absent(),
    this.rate = const Value.absent(),
    this.rateUnit = const Value.absent(),
    this.applicationTiming = const Value.absent(),
    this.notes = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  TreatmentComponentsCompanion.insert({
    this.id = const Value.absent(),
    required int treatmentId,
    required int trialId,
    required String productName,
    this.rate = const Value.absent(),
    this.rateUnit = const Value.absent(),
    this.applicationTiming = const Value.absent(),
    this.notes = const Value.absent(),
    this.sortOrder = const Value.absent(),
  })  : treatmentId = Value(treatmentId),
        trialId = Value(trialId),
        productName = Value(productName);
  static Insertable<TreatmentComponent> custom({
    Expression<int>? id,
    Expression<int>? treatmentId,
    Expression<int>? trialId,
    Expression<String>? productName,
    Expression<String>? rate,
    Expression<String>? rateUnit,
    Expression<String>? applicationTiming,
    Expression<String>? notes,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (treatmentId != null) 'treatment_id': treatmentId,
      if (trialId != null) 'trial_id': trialId,
      if (productName != null) 'product_name': productName,
      if (rate != null) 'rate': rate,
      if (rateUnit != null) 'rate_unit': rateUnit,
      if (applicationTiming != null) 'application_timing': applicationTiming,
      if (notes != null) 'notes': notes,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  TreatmentComponentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? treatmentId,
      Value<int>? trialId,
      Value<String>? productName,
      Value<String?>? rate,
      Value<String?>? rateUnit,
      Value<String?>? applicationTiming,
      Value<String?>? notes,
      Value<int>? sortOrder}) {
    return TreatmentComponentsCompanion(
      id: id ?? this.id,
      treatmentId: treatmentId ?? this.treatmentId,
      trialId: trialId ?? this.trialId,
      productName: productName ?? this.productName,
      rate: rate ?? this.rate,
      rateUnit: rateUnit ?? this.rateUnit,
      applicationTiming: applicationTiming ?? this.applicationTiming,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (treatmentId.present) {
      map['treatment_id'] = Variable<int>(treatmentId.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (rateUnit.present) {
      map['rate_unit'] = Variable<String>(rateUnit.value);
    }
    if (applicationTiming.present) {
      map['application_timing'] = Variable<String>(applicationTiming.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TreatmentComponentsCompanion(')
          ..write('id: $id, ')
          ..write('treatmentId: $treatmentId, ')
          ..write('trialId: $trialId, ')
          ..write('productName: $productName, ')
          ..write('rate: $rate, ')
          ..write('rateUnit: $rateUnit, ')
          ..write('applicationTiming: $applicationTiming, ')
          ..write('notes: $notes, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $AssessmentsTable extends Assessments
    with TableInfo<$AssessmentsTable, Assessment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssessmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _dataTypeMeta =
      const VerificationMeta('dataType');
  @override
  late final GeneratedColumn<String> dataType = GeneratedColumn<String>(
      'data_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('numeric'));
  static const VerificationMeta _minValueMeta =
      const VerificationMeta('minValue');
  @override
  late final GeneratedColumn<double> minValue = GeneratedColumn<double>(
      'min_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _maxValueMeta =
      const VerificationMeta('maxValue');
  @override
  late final GeneratedColumn<double> maxValue = GeneratedColumn<double>(
      'max_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns =>
      [id, trialId, name, dataType, minValue, maxValue, unit, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assessments';
  @override
  VerificationContext validateIntegrity(Insertable<Assessment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('data_type')) {
      context.handle(_dataTypeMeta,
          dataType.isAcceptableOrUnknown(data['data_type']!, _dataTypeMeta));
    }
    if (data.containsKey('min_value')) {
      context.handle(_minValueMeta,
          minValue.isAcceptableOrUnknown(data['min_value']!, _minValueMeta));
    }
    if (data.containsKey('max_value')) {
      context.handle(_maxValueMeta,
          maxValue.isAcceptableOrUnknown(data['max_value']!, _maxValueMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Assessment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Assessment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      dataType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_type'])!,
      minValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}min_value']),
      maxValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}max_value']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $AssessmentsTable createAlias(String alias) {
    return $AssessmentsTable(attachedDatabase, alias);
  }
}

class Assessment extends DataClass implements Insertable<Assessment> {
  final int id;
  final int trialId;
  final String name;
  final String dataType;
  final double? minValue;
  final double? maxValue;
  final String? unit;
  final bool isActive;
  const Assessment(
      {required this.id,
      required this.trialId,
      required this.name,
      required this.dataType,
      this.minValue,
      this.maxValue,
      this.unit,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['name'] = Variable<String>(name);
    map['data_type'] = Variable<String>(dataType);
    if (!nullToAbsent || minValue != null) {
      map['min_value'] = Variable<double>(minValue);
    }
    if (!nullToAbsent || maxValue != null) {
      map['max_value'] = Variable<double>(maxValue);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  AssessmentsCompanion toCompanion(bool nullToAbsent) {
    return AssessmentsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      name: Value(name),
      dataType: Value(dataType),
      minValue: minValue == null && nullToAbsent
          ? const Value.absent()
          : Value(minValue),
      maxValue: maxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(maxValue),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      isActive: Value(isActive),
    );
  }

  factory Assessment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Assessment(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      name: serializer.fromJson<String>(json['name']),
      dataType: serializer.fromJson<String>(json['dataType']),
      minValue: serializer.fromJson<double?>(json['minValue']),
      maxValue: serializer.fromJson<double?>(json['maxValue']),
      unit: serializer.fromJson<String?>(json['unit']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'name': serializer.toJson<String>(name),
      'dataType': serializer.toJson<String>(dataType),
      'minValue': serializer.toJson<double?>(minValue),
      'maxValue': serializer.toJson<double?>(maxValue),
      'unit': serializer.toJson<String?>(unit),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Assessment copyWith(
          {int? id,
          int? trialId,
          String? name,
          String? dataType,
          Value<double?> minValue = const Value.absent(),
          Value<double?> maxValue = const Value.absent(),
          Value<String?> unit = const Value.absent(),
          bool? isActive}) =>
      Assessment(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        name: name ?? this.name,
        dataType: dataType ?? this.dataType,
        minValue: minValue.present ? minValue.value : this.minValue,
        maxValue: maxValue.present ? maxValue.value : this.maxValue,
        unit: unit.present ? unit.value : this.unit,
        isActive: isActive ?? this.isActive,
      );
  Assessment copyWithCompanion(AssessmentsCompanion data) {
    return Assessment(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      name: data.name.present ? data.name.value : this.name,
      dataType: data.dataType.present ? data.dataType.value : this.dataType,
      minValue: data.minValue.present ? data.minValue.value : this.minValue,
      maxValue: data.maxValue.present ? data.maxValue.value : this.maxValue,
      unit: data.unit.present ? data.unit.value : this.unit,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Assessment(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('name: $name, ')
          ..write('dataType: $dataType, ')
          ..write('minValue: $minValue, ')
          ..write('maxValue: $maxValue, ')
          ..write('unit: $unit, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, trialId, name, dataType, minValue, maxValue, unit, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Assessment &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.name == this.name &&
          other.dataType == this.dataType &&
          other.minValue == this.minValue &&
          other.maxValue == this.maxValue &&
          other.unit == this.unit &&
          other.isActive == this.isActive);
}

class AssessmentsCompanion extends UpdateCompanion<Assessment> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> name;
  final Value<String> dataType;
  final Value<double?> minValue;
  final Value<double?> maxValue;
  final Value<String?> unit;
  final Value<bool> isActive;
  const AssessmentsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.name = const Value.absent(),
    this.dataType = const Value.absent(),
    this.minValue = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  AssessmentsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String name,
    this.dataType = const Value.absent(),
    this.minValue = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.isActive = const Value.absent(),
  })  : trialId = Value(trialId),
        name = Value(name);
  static Insertable<Assessment> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? name,
    Expression<String>? dataType,
    Expression<double>? minValue,
    Expression<double>? maxValue,
    Expression<String>? unit,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (name != null) 'name': name,
      if (dataType != null) 'data_type': dataType,
      if (minValue != null) 'min_value': minValue,
      if (maxValue != null) 'max_value': maxValue,
      if (unit != null) 'unit': unit,
      if (isActive != null) 'is_active': isActive,
    });
  }

  AssessmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? name,
      Value<String>? dataType,
      Value<double?>? minValue,
      Value<double?>? maxValue,
      Value<String?>? unit,
      Value<bool>? isActive}) {
    return AssessmentsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dataType.present) {
      map['data_type'] = Variable<String>(dataType.value);
    }
    if (minValue.present) {
      map['min_value'] = Variable<double>(minValue.value);
    }
    if (maxValue.present) {
      map['max_value'] = Variable<double>(maxValue.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('name: $name, ')
          ..write('dataType: $dataType, ')
          ..write('minValue: $minValue, ')
          ..write('maxValue: $maxValue, ')
          ..write('unit: $unit, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $PlotsTable extends Plots with TableInfo<$PlotsTable, Plot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotIdMeta = const VerificationMeta('plotId');
  @override
  late final GeneratedColumn<String> plotId = GeneratedColumn<String>(
      'plot_id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _plotSortIndexMeta =
      const VerificationMeta('plotSortIndex');
  @override
  late final GeneratedColumn<int> plotSortIndex = GeneratedColumn<int>(
      'plot_sort_index', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _repMeta = const VerificationMeta('rep');
  @override
  late final GeneratedColumn<int> rep = GeneratedColumn<int>(
      'rep', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _treatmentIdMeta =
      const VerificationMeta('treatmentId');
  @override
  late final GeneratedColumn<int> treatmentId = GeneratedColumn<int>(
      'treatment_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES treatments (id)'));
  static const VerificationMeta _rowMeta = const VerificationMeta('row');
  @override
  late final GeneratedColumn<String> row = GeneratedColumn<String>(
      'row', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _columnMeta = const VerificationMeta('column');
  @override
  late final GeneratedColumn<String> column = GeneratedColumn<String>(
      'column', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotId,
        plotSortIndex,
        rep,
        treatmentId,
        row,
        column,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plots';
  @override
  VerificationContext validateIntegrity(Insertable<Plot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_id')) {
      context.handle(_plotIdMeta,
          plotId.isAcceptableOrUnknown(data['plot_id']!, _plotIdMeta));
    } else if (isInserting) {
      context.missing(_plotIdMeta);
    }
    if (data.containsKey('plot_sort_index')) {
      context.handle(
          _plotSortIndexMeta,
          plotSortIndex.isAcceptableOrUnknown(
              data['plot_sort_index']!, _plotSortIndexMeta));
    }
    if (data.containsKey('rep')) {
      context.handle(
          _repMeta, rep.isAcceptableOrUnknown(data['rep']!, _repMeta));
    }
    if (data.containsKey('treatment_id')) {
      context.handle(
          _treatmentIdMeta,
          treatmentId.isAcceptableOrUnknown(
              data['treatment_id']!, _treatmentIdMeta));
    }
    if (data.containsKey('row')) {
      context.handle(
          _rowMeta, row.isAcceptableOrUnknown(data['row']!, _rowMeta));
    }
    if (data.containsKey('column')) {
      context.handle(_columnMeta,
          column.isAcceptableOrUnknown(data['column']!, _columnMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plot_id'])!,
      plotSortIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_sort_index']),
      rep: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rep']),
      treatmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}treatment_id']),
      row: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}row']),
      column: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}column']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $PlotsTable createAlias(String alias) {
    return $PlotsTable(attachedDatabase, alias);
  }
}

class Plot extends DataClass implements Insertable<Plot> {
  final int id;
  final int trialId;
  final String plotId;
  final int? plotSortIndex;
  final int? rep;
  final int? treatmentId;
  final String? row;
  final String? column;
  final String? notes;
  const Plot(
      {required this.id,
      required this.trialId,
      required this.plotId,
      this.plotSortIndex,
      this.rep,
      this.treatmentId,
      this.row,
      this.column,
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_id'] = Variable<String>(plotId);
    if (!nullToAbsent || plotSortIndex != null) {
      map['plot_sort_index'] = Variable<int>(plotSortIndex);
    }
    if (!nullToAbsent || rep != null) {
      map['rep'] = Variable<int>(rep);
    }
    if (!nullToAbsent || treatmentId != null) {
      map['treatment_id'] = Variable<int>(treatmentId);
    }
    if (!nullToAbsent || row != null) {
      map['row'] = Variable<String>(row);
    }
    if (!nullToAbsent || column != null) {
      map['column'] = Variable<String>(column);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  PlotsCompanion toCompanion(bool nullToAbsent) {
    return PlotsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotId: Value(plotId),
      plotSortIndex: plotSortIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(plotSortIndex),
      rep: rep == null && nullToAbsent ? const Value.absent() : Value(rep),
      treatmentId: treatmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(treatmentId),
      row: row == null && nullToAbsent ? const Value.absent() : Value(row),
      column:
          column == null && nullToAbsent ? const Value.absent() : Value(column),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory Plot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plot(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotId: serializer.fromJson<String>(json['plotId']),
      plotSortIndex: serializer.fromJson<int?>(json['plotSortIndex']),
      rep: serializer.fromJson<int?>(json['rep']),
      treatmentId: serializer.fromJson<int?>(json['treatmentId']),
      row: serializer.fromJson<String?>(json['row']),
      column: serializer.fromJson<String?>(json['column']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotId': serializer.toJson<String>(plotId),
      'plotSortIndex': serializer.toJson<int?>(plotSortIndex),
      'rep': serializer.toJson<int?>(rep),
      'treatmentId': serializer.toJson<int?>(treatmentId),
      'row': serializer.toJson<String?>(row),
      'column': serializer.toJson<String?>(column),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Plot copyWith(
          {int? id,
          int? trialId,
          String? plotId,
          Value<int?> plotSortIndex = const Value.absent(),
          Value<int?> rep = const Value.absent(),
          Value<int?> treatmentId = const Value.absent(),
          Value<String?> row = const Value.absent(),
          Value<String?> column = const Value.absent(),
          Value<String?> notes = const Value.absent()}) =>
      Plot(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotId: plotId ?? this.plotId,
        plotSortIndex:
            plotSortIndex.present ? plotSortIndex.value : this.plotSortIndex,
        rep: rep.present ? rep.value : this.rep,
        treatmentId: treatmentId.present ? treatmentId.value : this.treatmentId,
        row: row.present ? row.value : this.row,
        column: column.present ? column.value : this.column,
        notes: notes.present ? notes.value : this.notes,
      );
  Plot copyWithCompanion(PlotsCompanion data) {
    return Plot(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotId: data.plotId.present ? data.plotId.value : this.plotId,
      plotSortIndex: data.plotSortIndex.present
          ? data.plotSortIndex.value
          : this.plotSortIndex,
      rep: data.rep.present ? data.rep.value : this.rep,
      treatmentId:
          data.treatmentId.present ? data.treatmentId.value : this.treatmentId,
      row: data.row.present ? data.row.value : this.row,
      column: data.column.present ? data.column.value : this.column,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plot(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotId: $plotId, ')
          ..write('plotSortIndex: $plotSortIndex, ')
          ..write('rep: $rep, ')
          ..write('treatmentId: $treatmentId, ')
          ..write('row: $row, ')
          ..write('column: $column, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, trialId, plotId, plotSortIndex, rep, treatmentId, row, column, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plot &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotId == this.plotId &&
          other.plotSortIndex == this.plotSortIndex &&
          other.rep == this.rep &&
          other.treatmentId == this.treatmentId &&
          other.row == this.row &&
          other.column == this.column &&
          other.notes == this.notes);
}

class PlotsCompanion extends UpdateCompanion<Plot> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> plotId;
  final Value<int?> plotSortIndex;
  final Value<int?> rep;
  final Value<int?> treatmentId;
  final Value<String?> row;
  final Value<String?> column;
  final Value<String?> notes;
  const PlotsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotId = const Value.absent(),
    this.plotSortIndex = const Value.absent(),
    this.rep = const Value.absent(),
    this.treatmentId = const Value.absent(),
    this.row = const Value.absent(),
    this.column = const Value.absent(),
    this.notes = const Value.absent(),
  });
  PlotsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String plotId,
    this.plotSortIndex = const Value.absent(),
    this.rep = const Value.absent(),
    this.treatmentId = const Value.absent(),
    this.row = const Value.absent(),
    this.column = const Value.absent(),
    this.notes = const Value.absent(),
  })  : trialId = Value(trialId),
        plotId = Value(plotId);
  static Insertable<Plot> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? plotId,
    Expression<int>? plotSortIndex,
    Expression<int>? rep,
    Expression<int>? treatmentId,
    Expression<String>? row,
    Expression<String>? column,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotId != null) 'plot_id': plotId,
      if (plotSortIndex != null) 'plot_sort_index': plotSortIndex,
      if (rep != null) 'rep': rep,
      if (treatmentId != null) 'treatment_id': treatmentId,
      if (row != null) 'row': row,
      if (column != null) 'column': column,
      if (notes != null) 'notes': notes,
    });
  }

  PlotsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? plotId,
      Value<int?>? plotSortIndex,
      Value<int?>? rep,
      Value<int?>? treatmentId,
      Value<String?>? row,
      Value<String?>? column,
      Value<String?>? notes}) {
    return PlotsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotId: plotId ?? this.plotId,
      plotSortIndex: plotSortIndex ?? this.plotSortIndex,
      rep: rep ?? this.rep,
      treatmentId: treatmentId ?? this.treatmentId,
      row: row ?? this.row,
      column: column ?? this.column,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotId.present) {
      map['plot_id'] = Variable<String>(plotId.value);
    }
    if (plotSortIndex.present) {
      map['plot_sort_index'] = Variable<int>(plotSortIndex.value);
    }
    if (rep.present) {
      map['rep'] = Variable<int>(rep.value);
    }
    if (treatmentId.present) {
      map['treatment_id'] = Variable<int>(treatmentId.value);
    }
    if (row.present) {
      map['row'] = Variable<String>(row.value);
    }
    if (column.present) {
      map['column'] = Variable<String>(column.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlotsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotId: $plotId, ')
          ..write('plotSortIndex: $plotSortIndex, ')
          ..write('rep: $rep, ')
          ..write('treatmentId: $treatmentId, ')
          ..write('row: $row, ')
          ..write('column: $column, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sessionDateLocalMeta =
      const VerificationMeta('sessionDateLocal');
  @override
  late final GeneratedColumn<String> sessionDateLocal = GeneratedColumn<String>(
      'session_date_local', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _raterNameMeta =
      const VerificationMeta('raterName');
  @override
  late final GeneratedColumn<String> raterName = GeneratedColumn<String>(
      'rater_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('open'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        name,
        startedAt,
        endedAt,
        sessionDateLocal,
        raterName,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('session_date_local')) {
      context.handle(
          _sessionDateLocalMeta,
          sessionDateLocal.isAcceptableOrUnknown(
              data['session_date_local']!, _sessionDateLocalMeta));
    } else if (isInserting) {
      context.missing(_sessionDateLocalMeta);
    }
    if (data.containsKey('rater_name')) {
      context.handle(_raterNameMeta,
          raterName.isAcceptableOrUnknown(data['rater_name']!, _raterNameMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      sessionDateLocal: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}session_date_local'])!,
      raterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rater_name']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final int trialId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String sessionDateLocal;
  final String? raterName;
  final String status;
  const Session(
      {required this.id,
      required this.trialId,
      required this.name,
      required this.startedAt,
      this.endedAt,
      required this.sessionDateLocal,
      this.raterName,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['name'] = Variable<String>(name);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['session_date_local'] = Variable<String>(sessionDateLocal);
    if (!nullToAbsent || raterName != null) {
      map['rater_name'] = Variable<String>(raterName);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      name: Value(name),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      sessionDateLocal: Value(sessionDateLocal),
      raterName: raterName == null && nullToAbsent
          ? const Value.absent()
          : Value(raterName),
      status: Value(status),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      name: serializer.fromJson<String>(json['name']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      sessionDateLocal: serializer.fromJson<String>(json['sessionDateLocal']),
      raterName: serializer.fromJson<String?>(json['raterName']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'name': serializer.toJson<String>(name),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'sessionDateLocal': serializer.toJson<String>(sessionDateLocal),
      'raterName': serializer.toJson<String?>(raterName),
      'status': serializer.toJson<String>(status),
    };
  }

  Session copyWith(
          {int? id,
          int? trialId,
          String? name,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          String? sessionDateLocal,
          Value<String?> raterName = const Value.absent(),
          String? status}) =>
      Session(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        name: name ?? this.name,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        sessionDateLocal: sessionDateLocal ?? this.sessionDateLocal,
        raterName: raterName.present ? raterName.value : this.raterName,
        status: status ?? this.status,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      name: data.name.present ? data.name.value : this.name,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      sessionDateLocal: data.sessionDateLocal.present
          ? data.sessionDateLocal.value
          : this.sessionDateLocal,
      raterName: data.raterName.present ? data.raterName.value : this.raterName,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('sessionDateLocal: $sessionDateLocal, ')
          ..write('raterName: $raterName, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, name, startedAt, endedAt,
      sessionDateLocal, raterName, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.name == this.name &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.sessionDateLocal == this.sessionDateLocal &&
          other.raterName == this.raterName &&
          other.status == this.status);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> name;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> sessionDateLocal;
  final Value<String?> raterName;
  final Value<String> status;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.sessionDateLocal = const Value.absent(),
    this.raterName = const Value.absent(),
    this.status = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String name,
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    required String sessionDateLocal,
    this.raterName = const Value.absent(),
    this.status = const Value.absent(),
  })  : trialId = Value(trialId),
        name = Value(name),
        sessionDateLocal = Value(sessionDateLocal);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? name,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? sessionDateLocal,
    Expression<String>? raterName,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (name != null) 'name': name,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (sessionDateLocal != null) 'session_date_local': sessionDateLocal,
      if (raterName != null) 'rater_name': raterName,
      if (status != null) 'status': status,
    });
  }

  SessionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? name,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<String>? sessionDateLocal,
      Value<String?>? raterName,
      Value<String>? status}) {
    return SessionsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      sessionDateLocal: sessionDateLocal ?? this.sessionDateLocal,
      raterName: raterName ?? this.raterName,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (sessionDateLocal.present) {
      map['session_date_local'] = Variable<String>(sessionDateLocal.value);
    }
    if (raterName.present) {
      map['rater_name'] = Variable<String>(raterName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('sessionDateLocal: $sessionDateLocal, ')
          ..write('raterName: $raterName, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $SessionAssessmentsTable extends SessionAssessments
    with TableInfo<$SessionAssessmentsTable, SessionAssessment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionAssessmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _assessmentIdMeta =
      const VerificationMeta('assessmentId');
  @override
  late final GeneratedColumn<int> assessmentId = GeneratedColumn<int>(
      'assessment_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES assessments (id)'));
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, assessmentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_assessments';
  @override
  VerificationContext validateIntegrity(Insertable<SessionAssessment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('assessment_id')) {
      context.handle(
          _assessmentIdMeta,
          assessmentId.isAcceptableOrUnknown(
              data['assessment_id']!, _assessmentIdMeta));
    } else if (isInserting) {
      context.missing(_assessmentIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionAssessment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionAssessment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      assessmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}assessment_id'])!,
    );
  }

  @override
  $SessionAssessmentsTable createAlias(String alias) {
    return $SessionAssessmentsTable(attachedDatabase, alias);
  }
}

class SessionAssessment extends DataClass
    implements Insertable<SessionAssessment> {
  final int id;
  final int sessionId;
  final int assessmentId;
  const SessionAssessment(
      {required this.id, required this.sessionId, required this.assessmentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['assessment_id'] = Variable<int>(assessmentId);
    return map;
  }

  SessionAssessmentsCompanion toCompanion(bool nullToAbsent) {
    return SessionAssessmentsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      assessmentId: Value(assessmentId),
    );
  }

  factory SessionAssessment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionAssessment(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      assessmentId: serializer.fromJson<int>(json['assessmentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'assessmentId': serializer.toJson<int>(assessmentId),
    };
  }

  SessionAssessment copyWith({int? id, int? sessionId, int? assessmentId}) =>
      SessionAssessment(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        assessmentId: assessmentId ?? this.assessmentId,
      );
  SessionAssessment copyWithCompanion(SessionAssessmentsCompanion data) {
    return SessionAssessment(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      assessmentId: data.assessmentId.present
          ? data.assessmentId.value
          : this.assessmentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionAssessment(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('assessmentId: $assessmentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, assessmentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionAssessment &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.assessmentId == this.assessmentId);
}

class SessionAssessmentsCompanion extends UpdateCompanion<SessionAssessment> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> assessmentId;
  const SessionAssessmentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.assessmentId = const Value.absent(),
  });
  SessionAssessmentsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int assessmentId,
  })  : sessionId = Value(sessionId),
        assessmentId = Value(assessmentId);
  static Insertable<SessionAssessment> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? assessmentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (assessmentId != null) 'assessment_id': assessmentId,
    });
  }

  SessionAssessmentsCompanion copyWith(
      {Value<int>? id, Value<int>? sessionId, Value<int>? assessmentId}) {
    return SessionAssessmentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      assessmentId: assessmentId ?? this.assessmentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (assessmentId.present) {
      map['assessment_id'] = Variable<int>(assessmentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionAssessmentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('assessmentId: $assessmentId')
          ..write(')'))
        .toString();
  }
}

class $RatingRecordsTable extends RatingRecords
    with TableInfo<$RatingRecordsTable, RatingRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatingRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _assessmentIdMeta =
      const VerificationMeta('assessmentId');
  @override
  late final GeneratedColumn<int> assessmentId = GeneratedColumn<int>(
      'assessment_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES assessments (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _subUnitIdMeta =
      const VerificationMeta('subUnitId');
  @override
  late final GeneratedColumn<int> subUnitId = GeneratedColumn<int>(
      'sub_unit_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _resultStatusMeta =
      const VerificationMeta('resultStatus');
  @override
  late final GeneratedColumn<String> resultStatus = GeneratedColumn<String>(
      'result_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('RECORDED'));
  static const VerificationMeta _numericValueMeta =
      const VerificationMeta('numericValue');
  @override
  late final GeneratedColumn<double> numericValue = GeneratedColumn<double>(
      'numeric_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _textValueMeta =
      const VerificationMeta('textValue');
  @override
  late final GeneratedColumn<String> textValue = GeneratedColumn<String>(
      'text_value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isCurrentMeta =
      const VerificationMeta('isCurrent');
  @override
  late final GeneratedColumn<bool> isCurrent = GeneratedColumn<bool>(
      'is_current', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_current" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _previousIdMeta =
      const VerificationMeta('previousId');
  @override
  late final GeneratedColumn<int> previousId = GeneratedColumn<int>(
      'previous_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _raterNameMeta =
      const VerificationMeta('raterName');
  @override
  late final GeneratedColumn<String> raterName = GeneratedColumn<String>(
      'rater_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotPk,
        assessmentId,
        sessionId,
        subUnitId,
        resultStatus,
        numericValue,
        textValue,
        isCurrent,
        previousId,
        createdAt,
        raterName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rating_records';
  @override
  VerificationContext validateIntegrity(Insertable<RatingRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    } else if (isInserting) {
      context.missing(_plotPkMeta);
    }
    if (data.containsKey('assessment_id')) {
      context.handle(
          _assessmentIdMeta,
          assessmentId.isAcceptableOrUnknown(
              data['assessment_id']!, _assessmentIdMeta));
    } else if (isInserting) {
      context.missing(_assessmentIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sub_unit_id')) {
      context.handle(
          _subUnitIdMeta,
          subUnitId.isAcceptableOrUnknown(
              data['sub_unit_id']!, _subUnitIdMeta));
    }
    if (data.containsKey('result_status')) {
      context.handle(
          _resultStatusMeta,
          resultStatus.isAcceptableOrUnknown(
              data['result_status']!, _resultStatusMeta));
    }
    if (data.containsKey('numeric_value')) {
      context.handle(
          _numericValueMeta,
          numericValue.isAcceptableOrUnknown(
              data['numeric_value']!, _numericValueMeta));
    }
    if (data.containsKey('text_value')) {
      context.handle(_textValueMeta,
          textValue.isAcceptableOrUnknown(data['text_value']!, _textValueMeta));
    }
    if (data.containsKey('is_current')) {
      context.handle(_isCurrentMeta,
          isCurrent.isAcceptableOrUnknown(data['is_current']!, _isCurrentMeta));
    }
    if (data.containsKey('previous_id')) {
      context.handle(
          _previousIdMeta,
          previousId.isAcceptableOrUnknown(
              data['previous_id']!, _previousIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('rater_name')) {
      context.handle(_raterNameMeta,
          raterName.isAcceptableOrUnknown(data['rater_name']!, _raterNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RatingRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatingRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk'])!,
      assessmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}assessment_id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      subUnitId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sub_unit_id']),
      resultStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_status'])!,
      numericValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}numeric_value']),
      textValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text_value']),
      isCurrent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_current'])!,
      previousId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}previous_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      raterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rater_name']),
    );
  }

  @override
  $RatingRecordsTable createAlias(String alias) {
    return $RatingRecordsTable(attachedDatabase, alias);
  }
}

class RatingRecord extends DataClass implements Insertable<RatingRecord> {
  final int id;
  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;
  final int? subUnitId;
  final String resultStatus;
  final double? numericValue;
  final String? textValue;
  final bool isCurrent;
  final int? previousId;
  final DateTime createdAt;
  final String? raterName;
  const RatingRecord(
      {required this.id,
      required this.trialId,
      required this.plotPk,
      required this.assessmentId,
      required this.sessionId,
      this.subUnitId,
      required this.resultStatus,
      this.numericValue,
      this.textValue,
      required this.isCurrent,
      this.previousId,
      required this.createdAt,
      this.raterName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_pk'] = Variable<int>(plotPk);
    map['assessment_id'] = Variable<int>(assessmentId);
    map['session_id'] = Variable<int>(sessionId);
    if (!nullToAbsent || subUnitId != null) {
      map['sub_unit_id'] = Variable<int>(subUnitId);
    }
    map['result_status'] = Variable<String>(resultStatus);
    if (!nullToAbsent || numericValue != null) {
      map['numeric_value'] = Variable<double>(numericValue);
    }
    if (!nullToAbsent || textValue != null) {
      map['text_value'] = Variable<String>(textValue);
    }
    map['is_current'] = Variable<bool>(isCurrent);
    if (!nullToAbsent || previousId != null) {
      map['previous_id'] = Variable<int>(previousId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || raterName != null) {
      map['rater_name'] = Variable<String>(raterName);
    }
    return map;
  }

  RatingRecordsCompanion toCompanion(bool nullToAbsent) {
    return RatingRecordsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk: Value(plotPk),
      assessmentId: Value(assessmentId),
      sessionId: Value(sessionId),
      subUnitId: subUnitId == null && nullToAbsent
          ? const Value.absent()
          : Value(subUnitId),
      resultStatus: Value(resultStatus),
      numericValue: numericValue == null && nullToAbsent
          ? const Value.absent()
          : Value(numericValue),
      textValue: textValue == null && nullToAbsent
          ? const Value.absent()
          : Value(textValue),
      isCurrent: Value(isCurrent),
      previousId: previousId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousId),
      createdAt: Value(createdAt),
      raterName: raterName == null && nullToAbsent
          ? const Value.absent()
          : Value(raterName),
    );
  }

  factory RatingRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatingRecord(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotPk: serializer.fromJson<int>(json['plotPk']),
      assessmentId: serializer.fromJson<int>(json['assessmentId']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      subUnitId: serializer.fromJson<int?>(json['subUnitId']),
      resultStatus: serializer.fromJson<String>(json['resultStatus']),
      numericValue: serializer.fromJson<double?>(json['numericValue']),
      textValue: serializer.fromJson<String?>(json['textValue']),
      isCurrent: serializer.fromJson<bool>(json['isCurrent']),
      previousId: serializer.fromJson<int?>(json['previousId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      raterName: serializer.fromJson<String?>(json['raterName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotPk': serializer.toJson<int>(plotPk),
      'assessmentId': serializer.toJson<int>(assessmentId),
      'sessionId': serializer.toJson<int>(sessionId),
      'subUnitId': serializer.toJson<int?>(subUnitId),
      'resultStatus': serializer.toJson<String>(resultStatus),
      'numericValue': serializer.toJson<double?>(numericValue),
      'textValue': serializer.toJson<String?>(textValue),
      'isCurrent': serializer.toJson<bool>(isCurrent),
      'previousId': serializer.toJson<int?>(previousId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'raterName': serializer.toJson<String?>(raterName),
    };
  }

  RatingRecord copyWith(
          {int? id,
          int? trialId,
          int? plotPk,
          int? assessmentId,
          int? sessionId,
          Value<int?> subUnitId = const Value.absent(),
          String? resultStatus,
          Value<double?> numericValue = const Value.absent(),
          Value<String?> textValue = const Value.absent(),
          bool? isCurrent,
          Value<int?> previousId = const Value.absent(),
          DateTime? createdAt,
          Value<String?> raterName = const Value.absent()}) =>
      RatingRecord(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk ?? this.plotPk,
        assessmentId: assessmentId ?? this.assessmentId,
        sessionId: sessionId ?? this.sessionId,
        subUnitId: subUnitId.present ? subUnitId.value : this.subUnitId,
        resultStatus: resultStatus ?? this.resultStatus,
        numericValue:
            numericValue.present ? numericValue.value : this.numericValue,
        textValue: textValue.present ? textValue.value : this.textValue,
        isCurrent: isCurrent ?? this.isCurrent,
        previousId: previousId.present ? previousId.value : this.previousId,
        createdAt: createdAt ?? this.createdAt,
        raterName: raterName.present ? raterName.value : this.raterName,
      );
  RatingRecord copyWithCompanion(RatingRecordsCompanion data) {
    return RatingRecord(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      assessmentId: data.assessmentId.present
          ? data.assessmentId.value
          : this.assessmentId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      subUnitId: data.subUnitId.present ? data.subUnitId.value : this.subUnitId,
      resultStatus: data.resultStatus.present
          ? data.resultStatus.value
          : this.resultStatus,
      numericValue: data.numericValue.present
          ? data.numericValue.value
          : this.numericValue,
      textValue: data.textValue.present ? data.textValue.value : this.textValue,
      isCurrent: data.isCurrent.present ? data.isCurrent.value : this.isCurrent,
      previousId:
          data.previousId.present ? data.previousId.value : this.previousId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      raterName: data.raterName.present ? data.raterName.value : this.raterName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingRecord(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('subUnitId: $subUnitId, ')
          ..write('resultStatus: $resultStatus, ')
          ..write('numericValue: $numericValue, ')
          ..write('textValue: $textValue, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('previousId: $previousId, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trialId,
      plotPk,
      assessmentId,
      sessionId,
      subUnitId,
      resultStatus,
      numericValue,
      textValue,
      isCurrent,
      previousId,
      createdAt,
      raterName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingRecord &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.assessmentId == this.assessmentId &&
          other.sessionId == this.sessionId &&
          other.subUnitId == this.subUnitId &&
          other.resultStatus == this.resultStatus &&
          other.numericValue == this.numericValue &&
          other.textValue == this.textValue &&
          other.isCurrent == this.isCurrent &&
          other.previousId == this.previousId &&
          other.createdAt == this.createdAt &&
          other.raterName == this.raterName);
}

class RatingRecordsCompanion extends UpdateCompanion<RatingRecord> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> plotPk;
  final Value<int> assessmentId;
  final Value<int> sessionId;
  final Value<int?> subUnitId;
  final Value<String> resultStatus;
  final Value<double?> numericValue;
  final Value<String?> textValue;
  final Value<bool> isCurrent;
  final Value<int?> previousId;
  final Value<DateTime> createdAt;
  final Value<String?> raterName;
  const RatingRecordsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.assessmentId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.subUnitId = const Value.absent(),
    this.resultStatus = const Value.absent(),
    this.numericValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.previousId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  });
  RatingRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    this.subUnitId = const Value.absent(),
    this.resultStatus = const Value.absent(),
    this.numericValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.previousId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  })  : trialId = Value(trialId),
        plotPk = Value(plotPk),
        assessmentId = Value(assessmentId),
        sessionId = Value(sessionId);
  static Insertable<RatingRecord> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? assessmentId,
    Expression<int>? sessionId,
    Expression<int>? subUnitId,
    Expression<String>? resultStatus,
    Expression<double>? numericValue,
    Expression<String>? textValue,
    Expression<bool>? isCurrent,
    Expression<int>? previousId,
    Expression<DateTime>? createdAt,
    Expression<String>? raterName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (assessmentId != null) 'assessment_id': assessmentId,
      if (sessionId != null) 'session_id': sessionId,
      if (subUnitId != null) 'sub_unit_id': subUnitId,
      if (resultStatus != null) 'result_status': resultStatus,
      if (numericValue != null) 'numeric_value': numericValue,
      if (textValue != null) 'text_value': textValue,
      if (isCurrent != null) 'is_current': isCurrent,
      if (previousId != null) 'previous_id': previousId,
      if (createdAt != null) 'created_at': createdAt,
      if (raterName != null) 'rater_name': raterName,
    });
  }

  RatingRecordsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? plotPk,
      Value<int>? assessmentId,
      Value<int>? sessionId,
      Value<int?>? subUnitId,
      Value<String>? resultStatus,
      Value<double?>? numericValue,
      Value<String?>? textValue,
      Value<bool>? isCurrent,
      Value<int?>? previousId,
      Value<DateTime>? createdAt,
      Value<String?>? raterName}) {
    return RatingRecordsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      assessmentId: assessmentId ?? this.assessmentId,
      sessionId: sessionId ?? this.sessionId,
      subUnitId: subUnitId ?? this.subUnitId,
      resultStatus: resultStatus ?? this.resultStatus,
      numericValue: numericValue ?? this.numericValue,
      textValue: textValue ?? this.textValue,
      isCurrent: isCurrent ?? this.isCurrent,
      previousId: previousId ?? this.previousId,
      createdAt: createdAt ?? this.createdAt,
      raterName: raterName ?? this.raterName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (assessmentId.present) {
      map['assessment_id'] = Variable<int>(assessmentId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (subUnitId.present) {
      map['sub_unit_id'] = Variable<int>(subUnitId.value);
    }
    if (resultStatus.present) {
      map['result_status'] = Variable<String>(resultStatus.value);
    }
    if (numericValue.present) {
      map['numeric_value'] = Variable<double>(numericValue.value);
    }
    if (textValue.present) {
      map['text_value'] = Variable<String>(textValue.value);
    }
    if (isCurrent.present) {
      map['is_current'] = Variable<bool>(isCurrent.value);
    }
    if (previousId.present) {
      map['previous_id'] = Variable<int>(previousId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (raterName.present) {
      map['rater_name'] = Variable<String>(raterName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatingRecordsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('subUnitId: $subUnitId, ')
          ..write('resultStatus: $resultStatus, ')
          ..write('numericValue: $numericValue, ')
          ..write('textValue: $textValue, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('previousId: $previousId, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _raterNameMeta =
      const VerificationMeta('raterName');
  @override
  late final GeneratedColumn<String> raterName = GeneratedColumn<String>(
      'rater_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, trialId, plotPk, sessionId, content, createdAt, raterName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(Insertable<Note> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    } else if (isInserting) {
      context.missing(_plotPkMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('rater_name')) {
      context.handle(_raterNameMeta,
          raterName.isAcceptableOrUnknown(data['rater_name']!, _raterNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      raterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rater_name']),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final int trialId;
  final int plotPk;
  final int sessionId;
  final String content;
  final DateTime createdAt;
  final String? raterName;
  const Note(
      {required this.id,
      required this.trialId,
      required this.plotPk,
      required this.sessionId,
      required this.content,
      required this.createdAt,
      this.raterName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_pk'] = Variable<int>(plotPk);
    map['session_id'] = Variable<int>(sessionId);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || raterName != null) {
      map['rater_name'] = Variable<String>(raterName);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk: Value(plotPk),
      sessionId: Value(sessionId),
      content: Value(content),
      createdAt: Value(createdAt),
      raterName: raterName == null && nullToAbsent
          ? const Value.absent()
          : Value(raterName),
    );
  }

  factory Note.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotPk: serializer.fromJson<int>(json['plotPk']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      raterName: serializer.fromJson<String?>(json['raterName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotPk': serializer.toJson<int>(plotPk),
      'sessionId': serializer.toJson<int>(sessionId),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'raterName': serializer.toJson<String?>(raterName),
    };
  }

  Note copyWith(
          {int? id,
          int? trialId,
          int? plotPk,
          int? sessionId,
          String? content,
          DateTime? createdAt,
          Value<String?> raterName = const Value.absent()}) =>
      Note(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk ?? this.plotPk,
        sessionId: sessionId ?? this.sessionId,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        raterName: raterName.present ? raterName.value : this.raterName,
      );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      raterName: data.raterName.present ? data.raterName.value : this.raterName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, trialId, plotPk, sessionId, content, createdAt, raterName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.sessionId == this.sessionId &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.raterName == this.raterName);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> plotPk;
  final Value<int> sessionId;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<String?> raterName;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int plotPk,
    required int sessionId,
    required String content,
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  })  : trialId = Value(trialId),
        plotPk = Value(plotPk),
        sessionId = Value(sessionId),
        content = Value(content);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? sessionId,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<String>? raterName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (sessionId != null) 'session_id': sessionId,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (raterName != null) 'rater_name': raterName,
    });
  }

  NotesCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? plotPk,
      Value<int>? sessionId,
      Value<String>? content,
      Value<DateTime>? createdAt,
      Value<String?>? raterName}) {
    return NotesCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      raterName: raterName ?? this.raterName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (raterName.present) {
      map['rater_name'] = Variable<String>(raterName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tempPathMeta =
      const VerificationMeta('tempPath');
  @override
  late final GeneratedColumn<String> tempPath = GeneratedColumn<String>(
      'temp_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('final'));
  static const VerificationMeta _captionMeta =
      const VerificationMeta('caption');
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
      'caption', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotPk,
        sessionId,
        filePath,
        tempPath,
        status,
        caption,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(Insertable<Photo> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    } else if (isInserting) {
      context.missing(_plotPkMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('temp_path')) {
      context.handle(_tempPathMeta,
          tempPath.isAcceptableOrUnknown(data['temp_path']!, _tempPathMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('caption')) {
      context.handle(_captionMeta,
          caption.isAcceptableOrUnknown(data['caption']!, _captionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      tempPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}temp_path']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      caption: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}caption']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class Photo extends DataClass implements Insertable<Photo> {
  final int id;
  final int trialId;
  final int plotPk;
  final int sessionId;
  final String filePath;
  final String? tempPath;
  final String status;
  final String? caption;
  final DateTime createdAt;
  const Photo(
      {required this.id,
      required this.trialId,
      required this.plotPk,
      required this.sessionId,
      required this.filePath,
      this.tempPath,
      required this.status,
      this.caption,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_pk'] = Variable<int>(plotPk);
    map['session_id'] = Variable<int>(sessionId);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || tempPath != null) {
      map['temp_path'] = Variable<String>(tempPath);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk: Value(plotPk),
      sessionId: Value(sessionId),
      filePath: Value(filePath),
      tempPath: tempPath == null && nullToAbsent
          ? const Value.absent()
          : Value(tempPath),
      status: Value(status),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      createdAt: Value(createdAt),
    );
  }

  factory Photo.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotPk: serializer.fromJson<int>(json['plotPk']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      tempPath: serializer.fromJson<String?>(json['tempPath']),
      status: serializer.fromJson<String>(json['status']),
      caption: serializer.fromJson<String?>(json['caption']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotPk': serializer.toJson<int>(plotPk),
      'sessionId': serializer.toJson<int>(sessionId),
      'filePath': serializer.toJson<String>(filePath),
      'tempPath': serializer.toJson<String?>(tempPath),
      'status': serializer.toJson<String>(status),
      'caption': serializer.toJson<String?>(caption),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Photo copyWith(
          {int? id,
          int? trialId,
          int? plotPk,
          int? sessionId,
          String? filePath,
          Value<String?> tempPath = const Value.absent(),
          String? status,
          Value<String?> caption = const Value.absent(),
          DateTime? createdAt}) =>
      Photo(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk ?? this.plotPk,
        sessionId: sessionId ?? this.sessionId,
        filePath: filePath ?? this.filePath,
        tempPath: tempPath.present ? tempPath.value : this.tempPath,
        status: status ?? this.status,
        caption: caption.present ? caption.value : this.caption,
        createdAt: createdAt ?? this.createdAt,
      );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      tempPath: data.tempPath.present ? data.tempPath.value : this.tempPath,
      status: data.status.present ? data.status.value : this.status,
      caption: data.caption.present ? data.caption.value : this.caption,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('filePath: $filePath, ')
          ..write('tempPath: $tempPath, ')
          ..write('status: $status, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, plotPk, sessionId, filePath,
      tempPath, status, caption, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.sessionId == this.sessionId &&
          other.filePath == this.filePath &&
          other.tempPath == this.tempPath &&
          other.status == this.status &&
          other.caption == this.caption &&
          other.createdAt == this.createdAt);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> plotPk;
  final Value<int> sessionId;
  final Value<String> filePath;
  final Value<String?> tempPath;
  final Value<String> status;
  final Value<String?> caption;
  final Value<DateTime> createdAt;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.tempPath = const Value.absent(),
    this.status = const Value.absent(),
    this.caption = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PhotosCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int plotPk,
    required int sessionId,
    required String filePath,
    this.tempPath = const Value.absent(),
    this.status = const Value.absent(),
    this.caption = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : trialId = Value(trialId),
        plotPk = Value(plotPk),
        sessionId = Value(sessionId),
        filePath = Value(filePath);
  static Insertable<Photo> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? sessionId,
    Expression<String>? filePath,
    Expression<String>? tempPath,
    Expression<String>? status,
    Expression<String>? caption,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (sessionId != null) 'session_id': sessionId,
      if (filePath != null) 'file_path': filePath,
      if (tempPath != null) 'temp_path': tempPath,
      if (status != null) 'status': status,
      if (caption != null) 'caption': caption,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PhotosCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? plotPk,
      Value<int>? sessionId,
      Value<String>? filePath,
      Value<String?>? tempPath,
      Value<String>? status,
      Value<String?>? caption,
      Value<DateTime>? createdAt}) {
    return PhotosCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      sessionId: sessionId ?? this.sessionId,
      filePath: filePath ?? this.filePath,
      tempPath: tempPath ?? this.tempPath,
      status: status ?? this.status,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (tempPath.present) {
      map['temp_path'] = Variable<String>(tempPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('filePath: $filePath, ')
          ..write('tempPath: $tempPath, ')
          ..write('status: $status, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlotFlagsTable extends PlotFlags
    with TableInfo<$PlotFlagsTable, PlotFlag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlotFlagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _flagTypeMeta =
      const VerificationMeta('flagType');
  @override
  late final GeneratedColumn<String> flagType = GeneratedColumn<String>(
      'flag_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _raterNameMeta =
      const VerificationMeta('raterName');
  @override
  late final GeneratedColumn<String> raterName = GeneratedColumn<String>(
      'rater_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotPk,
        sessionId,
        flagType,
        description,
        createdAt,
        raterName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plot_flags';
  @override
  VerificationContext validateIntegrity(Insertable<PlotFlag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    } else if (isInserting) {
      context.missing(_plotPkMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('flag_type')) {
      context.handle(_flagTypeMeta,
          flagType.isAcceptableOrUnknown(data['flag_type']!, _flagTypeMeta));
    } else if (isInserting) {
      context.missing(_flagTypeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('rater_name')) {
      context.handle(_raterNameMeta,
          raterName.isAcceptableOrUnknown(data['rater_name']!, _raterNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlotFlag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlotFlag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      flagType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}flag_type'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      raterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rater_name']),
    );
  }

  @override
  $PlotFlagsTable createAlias(String alias) {
    return $PlotFlagsTable(attachedDatabase, alias);
  }
}

class PlotFlag extends DataClass implements Insertable<PlotFlag> {
  final int id;
  final int trialId;
  final int plotPk;
  final int sessionId;
  final String flagType;
  final String? description;
  final DateTime createdAt;
  final String? raterName;
  const PlotFlag(
      {required this.id,
      required this.trialId,
      required this.plotPk,
      required this.sessionId,
      required this.flagType,
      this.description,
      required this.createdAt,
      this.raterName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_pk'] = Variable<int>(plotPk);
    map['session_id'] = Variable<int>(sessionId);
    map['flag_type'] = Variable<String>(flagType);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || raterName != null) {
      map['rater_name'] = Variable<String>(raterName);
    }
    return map;
  }

  PlotFlagsCompanion toCompanion(bool nullToAbsent) {
    return PlotFlagsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk: Value(plotPk),
      sessionId: Value(sessionId),
      flagType: Value(flagType),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      raterName: raterName == null && nullToAbsent
          ? const Value.absent()
          : Value(raterName),
    );
  }

  factory PlotFlag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlotFlag(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotPk: serializer.fromJson<int>(json['plotPk']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      flagType: serializer.fromJson<String>(json['flagType']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      raterName: serializer.fromJson<String?>(json['raterName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotPk': serializer.toJson<int>(plotPk),
      'sessionId': serializer.toJson<int>(sessionId),
      'flagType': serializer.toJson<String>(flagType),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'raterName': serializer.toJson<String?>(raterName),
    };
  }

  PlotFlag copyWith(
          {int? id,
          int? trialId,
          int? plotPk,
          int? sessionId,
          String? flagType,
          Value<String?> description = const Value.absent(),
          DateTime? createdAt,
          Value<String?> raterName = const Value.absent()}) =>
      PlotFlag(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk ?? this.plotPk,
        sessionId: sessionId ?? this.sessionId,
        flagType: flagType ?? this.flagType,
        description: description.present ? description.value : this.description,
        createdAt: createdAt ?? this.createdAt,
        raterName: raterName.present ? raterName.value : this.raterName,
      );
  PlotFlag copyWithCompanion(PlotFlagsCompanion data) {
    return PlotFlag(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      flagType: data.flagType.present ? data.flagType.value : this.flagType,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      raterName: data.raterName.present ? data.raterName.value : this.raterName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlotFlag(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('flagType: $flagType, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, plotPk, sessionId, flagType,
      description, createdAt, raterName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlotFlag &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.sessionId == this.sessionId &&
          other.flagType == this.flagType &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.raterName == this.raterName);
}

class PlotFlagsCompanion extends UpdateCompanion<PlotFlag> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> plotPk;
  final Value<int> sessionId;
  final Value<String> flagType;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<String?> raterName;
  const PlotFlagsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.flagType = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  });
  PlotFlagsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int plotPk,
    required int sessionId,
    required String flagType,
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  })  : trialId = Value(trialId),
        plotPk = Value(plotPk),
        sessionId = Value(sessionId),
        flagType = Value(flagType);
  static Insertable<PlotFlag> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? sessionId,
    Expression<String>? flagType,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<String>? raterName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (sessionId != null) 'session_id': sessionId,
      if (flagType != null) 'flag_type': flagType,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (raterName != null) 'rater_name': raterName,
    });
  }

  PlotFlagsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? plotPk,
      Value<int>? sessionId,
      Value<String>? flagType,
      Value<String?>? description,
      Value<DateTime>? createdAt,
      Value<String?>? raterName}) {
    return PlotFlagsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      sessionId: sessionId ?? this.sessionId,
      flagType: flagType ?? this.flagType,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      raterName: raterName ?? this.raterName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (flagType.present) {
      map['flag_type'] = Variable<String>(flagType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (raterName.present) {
      map['rater_name'] = Variable<String>(raterName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlotFlagsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('flagType: $flagType, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }
}

class $DeviationFlagsTable extends DeviationFlags
    with TableInfo<$DeviationFlagsTable, DeviationFlag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviationFlagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _ratingRecordIdMeta =
      const VerificationMeta('ratingRecordId');
  @override
  late final GeneratedColumn<int> ratingRecordId = GeneratedColumn<int>(
      'rating_record_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES rating_records (id)'));
  static const VerificationMeta _deviationTypeMeta =
      const VerificationMeta('deviationType');
  @override
  late final GeneratedColumn<String> deviationType = GeneratedColumn<String>(
      'deviation_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _raterNameMeta =
      const VerificationMeta('raterName');
  @override
  late final GeneratedColumn<String> raterName = GeneratedColumn<String>(
      'rater_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotPk,
        sessionId,
        ratingRecordId,
        deviationType,
        description,
        createdAt,
        raterName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deviation_flags';
  @override
  VerificationContext validateIntegrity(Insertable<DeviationFlag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('rating_record_id')) {
      context.handle(
          _ratingRecordIdMeta,
          ratingRecordId.isAcceptableOrUnknown(
              data['rating_record_id']!, _ratingRecordIdMeta));
    }
    if (data.containsKey('deviation_type')) {
      context.handle(
          _deviationTypeMeta,
          deviationType.isAcceptableOrUnknown(
              data['deviation_type']!, _deviationTypeMeta));
    } else if (isInserting) {
      context.missing(_deviationTypeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('rater_name')) {
      context.handle(_raterNameMeta,
          raterName.isAcceptableOrUnknown(data['rater_name']!, _raterNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviationFlag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviationFlag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk']),
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      ratingRecordId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating_record_id']),
      deviationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deviation_type'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      raterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rater_name']),
    );
  }

  @override
  $DeviationFlagsTable createAlias(String alias) {
    return $DeviationFlagsTable(attachedDatabase, alias);
  }
}

class DeviationFlag extends DataClass implements Insertable<DeviationFlag> {
  final int id;
  final int trialId;
  final int? plotPk;
  final int sessionId;
  final int? ratingRecordId;
  final String deviationType;
  final String? description;
  final DateTime createdAt;
  final String? raterName;
  const DeviationFlag(
      {required this.id,
      required this.trialId,
      this.plotPk,
      required this.sessionId,
      this.ratingRecordId,
      required this.deviationType,
      this.description,
      required this.createdAt,
      this.raterName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    if (!nullToAbsent || plotPk != null) {
      map['plot_pk'] = Variable<int>(plotPk);
    }
    map['session_id'] = Variable<int>(sessionId);
    if (!nullToAbsent || ratingRecordId != null) {
      map['rating_record_id'] = Variable<int>(ratingRecordId);
    }
    map['deviation_type'] = Variable<String>(deviationType);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || raterName != null) {
      map['rater_name'] = Variable<String>(raterName);
    }
    return map;
  }

  DeviationFlagsCompanion toCompanion(bool nullToAbsent) {
    return DeviationFlagsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk:
          plotPk == null && nullToAbsent ? const Value.absent() : Value(plotPk),
      sessionId: Value(sessionId),
      ratingRecordId: ratingRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingRecordId),
      deviationType: Value(deviationType),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      raterName: raterName == null && nullToAbsent
          ? const Value.absent()
          : Value(raterName),
    );
  }

  factory DeviationFlag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviationFlag(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotPk: serializer.fromJson<int?>(json['plotPk']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      ratingRecordId: serializer.fromJson<int?>(json['ratingRecordId']),
      deviationType: serializer.fromJson<String>(json['deviationType']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      raterName: serializer.fromJson<String?>(json['raterName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotPk': serializer.toJson<int?>(plotPk),
      'sessionId': serializer.toJson<int>(sessionId),
      'ratingRecordId': serializer.toJson<int?>(ratingRecordId),
      'deviationType': serializer.toJson<String>(deviationType),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'raterName': serializer.toJson<String?>(raterName),
    };
  }

  DeviationFlag copyWith(
          {int? id,
          int? trialId,
          Value<int?> plotPk = const Value.absent(),
          int? sessionId,
          Value<int?> ratingRecordId = const Value.absent(),
          String? deviationType,
          Value<String?> description = const Value.absent(),
          DateTime? createdAt,
          Value<String?> raterName = const Value.absent()}) =>
      DeviationFlag(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk.present ? plotPk.value : this.plotPk,
        sessionId: sessionId ?? this.sessionId,
        ratingRecordId:
            ratingRecordId.present ? ratingRecordId.value : this.ratingRecordId,
        deviationType: deviationType ?? this.deviationType,
        description: description.present ? description.value : this.description,
        createdAt: createdAt ?? this.createdAt,
        raterName: raterName.present ? raterName.value : this.raterName,
      );
  DeviationFlag copyWithCompanion(DeviationFlagsCompanion data) {
    return DeviationFlag(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ratingRecordId: data.ratingRecordId.present
          ? data.ratingRecordId.value
          : this.ratingRecordId,
      deviationType: data.deviationType.present
          ? data.deviationType.value
          : this.deviationType,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      raterName: data.raterName.present ? data.raterName.value : this.raterName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviationFlag(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('ratingRecordId: $ratingRecordId, ')
          ..write('deviationType: $deviationType, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, plotPk, sessionId,
      ratingRecordId, deviationType, description, createdAt, raterName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviationFlag &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.sessionId == this.sessionId &&
          other.ratingRecordId == this.ratingRecordId &&
          other.deviationType == this.deviationType &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.raterName == this.raterName);
}

class DeviationFlagsCompanion extends UpdateCompanion<DeviationFlag> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int?> plotPk;
  final Value<int> sessionId;
  final Value<int?> ratingRecordId;
  final Value<String> deviationType;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<String?> raterName;
  const DeviationFlagsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ratingRecordId = const Value.absent(),
    this.deviationType = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  });
  DeviationFlagsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    this.plotPk = const Value.absent(),
    required int sessionId,
    this.ratingRecordId = const Value.absent(),
    required String deviationType,
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
  })  : trialId = Value(trialId),
        sessionId = Value(sessionId),
        deviationType = Value(deviationType);
  static Insertable<DeviationFlag> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? sessionId,
    Expression<int>? ratingRecordId,
    Expression<String>? deviationType,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<String>? raterName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (sessionId != null) 'session_id': sessionId,
      if (ratingRecordId != null) 'rating_record_id': ratingRecordId,
      if (deviationType != null) 'deviation_type': deviationType,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (raterName != null) 'rater_name': raterName,
    });
  }

  DeviationFlagsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int?>? plotPk,
      Value<int>? sessionId,
      Value<int?>? ratingRecordId,
      Value<String>? deviationType,
      Value<String?>? description,
      Value<DateTime>? createdAt,
      Value<String?>? raterName}) {
    return DeviationFlagsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      sessionId: sessionId ?? this.sessionId,
      ratingRecordId: ratingRecordId ?? this.ratingRecordId,
      deviationType: deviationType ?? this.deviationType,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      raterName: raterName ?? this.raterName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ratingRecordId.present) {
      map['rating_record_id'] = Variable<int>(ratingRecordId.value);
    }
    if (deviationType.present) {
      map['deviation_type'] = Variable<String>(deviationType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (raterName.present) {
      map['rater_name'] = Variable<String>(raterName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviationFlagsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('ratingRecordId: $ratingRecordId, ')
          ..write('deviationType: $deviationType, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName')
          ..write(')'))
        .toString();
  }
}

class $SeedingRecordsTable extends SeedingRecords
    with TableInfo<$SeedingRecordsTable, SeedingRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeedingRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _seedingDateMeta =
      const VerificationMeta('seedingDate');
  @override
  late final GeneratedColumn<DateTime> seedingDate = GeneratedColumn<DateTime>(
      'seeding_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _operatorNameMeta =
      const VerificationMeta('operatorName');
  @override
  late final GeneratedColumn<String> operatorName = GeneratedColumn<String>(
      'operator_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentsMeta =
      const VerificationMeta('comments');
  @override
  late final GeneratedColumn<String> comments = GeneratedColumn<String>(
      'comments', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotPk,
        sessionId,
        seedingDate,
        operatorName,
        comments,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seeding_records';
  @override
  VerificationContext validateIntegrity(Insertable<SeedingRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('seeding_date')) {
      context.handle(
          _seedingDateMeta,
          seedingDate.isAcceptableOrUnknown(
              data['seeding_date']!, _seedingDateMeta));
    } else if (isInserting) {
      context.missing(_seedingDateMeta);
    }
    if (data.containsKey('operator_name')) {
      context.handle(
          _operatorNameMeta,
          operatorName.isAcceptableOrUnknown(
              data['operator_name']!, _operatorNameMeta));
    }
    if (data.containsKey('comments')) {
      context.handle(_commentsMeta,
          comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeedingRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeedingRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk']),
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id']),
      seedingDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}seeding_date'])!,
      operatorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operator_name']),
      comments: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comments']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SeedingRecordsTable createAlias(String alias) {
    return $SeedingRecordsTable(attachedDatabase, alias);
  }
}

class SeedingRecord extends DataClass implements Insertable<SeedingRecord> {
  final int id;
  final int trialId;
  final int? plotPk;
  final int? sessionId;
  final DateTime seedingDate;
  final String? operatorName;
  final String? comments;
  final DateTime createdAt;
  const SeedingRecord(
      {required this.id,
      required this.trialId,
      this.plotPk,
      this.sessionId,
      required this.seedingDate,
      this.operatorName,
      this.comments,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    if (!nullToAbsent || plotPk != null) {
      map['plot_pk'] = Variable<int>(plotPk);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['seeding_date'] = Variable<DateTime>(seedingDate);
    if (!nullToAbsent || operatorName != null) {
      map['operator_name'] = Variable<String>(operatorName);
    }
    if (!nullToAbsent || comments != null) {
      map['comments'] = Variable<String>(comments);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SeedingRecordsCompanion toCompanion(bool nullToAbsent) {
    return SeedingRecordsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk:
          plotPk == null && nullToAbsent ? const Value.absent() : Value(plotPk),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      seedingDate: Value(seedingDate),
      operatorName: operatorName == null && nullToAbsent
          ? const Value.absent()
          : Value(operatorName),
      comments: comments == null && nullToAbsent
          ? const Value.absent()
          : Value(comments),
      createdAt: Value(createdAt),
    );
  }

  factory SeedingRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeedingRecord(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotPk: serializer.fromJson<int?>(json['plotPk']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      seedingDate: serializer.fromJson<DateTime>(json['seedingDate']),
      operatorName: serializer.fromJson<String?>(json['operatorName']),
      comments: serializer.fromJson<String?>(json['comments']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotPk': serializer.toJson<int?>(plotPk),
      'sessionId': serializer.toJson<int?>(sessionId),
      'seedingDate': serializer.toJson<DateTime>(seedingDate),
      'operatorName': serializer.toJson<String?>(operatorName),
      'comments': serializer.toJson<String?>(comments),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SeedingRecord copyWith(
          {int? id,
          int? trialId,
          Value<int?> plotPk = const Value.absent(),
          Value<int?> sessionId = const Value.absent(),
          DateTime? seedingDate,
          Value<String?> operatorName = const Value.absent(),
          Value<String?> comments = const Value.absent(),
          DateTime? createdAt}) =>
      SeedingRecord(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk.present ? plotPk.value : this.plotPk,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        seedingDate: seedingDate ?? this.seedingDate,
        operatorName:
            operatorName.present ? operatorName.value : this.operatorName,
        comments: comments.present ? comments.value : this.comments,
        createdAt: createdAt ?? this.createdAt,
      );
  SeedingRecord copyWithCompanion(SeedingRecordsCompanion data) {
    return SeedingRecord(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      seedingDate:
          data.seedingDate.present ? data.seedingDate.value : this.seedingDate,
      operatorName: data.operatorName.present
          ? data.operatorName.value
          : this.operatorName,
      comments: data.comments.present ? data.comments.value : this.comments,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeedingRecord(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('seedingDate: $seedingDate, ')
          ..write('operatorName: $operatorName, ')
          ..write('comments: $comments, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, plotPk, sessionId, seedingDate,
      operatorName, comments, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeedingRecord &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.sessionId == this.sessionId &&
          other.seedingDate == this.seedingDate &&
          other.operatorName == this.operatorName &&
          other.comments == this.comments &&
          other.createdAt == this.createdAt);
}

class SeedingRecordsCompanion extends UpdateCompanion<SeedingRecord> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int?> plotPk;
  final Value<int?> sessionId;
  final Value<DateTime> seedingDate;
  final Value<String?> operatorName;
  final Value<String?> comments;
  final Value<DateTime> createdAt;
  const SeedingRecordsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.seedingDate = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.comments = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SeedingRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    this.plotPk = const Value.absent(),
    this.sessionId = const Value.absent(),
    required DateTime seedingDate,
    this.operatorName = const Value.absent(),
    this.comments = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : trialId = Value(trialId),
        seedingDate = Value(seedingDate);
  static Insertable<SeedingRecord> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? sessionId,
    Expression<DateTime>? seedingDate,
    Expression<String>? operatorName,
    Expression<String>? comments,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (sessionId != null) 'session_id': sessionId,
      if (seedingDate != null) 'seeding_date': seedingDate,
      if (operatorName != null) 'operator_name': operatorName,
      if (comments != null) 'comments': comments,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SeedingRecordsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int?>? plotPk,
      Value<int?>? sessionId,
      Value<DateTime>? seedingDate,
      Value<String?>? operatorName,
      Value<String?>? comments,
      Value<DateTime>? createdAt}) {
    return SeedingRecordsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      sessionId: sessionId ?? this.sessionId,
      seedingDate: seedingDate ?? this.seedingDate,
      operatorName: operatorName ?? this.operatorName,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (seedingDate.present) {
      map['seeding_date'] = Variable<DateTime>(seedingDate.value);
    }
    if (operatorName.present) {
      map['operator_name'] = Variable<String>(operatorName.value);
    }
    if (comments.present) {
      map['comments'] = Variable<String>(comments.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeedingRecordsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('sessionId: $sessionId, ')
          ..write('seedingDate: $seedingDate, ')
          ..write('operatorName: $operatorName, ')
          ..write('comments: $comments, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ProtocolSeedingFieldsTable extends ProtocolSeedingFields
    with TableInfo<$ProtocolSeedingFieldsTable, ProtocolSeedingField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProtocolSeedingFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _fieldKeyMeta =
      const VerificationMeta('fieldKey');
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
      'field_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fieldLabelMeta =
      const VerificationMeta('fieldLabel');
  @override
  late final GeneratedColumn<String> fieldLabel = GeneratedColumn<String>(
      'field_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fieldTypeMeta =
      const VerificationMeta('fieldType');
  @override
  late final GeneratedColumn<String> fieldType = GeneratedColumn<String>(
      'field_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isRequiredMeta =
      const VerificationMeta('isRequired');
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
      'is_required', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_required" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isVisibleMeta =
      const VerificationMeta('isVisible');
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
      'is_visible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_visible" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        fieldKey,
        fieldLabel,
        fieldType,
        unit,
        isRequired,
        isVisible,
        sortOrder,
        source
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'protocol_seeding_fields';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProtocolSeedingField> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(_fieldKeyMeta,
          fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta));
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('field_label')) {
      context.handle(
          _fieldLabelMeta,
          fieldLabel.isAcceptableOrUnknown(
              data['field_label']!, _fieldLabelMeta));
    } else if (isInserting) {
      context.missing(_fieldLabelMeta);
    }
    if (data.containsKey('field_type')) {
      context.handle(_fieldTypeMeta,
          fieldType.isAcceptableOrUnknown(data['field_type']!, _fieldTypeMeta));
    } else if (isInserting) {
      context.missing(_fieldTypeMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('is_required')) {
      context.handle(
          _isRequiredMeta,
          isRequired.isAcceptableOrUnknown(
              data['is_required']!, _isRequiredMeta));
    }
    if (data.containsKey('is_visible')) {
      context.handle(_isVisibleMeta,
          isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProtocolSeedingField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProtocolSeedingField(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      fieldKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field_key'])!,
      fieldLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field_label'])!,
      fieldType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field_type'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      isRequired: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_required'])!,
      isVisible: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_visible'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $ProtocolSeedingFieldsTable createAlias(String alias) {
    return $ProtocolSeedingFieldsTable(attachedDatabase, alias);
  }
}

class ProtocolSeedingField extends DataClass
    implements Insertable<ProtocolSeedingField> {
  final int id;
  final int trialId;
  final String fieldKey;
  final String fieldLabel;
  final String fieldType;
  final String? unit;
  final bool isRequired;
  final bool isVisible;
  final int sortOrder;
  final String source;
  const ProtocolSeedingField(
      {required this.id,
      required this.trialId,
      required this.fieldKey,
      required this.fieldLabel,
      required this.fieldType,
      this.unit,
      required this.isRequired,
      required this.isVisible,
      required this.sortOrder,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['field_key'] = Variable<String>(fieldKey);
    map['field_label'] = Variable<String>(fieldLabel);
    map['field_type'] = Variable<String>(fieldType);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['is_required'] = Variable<bool>(isRequired);
    map['is_visible'] = Variable<bool>(isVisible);
    map['sort_order'] = Variable<int>(sortOrder);
    map['source'] = Variable<String>(source);
    return map;
  }

  ProtocolSeedingFieldsCompanion toCompanion(bool nullToAbsent) {
    return ProtocolSeedingFieldsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      fieldKey: Value(fieldKey),
      fieldLabel: Value(fieldLabel),
      fieldType: Value(fieldType),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      isRequired: Value(isRequired),
      isVisible: Value(isVisible),
      sortOrder: Value(sortOrder),
      source: Value(source),
    );
  }

  factory ProtocolSeedingField.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProtocolSeedingField(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      fieldLabel: serializer.fromJson<String>(json['fieldLabel']),
      fieldType: serializer.fromJson<String>(json['fieldType']),
      unit: serializer.fromJson<String?>(json['unit']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'fieldLabel': serializer.toJson<String>(fieldLabel),
      'fieldType': serializer.toJson<String>(fieldType),
      'unit': serializer.toJson<String?>(unit),
      'isRequired': serializer.toJson<bool>(isRequired),
      'isVisible': serializer.toJson<bool>(isVisible),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'source': serializer.toJson<String>(source),
    };
  }

  ProtocolSeedingField copyWith(
          {int? id,
          int? trialId,
          String? fieldKey,
          String? fieldLabel,
          String? fieldType,
          Value<String?> unit = const Value.absent(),
          bool? isRequired,
          bool? isVisible,
          int? sortOrder,
          String? source}) =>
      ProtocolSeedingField(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        fieldKey: fieldKey ?? this.fieldKey,
        fieldLabel: fieldLabel ?? this.fieldLabel,
        fieldType: fieldType ?? this.fieldType,
        unit: unit.present ? unit.value : this.unit,
        isRequired: isRequired ?? this.isRequired,
        isVisible: isVisible ?? this.isVisible,
        sortOrder: sortOrder ?? this.sortOrder,
        source: source ?? this.source,
      );
  ProtocolSeedingField copyWithCompanion(ProtocolSeedingFieldsCompanion data) {
    return ProtocolSeedingField(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      fieldLabel:
          data.fieldLabel.present ? data.fieldLabel.value : this.fieldLabel,
      fieldType: data.fieldType.present ? data.fieldType.value : this.fieldType,
      unit: data.unit.present ? data.unit.value : this.unit,
      isRequired:
          data.isRequired.present ? data.isRequired.value : this.isRequired,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProtocolSeedingField(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('fieldLabel: $fieldLabel, ')
          ..write('fieldType: $fieldType, ')
          ..write('unit: $unit, ')
          ..write('isRequired: $isRequired, ')
          ..write('isVisible: $isVisible, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, fieldKey, fieldLabel, fieldType,
      unit, isRequired, isVisible, sortOrder, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProtocolSeedingField &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.fieldKey == this.fieldKey &&
          other.fieldLabel == this.fieldLabel &&
          other.fieldType == this.fieldType &&
          other.unit == this.unit &&
          other.isRequired == this.isRequired &&
          other.isVisible == this.isVisible &&
          other.sortOrder == this.sortOrder &&
          other.source == this.source);
}

class ProtocolSeedingFieldsCompanion
    extends UpdateCompanion<ProtocolSeedingField> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> fieldKey;
  final Value<String> fieldLabel;
  final Value<String> fieldType;
  final Value<String?> unit;
  final Value<bool> isRequired;
  final Value<bool> isVisible;
  final Value<int> sortOrder;
  final Value<String> source;
  const ProtocolSeedingFieldsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.fieldLabel = const Value.absent(),
    this.fieldType = const Value.absent(),
    this.unit = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.source = const Value.absent(),
  });
  ProtocolSeedingFieldsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String fieldKey,
    required String fieldLabel,
    required String fieldType,
    this.unit = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.source = const Value.absent(),
  })  : trialId = Value(trialId),
        fieldKey = Value(fieldKey),
        fieldLabel = Value(fieldLabel),
        fieldType = Value(fieldType);
  static Insertable<ProtocolSeedingField> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? fieldKey,
    Expression<String>? fieldLabel,
    Expression<String>? fieldType,
    Expression<String>? unit,
    Expression<bool>? isRequired,
    Expression<bool>? isVisible,
    Expression<int>? sortOrder,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (fieldLabel != null) 'field_label': fieldLabel,
      if (fieldType != null) 'field_type': fieldType,
      if (unit != null) 'unit': unit,
      if (isRequired != null) 'is_required': isRequired,
      if (isVisible != null) 'is_visible': isVisible,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (source != null) 'source': source,
    });
  }

  ProtocolSeedingFieldsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? fieldKey,
      Value<String>? fieldLabel,
      Value<String>? fieldType,
      Value<String?>? unit,
      Value<bool>? isRequired,
      Value<bool>? isVisible,
      Value<int>? sortOrder,
      Value<String>? source}) {
    return ProtocolSeedingFieldsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      fieldKey: fieldKey ?? this.fieldKey,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldType: fieldType ?? this.fieldType,
      unit: unit ?? this.unit,
      isRequired: isRequired ?? this.isRequired,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (fieldLabel.present) {
      map['field_label'] = Variable<String>(fieldLabel.value);
    }
    if (fieldType.present) {
      map['field_type'] = Variable<String>(fieldType.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProtocolSeedingFieldsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('fieldLabel: $fieldLabel, ')
          ..write('fieldType: $fieldType, ')
          ..write('unit: $unit, ')
          ..write('isRequired: $isRequired, ')
          ..write('isVisible: $isVisible, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $SeedingFieldValuesTable extends SeedingFieldValues
    with TableInfo<$SeedingFieldValuesTable, SeedingFieldValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeedingFieldValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _seedingRecordIdMeta =
      const VerificationMeta('seedingRecordId');
  @override
  late final GeneratedColumn<int> seedingRecordId = GeneratedColumn<int>(
      'seeding_record_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES seeding_records (id)'));
  static const VerificationMeta _fieldKeyMeta =
      const VerificationMeta('fieldKey');
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
      'field_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fieldLabelMeta =
      const VerificationMeta('fieldLabel');
  @override
  late final GeneratedColumn<String> fieldLabel = GeneratedColumn<String>(
      'field_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueTextMeta =
      const VerificationMeta('valueText');
  @override
  late final GeneratedColumn<String> valueText = GeneratedColumn<String>(
      'value_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _valueNumberMeta =
      const VerificationMeta('valueNumber');
  @override
  late final GeneratedColumn<double> valueNumber = GeneratedColumn<double>(
      'value_number', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _valueDateMeta =
      const VerificationMeta('valueDate');
  @override
  late final GeneratedColumn<String> valueDate = GeneratedColumn<String>(
      'value_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _valueBoolMeta =
      const VerificationMeta('valueBool');
  @override
  late final GeneratedColumn<bool> valueBool = GeneratedColumn<bool>(
      'value_bool', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("value_bool" IN (0, 1))'));
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        seedingRecordId,
        fieldKey,
        fieldLabel,
        valueText,
        valueNumber,
        valueDate,
        valueBool,
        unit,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seeding_field_values';
  @override
  VerificationContext validateIntegrity(Insertable<SeedingFieldValue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('seeding_record_id')) {
      context.handle(
          _seedingRecordIdMeta,
          seedingRecordId.isAcceptableOrUnknown(
              data['seeding_record_id']!, _seedingRecordIdMeta));
    } else if (isInserting) {
      context.missing(_seedingRecordIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(_fieldKeyMeta,
          fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta));
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('field_label')) {
      context.handle(
          _fieldLabelMeta,
          fieldLabel.isAcceptableOrUnknown(
              data['field_label']!, _fieldLabelMeta));
    } else if (isInserting) {
      context.missing(_fieldLabelMeta);
    }
    if (data.containsKey('value_text')) {
      context.handle(_valueTextMeta,
          valueText.isAcceptableOrUnknown(data['value_text']!, _valueTextMeta));
    }
    if (data.containsKey('value_number')) {
      context.handle(
          _valueNumberMeta,
          valueNumber.isAcceptableOrUnknown(
              data['value_number']!, _valueNumberMeta));
    }
    if (data.containsKey('value_date')) {
      context.handle(_valueDateMeta,
          valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta));
    }
    if (data.containsKey('value_bool')) {
      context.handle(_valueBoolMeta,
          valueBool.isAcceptableOrUnknown(data['value_bool']!, _valueBoolMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeedingFieldValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeedingFieldValue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      seedingRecordId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seeding_record_id'])!,
      fieldKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field_key'])!,
      fieldLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field_label'])!,
      valueText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value_text']),
      valueNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value_number']),
      valueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value_date']),
      valueBool: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}value_bool']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $SeedingFieldValuesTable createAlias(String alias) {
    return $SeedingFieldValuesTable(attachedDatabase, alias);
  }
}

class SeedingFieldValue extends DataClass
    implements Insertable<SeedingFieldValue> {
  final int id;
  final int seedingRecordId;
  final String fieldKey;
  final String fieldLabel;
  final String? valueText;
  final double? valueNumber;
  final String? valueDate;
  final bool? valueBool;
  final String? unit;
  final int sortOrder;
  const SeedingFieldValue(
      {required this.id,
      required this.seedingRecordId,
      required this.fieldKey,
      required this.fieldLabel,
      this.valueText,
      this.valueNumber,
      this.valueDate,
      this.valueBool,
      this.unit,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['seeding_record_id'] = Variable<int>(seedingRecordId);
    map['field_key'] = Variable<String>(fieldKey);
    map['field_label'] = Variable<String>(fieldLabel);
    if (!nullToAbsent || valueText != null) {
      map['value_text'] = Variable<String>(valueText);
    }
    if (!nullToAbsent || valueNumber != null) {
      map['value_number'] = Variable<double>(valueNumber);
    }
    if (!nullToAbsent || valueDate != null) {
      map['value_date'] = Variable<String>(valueDate);
    }
    if (!nullToAbsent || valueBool != null) {
      map['value_bool'] = Variable<bool>(valueBool);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SeedingFieldValuesCompanion toCompanion(bool nullToAbsent) {
    return SeedingFieldValuesCompanion(
      id: Value(id),
      seedingRecordId: Value(seedingRecordId),
      fieldKey: Value(fieldKey),
      fieldLabel: Value(fieldLabel),
      valueText: valueText == null && nullToAbsent
          ? const Value.absent()
          : Value(valueText),
      valueNumber: valueNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(valueNumber),
      valueDate: valueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(valueDate),
      valueBool: valueBool == null && nullToAbsent
          ? const Value.absent()
          : Value(valueBool),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      sortOrder: Value(sortOrder),
    );
  }

  factory SeedingFieldValue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeedingFieldValue(
      id: serializer.fromJson<int>(json['id']),
      seedingRecordId: serializer.fromJson<int>(json['seedingRecordId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      fieldLabel: serializer.fromJson<String>(json['fieldLabel']),
      valueText: serializer.fromJson<String?>(json['valueText']),
      valueNumber: serializer.fromJson<double?>(json['valueNumber']),
      valueDate: serializer.fromJson<String?>(json['valueDate']),
      valueBool: serializer.fromJson<bool?>(json['valueBool']),
      unit: serializer.fromJson<String?>(json['unit']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'seedingRecordId': serializer.toJson<int>(seedingRecordId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'fieldLabel': serializer.toJson<String>(fieldLabel),
      'valueText': serializer.toJson<String?>(valueText),
      'valueNumber': serializer.toJson<double?>(valueNumber),
      'valueDate': serializer.toJson<String?>(valueDate),
      'valueBool': serializer.toJson<bool?>(valueBool),
      'unit': serializer.toJson<String?>(unit),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SeedingFieldValue copyWith(
          {int? id,
          int? seedingRecordId,
          String? fieldKey,
          String? fieldLabel,
          Value<String?> valueText = const Value.absent(),
          Value<double?> valueNumber = const Value.absent(),
          Value<String?> valueDate = const Value.absent(),
          Value<bool?> valueBool = const Value.absent(),
          Value<String?> unit = const Value.absent(),
          int? sortOrder}) =>
      SeedingFieldValue(
        id: id ?? this.id,
        seedingRecordId: seedingRecordId ?? this.seedingRecordId,
        fieldKey: fieldKey ?? this.fieldKey,
        fieldLabel: fieldLabel ?? this.fieldLabel,
        valueText: valueText.present ? valueText.value : this.valueText,
        valueNumber: valueNumber.present ? valueNumber.value : this.valueNumber,
        valueDate: valueDate.present ? valueDate.value : this.valueDate,
        valueBool: valueBool.present ? valueBool.value : this.valueBool,
        unit: unit.present ? unit.value : this.unit,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  SeedingFieldValue copyWithCompanion(SeedingFieldValuesCompanion data) {
    return SeedingFieldValue(
      id: data.id.present ? data.id.value : this.id,
      seedingRecordId: data.seedingRecordId.present
          ? data.seedingRecordId.value
          : this.seedingRecordId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      fieldLabel:
          data.fieldLabel.present ? data.fieldLabel.value : this.fieldLabel,
      valueText: data.valueText.present ? data.valueText.value : this.valueText,
      valueNumber:
          data.valueNumber.present ? data.valueNumber.value : this.valueNumber,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
      valueBool: data.valueBool.present ? data.valueBool.value : this.valueBool,
      unit: data.unit.present ? data.unit.value : this.unit,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeedingFieldValue(')
          ..write('id: $id, ')
          ..write('seedingRecordId: $seedingRecordId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('fieldLabel: $fieldLabel, ')
          ..write('valueText: $valueText, ')
          ..write('valueNumber: $valueNumber, ')
          ..write('valueDate: $valueDate, ')
          ..write('valueBool: $valueBool, ')
          ..write('unit: $unit, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, seedingRecordId, fieldKey, fieldLabel,
      valueText, valueNumber, valueDate, valueBool, unit, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeedingFieldValue &&
          other.id == this.id &&
          other.seedingRecordId == this.seedingRecordId &&
          other.fieldKey == this.fieldKey &&
          other.fieldLabel == this.fieldLabel &&
          other.valueText == this.valueText &&
          other.valueNumber == this.valueNumber &&
          other.valueDate == this.valueDate &&
          other.valueBool == this.valueBool &&
          other.unit == this.unit &&
          other.sortOrder == this.sortOrder);
}

class SeedingFieldValuesCompanion extends UpdateCompanion<SeedingFieldValue> {
  final Value<int> id;
  final Value<int> seedingRecordId;
  final Value<String> fieldKey;
  final Value<String> fieldLabel;
  final Value<String?> valueText;
  final Value<double?> valueNumber;
  final Value<String?> valueDate;
  final Value<bool?> valueBool;
  final Value<String?> unit;
  final Value<int> sortOrder;
  const SeedingFieldValuesCompanion({
    this.id = const Value.absent(),
    this.seedingRecordId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.fieldLabel = const Value.absent(),
    this.valueText = const Value.absent(),
    this.valueNumber = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.valueBool = const Value.absent(),
    this.unit = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  SeedingFieldValuesCompanion.insert({
    this.id = const Value.absent(),
    required int seedingRecordId,
    required String fieldKey,
    required String fieldLabel,
    this.valueText = const Value.absent(),
    this.valueNumber = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.valueBool = const Value.absent(),
    this.unit = const Value.absent(),
    this.sortOrder = const Value.absent(),
  })  : seedingRecordId = Value(seedingRecordId),
        fieldKey = Value(fieldKey),
        fieldLabel = Value(fieldLabel);
  static Insertable<SeedingFieldValue> custom({
    Expression<int>? id,
    Expression<int>? seedingRecordId,
    Expression<String>? fieldKey,
    Expression<String>? fieldLabel,
    Expression<String>? valueText,
    Expression<double>? valueNumber,
    Expression<String>? valueDate,
    Expression<bool>? valueBool,
    Expression<String>? unit,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seedingRecordId != null) 'seeding_record_id': seedingRecordId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (fieldLabel != null) 'field_label': fieldLabel,
      if (valueText != null) 'value_text': valueText,
      if (valueNumber != null) 'value_number': valueNumber,
      if (valueDate != null) 'value_date': valueDate,
      if (valueBool != null) 'value_bool': valueBool,
      if (unit != null) 'unit': unit,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  SeedingFieldValuesCompanion copyWith(
      {Value<int>? id,
      Value<int>? seedingRecordId,
      Value<String>? fieldKey,
      Value<String>? fieldLabel,
      Value<String?>? valueText,
      Value<double?>? valueNumber,
      Value<String?>? valueDate,
      Value<bool?>? valueBool,
      Value<String?>? unit,
      Value<int>? sortOrder}) {
    return SeedingFieldValuesCompanion(
      id: id ?? this.id,
      seedingRecordId: seedingRecordId ?? this.seedingRecordId,
      fieldKey: fieldKey ?? this.fieldKey,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      valueText: valueText ?? this.valueText,
      valueNumber: valueNumber ?? this.valueNumber,
      valueDate: valueDate ?? this.valueDate,
      valueBool: valueBool ?? this.valueBool,
      unit: unit ?? this.unit,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (seedingRecordId.present) {
      map['seeding_record_id'] = Variable<int>(seedingRecordId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (fieldLabel.present) {
      map['field_label'] = Variable<String>(fieldLabel.value);
    }
    if (valueText.present) {
      map['value_text'] = Variable<String>(valueText.value);
    }
    if (valueNumber.present) {
      map['value_number'] = Variable<double>(valueNumber.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<String>(valueDate.value);
    }
    if (valueBool.present) {
      map['value_bool'] = Variable<bool>(valueBool.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeedingFieldValuesCompanion(')
          ..write('id: $id, ')
          ..write('seedingRecordId: $seedingRecordId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('fieldLabel: $fieldLabel, ')
          ..write('valueText: $valueText, ')
          ..write('valueNumber: $valueNumber, ')
          ..write('valueDate: $valueDate, ')
          ..write('valueBool: $valueBool, ')
          ..write('unit: $unit, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ApplicationSlotsTable extends ApplicationSlots
    with TableInfo<$ApplicationSlotsTable, ApplicationSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplicationSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _slotCodeMeta =
      const VerificationMeta('slotCode');
  @override
  late final GeneratedColumn<String> slotCode = GeneratedColumn<String>(
      'slot_code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 20),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _timingLabelMeta =
      const VerificationMeta('timingLabel');
  @override
  late final GeneratedColumn<String> timingLabel = GeneratedColumn<String>(
      'timing_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _methodDefaultMeta =
      const VerificationMeta('methodDefault');
  @override
  late final GeneratedColumn<String> methodDefault = GeneratedColumn<String>(
      'method_default', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('spray'));
  static const VerificationMeta _plannedGrowthStageMeta =
      const VerificationMeta('plannedGrowthStage');
  @override
  late final GeneratedColumn<String> plannedGrowthStage =
      GeneratedColumn<String>('planned_growth_stage', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _protocolNotesMeta =
      const VerificationMeta('protocolNotes');
  @override
  late final GeneratedColumn<String> protocolNotes = GeneratedColumn<String>(
      'protocol_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        slotCode,
        timingLabel,
        methodDefault,
        plannedGrowthStage,
        protocolNotes,
        sortOrder,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'application_slots';
  @override
  VerificationContext validateIntegrity(Insertable<ApplicationSlot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('slot_code')) {
      context.handle(_slotCodeMeta,
          slotCode.isAcceptableOrUnknown(data['slot_code']!, _slotCodeMeta));
    } else if (isInserting) {
      context.missing(_slotCodeMeta);
    }
    if (data.containsKey('timing_label')) {
      context.handle(
          _timingLabelMeta,
          timingLabel.isAcceptableOrUnknown(
              data['timing_label']!, _timingLabelMeta));
    }
    if (data.containsKey('method_default')) {
      context.handle(
          _methodDefaultMeta,
          methodDefault.isAcceptableOrUnknown(
              data['method_default']!, _methodDefaultMeta));
    }
    if (data.containsKey('planned_growth_stage')) {
      context.handle(
          _plannedGrowthStageMeta,
          plannedGrowthStage.isAcceptableOrUnknown(
              data['planned_growth_stage']!, _plannedGrowthStageMeta));
    }
    if (data.containsKey('protocol_notes')) {
      context.handle(
          _protocolNotesMeta,
          protocolNotes.isAcceptableOrUnknown(
              data['protocol_notes']!, _protocolNotesMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplicationSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplicationSlot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      slotCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slot_code'])!,
      timingLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timing_label']),
      methodDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method_default'])!,
      plannedGrowthStage: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}planned_growth_stage']),
      protocolNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}protocol_notes']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ApplicationSlotsTable createAlias(String alias) {
    return $ApplicationSlotsTable(attachedDatabase, alias);
  }
}

class ApplicationSlot extends DataClass implements Insertable<ApplicationSlot> {
  final int id;
  final int trialId;
  final String slotCode;
  final String? timingLabel;
  final String methodDefault;
  final String? plannedGrowthStage;
  final String? protocolNotes;
  final int sortOrder;
  final DateTime createdAt;
  const ApplicationSlot(
      {required this.id,
      required this.trialId,
      required this.slotCode,
      this.timingLabel,
      required this.methodDefault,
      this.plannedGrowthStage,
      this.protocolNotes,
      required this.sortOrder,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['slot_code'] = Variable<String>(slotCode);
    if (!nullToAbsent || timingLabel != null) {
      map['timing_label'] = Variable<String>(timingLabel);
    }
    map['method_default'] = Variable<String>(methodDefault);
    if (!nullToAbsent || plannedGrowthStage != null) {
      map['planned_growth_stage'] = Variable<String>(plannedGrowthStage);
    }
    if (!nullToAbsent || protocolNotes != null) {
      map['protocol_notes'] = Variable<String>(protocolNotes);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ApplicationSlotsCompanion toCompanion(bool nullToAbsent) {
    return ApplicationSlotsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      slotCode: Value(slotCode),
      timingLabel: timingLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(timingLabel),
      methodDefault: Value(methodDefault),
      plannedGrowthStage: plannedGrowthStage == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedGrowthStage),
      protocolNotes: protocolNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(protocolNotes),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory ApplicationSlot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplicationSlot(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      slotCode: serializer.fromJson<String>(json['slotCode']),
      timingLabel: serializer.fromJson<String?>(json['timingLabel']),
      methodDefault: serializer.fromJson<String>(json['methodDefault']),
      plannedGrowthStage:
          serializer.fromJson<String?>(json['plannedGrowthStage']),
      protocolNotes: serializer.fromJson<String?>(json['protocolNotes']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'slotCode': serializer.toJson<String>(slotCode),
      'timingLabel': serializer.toJson<String?>(timingLabel),
      'methodDefault': serializer.toJson<String>(methodDefault),
      'plannedGrowthStage': serializer.toJson<String?>(plannedGrowthStage),
      'protocolNotes': serializer.toJson<String?>(protocolNotes),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ApplicationSlot copyWith(
          {int? id,
          int? trialId,
          String? slotCode,
          Value<String?> timingLabel = const Value.absent(),
          String? methodDefault,
          Value<String?> plannedGrowthStage = const Value.absent(),
          Value<String?> protocolNotes = const Value.absent(),
          int? sortOrder,
          DateTime? createdAt}) =>
      ApplicationSlot(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        slotCode: slotCode ?? this.slotCode,
        timingLabel: timingLabel.present ? timingLabel.value : this.timingLabel,
        methodDefault: methodDefault ?? this.methodDefault,
        plannedGrowthStage: plannedGrowthStage.present
            ? plannedGrowthStage.value
            : this.plannedGrowthStage,
        protocolNotes:
            protocolNotes.present ? protocolNotes.value : this.protocolNotes,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );
  ApplicationSlot copyWithCompanion(ApplicationSlotsCompanion data) {
    return ApplicationSlot(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      slotCode: data.slotCode.present ? data.slotCode.value : this.slotCode,
      timingLabel:
          data.timingLabel.present ? data.timingLabel.value : this.timingLabel,
      methodDefault: data.methodDefault.present
          ? data.methodDefault.value
          : this.methodDefault,
      plannedGrowthStage: data.plannedGrowthStage.present
          ? data.plannedGrowthStage.value
          : this.plannedGrowthStage,
      protocolNotes: data.protocolNotes.present
          ? data.protocolNotes.value
          : this.protocolNotes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationSlot(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('slotCode: $slotCode, ')
          ..write('timingLabel: $timingLabel, ')
          ..write('methodDefault: $methodDefault, ')
          ..write('plannedGrowthStage: $plannedGrowthStage, ')
          ..write('protocolNotes: $protocolNotes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, slotCode, timingLabel,
      methodDefault, plannedGrowthStage, protocolNotes, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplicationSlot &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.slotCode == this.slotCode &&
          other.timingLabel == this.timingLabel &&
          other.methodDefault == this.methodDefault &&
          other.plannedGrowthStage == this.plannedGrowthStage &&
          other.protocolNotes == this.protocolNotes &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class ApplicationSlotsCompanion extends UpdateCompanion<ApplicationSlot> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> slotCode;
  final Value<String?> timingLabel;
  final Value<String> methodDefault;
  final Value<String?> plannedGrowthStage;
  final Value<String?> protocolNotes;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const ApplicationSlotsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.slotCode = const Value.absent(),
    this.timingLabel = const Value.absent(),
    this.methodDefault = const Value.absent(),
    this.plannedGrowthStage = const Value.absent(),
    this.protocolNotes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ApplicationSlotsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String slotCode,
    this.timingLabel = const Value.absent(),
    this.methodDefault = const Value.absent(),
    this.plannedGrowthStage = const Value.absent(),
    this.protocolNotes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : trialId = Value(trialId),
        slotCode = Value(slotCode);
  static Insertable<ApplicationSlot> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? slotCode,
    Expression<String>? timingLabel,
    Expression<String>? methodDefault,
    Expression<String>? plannedGrowthStage,
    Expression<String>? protocolNotes,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (slotCode != null) 'slot_code': slotCode,
      if (timingLabel != null) 'timing_label': timingLabel,
      if (methodDefault != null) 'method_default': methodDefault,
      if (plannedGrowthStage != null)
        'planned_growth_stage': plannedGrowthStage,
      if (protocolNotes != null) 'protocol_notes': protocolNotes,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ApplicationSlotsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? slotCode,
      Value<String?>? timingLabel,
      Value<String>? methodDefault,
      Value<String?>? plannedGrowthStage,
      Value<String?>? protocolNotes,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt}) {
    return ApplicationSlotsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      slotCode: slotCode ?? this.slotCode,
      timingLabel: timingLabel ?? this.timingLabel,
      methodDefault: methodDefault ?? this.methodDefault,
      plannedGrowthStage: plannedGrowthStage ?? this.plannedGrowthStage,
      protocolNotes: protocolNotes ?? this.protocolNotes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (slotCode.present) {
      map['slot_code'] = Variable<String>(slotCode.value);
    }
    if (timingLabel.present) {
      map['timing_label'] = Variable<String>(timingLabel.value);
    }
    if (methodDefault.present) {
      map['method_default'] = Variable<String>(methodDefault.value);
    }
    if (plannedGrowthStage.present) {
      map['planned_growth_stage'] = Variable<String>(plannedGrowthStage.value);
    }
    if (protocolNotes.present) {
      map['protocol_notes'] = Variable<String>(protocolNotes.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationSlotsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('slotCode: $slotCode, ')
          ..write('timingLabel: $timingLabel, ')
          ..write('methodDefault: $methodDefault, ')
          ..write('plannedGrowthStage: $plannedGrowthStage, ')
          ..write('protocolNotes: $protocolNotes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ApplicationEventsTable extends ApplicationEvents
    with TableInfo<$ApplicationEventsTable, ApplicationEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplicationEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _applicationSlotIdMeta =
      const VerificationMeta('applicationSlotId');
  @override
  late final GeneratedColumn<int> applicationSlotId = GeneratedColumn<int>(
      'application_slot_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES application_slots (id)'));
  static const VerificationMeta _applicationNumberMeta =
      const VerificationMeta('applicationNumber');
  @override
  late final GeneratedColumn<int> applicationNumber = GeneratedColumn<int>(
      'application_number', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _timingLabelMeta =
      const VerificationMeta('timingLabel');
  @override
  late final GeneratedColumn<String> timingLabel = GeneratedColumn<String>(
      'timing_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
      'method', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('spray'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('planned'));
  static const VerificationMeta _applicationDateMeta =
      const VerificationMeta('applicationDate');
  @override
  late final GeneratedColumn<DateTime> applicationDate =
      GeneratedColumn<DateTime>('application_date', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _growthStageMeta =
      const VerificationMeta('growthStage');
  @override
  late final GeneratedColumn<String> growthStage = GeneratedColumn<String>(
      'growth_stage', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _operatorNameMeta =
      const VerificationMeta('operatorName');
  @override
  late final GeneratedColumn<String> operatorName = GeneratedColumn<String>(
      'operator_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _equipmentMeta =
      const VerificationMeta('equipment');
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
      'equipment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _weatherMeta =
      const VerificationMeta('weather');
  @override
  late final GeneratedColumn<String> weather = GeneratedColumn<String>(
      'weather', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _partialFlagMeta =
      const VerificationMeta('partialFlag');
  @override
  late final GeneratedColumn<bool> partialFlag = GeneratedColumn<bool>(
      'partial_flag', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("partial_flag" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _completedByMeta =
      const VerificationMeta('completedBy');
  @override
  late final GeneratedColumn<String> completedBy = GeneratedColumn<String>(
      'completed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        sessionId,
        applicationSlotId,
        applicationNumber,
        timingLabel,
        method,
        status,
        applicationDate,
        growthStage,
        operatorName,
        equipment,
        weather,
        notes,
        partialFlag,
        completedAt,
        completedBy,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'application_events';
  @override
  VerificationContext validateIntegrity(Insertable<ApplicationEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('application_slot_id')) {
      context.handle(
          _applicationSlotIdMeta,
          applicationSlotId.isAcceptableOrUnknown(
              data['application_slot_id']!, _applicationSlotIdMeta));
    }
    if (data.containsKey('application_number')) {
      context.handle(
          _applicationNumberMeta,
          applicationNumber.isAcceptableOrUnknown(
              data['application_number']!, _applicationNumberMeta));
    }
    if (data.containsKey('timing_label')) {
      context.handle(
          _timingLabelMeta,
          timingLabel.isAcceptableOrUnknown(
              data['timing_label']!, _timingLabelMeta));
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('application_date')) {
      context.handle(
          _applicationDateMeta,
          applicationDate.isAcceptableOrUnknown(
              data['application_date']!, _applicationDateMeta));
    } else if (isInserting) {
      context.missing(_applicationDateMeta);
    }
    if (data.containsKey('growth_stage')) {
      context.handle(
          _growthStageMeta,
          growthStage.isAcceptableOrUnknown(
              data['growth_stage']!, _growthStageMeta));
    }
    if (data.containsKey('operator_name')) {
      context.handle(
          _operatorNameMeta,
          operatorName.isAcceptableOrUnknown(
              data['operator_name']!, _operatorNameMeta));
    }
    if (data.containsKey('equipment')) {
      context.handle(_equipmentMeta,
          equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta));
    }
    if (data.containsKey('weather')) {
      context.handle(_weatherMeta,
          weather.isAcceptableOrUnknown(data['weather']!, _weatherMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('partial_flag')) {
      context.handle(
          _partialFlagMeta,
          partialFlag.isAcceptableOrUnknown(
              data['partial_flag']!, _partialFlagMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('completed_by')) {
      context.handle(
          _completedByMeta,
          completedBy.isAcceptableOrUnknown(
              data['completed_by']!, _completedByMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplicationEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplicationEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id']),
      applicationSlotId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}application_slot_id']),
      applicationNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}application_number'])!,
      timingLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timing_label']),
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      applicationDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}application_date'])!,
      growthStage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}growth_stage']),
      operatorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operator_name']),
      equipment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment']),
      weather: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}weather']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      partialFlag: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}partial_flag'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      completedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}completed_by']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ApplicationEventsTable createAlias(String alias) {
    return $ApplicationEventsTable(attachedDatabase, alias);
  }
}

class ApplicationEvent extends DataClass
    implements Insertable<ApplicationEvent> {
  final int id;
  final int trialId;
  final int? sessionId;
  final int? applicationSlotId;
  final int applicationNumber;
  final String? timingLabel;
  final String method;
  final String status;
  final DateTime applicationDate;
  final String? growthStage;
  final String? operatorName;
  final String? equipment;
  final String? weather;
  final String? notes;
  final bool partialFlag;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;
  const ApplicationEvent(
      {required this.id,
      required this.trialId,
      this.sessionId,
      this.applicationSlotId,
      required this.applicationNumber,
      this.timingLabel,
      required this.method,
      required this.status,
      required this.applicationDate,
      this.growthStage,
      this.operatorName,
      this.equipment,
      this.weather,
      this.notes,
      required this.partialFlag,
      this.completedAt,
      this.completedBy,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    if (!nullToAbsent || applicationSlotId != null) {
      map['application_slot_id'] = Variable<int>(applicationSlotId);
    }
    map['application_number'] = Variable<int>(applicationNumber);
    if (!nullToAbsent || timingLabel != null) {
      map['timing_label'] = Variable<String>(timingLabel);
    }
    map['method'] = Variable<String>(method);
    map['status'] = Variable<String>(status);
    map['application_date'] = Variable<DateTime>(applicationDate);
    if (!nullToAbsent || growthStage != null) {
      map['growth_stage'] = Variable<String>(growthStage);
    }
    if (!nullToAbsent || operatorName != null) {
      map['operator_name'] = Variable<String>(operatorName);
    }
    if (!nullToAbsent || equipment != null) {
      map['equipment'] = Variable<String>(equipment);
    }
    if (!nullToAbsent || weather != null) {
      map['weather'] = Variable<String>(weather);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['partial_flag'] = Variable<bool>(partialFlag);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || completedBy != null) {
      map['completed_by'] = Variable<String>(completedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ApplicationEventsCompanion toCompanion(bool nullToAbsent) {
    return ApplicationEventsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      applicationSlotId: applicationSlotId == null && nullToAbsent
          ? const Value.absent()
          : Value(applicationSlotId),
      applicationNumber: Value(applicationNumber),
      timingLabel: timingLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(timingLabel),
      method: Value(method),
      status: Value(status),
      applicationDate: Value(applicationDate),
      growthStage: growthStage == null && nullToAbsent
          ? const Value.absent()
          : Value(growthStage),
      operatorName: operatorName == null && nullToAbsent
          ? const Value.absent()
          : Value(operatorName),
      equipment: equipment == null && nullToAbsent
          ? const Value.absent()
          : Value(equipment),
      weather: weather == null && nullToAbsent
          ? const Value.absent()
          : Value(weather),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      partialFlag: Value(partialFlag),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      completedBy: completedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(completedBy),
      createdAt: Value(createdAt),
    );
  }

  factory ApplicationEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplicationEvent(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      applicationSlotId: serializer.fromJson<int?>(json['applicationSlotId']),
      applicationNumber: serializer.fromJson<int>(json['applicationNumber']),
      timingLabel: serializer.fromJson<String?>(json['timingLabel']),
      method: serializer.fromJson<String>(json['method']),
      status: serializer.fromJson<String>(json['status']),
      applicationDate: serializer.fromJson<DateTime>(json['applicationDate']),
      growthStage: serializer.fromJson<String?>(json['growthStage']),
      operatorName: serializer.fromJson<String?>(json['operatorName']),
      equipment: serializer.fromJson<String?>(json['equipment']),
      weather: serializer.fromJson<String?>(json['weather']),
      notes: serializer.fromJson<String?>(json['notes']),
      partialFlag: serializer.fromJson<bool>(json['partialFlag']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      completedBy: serializer.fromJson<String?>(json['completedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'sessionId': serializer.toJson<int?>(sessionId),
      'applicationSlotId': serializer.toJson<int?>(applicationSlotId),
      'applicationNumber': serializer.toJson<int>(applicationNumber),
      'timingLabel': serializer.toJson<String?>(timingLabel),
      'method': serializer.toJson<String>(method),
      'status': serializer.toJson<String>(status),
      'applicationDate': serializer.toJson<DateTime>(applicationDate),
      'growthStage': serializer.toJson<String?>(growthStage),
      'operatorName': serializer.toJson<String?>(operatorName),
      'equipment': serializer.toJson<String?>(equipment),
      'weather': serializer.toJson<String?>(weather),
      'notes': serializer.toJson<String?>(notes),
      'partialFlag': serializer.toJson<bool>(partialFlag),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'completedBy': serializer.toJson<String?>(completedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ApplicationEvent copyWith(
          {int? id,
          int? trialId,
          Value<int?> sessionId = const Value.absent(),
          Value<int?> applicationSlotId = const Value.absent(),
          int? applicationNumber,
          Value<String?> timingLabel = const Value.absent(),
          String? method,
          String? status,
          DateTime? applicationDate,
          Value<String?> growthStage = const Value.absent(),
          Value<String?> operatorName = const Value.absent(),
          Value<String?> equipment = const Value.absent(),
          Value<String?> weather = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          bool? partialFlag,
          Value<DateTime?> completedAt = const Value.absent(),
          Value<String?> completedBy = const Value.absent(),
          DateTime? createdAt}) =>
      ApplicationEvent(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        applicationSlotId: applicationSlotId.present
            ? applicationSlotId.value
            : this.applicationSlotId,
        applicationNumber: applicationNumber ?? this.applicationNumber,
        timingLabel: timingLabel.present ? timingLabel.value : this.timingLabel,
        method: method ?? this.method,
        status: status ?? this.status,
        applicationDate: applicationDate ?? this.applicationDate,
        growthStage: growthStage.present ? growthStage.value : this.growthStage,
        operatorName:
            operatorName.present ? operatorName.value : this.operatorName,
        equipment: equipment.present ? equipment.value : this.equipment,
        weather: weather.present ? weather.value : this.weather,
        notes: notes.present ? notes.value : this.notes,
        partialFlag: partialFlag ?? this.partialFlag,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        completedBy: completedBy.present ? completedBy.value : this.completedBy,
        createdAt: createdAt ?? this.createdAt,
      );
  ApplicationEvent copyWithCompanion(ApplicationEventsCompanion data) {
    return ApplicationEvent(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      applicationSlotId: data.applicationSlotId.present
          ? data.applicationSlotId.value
          : this.applicationSlotId,
      applicationNumber: data.applicationNumber.present
          ? data.applicationNumber.value
          : this.applicationNumber,
      timingLabel:
          data.timingLabel.present ? data.timingLabel.value : this.timingLabel,
      method: data.method.present ? data.method.value : this.method,
      status: data.status.present ? data.status.value : this.status,
      applicationDate: data.applicationDate.present
          ? data.applicationDate.value
          : this.applicationDate,
      growthStage:
          data.growthStage.present ? data.growthStage.value : this.growthStage,
      operatorName: data.operatorName.present
          ? data.operatorName.value
          : this.operatorName,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      weather: data.weather.present ? data.weather.value : this.weather,
      notes: data.notes.present ? data.notes.value : this.notes,
      partialFlag:
          data.partialFlag.present ? data.partialFlag.value : this.partialFlag,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      completedBy:
          data.completedBy.present ? data.completedBy.value : this.completedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationEvent(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('sessionId: $sessionId, ')
          ..write('applicationSlotId: $applicationSlotId, ')
          ..write('applicationNumber: $applicationNumber, ')
          ..write('timingLabel: $timingLabel, ')
          ..write('method: $method, ')
          ..write('status: $status, ')
          ..write('applicationDate: $applicationDate, ')
          ..write('growthStage: $growthStage, ')
          ..write('operatorName: $operatorName, ')
          ..write('equipment: $equipment, ')
          ..write('weather: $weather, ')
          ..write('notes: $notes, ')
          ..write('partialFlag: $partialFlag, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trialId,
      sessionId,
      applicationSlotId,
      applicationNumber,
      timingLabel,
      method,
      status,
      applicationDate,
      growthStage,
      operatorName,
      equipment,
      weather,
      notes,
      partialFlag,
      completedAt,
      completedBy,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplicationEvent &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.sessionId == this.sessionId &&
          other.applicationSlotId == this.applicationSlotId &&
          other.applicationNumber == this.applicationNumber &&
          other.timingLabel == this.timingLabel &&
          other.method == this.method &&
          other.status == this.status &&
          other.applicationDate == this.applicationDate &&
          other.growthStage == this.growthStage &&
          other.operatorName == this.operatorName &&
          other.equipment == this.equipment &&
          other.weather == this.weather &&
          other.notes == this.notes &&
          other.partialFlag == this.partialFlag &&
          other.completedAt == this.completedAt &&
          other.completedBy == this.completedBy &&
          other.createdAt == this.createdAt);
}

class ApplicationEventsCompanion extends UpdateCompanion<ApplicationEvent> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int?> sessionId;
  final Value<int?> applicationSlotId;
  final Value<int> applicationNumber;
  final Value<String?> timingLabel;
  final Value<String> method;
  final Value<String> status;
  final Value<DateTime> applicationDate;
  final Value<String?> growthStage;
  final Value<String?> operatorName;
  final Value<String?> equipment;
  final Value<String?> weather;
  final Value<String?> notes;
  final Value<bool> partialFlag;
  final Value<DateTime?> completedAt;
  final Value<String?> completedBy;
  final Value<DateTime> createdAt;
  const ApplicationEventsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.applicationSlotId = const Value.absent(),
    this.applicationNumber = const Value.absent(),
    this.timingLabel = const Value.absent(),
    this.method = const Value.absent(),
    this.status = const Value.absent(),
    this.applicationDate = const Value.absent(),
    this.growthStage = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.equipment = const Value.absent(),
    this.weather = const Value.absent(),
    this.notes = const Value.absent(),
    this.partialFlag = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ApplicationEventsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    this.sessionId = const Value.absent(),
    this.applicationSlotId = const Value.absent(),
    this.applicationNumber = const Value.absent(),
    this.timingLabel = const Value.absent(),
    this.method = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime applicationDate,
    this.growthStage = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.equipment = const Value.absent(),
    this.weather = const Value.absent(),
    this.notes = const Value.absent(),
    this.partialFlag = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : trialId = Value(trialId),
        applicationDate = Value(applicationDate);
  static Insertable<ApplicationEvent> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? sessionId,
    Expression<int>? applicationSlotId,
    Expression<int>? applicationNumber,
    Expression<String>? timingLabel,
    Expression<String>? method,
    Expression<String>? status,
    Expression<DateTime>? applicationDate,
    Expression<String>? growthStage,
    Expression<String>? operatorName,
    Expression<String>? equipment,
    Expression<String>? weather,
    Expression<String>? notes,
    Expression<bool>? partialFlag,
    Expression<DateTime>? completedAt,
    Expression<String>? completedBy,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (sessionId != null) 'session_id': sessionId,
      if (applicationSlotId != null) 'application_slot_id': applicationSlotId,
      if (applicationNumber != null) 'application_number': applicationNumber,
      if (timingLabel != null) 'timing_label': timingLabel,
      if (method != null) 'method': method,
      if (status != null) 'status': status,
      if (applicationDate != null) 'application_date': applicationDate,
      if (growthStage != null) 'growth_stage': growthStage,
      if (operatorName != null) 'operator_name': operatorName,
      if (equipment != null) 'equipment': equipment,
      if (weather != null) 'weather': weather,
      if (notes != null) 'notes': notes,
      if (partialFlag != null) 'partial_flag': partialFlag,
      if (completedAt != null) 'completed_at': completedAt,
      if (completedBy != null) 'completed_by': completedBy,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ApplicationEventsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int?>? sessionId,
      Value<int?>? applicationSlotId,
      Value<int>? applicationNumber,
      Value<String?>? timingLabel,
      Value<String>? method,
      Value<String>? status,
      Value<DateTime>? applicationDate,
      Value<String?>? growthStage,
      Value<String?>? operatorName,
      Value<String?>? equipment,
      Value<String?>? weather,
      Value<String?>? notes,
      Value<bool>? partialFlag,
      Value<DateTime?>? completedAt,
      Value<String?>? completedBy,
      Value<DateTime>? createdAt}) {
    return ApplicationEventsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      sessionId: sessionId ?? this.sessionId,
      applicationSlotId: applicationSlotId ?? this.applicationSlotId,
      applicationNumber: applicationNumber ?? this.applicationNumber,
      timingLabel: timingLabel ?? this.timingLabel,
      method: method ?? this.method,
      status: status ?? this.status,
      applicationDate: applicationDate ?? this.applicationDate,
      growthStage: growthStage ?? this.growthStage,
      operatorName: operatorName ?? this.operatorName,
      equipment: equipment ?? this.equipment,
      weather: weather ?? this.weather,
      notes: notes ?? this.notes,
      partialFlag: partialFlag ?? this.partialFlag,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (applicationSlotId.present) {
      map['application_slot_id'] = Variable<int>(applicationSlotId.value);
    }
    if (applicationNumber.present) {
      map['application_number'] = Variable<int>(applicationNumber.value);
    }
    if (timingLabel.present) {
      map['timing_label'] = Variable<String>(timingLabel.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (applicationDate.present) {
      map['application_date'] = Variable<DateTime>(applicationDate.value);
    }
    if (growthStage.present) {
      map['growth_stage'] = Variable<String>(growthStage.value);
    }
    if (operatorName.present) {
      map['operator_name'] = Variable<String>(operatorName.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (weather.present) {
      map['weather'] = Variable<String>(weather.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (partialFlag.present) {
      map['partial_flag'] = Variable<bool>(partialFlag.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completedBy.present) {
      map['completed_by'] = Variable<String>(completedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationEventsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('sessionId: $sessionId, ')
          ..write('applicationSlotId: $applicationSlotId, ')
          ..write('applicationNumber: $applicationNumber, ')
          ..write('timingLabel: $timingLabel, ')
          ..write('method: $method, ')
          ..write('status: $status, ')
          ..write('applicationDate: $applicationDate, ')
          ..write('growthStage: $growthStage, ')
          ..write('operatorName: $operatorName, ')
          ..write('equipment: $equipment, ')
          ..write('weather: $weather, ')
          ..write('notes: $notes, ')
          ..write('partialFlag: $partialFlag, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ApplicationPlotRecordsTable extends ApplicationPlotRecords
    with TableInfo<$ApplicationPlotRecordsTable, ApplicationPlotRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplicationPlotRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
      'event_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES application_events (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('applied'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, eventId, plotPk, trialId, status, notes, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'application_plot_records';
  @override
  VerificationContext validateIntegrity(
      Insertable<ApplicationPlotRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    } else if (isInserting) {
      context.missing(_plotPkMeta);
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplicationPlotRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplicationPlotRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}event_id'])!,
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ApplicationPlotRecordsTable createAlias(String alias) {
    return $ApplicationPlotRecordsTable(attachedDatabase, alias);
  }
}

class ApplicationPlotRecord extends DataClass
    implements Insertable<ApplicationPlotRecord> {
  final int id;
  final int eventId;
  final int plotPk;
  final int trialId;
  final String status;
  final String? notes;
  final DateTime createdAt;
  const ApplicationPlotRecord(
      {required this.id,
      required this.eventId,
      required this.plotPk,
      required this.trialId,
      required this.status,
      this.notes,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['plot_pk'] = Variable<int>(plotPk);
    map['trial_id'] = Variable<int>(trialId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ApplicationPlotRecordsCompanion toCompanion(bool nullToAbsent) {
    return ApplicationPlotRecordsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      plotPk: Value(plotPk),
      trialId: Value(trialId),
      status: Value(status),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory ApplicationPlotRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplicationPlotRecord(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      plotPk: serializer.fromJson<int>(json['plotPk']),
      trialId: serializer.fromJson<int>(json['trialId']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'plotPk': serializer.toJson<int>(plotPk),
      'trialId': serializer.toJson<int>(trialId),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ApplicationPlotRecord copyWith(
          {int? id,
          int? eventId,
          int? plotPk,
          int? trialId,
          String? status,
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt}) =>
      ApplicationPlotRecord(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        plotPk: plotPk ?? this.plotPk,
        trialId: trialId ?? this.trialId,
        status: status ?? this.status,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
  ApplicationPlotRecord copyWithCompanion(
      ApplicationPlotRecordsCompanion data) {
    return ApplicationPlotRecord(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationPlotRecord(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('plotPk: $plotPk, ')
          ..write('trialId: $trialId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, eventId, plotPk, trialId, status, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplicationPlotRecord &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.plotPk == this.plotPk &&
          other.trialId == this.trialId &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class ApplicationPlotRecordsCompanion
    extends UpdateCompanion<ApplicationPlotRecord> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<int> plotPk;
  final Value<int> trialId;
  final Value<String> status;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const ApplicationPlotRecordsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.trialId = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ApplicationPlotRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required int plotPk,
    required int trialId,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : eventId = Value(eventId),
        plotPk = Value(plotPk),
        trialId = Value(trialId);
  static Insertable<ApplicationPlotRecord> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<int>? plotPk,
    Expression<int>? trialId,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (trialId != null) 'trial_id': trialId,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ApplicationPlotRecordsCompanion copyWith(
      {Value<int>? id,
      Value<int>? eventId,
      Value<int>? plotPk,
      Value<int>? trialId,
      Value<String>? status,
      Value<String?>? notes,
      Value<DateTime>? createdAt}) {
    return ApplicationPlotRecordsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      plotPk: plotPk ?? this.plotPk,
      trialId: trialId ?? this.trialId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationPlotRecordsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('plotPk: $plotPk, ')
          ..write('trialId: $trialId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AuditEventsTable extends AuditEvents
    with TableInfo<$AuditEventsTable, AuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _plotPkMeta = const VerificationMeta('plotPk');
  @override
  late final GeneratedColumn<int> plotPk = GeneratedColumn<int>(
      'plot_pk', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _performedByMeta =
      const VerificationMeta('performedBy');
  @override
  late final GeneratedColumn<String> performedBy = GeneratedColumn<String>(
      'performed_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        sessionId,
        plotPk,
        eventType,
        description,
        performedBy,
        createdAt,
        metadata
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_events';
  @override
  VerificationContext validateIntegrity(Insertable<AuditEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('performed_by')) {
      context.handle(
          _performedByMeta,
          performedBy.isAcceptableOrUnknown(
              data['performed_by']!, _performedByMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id']),
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id']),
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk']),
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      performedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}performed_by']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
    );
  }

  @override
  $AuditEventsTable createAlias(String alias) {
    return $AuditEventsTable(attachedDatabase, alias);
  }
}

class AuditEvent extends DataClass implements Insertable<AuditEvent> {
  final int id;
  final int? trialId;
  final int? sessionId;
  final int? plotPk;
  final String eventType;
  final String description;
  final String? performedBy;
  final DateTime createdAt;
  final String? metadata;
  const AuditEvent(
      {required this.id,
      this.trialId,
      this.sessionId,
      this.plotPk,
      required this.eventType,
      required this.description,
      this.performedBy,
      required this.createdAt,
      this.metadata});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || trialId != null) {
      map['trial_id'] = Variable<int>(trialId);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    if (!nullToAbsent || plotPk != null) {
      map['plot_pk'] = Variable<int>(plotPk);
    }
    map['event_type'] = Variable<String>(eventType);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || performedBy != null) {
      map['performed_by'] = Variable<String>(performedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  AuditEventsCompanion toCompanion(bool nullToAbsent) {
    return AuditEventsCompanion(
      id: Value(id),
      trialId: trialId == null && nullToAbsent
          ? const Value.absent()
          : Value(trialId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      plotPk:
          plotPk == null && nullToAbsent ? const Value.absent() : Value(plotPk),
      eventType: Value(eventType),
      description: Value(description),
      performedBy: performedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(performedBy),
      createdAt: Value(createdAt),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
    );
  }

  factory AuditEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditEvent(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int?>(json['trialId']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      plotPk: serializer.fromJson<int?>(json['plotPk']),
      eventType: serializer.fromJson<String>(json['eventType']),
      description: serializer.fromJson<String>(json['description']),
      performedBy: serializer.fromJson<String?>(json['performedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int?>(trialId),
      'sessionId': serializer.toJson<int?>(sessionId),
      'plotPk': serializer.toJson<int?>(plotPk),
      'eventType': serializer.toJson<String>(eventType),
      'description': serializer.toJson<String>(description),
      'performedBy': serializer.toJson<String?>(performedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  AuditEvent copyWith(
          {int? id,
          Value<int?> trialId = const Value.absent(),
          Value<int?> sessionId = const Value.absent(),
          Value<int?> plotPk = const Value.absent(),
          String? eventType,
          String? description,
          Value<String?> performedBy = const Value.absent(),
          DateTime? createdAt,
          Value<String?> metadata = const Value.absent()}) =>
      AuditEvent(
        id: id ?? this.id,
        trialId: trialId.present ? trialId.value : this.trialId,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        plotPk: plotPk.present ? plotPk.value : this.plotPk,
        eventType: eventType ?? this.eventType,
        description: description ?? this.description,
        performedBy: performedBy.present ? performedBy.value : this.performedBy,
        createdAt: createdAt ?? this.createdAt,
        metadata: metadata.present ? metadata.value : this.metadata,
      );
  AuditEvent copyWithCompanion(AuditEventsCompanion data) {
    return AuditEvent(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      description:
          data.description.present ? data.description.value : this.description,
      performedBy:
          data.performedBy.present ? data.performedBy.value : this.performedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditEvent(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('sessionId: $sessionId, ')
          ..write('plotPk: $plotPk, ')
          ..write('eventType: $eventType, ')
          ..write('description: $description, ')
          ..write('performedBy: $performedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, sessionId, plotPk, eventType,
      description, performedBy, createdAt, metadata);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditEvent &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.sessionId == this.sessionId &&
          other.plotPk == this.plotPk &&
          other.eventType == this.eventType &&
          other.description == this.description &&
          other.performedBy == this.performedBy &&
          other.createdAt == this.createdAt &&
          other.metadata == this.metadata);
}

class AuditEventsCompanion extends UpdateCompanion<AuditEvent> {
  final Value<int> id;
  final Value<int?> trialId;
  final Value<int?> sessionId;
  final Value<int?> plotPk;
  final Value<String> eventType;
  final Value<String> description;
  final Value<String?> performedBy;
  final Value<DateTime> createdAt;
  final Value<String?> metadata;
  const AuditEventsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.eventType = const Value.absent(),
    this.description = const Value.absent(),
    this.performedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.metadata = const Value.absent(),
  });
  AuditEventsCompanion.insert({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.plotPk = const Value.absent(),
    required String eventType,
    required String description,
    this.performedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.metadata = const Value.absent(),
  })  : eventType = Value(eventType),
        description = Value(description);
  static Insertable<AuditEvent> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? sessionId,
    Expression<int>? plotPk,
    Expression<String>? eventType,
    Expression<String>? description,
    Expression<String>? performedBy,
    Expression<DateTime>? createdAt,
    Expression<String>? metadata,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (sessionId != null) 'session_id': sessionId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (eventType != null) 'event_type': eventType,
      if (description != null) 'description': description,
      if (performedBy != null) 'performed_by': performedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (metadata != null) 'metadata': metadata,
    });
  }

  AuditEventsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? trialId,
      Value<int?>? sessionId,
      Value<int?>? plotPk,
      Value<String>? eventType,
      Value<String>? description,
      Value<String?>? performedBy,
      Value<DateTime>? createdAt,
      Value<String?>? metadata}) {
    return AuditEventsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      sessionId: sessionId ?? this.sessionId,
      plotPk: plotPk ?? this.plotPk,
      eventType: eventType ?? this.eventType,
      description: description ?? this.description,
      performedBy: performedBy ?? this.performedBy,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (performedBy.present) {
      map['performed_by'] = Variable<String>(performedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('sessionId: $sessionId, ')
          ..write('plotPk: $plotPk, ')
          ..write('eventType: $eventType, ')
          ..write('description: $description, ')
          ..write('performedBy: $performedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }
}

class $ImportEventsTable extends ImportEvents
    with TableInfo<$ImportEventsTable, ImportEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trialIdMeta =
      const VerificationMeta('trialId');
  @override
  late final GeneratedColumn<int> trialId = GeneratedColumn<int>(
      'trial_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES trials (id)'));
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rowsImportedMeta =
      const VerificationMeta('rowsImported');
  @override
  late final GeneratedColumn<int> rowsImported = GeneratedColumn<int>(
      'rows_imported', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rowsSkippedMeta =
      const VerificationMeta('rowsSkipped');
  @override
  late final GeneratedColumn<int> rowsSkipped = GeneratedColumn<int>(
      'rows_skipped', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _warningsMeta =
      const VerificationMeta('warnings');
  @override
  late final GeneratedColumn<String> warnings = GeneratedColumn<String>(
      'warnings', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        fileName,
        status,
        rowsImported,
        rowsSkipped,
        warnings,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_events';
  @override
  VerificationContext validateIntegrity(Insertable<ImportEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trial_id')) {
      context.handle(_trialIdMeta,
          trialId.isAcceptableOrUnknown(data['trial_id']!, _trialIdMeta));
    } else if (isInserting) {
      context.missing(_trialIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('rows_imported')) {
      context.handle(
          _rowsImportedMeta,
          rowsImported.isAcceptableOrUnknown(
              data['rows_imported']!, _rowsImportedMeta));
    }
    if (data.containsKey('rows_skipped')) {
      context.handle(
          _rowsSkippedMeta,
          rowsSkipped.isAcceptableOrUnknown(
              data['rows_skipped']!, _rowsSkippedMeta));
    }
    if (data.containsKey('warnings')) {
      context.handle(_warningsMeta,
          warnings.isAcceptableOrUnknown(data['warnings']!, _warningsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      rowsImported: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rows_imported'])!,
      rowsSkipped: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rows_skipped'])!,
      warnings: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}warnings']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ImportEventsTable createAlias(String alias) {
    return $ImportEventsTable(attachedDatabase, alias);
  }
}

class ImportEvent extends DataClass implements Insertable<ImportEvent> {
  final int id;
  final int trialId;
  final String fileName;
  final String status;
  final int rowsImported;
  final int rowsSkipped;
  final String? warnings;
  final DateTime createdAt;
  const ImportEvent(
      {required this.id,
      required this.trialId,
      required this.fileName,
      required this.status,
      required this.rowsImported,
      required this.rowsSkipped,
      this.warnings,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['file_name'] = Variable<String>(fileName);
    map['status'] = Variable<String>(status);
    map['rows_imported'] = Variable<int>(rowsImported);
    map['rows_skipped'] = Variable<int>(rowsSkipped);
    if (!nullToAbsent || warnings != null) {
      map['warnings'] = Variable<String>(warnings);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ImportEventsCompanion toCompanion(bool nullToAbsent) {
    return ImportEventsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      fileName: Value(fileName),
      status: Value(status),
      rowsImported: Value(rowsImported),
      rowsSkipped: Value(rowsSkipped),
      warnings: warnings == null && nullToAbsent
          ? const Value.absent()
          : Value(warnings),
      createdAt: Value(createdAt),
    );
  }

  factory ImportEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportEvent(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      status: serializer.fromJson<String>(json['status']),
      rowsImported: serializer.fromJson<int>(json['rowsImported']),
      rowsSkipped: serializer.fromJson<int>(json['rowsSkipped']),
      warnings: serializer.fromJson<String?>(json['warnings']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'fileName': serializer.toJson<String>(fileName),
      'status': serializer.toJson<String>(status),
      'rowsImported': serializer.toJson<int>(rowsImported),
      'rowsSkipped': serializer.toJson<int>(rowsSkipped),
      'warnings': serializer.toJson<String?>(warnings),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ImportEvent copyWith(
          {int? id,
          int? trialId,
          String? fileName,
          String? status,
          int? rowsImported,
          int? rowsSkipped,
          Value<String?> warnings = const Value.absent(),
          DateTime? createdAt}) =>
      ImportEvent(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        fileName: fileName ?? this.fileName,
        status: status ?? this.status,
        rowsImported: rowsImported ?? this.rowsImported,
        rowsSkipped: rowsSkipped ?? this.rowsSkipped,
        warnings: warnings.present ? warnings.value : this.warnings,
        createdAt: createdAt ?? this.createdAt,
      );
  ImportEvent copyWithCompanion(ImportEventsCompanion data) {
    return ImportEvent(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      status: data.status.present ? data.status.value : this.status,
      rowsImported: data.rowsImported.present
          ? data.rowsImported.value
          : this.rowsImported,
      rowsSkipped:
          data.rowsSkipped.present ? data.rowsSkipped.value : this.rowsSkipped,
      warnings: data.warnings.present ? data.warnings.value : this.warnings,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportEvent(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('fileName: $fileName, ')
          ..write('status: $status, ')
          ..write('rowsImported: $rowsImported, ')
          ..write('rowsSkipped: $rowsSkipped, ')
          ..write('warnings: $warnings, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, fileName, status, rowsImported,
      rowsSkipped, warnings, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportEvent &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.fileName == this.fileName &&
          other.status == this.status &&
          other.rowsImported == this.rowsImported &&
          other.rowsSkipped == this.rowsSkipped &&
          other.warnings == this.warnings &&
          other.createdAt == this.createdAt);
}

class ImportEventsCompanion extends UpdateCompanion<ImportEvent> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<String> fileName;
  final Value<String> status;
  final Value<int> rowsImported;
  final Value<int> rowsSkipped;
  final Value<String?> warnings;
  final Value<DateTime> createdAt;
  const ImportEventsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.status = const Value.absent(),
    this.rowsImported = const Value.absent(),
    this.rowsSkipped = const Value.absent(),
    this.warnings = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ImportEventsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required String fileName,
    required String status,
    this.rowsImported = const Value.absent(),
    this.rowsSkipped = const Value.absent(),
    this.warnings = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : trialId = Value(trialId),
        fileName = Value(fileName),
        status = Value(status);
  static Insertable<ImportEvent> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<String>? fileName,
    Expression<String>? status,
    Expression<int>? rowsImported,
    Expression<int>? rowsSkipped,
    Expression<String>? warnings,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (fileName != null) 'file_name': fileName,
      if (status != null) 'status': status,
      if (rowsImported != null) 'rows_imported': rowsImported,
      if (rowsSkipped != null) 'rows_skipped': rowsSkipped,
      if (warnings != null) 'warnings': warnings,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ImportEventsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<String>? fileName,
      Value<String>? status,
      Value<int>? rowsImported,
      Value<int>? rowsSkipped,
      Value<String?>? warnings,
      Value<DateTime>? createdAt}) {
    return ImportEventsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      rowsImported: rowsImported ?? this.rowsImported,
      rowsSkipped: rowsSkipped ?? this.rowsSkipped,
      warnings: warnings ?? this.warnings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowsImported.present) {
      map['rows_imported'] = Variable<int>(rowsImported.value);
    }
    if (rowsSkipped.present) {
      map['rows_skipped'] = Variable<int>(rowsSkipped.value);
    }
    if (warnings.present) {
      map['warnings'] = Variable<String>(warnings.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportEventsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('fileName: $fileName, ')
          ..write('status: $status, ')
          ..write('rowsImported: $rowsImported, ')
          ..write('rowsSkipped: $rowsSkipped, ')
          ..write('warnings: $warnings, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TrialsTable trials = $TrialsTable(this);
  late final $TreatmentsTable treatments = $TreatmentsTable(this);
  late final $TreatmentComponentsTable treatmentComponents =
      $TreatmentComponentsTable(this);
  late final $AssessmentsTable assessments = $AssessmentsTable(this);
  late final $PlotsTable plots = $PlotsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionAssessmentsTable sessionAssessments =
      $SessionAssessmentsTable(this);
  late final $RatingRecordsTable ratingRecords = $RatingRecordsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $PlotFlagsTable plotFlags = $PlotFlagsTable(this);
  late final $DeviationFlagsTable deviationFlags = $DeviationFlagsTable(this);
  late final $SeedingRecordsTable seedingRecords = $SeedingRecordsTable(this);
  late final $ProtocolSeedingFieldsTable protocolSeedingFields =
      $ProtocolSeedingFieldsTable(this);
  late final $SeedingFieldValuesTable seedingFieldValues =
      $SeedingFieldValuesTable(this);
  late final $ApplicationSlotsTable applicationSlots =
      $ApplicationSlotsTable(this);
  late final $ApplicationEventsTable applicationEvents =
      $ApplicationEventsTable(this);
  late final $ApplicationPlotRecordsTable applicationPlotRecords =
      $ApplicationPlotRecordsTable(this);
  late final $AuditEventsTable auditEvents = $AuditEventsTable(this);
  late final $ImportEventsTable importEvents = $ImportEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        trials,
        treatments,
        treatmentComponents,
        assessments,
        plots,
        sessions,
        sessionAssessments,
        ratingRecords,
        notes,
        photos,
        plotFlags,
        deviationFlags,
        seedingRecords,
        protocolSeedingFields,
        seedingFieldValues,
        applicationSlots,
        applicationEvents,
        applicationPlotRecords,
        auditEvents,
        importEvents
      ];
}

typedef $$TrialsTableCreateCompanionBuilder = TrialsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> crop,
  Value<String?> location,
  Value<String?> season,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$TrialsTableUpdateCompanionBuilder = TrialsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> crop,
  Value<String?> location,
  Value<String?> season,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$TrialsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrialsTable,
    Trial,
    $$TrialsTableFilterComposer,
    $$TrialsTableOrderingComposer,
    $$TrialsTableCreateCompanionBuilder,
    $$TrialsTableUpdateCompanionBuilder> {
  $$TrialsTableTableManager(_$AppDatabase db, $TrialsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$TrialsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$TrialsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> crop = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> season = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              TrialsCompanion(
            id: id,
            name: name,
            crop: crop,
            location: location,
            season: season,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> crop = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> season = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              TrialsCompanion.insert(
            id: id,
            name: name,
            crop: crop,
            location: location,
            season: season,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ));
}

class $$TrialsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TrialsTable> {
  $$TrialsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get crop => $state.composableBuilder(
      column: $state.table.crop,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get location => $state.composableBuilder(
      column: $state.table.location,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get season => $state.composableBuilder(
      column: $state.table.season,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter treatmentsRefs(
      ComposableFilter Function($$TreatmentsTableFilterComposer f) f) {
    final $$TreatmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.treatments,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$TreatmentsTableFilterComposer(ComposerState($state.db,
                $state.db.treatments, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter treatmentComponentsRefs(
      ComposableFilter Function($$TreatmentComponentsTableFilterComposer f) f) {
    final $$TreatmentComponentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.treatmentComponents,
            getReferencedColumn: (t) => t.trialId,
            builder: (joinBuilder, parentComposers) =>
                $$TreatmentComponentsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.treatmentComponents,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter assessmentsRefs(
      ComposableFilter Function($$AssessmentsTableFilterComposer f) f) {
    final $$AssessmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter plotsRefs(
      ComposableFilter Function($$PlotsTableFilterComposer f) f) {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter sessionsRefs(
      ComposableFilter Function($$SessionsTableFilterComposer f) f) {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter ratingRecordsRefs(
      ComposableFilter Function($$RatingRecordsTableFilterComposer f) f) {
    final $$RatingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.ratingRecords,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter notesRefs(
      ComposableFilter Function($$NotesTableFilterComposer f) f) {
    final $$NotesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.notes,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) => $$NotesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.notes, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter photosRefs(
      ComposableFilter Function($$PhotosTableFilterComposer f) f) {
    final $$PhotosTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.photos,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) => $$PhotosTableFilterComposer(
            ComposerState(
                $state.db, $state.db.photos, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter plotFlagsRefs(
      ComposableFilter Function($$PlotFlagsTableFilterComposer f) f) {
    final $$PlotFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.plotFlags,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$PlotFlagsTableFilterComposer(ComposerState(
                $state.db, $state.db.plotFlags, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter deviationFlagsRefs(
      ComposableFilter Function($$DeviationFlagsTableFilterComposer f) f) {
    final $$DeviationFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.deviationFlags,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$DeviationFlagsTableFilterComposer(ComposerState($state.db,
                $state.db.deviationFlags, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter seedingRecordsRefs(
      ComposableFilter Function($$SeedingRecordsTableFilterComposer f) f) {
    final $$SeedingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.seedingRecords,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$SeedingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.seedingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter protocolSeedingFieldsRefs(
      ComposableFilter Function($$ProtocolSeedingFieldsTableFilterComposer f)
          f) {
    final $$ProtocolSeedingFieldsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.protocolSeedingFields,
            getReferencedColumn: (t) => t.trialId,
            builder: (joinBuilder, parentComposers) =>
                $$ProtocolSeedingFieldsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.protocolSeedingFields,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter applicationSlotsRefs(
      ComposableFilter Function($$ApplicationSlotsTableFilterComposer f) f) {
    final $$ApplicationSlotsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationSlots,
            getReferencedColumn: (t) => t.trialId,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationSlotsTableFilterComposer(ComposerState($state.db,
                    $state.db.applicationSlots, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter applicationEventsRefs(
      ComposableFilter Function($$ApplicationEventsTableFilterComposer f) f) {
    final $$ApplicationEventsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationEvents,
            getReferencedColumn: (t) => t.trialId,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationEventsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationEvents,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter applicationPlotRecordsRefs(
      ComposableFilter Function($$ApplicationPlotRecordsTableFilterComposer f)
          f) {
    final $$ApplicationPlotRecordsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationPlotRecords,
            getReferencedColumn: (t) => t.trialId,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationPlotRecordsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationPlotRecords,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter auditEventsRefs(
      ComposableFilter Function($$AuditEventsTableFilterComposer f) f) {
    final $$AuditEventsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.auditEvents,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$AuditEventsTableFilterComposer(ComposerState($state.db,
                $state.db.auditEvents, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter importEventsRefs(
      ComposableFilter Function($$ImportEventsTableFilterComposer f) f) {
    final $$ImportEventsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.importEvents,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$ImportEventsTableFilterComposer(ComposerState($state.db,
                $state.db.importEvents, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$TrialsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TrialsTable> {
  $$TrialsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get crop => $state.composableBuilder(
      column: $state.table.crop,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get location => $state.composableBuilder(
      column: $state.table.location,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get season => $state.composableBuilder(
      column: $state.table.season,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$TreatmentsTableCreateCompanionBuilder = TreatmentsCompanion Function({
  Value<int> id,
  required int trialId,
  required String code,
  required String name,
  Value<String?> description,
});
typedef $$TreatmentsTableUpdateCompanionBuilder = TreatmentsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> code,
  Value<String> name,
  Value<String?> description,
});

class $$TreatmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TreatmentsTable,
    Treatment,
    $$TreatmentsTableFilterComposer,
    $$TreatmentsTableOrderingComposer,
    $$TreatmentsTableCreateCompanionBuilder,
    $$TreatmentsTableUpdateCompanionBuilder> {
  $$TreatmentsTableTableManager(_$AppDatabase db, $TreatmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$TreatmentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$TreatmentsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
          }) =>
              TreatmentsCompanion(
            id: id,
            trialId: trialId,
            code: code,
            name: name,
            description: description,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String code,
            required String name,
            Value<String?> description = const Value.absent(),
          }) =>
              TreatmentsCompanion.insert(
            id: id,
            trialId: trialId,
            code: code,
            name: name,
            description: description,
          ),
        ));
}

class $$TreatmentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TreatmentsTable> {
  $$TreatmentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get code => $state.composableBuilder(
      column: $state.table.code,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter treatmentComponentsRefs(
      ComposableFilter Function($$TreatmentComponentsTableFilterComposer f) f) {
    final $$TreatmentComponentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.treatmentComponents,
            getReferencedColumn: (t) => t.treatmentId,
            builder: (joinBuilder, parentComposers) =>
                $$TreatmentComponentsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.treatmentComponents,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter plotsRefs(
      ComposableFilter Function($$PlotsTableFilterComposer f) f) {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.treatmentId,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$TreatmentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TreatmentsTable> {
  $$TreatmentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get code => $state.composableBuilder(
      column: $state.table.code,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$TreatmentComponentsTableCreateCompanionBuilder
    = TreatmentComponentsCompanion Function({
  Value<int> id,
  required int treatmentId,
  required int trialId,
  required String productName,
  Value<String?> rate,
  Value<String?> rateUnit,
  Value<String?> applicationTiming,
  Value<String?> notes,
  Value<int> sortOrder,
});
typedef $$TreatmentComponentsTableUpdateCompanionBuilder
    = TreatmentComponentsCompanion Function({
  Value<int> id,
  Value<int> treatmentId,
  Value<int> trialId,
  Value<String> productName,
  Value<String?> rate,
  Value<String?> rateUnit,
  Value<String?> applicationTiming,
  Value<String?> notes,
  Value<int> sortOrder,
});

class $$TreatmentComponentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TreatmentComponentsTable,
    TreatmentComponent,
    $$TreatmentComponentsTableFilterComposer,
    $$TreatmentComponentsTableOrderingComposer,
    $$TreatmentComponentsTableCreateCompanionBuilder,
    $$TreatmentComponentsTableUpdateCompanionBuilder> {
  $$TreatmentComponentsTableTableManager(
      _$AppDatabase db, $TreatmentComponentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TreatmentComponentsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$TreatmentComponentsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> treatmentId = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<String?> rate = const Value.absent(),
            Value<String?> rateUnit = const Value.absent(),
            Value<String?> applicationTiming = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              TreatmentComponentsCompanion(
            id: id,
            treatmentId: treatmentId,
            trialId: trialId,
            productName: productName,
            rate: rate,
            rateUnit: rateUnit,
            applicationTiming: applicationTiming,
            notes: notes,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int treatmentId,
            required int trialId,
            required String productName,
            Value<String?> rate = const Value.absent(),
            Value<String?> rateUnit = const Value.absent(),
            Value<String?> applicationTiming = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              TreatmentComponentsCompanion.insert(
            id: id,
            treatmentId: treatmentId,
            trialId: trialId,
            productName: productName,
            rate: rate,
            rateUnit: rateUnit,
            applicationTiming: applicationTiming,
            notes: notes,
            sortOrder: sortOrder,
          ),
        ));
}

class $$TreatmentComponentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TreatmentComponentsTable> {
  $$TreatmentComponentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get productName => $state.composableBuilder(
      column: $state.table.productName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get rate => $state.composableBuilder(
      column: $state.table.rate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get rateUnit => $state.composableBuilder(
      column: $state.table.rateUnit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get applicationTiming => $state.composableBuilder(
      column: $state.table.applicationTiming,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TreatmentsTableFilterComposer get treatmentId {
    final $$TreatmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.treatmentId,
        referencedTable: $state.db.treatments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TreatmentsTableFilterComposer(ComposerState($state.db,
                $state.db.treatments, joinBuilder, parentComposers)));
    return composer;
  }

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$TreatmentComponentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TreatmentComponentsTable> {
  $$TreatmentComponentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get productName => $state.composableBuilder(
      column: $state.table.productName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get rate => $state.composableBuilder(
      column: $state.table.rate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get rateUnit => $state.composableBuilder(
      column: $state.table.rateUnit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get applicationTiming => $state.composableBuilder(
      column: $state.table.applicationTiming,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TreatmentsTableOrderingComposer get treatmentId {
    final $$TreatmentsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.treatmentId,
        referencedTable: $state.db.treatments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TreatmentsTableOrderingComposer(ComposerState($state.db,
                $state.db.treatments, joinBuilder, parentComposers)));
    return composer;
  }

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$AssessmentsTableCreateCompanionBuilder = AssessmentsCompanion
    Function({
  Value<int> id,
  required int trialId,
  required String name,
  Value<String> dataType,
  Value<double?> minValue,
  Value<double?> maxValue,
  Value<String?> unit,
  Value<bool> isActive,
});
typedef $$AssessmentsTableUpdateCompanionBuilder = AssessmentsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> name,
  Value<String> dataType,
  Value<double?> minValue,
  Value<double?> maxValue,
  Value<String?> unit,
  Value<bool> isActive,
});

class $$AssessmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssessmentsTable,
    Assessment,
    $$AssessmentsTableFilterComposer,
    $$AssessmentsTableOrderingComposer,
    $$AssessmentsTableCreateCompanionBuilder,
    $$AssessmentsTableUpdateCompanionBuilder> {
  $$AssessmentsTableTableManager(_$AppDatabase db, $AssessmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AssessmentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AssessmentsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> dataType = const Value.absent(),
            Value<double?> minValue = const Value.absent(),
            Value<double?> maxValue = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              AssessmentsCompanion(
            id: id,
            trialId: trialId,
            name: name,
            dataType: dataType,
            minValue: minValue,
            maxValue: maxValue,
            unit: unit,
            isActive: isActive,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String name,
            Value<String> dataType = const Value.absent(),
            Value<double?> minValue = const Value.absent(),
            Value<double?> maxValue = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              AssessmentsCompanion.insert(
            id: id,
            trialId: trialId,
            name: name,
            dataType: dataType,
            minValue: minValue,
            maxValue: maxValue,
            unit: unit,
            isActive: isActive,
          ),
        ));
}

class $$AssessmentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AssessmentsTable> {
  $$AssessmentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get dataType => $state.composableBuilder(
      column: $state.table.dataType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get minValue => $state.composableBuilder(
      column: $state.table.minValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get maxValue => $state.composableBuilder(
      column: $state.table.maxValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter sessionAssessmentsRefs(
      ComposableFilter Function($$SessionAssessmentsTableFilterComposer f) f) {
    final $$SessionAssessmentsTableFilterComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.sessionAssessments,
            getReferencedColumn: (t) => t.assessmentId,
            builder: (joinBuilder, parentComposers) =>
                $$SessionAssessmentsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.sessionAssessments,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter ratingRecordsRefs(
      ComposableFilter Function($$RatingRecordsTableFilterComposer f) f) {
    final $$RatingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.ratingRecords,
        getReferencedColumn: (t) => t.assessmentId,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$AssessmentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AssessmentsTable> {
  $$AssessmentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get dataType => $state.composableBuilder(
      column: $state.table.dataType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get minValue => $state.composableBuilder(
      column: $state.table.minValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get maxValue => $state.composableBuilder(
      column: $state.table.maxValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$PlotsTableCreateCompanionBuilder = PlotsCompanion Function({
  Value<int> id,
  required int trialId,
  required String plotId,
  Value<int?> plotSortIndex,
  Value<int?> rep,
  Value<int?> treatmentId,
  Value<String?> row,
  Value<String?> column,
  Value<String?> notes,
});
typedef $$PlotsTableUpdateCompanionBuilder = PlotsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> plotId,
  Value<int?> plotSortIndex,
  Value<int?> rep,
  Value<int?> treatmentId,
  Value<String?> row,
  Value<String?> column,
  Value<String?> notes,
});

class $$PlotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlotsTable,
    Plot,
    $$PlotsTableFilterComposer,
    $$PlotsTableOrderingComposer,
    $$PlotsTableCreateCompanionBuilder,
    $$PlotsTableUpdateCompanionBuilder> {
  $$PlotsTableTableManager(_$AppDatabase db, $PlotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$PlotsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$PlotsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> plotId = const Value.absent(),
            Value<int?> plotSortIndex = const Value.absent(),
            Value<int?> rep = const Value.absent(),
            Value<int?> treatmentId = const Value.absent(),
            Value<String?> row = const Value.absent(),
            Value<String?> column = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              PlotsCompanion(
            id: id,
            trialId: trialId,
            plotId: plotId,
            plotSortIndex: plotSortIndex,
            rep: rep,
            treatmentId: treatmentId,
            row: row,
            column: column,
            notes: notes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String plotId,
            Value<int?> plotSortIndex = const Value.absent(),
            Value<int?> rep = const Value.absent(),
            Value<int?> treatmentId = const Value.absent(),
            Value<String?> row = const Value.absent(),
            Value<String?> column = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              PlotsCompanion.insert(
            id: id,
            trialId: trialId,
            plotId: plotId,
            plotSortIndex: plotSortIndex,
            rep: rep,
            treatmentId: treatmentId,
            row: row,
            column: column,
            notes: notes,
          ),
        ));
}

class $$PlotsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $PlotsTable> {
  $$PlotsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get plotId => $state.composableBuilder(
      column: $state.table.plotId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get plotSortIndex => $state.composableBuilder(
      column: $state.table.plotSortIndex,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get rep => $state.composableBuilder(
      column: $state.table.rep,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get row => $state.composableBuilder(
      column: $state.table.row,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get column => $state.composableBuilder(
      column: $state.table.column,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$TreatmentsTableFilterComposer get treatmentId {
    final $$TreatmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.treatmentId,
        referencedTable: $state.db.treatments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TreatmentsTableFilterComposer(ComposerState($state.db,
                $state.db.treatments, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter ratingRecordsRefs(
      ComposableFilter Function($$RatingRecordsTableFilterComposer f) f) {
    final $$RatingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.ratingRecords,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter notesRefs(
      ComposableFilter Function($$NotesTableFilterComposer f) f) {
    final $$NotesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.notes,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) => $$NotesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.notes, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter photosRefs(
      ComposableFilter Function($$PhotosTableFilterComposer f) f) {
    final $$PhotosTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.photos,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) => $$PhotosTableFilterComposer(
            ComposerState(
                $state.db, $state.db.photos, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter plotFlagsRefs(
      ComposableFilter Function($$PlotFlagsTableFilterComposer f) f) {
    final $$PlotFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.plotFlags,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) =>
            $$PlotFlagsTableFilterComposer(ComposerState(
                $state.db, $state.db.plotFlags, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter deviationFlagsRefs(
      ComposableFilter Function($$DeviationFlagsTableFilterComposer f) f) {
    final $$DeviationFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.deviationFlags,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) =>
            $$DeviationFlagsTableFilterComposer(ComposerState($state.db,
                $state.db.deviationFlags, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter seedingRecordsRefs(
      ComposableFilter Function($$SeedingRecordsTableFilterComposer f) f) {
    final $$SeedingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.seedingRecords,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) =>
            $$SeedingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.seedingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter applicationPlotRecordsRefs(
      ComposableFilter Function($$ApplicationPlotRecordsTableFilterComposer f)
          f) {
    final $$ApplicationPlotRecordsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationPlotRecords,
            getReferencedColumn: (t) => t.plotPk,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationPlotRecordsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationPlotRecords,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter auditEventsRefs(
      ComposableFilter Function($$AuditEventsTableFilterComposer f) f) {
    final $$AuditEventsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.auditEvents,
        getReferencedColumn: (t) => t.plotPk,
        builder: (joinBuilder, parentComposers) =>
            $$AuditEventsTableFilterComposer(ComposerState($state.db,
                $state.db.auditEvents, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$PlotsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $PlotsTable> {
  $$PlotsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get plotId => $state.composableBuilder(
      column: $state.table.plotId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get plotSortIndex => $state.composableBuilder(
      column: $state.table.plotSortIndex,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get rep => $state.composableBuilder(
      column: $state.table.rep,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get row => $state.composableBuilder(
      column: $state.table.row,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get column => $state.composableBuilder(
      column: $state.table.column,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$TreatmentsTableOrderingComposer get treatmentId {
    final $$TreatmentsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.treatmentId,
        referencedTable: $state.db.treatments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TreatmentsTableOrderingComposer(ComposerState($state.db,
                $state.db.treatments, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required int trialId,
  required String name,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  required String sessionDateLocal,
  Value<String?> raterName,
  Value<String> status,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> name,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<String> sessionDateLocal,
  Value<String?> raterName,
  Value<String> status,
});

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SessionsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SessionsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<String> sessionDateLocal = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
            Value<String> status = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            trialId: trialId,
            name: name,
            startedAt: startedAt,
            endedAt: endedAt,
            sessionDateLocal: sessionDateLocal,
            raterName: raterName,
            status: status,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String name,
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            required String sessionDateLocal,
            Value<String?> raterName = const Value.absent(),
            Value<String> status = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            trialId: trialId,
            name: name,
            startedAt: startedAt,
            endedAt: endedAt,
            sessionDateLocal: sessionDateLocal,
            raterName: raterName,
            status: status,
          ),
        ));
}

class $$SessionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get startedAt => $state.composableBuilder(
      column: $state.table.startedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get endedAt => $state.composableBuilder(
      column: $state.table.endedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get sessionDateLocal => $state.composableBuilder(
      column: $state.table.sessionDateLocal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter sessionAssessmentsRefs(
      ComposableFilter Function($$SessionAssessmentsTableFilterComposer f) f) {
    final $$SessionAssessmentsTableFilterComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.sessionAssessments,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder, parentComposers) =>
                $$SessionAssessmentsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.sessionAssessments,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter ratingRecordsRefs(
      ComposableFilter Function($$RatingRecordsTableFilterComposer f) f) {
    final $$RatingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.ratingRecords,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter notesRefs(
      ComposableFilter Function($$NotesTableFilterComposer f) f) {
    final $$NotesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.notes,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) => $$NotesTableFilterComposer(
            ComposerState(
                $state.db, $state.db.notes, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter photosRefs(
      ComposableFilter Function($$PhotosTableFilterComposer f) f) {
    final $$PhotosTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.photos,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) => $$PhotosTableFilterComposer(
            ComposerState(
                $state.db, $state.db.photos, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter plotFlagsRefs(
      ComposableFilter Function($$PlotFlagsTableFilterComposer f) f) {
    final $$PlotFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.plotFlags,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) =>
            $$PlotFlagsTableFilterComposer(ComposerState(
                $state.db, $state.db.plotFlags, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter deviationFlagsRefs(
      ComposableFilter Function($$DeviationFlagsTableFilterComposer f) f) {
    final $$DeviationFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.deviationFlags,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) =>
            $$DeviationFlagsTableFilterComposer(ComposerState($state.db,
                $state.db.deviationFlags, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter seedingRecordsRefs(
      ComposableFilter Function($$SeedingRecordsTableFilterComposer f) f) {
    final $$SeedingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.seedingRecords,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) =>
            $$SeedingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.seedingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter applicationEventsRefs(
      ComposableFilter Function($$ApplicationEventsTableFilterComposer f) f) {
    final $$ApplicationEventsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationEvents,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationEventsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationEvents,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }

  ComposableFilter auditEventsRefs(
      ComposableFilter Function($$AuditEventsTableFilterComposer f) f) {
    final $$AuditEventsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.auditEvents,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder, parentComposers) =>
            $$AuditEventsTableFilterComposer(ComposerState($state.db,
                $state.db.auditEvents, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get startedAt => $state.composableBuilder(
      column: $state.table.startedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get endedAt => $state.composableBuilder(
      column: $state.table.endedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get sessionDateLocal => $state.composableBuilder(
      column: $state.table.sessionDateLocal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SessionAssessmentsTableCreateCompanionBuilder
    = SessionAssessmentsCompanion Function({
  Value<int> id,
  required int sessionId,
  required int assessmentId,
});
typedef $$SessionAssessmentsTableUpdateCompanionBuilder
    = SessionAssessmentsCompanion Function({
  Value<int> id,
  Value<int> sessionId,
  Value<int> assessmentId,
});

class $$SessionAssessmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionAssessmentsTable,
    SessionAssessment,
    $$SessionAssessmentsTableFilterComposer,
    $$SessionAssessmentsTableOrderingComposer,
    $$SessionAssessmentsTableCreateCompanionBuilder,
    $$SessionAssessmentsTableUpdateCompanionBuilder> {
  $$SessionAssessmentsTableTableManager(
      _$AppDatabase db, $SessionAssessmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SessionAssessmentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$SessionAssessmentsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<int> assessmentId = const Value.absent(),
          }) =>
              SessionAssessmentsCompanion(
            id: id,
            sessionId: sessionId,
            assessmentId: assessmentId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required int assessmentId,
          }) =>
              SessionAssessmentsCompanion.insert(
            id: id,
            sessionId: sessionId,
            assessmentId: assessmentId,
          ),
        ));
}

class $$SessionAssessmentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SessionAssessmentsTable> {
  $$SessionAssessmentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$AssessmentsTableFilterComposer get assessmentId {
    final $$AssessmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assessmentId,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$SessionAssessmentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SessionAssessmentsTable> {
  $$SessionAssessmentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$AssessmentsTableOrderingComposer get assessmentId {
    final $$AssessmentsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assessmentId,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableOrderingComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$RatingRecordsTableCreateCompanionBuilder = RatingRecordsCompanion
    Function({
  Value<int> id,
  required int trialId,
  required int plotPk,
  required int assessmentId,
  required int sessionId,
  Value<int?> subUnitId,
  Value<String> resultStatus,
  Value<double?> numericValue,
  Value<String?> textValue,
  Value<bool> isCurrent,
  Value<int?> previousId,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});
typedef $$RatingRecordsTableUpdateCompanionBuilder = RatingRecordsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> plotPk,
  Value<int> assessmentId,
  Value<int> sessionId,
  Value<int?> subUnitId,
  Value<String> resultStatus,
  Value<double?> numericValue,
  Value<String?> textValue,
  Value<bool> isCurrent,
  Value<int?> previousId,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});

class $$RatingRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RatingRecordsTable,
    RatingRecord,
    $$RatingRecordsTableFilterComposer,
    $$RatingRecordsTableOrderingComposer,
    $$RatingRecordsTableCreateCompanionBuilder,
    $$RatingRecordsTableUpdateCompanionBuilder> {
  $$RatingRecordsTableTableManager(_$AppDatabase db, $RatingRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$RatingRecordsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$RatingRecordsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int> plotPk = const Value.absent(),
            Value<int> assessmentId = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<int?> subUnitId = const Value.absent(),
            Value<String> resultStatus = const Value.absent(),
            Value<double?> numericValue = const Value.absent(),
            Value<String?> textValue = const Value.absent(),
            Value<bool> isCurrent = const Value.absent(),
            Value<int?> previousId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              RatingRecordsCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            sessionId: sessionId,
            subUnitId: subUnitId,
            resultStatus: resultStatus,
            numericValue: numericValue,
            textValue: textValue,
            isCurrent: isCurrent,
            previousId: previousId,
            createdAt: createdAt,
            raterName: raterName,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int plotPk,
            required int assessmentId,
            required int sessionId,
            Value<int?> subUnitId = const Value.absent(),
            Value<String> resultStatus = const Value.absent(),
            Value<double?> numericValue = const Value.absent(),
            Value<String?> textValue = const Value.absent(),
            Value<bool> isCurrent = const Value.absent(),
            Value<int?> previousId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              RatingRecordsCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            sessionId: sessionId,
            subUnitId: subUnitId,
            resultStatus: resultStatus,
            numericValue: numericValue,
            textValue: textValue,
            isCurrent: isCurrent,
            previousId: previousId,
            createdAt: createdAt,
            raterName: raterName,
          ),
        ));
}

class $$RatingRecordsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $RatingRecordsTable> {
  $$RatingRecordsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get subUnitId => $state.composableBuilder(
      column: $state.table.subUnitId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get resultStatus => $state.composableBuilder(
      column: $state.table.resultStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get numericValue => $state.composableBuilder(
      column: $state.table.numericValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get textValue => $state.composableBuilder(
      column: $state.table.textValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCurrent => $state.composableBuilder(
      column: $state.table.isCurrent,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get previousId => $state.composableBuilder(
      column: $state.table.previousId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$AssessmentsTableFilterComposer get assessmentId {
    final $$AssessmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assessmentId,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter deviationFlagsRefs(
      ComposableFilter Function($$DeviationFlagsTableFilterComposer f) f) {
    final $$DeviationFlagsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.deviationFlags,
        getReferencedColumn: (t) => t.ratingRecordId,
        builder: (joinBuilder, parentComposers) =>
            $$DeviationFlagsTableFilterComposer(ComposerState($state.db,
                $state.db.deviationFlags, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$RatingRecordsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $RatingRecordsTable> {
  $$RatingRecordsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get subUnitId => $state.composableBuilder(
      column: $state.table.subUnitId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get resultStatus => $state.composableBuilder(
      column: $state.table.resultStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get numericValue => $state.composableBuilder(
      column: $state.table.numericValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get textValue => $state.composableBuilder(
      column: $state.table.textValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCurrent => $state.composableBuilder(
      column: $state.table.isCurrent,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get previousId => $state.composableBuilder(
      column: $state.table.previousId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$AssessmentsTableOrderingComposer get assessmentId {
    final $$AssessmentsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assessmentId,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableOrderingComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  required int trialId,
  required int plotPk,
  required int sessionId,
  required String content,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> plotPk,
  Value<int> sessionId,
  Value<String> content,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});

class $$NotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotesTable,
    Note,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder> {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$NotesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$NotesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int> plotPk = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              NotesCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            content: content,
            createdAt: createdAt,
            raterName: raterName,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int plotPk,
            required int sessionId,
            required String content,
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              NotesCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            content: content,
            createdAt: createdAt,
            raterName: raterName,
          ),
        ));
}

class $$NotesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get content => $state.composableBuilder(
      column: $state.table.content,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$NotesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get content => $state.composableBuilder(
      column: $state.table.content,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$PhotosTableCreateCompanionBuilder = PhotosCompanion Function({
  Value<int> id,
  required int trialId,
  required int plotPk,
  required int sessionId,
  required String filePath,
  Value<String?> tempPath,
  Value<String> status,
  Value<String?> caption,
  Value<DateTime> createdAt,
});
typedef $$PhotosTableUpdateCompanionBuilder = PhotosCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> plotPk,
  Value<int> sessionId,
  Value<String> filePath,
  Value<String?> tempPath,
  Value<String> status,
  Value<String?> caption,
  Value<DateTime> createdAt,
});

class $$PhotosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhotosTable,
    Photo,
    $$PhotosTableFilterComposer,
    $$PhotosTableOrderingComposer,
    $$PhotosTableCreateCompanionBuilder,
    $$PhotosTableUpdateCompanionBuilder> {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$PhotosTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$PhotosTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int> plotPk = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> tempPath = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> caption = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PhotosCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            filePath: filePath,
            tempPath: tempPath,
            status: status,
            caption: caption,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int plotPk,
            required int sessionId,
            required String filePath,
            Value<String?> tempPath = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> caption = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PhotosCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            filePath: filePath,
            tempPath: tempPath,
            status: status,
            caption: caption,
            createdAt: createdAt,
          ),
        ));
}

class $$PhotosTableFilterComposer
    extends FilterComposer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get tempPath => $state.composableBuilder(
      column: $state.table.tempPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$PhotosTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get tempPath => $state.composableBuilder(
      column: $state.table.tempPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get caption => $state.composableBuilder(
      column: $state.table.caption,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$PlotFlagsTableCreateCompanionBuilder = PlotFlagsCompanion Function({
  Value<int> id,
  required int trialId,
  required int plotPk,
  required int sessionId,
  required String flagType,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});
typedef $$PlotFlagsTableUpdateCompanionBuilder = PlotFlagsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> plotPk,
  Value<int> sessionId,
  Value<String> flagType,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});

class $$PlotFlagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlotFlagsTable,
    PlotFlag,
    $$PlotFlagsTableFilterComposer,
    $$PlotFlagsTableOrderingComposer,
    $$PlotFlagsTableCreateCompanionBuilder,
    $$PlotFlagsTableUpdateCompanionBuilder> {
  $$PlotFlagsTableTableManager(_$AppDatabase db, $PlotFlagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$PlotFlagsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$PlotFlagsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int> plotPk = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<String> flagType = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              PlotFlagsCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            flagType: flagType,
            description: description,
            createdAt: createdAt,
            raterName: raterName,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int plotPk,
            required int sessionId,
            required String flagType,
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              PlotFlagsCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            flagType: flagType,
            description: description,
            createdAt: createdAt,
            raterName: raterName,
          ),
        ));
}

class $$PlotFlagsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $PlotFlagsTable> {
  $$PlotFlagsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get flagType => $state.composableBuilder(
      column: $state.table.flagType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$PlotFlagsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $PlotFlagsTable> {
  $$PlotFlagsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get flagType => $state.composableBuilder(
      column: $state.table.flagType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$DeviationFlagsTableCreateCompanionBuilder = DeviationFlagsCompanion
    Function({
  Value<int> id,
  required int trialId,
  Value<int?> plotPk,
  required int sessionId,
  Value<int?> ratingRecordId,
  required String deviationType,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});
typedef $$DeviationFlagsTableUpdateCompanionBuilder = DeviationFlagsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<int?> plotPk,
  Value<int> sessionId,
  Value<int?> ratingRecordId,
  Value<String> deviationType,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<String?> raterName,
});

class $$DeviationFlagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeviationFlagsTable,
    DeviationFlag,
    $$DeviationFlagsTableFilterComposer,
    $$DeviationFlagsTableOrderingComposer,
    $$DeviationFlagsTableCreateCompanionBuilder,
    $$DeviationFlagsTableUpdateCompanionBuilder> {
  $$DeviationFlagsTableTableManager(
      _$AppDatabase db, $DeviationFlagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$DeviationFlagsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$DeviationFlagsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int?> plotPk = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<int?> ratingRecordId = const Value.absent(),
            Value<String> deviationType = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              DeviationFlagsCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            ratingRecordId: ratingRecordId,
            deviationType: deviationType,
            description: description,
            createdAt: createdAt,
            raterName: raterName,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            Value<int?> plotPk = const Value.absent(),
            required int sessionId,
            Value<int?> ratingRecordId = const Value.absent(),
            required String deviationType,
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
          }) =>
              DeviationFlagsCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            ratingRecordId: ratingRecordId,
            deviationType: deviationType,
            description: description,
            createdAt: createdAt,
            raterName: raterName,
          ),
        ));
}

class $$DeviationFlagsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $DeviationFlagsTable> {
  $$DeviationFlagsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get deviationType => $state.composableBuilder(
      column: $state.table.deviationType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$RatingRecordsTableFilterComposer get ratingRecordId {
    final $$RatingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.ratingRecordId,
        referencedTable: $state.db.ratingRecords,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$DeviationFlagsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $DeviationFlagsTable> {
  $$DeviationFlagsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get deviationType => $state.composableBuilder(
      column: $state.table.deviationType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get raterName => $state.composableBuilder(
      column: $state.table.raterName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$RatingRecordsTableOrderingComposer get ratingRecordId {
    final $$RatingRecordsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.ratingRecordId,
            referencedTable: $state.db.ratingRecords,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$RatingRecordsTableOrderingComposer(ComposerState($state.db,
                    $state.db.ratingRecords, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SeedingRecordsTableCreateCompanionBuilder = SeedingRecordsCompanion
    Function({
  Value<int> id,
  required int trialId,
  Value<int?> plotPk,
  Value<int?> sessionId,
  required DateTime seedingDate,
  Value<String?> operatorName,
  Value<String?> comments,
  Value<DateTime> createdAt,
});
typedef $$SeedingRecordsTableUpdateCompanionBuilder = SeedingRecordsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<int?> plotPk,
  Value<int?> sessionId,
  Value<DateTime> seedingDate,
  Value<String?> operatorName,
  Value<String?> comments,
  Value<DateTime> createdAt,
});

class $$SeedingRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SeedingRecordsTable,
    SeedingRecord,
    $$SeedingRecordsTableFilterComposer,
    $$SeedingRecordsTableOrderingComposer,
    $$SeedingRecordsTableCreateCompanionBuilder,
    $$SeedingRecordsTableUpdateCompanionBuilder> {
  $$SeedingRecordsTableTableManager(
      _$AppDatabase db, $SeedingRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SeedingRecordsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SeedingRecordsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int?> plotPk = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            Value<DateTime> seedingDate = const Value.absent(),
            Value<String?> operatorName = const Value.absent(),
            Value<String?> comments = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SeedingRecordsCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            seedingDate: seedingDate,
            operatorName: operatorName,
            comments: comments,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            Value<int?> plotPk = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            required DateTime seedingDate,
            Value<String?> operatorName = const Value.absent(),
            Value<String?> comments = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SeedingRecordsCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            seedingDate: seedingDate,
            operatorName: operatorName,
            comments: comments,
            createdAt: createdAt,
          ),
        ));
}

class $$SeedingRecordsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SeedingRecordsTable> {
  $$SeedingRecordsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get seedingDate => $state.composableBuilder(
      column: $state.table.seedingDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get operatorName => $state.composableBuilder(
      column: $state.table.operatorName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get comments => $state.composableBuilder(
      column: $state.table.comments,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter seedingFieldValuesRefs(
      ComposableFilter Function($$SeedingFieldValuesTableFilterComposer f) f) {
    final $$SeedingFieldValuesTableFilterComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.seedingFieldValues,
            getReferencedColumn: (t) => t.seedingRecordId,
            builder: (joinBuilder, parentComposers) =>
                $$SeedingFieldValuesTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.seedingFieldValues,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$SeedingRecordsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SeedingRecordsTable> {
  $$SeedingRecordsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get seedingDate => $state.composableBuilder(
      column: $state.table.seedingDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get operatorName => $state.composableBuilder(
      column: $state.table.operatorName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get comments => $state.composableBuilder(
      column: $state.table.comments,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ProtocolSeedingFieldsTableCreateCompanionBuilder
    = ProtocolSeedingFieldsCompanion Function({
  Value<int> id,
  required int trialId,
  required String fieldKey,
  required String fieldLabel,
  required String fieldType,
  Value<String?> unit,
  Value<bool> isRequired,
  Value<bool> isVisible,
  Value<int> sortOrder,
  Value<String> source,
});
typedef $$ProtocolSeedingFieldsTableUpdateCompanionBuilder
    = ProtocolSeedingFieldsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> fieldKey,
  Value<String> fieldLabel,
  Value<String> fieldType,
  Value<String?> unit,
  Value<bool> isRequired,
  Value<bool> isVisible,
  Value<int> sortOrder,
  Value<String> source,
});

class $$ProtocolSeedingFieldsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProtocolSeedingFieldsTable,
    ProtocolSeedingField,
    $$ProtocolSeedingFieldsTableFilterComposer,
    $$ProtocolSeedingFieldsTableOrderingComposer,
    $$ProtocolSeedingFieldsTableCreateCompanionBuilder,
    $$ProtocolSeedingFieldsTableUpdateCompanionBuilder> {
  $$ProtocolSeedingFieldsTableTableManager(
      _$AppDatabase db, $ProtocolSeedingFieldsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ProtocolSeedingFieldsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ProtocolSeedingFieldsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> fieldKey = const Value.absent(),
            Value<String> fieldLabel = const Value.absent(),
            Value<String> fieldType = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<bool> isRequired = const Value.absent(),
            Value<bool> isVisible = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              ProtocolSeedingFieldsCompanion(
            id: id,
            trialId: trialId,
            fieldKey: fieldKey,
            fieldLabel: fieldLabel,
            fieldType: fieldType,
            unit: unit,
            isRequired: isRequired,
            isVisible: isVisible,
            sortOrder: sortOrder,
            source: source,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String fieldKey,
            required String fieldLabel,
            required String fieldType,
            Value<String?> unit = const Value.absent(),
            Value<bool> isRequired = const Value.absent(),
            Value<bool> isVisible = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              ProtocolSeedingFieldsCompanion.insert(
            id: id,
            trialId: trialId,
            fieldKey: fieldKey,
            fieldLabel: fieldLabel,
            fieldType: fieldType,
            unit: unit,
            isRequired: isRequired,
            isVisible: isVisible,
            sortOrder: sortOrder,
            source: source,
          ),
        ));
}

class $$ProtocolSeedingFieldsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ProtocolSeedingFieldsTable> {
  $$ProtocolSeedingFieldsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fieldKey => $state.composableBuilder(
      column: $state.table.fieldKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fieldLabel => $state.composableBuilder(
      column: $state.table.fieldLabel,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fieldType => $state.composableBuilder(
      column: $state.table.fieldType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isRequired => $state.composableBuilder(
      column: $state.table.isRequired,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isVisible => $state.composableBuilder(
      column: $state.table.isVisible,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ProtocolSeedingFieldsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ProtocolSeedingFieldsTable> {
  $$ProtocolSeedingFieldsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fieldKey => $state.composableBuilder(
      column: $state.table.fieldKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fieldLabel => $state.composableBuilder(
      column: $state.table.fieldLabel,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fieldType => $state.composableBuilder(
      column: $state.table.fieldType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isRequired => $state.composableBuilder(
      column: $state.table.isRequired,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isVisible => $state.composableBuilder(
      column: $state.table.isVisible,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get source => $state.composableBuilder(
      column: $state.table.source,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SeedingFieldValuesTableCreateCompanionBuilder
    = SeedingFieldValuesCompanion Function({
  Value<int> id,
  required int seedingRecordId,
  required String fieldKey,
  required String fieldLabel,
  Value<String?> valueText,
  Value<double?> valueNumber,
  Value<String?> valueDate,
  Value<bool?> valueBool,
  Value<String?> unit,
  Value<int> sortOrder,
});
typedef $$SeedingFieldValuesTableUpdateCompanionBuilder
    = SeedingFieldValuesCompanion Function({
  Value<int> id,
  Value<int> seedingRecordId,
  Value<String> fieldKey,
  Value<String> fieldLabel,
  Value<String?> valueText,
  Value<double?> valueNumber,
  Value<String?> valueDate,
  Value<bool?> valueBool,
  Value<String?> unit,
  Value<int> sortOrder,
});

class $$SeedingFieldValuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SeedingFieldValuesTable,
    SeedingFieldValue,
    $$SeedingFieldValuesTableFilterComposer,
    $$SeedingFieldValuesTableOrderingComposer,
    $$SeedingFieldValuesTableCreateCompanionBuilder,
    $$SeedingFieldValuesTableUpdateCompanionBuilder> {
  $$SeedingFieldValuesTableTableManager(
      _$AppDatabase db, $SeedingFieldValuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SeedingFieldValuesTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$SeedingFieldValuesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> seedingRecordId = const Value.absent(),
            Value<String> fieldKey = const Value.absent(),
            Value<String> fieldLabel = const Value.absent(),
            Value<String?> valueText = const Value.absent(),
            Value<double?> valueNumber = const Value.absent(),
            Value<String?> valueDate = const Value.absent(),
            Value<bool?> valueBool = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SeedingFieldValuesCompanion(
            id: id,
            seedingRecordId: seedingRecordId,
            fieldKey: fieldKey,
            fieldLabel: fieldLabel,
            valueText: valueText,
            valueNumber: valueNumber,
            valueDate: valueDate,
            valueBool: valueBool,
            unit: unit,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int seedingRecordId,
            required String fieldKey,
            required String fieldLabel,
            Value<String?> valueText = const Value.absent(),
            Value<double?> valueNumber = const Value.absent(),
            Value<String?> valueDate = const Value.absent(),
            Value<bool?> valueBool = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SeedingFieldValuesCompanion.insert(
            id: id,
            seedingRecordId: seedingRecordId,
            fieldKey: fieldKey,
            fieldLabel: fieldLabel,
            valueText: valueText,
            valueNumber: valueNumber,
            valueDate: valueDate,
            valueBool: valueBool,
            unit: unit,
            sortOrder: sortOrder,
          ),
        ));
}

class $$SeedingFieldValuesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SeedingFieldValuesTable> {
  $$SeedingFieldValuesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fieldKey => $state.composableBuilder(
      column: $state.table.fieldKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fieldLabel => $state.composableBuilder(
      column: $state.table.fieldLabel,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get valueText => $state.composableBuilder(
      column: $state.table.valueText,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get valueNumber => $state.composableBuilder(
      column: $state.table.valueNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get valueDate => $state.composableBuilder(
      column: $state.table.valueDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get valueBool => $state.composableBuilder(
      column: $state.table.valueBool,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$SeedingRecordsTableFilterComposer get seedingRecordId {
    final $$SeedingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.seedingRecordId,
        referencedTable: $state.db.seedingRecords,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SeedingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.seedingRecords, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$SeedingFieldValuesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SeedingFieldValuesTable> {
  $$SeedingFieldValuesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fieldKey => $state.composableBuilder(
      column: $state.table.fieldKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fieldLabel => $state.composableBuilder(
      column: $state.table.fieldLabel,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get valueText => $state.composableBuilder(
      column: $state.table.valueText,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get valueNumber => $state.composableBuilder(
      column: $state.table.valueNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get valueDate => $state.composableBuilder(
      column: $state.table.valueDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get valueBool => $state.composableBuilder(
      column: $state.table.valueBool,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$SeedingRecordsTableOrderingComposer get seedingRecordId {
    final $$SeedingRecordsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.seedingRecordId,
            referencedTable: $state.db.seedingRecords,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$SeedingRecordsTableOrderingComposer(ComposerState($state.db,
                    $state.db.seedingRecords, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ApplicationSlotsTableCreateCompanionBuilder
    = ApplicationSlotsCompanion Function({
  Value<int> id,
  required int trialId,
  required String slotCode,
  Value<String?> timingLabel,
  Value<String> methodDefault,
  Value<String?> plannedGrowthStage,
  Value<String?> protocolNotes,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});
typedef $$ApplicationSlotsTableUpdateCompanionBuilder
    = ApplicationSlotsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> slotCode,
  Value<String?> timingLabel,
  Value<String> methodDefault,
  Value<String?> plannedGrowthStage,
  Value<String?> protocolNotes,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});

class $$ApplicationSlotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ApplicationSlotsTable,
    ApplicationSlot,
    $$ApplicationSlotsTableFilterComposer,
    $$ApplicationSlotsTableOrderingComposer,
    $$ApplicationSlotsTableCreateCompanionBuilder,
    $$ApplicationSlotsTableUpdateCompanionBuilder> {
  $$ApplicationSlotsTableTableManager(
      _$AppDatabase db, $ApplicationSlotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ApplicationSlotsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ApplicationSlotsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> slotCode = const Value.absent(),
            Value<String?> timingLabel = const Value.absent(),
            Value<String> methodDefault = const Value.absent(),
            Value<String?> plannedGrowthStage = const Value.absent(),
            Value<String?> protocolNotes = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ApplicationSlotsCompanion(
            id: id,
            trialId: trialId,
            slotCode: slotCode,
            timingLabel: timingLabel,
            methodDefault: methodDefault,
            plannedGrowthStage: plannedGrowthStage,
            protocolNotes: protocolNotes,
            sortOrder: sortOrder,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String slotCode,
            Value<String?> timingLabel = const Value.absent(),
            Value<String> methodDefault = const Value.absent(),
            Value<String?> plannedGrowthStage = const Value.absent(),
            Value<String?> protocolNotes = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ApplicationSlotsCompanion.insert(
            id: id,
            trialId: trialId,
            slotCode: slotCode,
            timingLabel: timingLabel,
            methodDefault: methodDefault,
            plannedGrowthStage: plannedGrowthStage,
            protocolNotes: protocolNotes,
            sortOrder: sortOrder,
            createdAt: createdAt,
          ),
        ));
}

class $$ApplicationSlotsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ApplicationSlotsTable> {
  $$ApplicationSlotsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get slotCode => $state.composableBuilder(
      column: $state.table.slotCode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timingLabel => $state.composableBuilder(
      column: $state.table.timingLabel,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get methodDefault => $state.composableBuilder(
      column: $state.table.methodDefault,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get plannedGrowthStage => $state.composableBuilder(
      column: $state.table.plannedGrowthStage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get protocolNotes => $state.composableBuilder(
      column: $state.table.protocolNotes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter applicationEventsRefs(
      ComposableFilter Function($$ApplicationEventsTableFilterComposer f) f) {
    final $$ApplicationEventsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationEvents,
            getReferencedColumn: (t) => t.applicationSlotId,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationEventsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationEvents,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ApplicationSlotsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ApplicationSlotsTable> {
  $$ApplicationSlotsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get slotCode => $state.composableBuilder(
      column: $state.table.slotCode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timingLabel => $state.composableBuilder(
      column: $state.table.timingLabel,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get methodDefault => $state.composableBuilder(
      column: $state.table.methodDefault,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get plannedGrowthStage => $state.composableBuilder(
      column: $state.table.plannedGrowthStage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get protocolNotes => $state.composableBuilder(
      column: $state.table.protocolNotes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ApplicationEventsTableCreateCompanionBuilder
    = ApplicationEventsCompanion Function({
  Value<int> id,
  required int trialId,
  Value<int?> sessionId,
  Value<int?> applicationSlotId,
  Value<int> applicationNumber,
  Value<String?> timingLabel,
  Value<String> method,
  Value<String> status,
  required DateTime applicationDate,
  Value<String?> growthStage,
  Value<String?> operatorName,
  Value<String?> equipment,
  Value<String?> weather,
  Value<String?> notes,
  Value<bool> partialFlag,
  Value<DateTime?> completedAt,
  Value<String?> completedBy,
  Value<DateTime> createdAt,
});
typedef $$ApplicationEventsTableUpdateCompanionBuilder
    = ApplicationEventsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<int?> sessionId,
  Value<int?> applicationSlotId,
  Value<int> applicationNumber,
  Value<String?> timingLabel,
  Value<String> method,
  Value<String> status,
  Value<DateTime> applicationDate,
  Value<String?> growthStage,
  Value<String?> operatorName,
  Value<String?> equipment,
  Value<String?> weather,
  Value<String?> notes,
  Value<bool> partialFlag,
  Value<DateTime?> completedAt,
  Value<String?> completedBy,
  Value<DateTime> createdAt,
});

class $$ApplicationEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ApplicationEventsTable,
    ApplicationEvent,
    $$ApplicationEventsTableFilterComposer,
    $$ApplicationEventsTableOrderingComposer,
    $$ApplicationEventsTableCreateCompanionBuilder,
    $$ApplicationEventsTableUpdateCompanionBuilder> {
  $$ApplicationEventsTableTableManager(
      _$AppDatabase db, $ApplicationEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ApplicationEventsTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$ApplicationEventsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            Value<int?> applicationSlotId = const Value.absent(),
            Value<int> applicationNumber = const Value.absent(),
            Value<String?> timingLabel = const Value.absent(),
            Value<String> method = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> applicationDate = const Value.absent(),
            Value<String?> growthStage = const Value.absent(),
            Value<String?> operatorName = const Value.absent(),
            Value<String?> equipment = const Value.absent(),
            Value<String?> weather = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<bool> partialFlag = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String?> completedBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ApplicationEventsCompanion(
            id: id,
            trialId: trialId,
            sessionId: sessionId,
            applicationSlotId: applicationSlotId,
            applicationNumber: applicationNumber,
            timingLabel: timingLabel,
            method: method,
            status: status,
            applicationDate: applicationDate,
            growthStage: growthStage,
            operatorName: operatorName,
            equipment: equipment,
            weather: weather,
            notes: notes,
            partialFlag: partialFlag,
            completedAt: completedAt,
            completedBy: completedBy,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            Value<int?> sessionId = const Value.absent(),
            Value<int?> applicationSlotId = const Value.absent(),
            Value<int> applicationNumber = const Value.absent(),
            Value<String?> timingLabel = const Value.absent(),
            Value<String> method = const Value.absent(),
            Value<String> status = const Value.absent(),
            required DateTime applicationDate,
            Value<String?> growthStage = const Value.absent(),
            Value<String?> operatorName = const Value.absent(),
            Value<String?> equipment = const Value.absent(),
            Value<String?> weather = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<bool> partialFlag = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String?> completedBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ApplicationEventsCompanion.insert(
            id: id,
            trialId: trialId,
            sessionId: sessionId,
            applicationSlotId: applicationSlotId,
            applicationNumber: applicationNumber,
            timingLabel: timingLabel,
            method: method,
            status: status,
            applicationDate: applicationDate,
            growthStage: growthStage,
            operatorName: operatorName,
            equipment: equipment,
            weather: weather,
            notes: notes,
            partialFlag: partialFlag,
            completedAt: completedAt,
            completedBy: completedBy,
            createdAt: createdAt,
          ),
        ));
}

class $$ApplicationEventsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ApplicationEventsTable> {
  $$ApplicationEventsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get applicationNumber => $state.composableBuilder(
      column: $state.table.applicationNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timingLabel => $state.composableBuilder(
      column: $state.table.timingLabel,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get method => $state.composableBuilder(
      column: $state.table.method,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get applicationDate => $state.composableBuilder(
      column: $state.table.applicationDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get growthStage => $state.composableBuilder(
      column: $state.table.growthStage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get operatorName => $state.composableBuilder(
      column: $state.table.operatorName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get equipment => $state.composableBuilder(
      column: $state.table.equipment,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get weather => $state.composableBuilder(
      column: $state.table.weather,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get partialFlag => $state.composableBuilder(
      column: $state.table.partialFlag,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get completedAt => $state.composableBuilder(
      column: $state.table.completedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get completedBy => $state.composableBuilder(
      column: $state.table.completedBy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$ApplicationSlotsTableFilterComposer get applicationSlotId {
    final $$ApplicationSlotsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.applicationSlotId,
            referencedTable: $state.db.applicationSlots,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationSlotsTableFilterComposer(ComposerState($state.db,
                    $state.db.applicationSlots, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter applicationPlotRecordsRefs(
      ComposableFilter Function($$ApplicationPlotRecordsTableFilterComposer f)
          f) {
    final $$ApplicationPlotRecordsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.applicationPlotRecords,
            getReferencedColumn: (t) => t.eventId,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationPlotRecordsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationPlotRecords,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
  }
}

class $$ApplicationEventsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ApplicationEventsTable> {
  $$ApplicationEventsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get applicationNumber => $state.composableBuilder(
      column: $state.table.applicationNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timingLabel => $state.composableBuilder(
      column: $state.table.timingLabel,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get method => $state.composableBuilder(
      column: $state.table.method,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get applicationDate => $state.composableBuilder(
      column: $state.table.applicationDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get growthStage => $state.composableBuilder(
      column: $state.table.growthStage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get operatorName => $state.composableBuilder(
      column: $state.table.operatorName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get equipment => $state.composableBuilder(
      column: $state.table.equipment,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get weather => $state.composableBuilder(
      column: $state.table.weather,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get partialFlag => $state.composableBuilder(
      column: $state.table.partialFlag,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get completedAt => $state.composableBuilder(
      column: $state.table.completedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get completedBy => $state.composableBuilder(
      column: $state.table.completedBy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$ApplicationSlotsTableOrderingComposer get applicationSlotId {
    final $$ApplicationSlotsTableOrderingComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.applicationSlotId,
            referencedTable: $state.db.applicationSlots,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationSlotsTableOrderingComposer(ComposerState($state.db,
                    $state.db.applicationSlots, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ApplicationPlotRecordsTableCreateCompanionBuilder
    = ApplicationPlotRecordsCompanion Function({
  Value<int> id,
  required int eventId,
  required int plotPk,
  required int trialId,
  Value<String> status,
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$ApplicationPlotRecordsTableUpdateCompanionBuilder
    = ApplicationPlotRecordsCompanion Function({
  Value<int> id,
  Value<int> eventId,
  Value<int> plotPk,
  Value<int> trialId,
  Value<String> status,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

class $$ApplicationPlotRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ApplicationPlotRecordsTable,
    ApplicationPlotRecord,
    $$ApplicationPlotRecordsTableFilterComposer,
    $$ApplicationPlotRecordsTableOrderingComposer,
    $$ApplicationPlotRecordsTableCreateCompanionBuilder,
    $$ApplicationPlotRecordsTableUpdateCompanionBuilder> {
  $$ApplicationPlotRecordsTableTableManager(
      _$AppDatabase db, $ApplicationPlotRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$ApplicationPlotRecordsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$ApplicationPlotRecordsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> eventId = const Value.absent(),
            Value<int> plotPk = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ApplicationPlotRecordsCompanion(
            id: id,
            eventId: eventId,
            plotPk: plotPk,
            trialId: trialId,
            status: status,
            notes: notes,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int eventId,
            required int plotPk,
            required int trialId,
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ApplicationPlotRecordsCompanion.insert(
            id: id,
            eventId: eventId,
            plotPk: plotPk,
            trialId: trialId,
            status: status,
            notes: notes,
            createdAt: createdAt,
          ),
        ));
}

class $$ApplicationPlotRecordsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ApplicationPlotRecordsTable> {
  $$ApplicationPlotRecordsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$ApplicationEventsTableFilterComposer get eventId {
    final $$ApplicationEventsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.eventId,
            referencedTable: $state.db.applicationEvents,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationEventsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.applicationEvents,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ApplicationPlotRecordsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ApplicationPlotRecordsTable> {
  $$ApplicationPlotRecordsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$ApplicationEventsTableOrderingComposer get eventId {
    final $$ApplicationEventsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.eventId,
            referencedTable: $state.db.applicationEvents,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$ApplicationEventsTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.applicationEvents,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$AuditEventsTableCreateCompanionBuilder = AuditEventsCompanion
    Function({
  Value<int> id,
  Value<int?> trialId,
  Value<int?> sessionId,
  Value<int?> plotPk,
  required String eventType,
  required String description,
  Value<String?> performedBy,
  Value<DateTime> createdAt,
  Value<String?> metadata,
});
typedef $$AuditEventsTableUpdateCompanionBuilder = AuditEventsCompanion
    Function({
  Value<int> id,
  Value<int?> trialId,
  Value<int?> sessionId,
  Value<int?> plotPk,
  Value<String> eventType,
  Value<String> description,
  Value<String?> performedBy,
  Value<DateTime> createdAt,
  Value<String?> metadata,
});

class $$AuditEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AuditEventsTable,
    AuditEvent,
    $$AuditEventsTableFilterComposer,
    $$AuditEventsTableOrderingComposer,
    $$AuditEventsTableCreateCompanionBuilder,
    $$AuditEventsTableUpdateCompanionBuilder> {
  $$AuditEventsTableTableManager(_$AppDatabase db, $AuditEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AuditEventsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AuditEventsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> trialId = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            Value<int?> plotPk = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String?> performedBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
          }) =>
              AuditEventsCompanion(
            id: id,
            trialId: trialId,
            sessionId: sessionId,
            plotPk: plotPk,
            eventType: eventType,
            description: description,
            performedBy: performedBy,
            createdAt: createdAt,
            metadata: metadata,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> trialId = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            Value<int?> plotPk = const Value.absent(),
            required String eventType,
            required String description,
            Value<String?> performedBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
          }) =>
              AuditEventsCompanion.insert(
            id: id,
            trialId: trialId,
            sessionId: sessionId,
            plotPk: plotPk,
            eventType: eventType,
            description: description,
            performedBy: performedBy,
            createdAt: createdAt,
            metadata: metadata,
          ),
        ));
}

class $$AuditEventsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AuditEventsTable> {
  $$AuditEventsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get eventType => $state.composableBuilder(
      column: $state.table.eventType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get performedBy => $state.composableBuilder(
      column: $state.table.performedBy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get metadata => $state.composableBuilder(
      column: $state.table.metadata,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableFilterComposer get plotPk {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$AuditEventsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AuditEventsTable> {
  $$AuditEventsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get eventType => $state.composableBuilder(
      column: $state.table.eventType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get performedBy => $state.composableBuilder(
      column: $state.table.performedBy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get metadata => $state.composableBuilder(
      column: $state.table.metadata,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableOrderingComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return composer;
  }

  $$PlotsTableOrderingComposer get plotPk {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotPk,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ImportEventsTableCreateCompanionBuilder = ImportEventsCompanion
    Function({
  Value<int> id,
  required int trialId,
  required String fileName,
  required String status,
  Value<int> rowsImported,
  Value<int> rowsSkipped,
  Value<String?> warnings,
  Value<DateTime> createdAt,
});
typedef $$ImportEventsTableUpdateCompanionBuilder = ImportEventsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<String> fileName,
  Value<String> status,
  Value<int> rowsImported,
  Value<int> rowsSkipped,
  Value<String?> warnings,
  Value<DateTime> createdAt,
});

class $$ImportEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ImportEventsTable,
    ImportEvent,
    $$ImportEventsTableFilterComposer,
    $$ImportEventsTableOrderingComposer,
    $$ImportEventsTableCreateCompanionBuilder,
    $$ImportEventsTableUpdateCompanionBuilder> {
  $$ImportEventsTableTableManager(_$AppDatabase db, $ImportEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ImportEventsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ImportEventsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowsImported = const Value.absent(),
            Value<int> rowsSkipped = const Value.absent(),
            Value<String?> warnings = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ImportEventsCompanion(
            id: id,
            trialId: trialId,
            fileName: fileName,
            status: status,
            rowsImported: rowsImported,
            rowsSkipped: rowsSkipped,
            warnings: warnings,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required String fileName,
            required String status,
            Value<int> rowsImported = const Value.absent(),
            Value<int> rowsSkipped = const Value.absent(),
            Value<String?> warnings = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ImportEventsCompanion.insert(
            id: id,
            trialId: trialId,
            fileName: fileName,
            status: status,
            rowsImported: rowsImported,
            rowsSkipped: rowsSkipped,
            warnings: warnings,
            createdAt: createdAt,
          ),
        ));
}

class $$ImportEventsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $ImportEventsTable> {
  $$ImportEventsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fileName => $state.composableBuilder(
      column: $state.table.fileName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get rowsImported => $state.composableBuilder(
      column: $state.table.rowsImported,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get rowsSkipped => $state.composableBuilder(
      column: $state.table.rowsSkipped,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get warnings => $state.composableBuilder(
      column: $state.table.warnings,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$TrialsTableFilterComposer get trialId {
    final $$TrialsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$TrialsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$ImportEventsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $ImportEventsTable> {
  $$ImportEventsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fileName => $state.composableBuilder(
      column: $state.table.fileName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get rowsImported => $state.composableBuilder(
      column: $state.table.rowsImported,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get rowsSkipped => $state.composableBuilder(
      column: $state.table.rowsSkipped,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get warnings => $state.composableBuilder(
      column: $state.table.warnings,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$TrialsTableOrderingComposer get trialId {
    final $$TrialsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trialId,
        referencedTable: $state.db.trials,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$TrialsTableOrderingComposer(ComposerState(
                $state.db, $state.db.trials, joinBuilder, parentComposers)));
    return composer;
  }
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TrialsTableTableManager get trials =>
      $$TrialsTableTableManager(_db, _db.trials);
  $$TreatmentsTableTableManager get treatments =>
      $$TreatmentsTableTableManager(_db, _db.treatments);
  $$TreatmentComponentsTableTableManager get treatmentComponents =>
      $$TreatmentComponentsTableTableManager(_db, _db.treatmentComponents);
  $$AssessmentsTableTableManager get assessments =>
      $$AssessmentsTableTableManager(_db, _db.assessments);
  $$PlotsTableTableManager get plots =>
      $$PlotsTableTableManager(_db, _db.plots);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionAssessmentsTableTableManager get sessionAssessments =>
      $$SessionAssessmentsTableTableManager(_db, _db.sessionAssessments);
  $$RatingRecordsTableTableManager get ratingRecords =>
      $$RatingRecordsTableTableManager(_db, _db.ratingRecords);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$PlotFlagsTableTableManager get plotFlags =>
      $$PlotFlagsTableTableManager(_db, _db.plotFlags);
  $$DeviationFlagsTableTableManager get deviationFlags =>
      $$DeviationFlagsTableTableManager(_db, _db.deviationFlags);
  $$SeedingRecordsTableTableManager get seedingRecords =>
      $$SeedingRecordsTableTableManager(_db, _db.seedingRecords);
  $$ProtocolSeedingFieldsTableTableManager get protocolSeedingFields =>
      $$ProtocolSeedingFieldsTableTableManager(_db, _db.protocolSeedingFields);
  $$SeedingFieldValuesTableTableManager get seedingFieldValues =>
      $$SeedingFieldValuesTableTableManager(_db, _db.seedingFieldValues);
  $$ApplicationSlotsTableTableManager get applicationSlots =>
      $$ApplicationSlotsTableTableManager(_db, _db.applicationSlots);
  $$ApplicationEventsTableTableManager get applicationEvents =>
      $$ApplicationEventsTableTableManager(_db, _db.applicationEvents);
  $$ApplicationPlotRecordsTableTableManager get applicationPlotRecords =>
      $$ApplicationPlotRecordsTableTableManager(
          _db, _db.applicationPlotRecords);
  $$AuditEventsTableTableManager get auditEvents =>
      $$AuditEventsTableTableManager(_db, _db.auditEvents);
  $$ImportEventsTableTableManager get importEvents =>
      $$ImportEventsTableTableManager(_db, _db.importEvents);
}
