// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _initialsMeta =
      const VerificationMeta('initials');
  @override
  late final GeneratedColumn<String> initials = GeneratedColumn<String>(
      'initials', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roleKeyMeta =
      const VerificationMeta('roleKey');
  @override
  late final GeneratedColumn<String> roleKey = GeneratedColumn<String>(
      'role_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('technician'));
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
      [id, displayName, initials, roleKey, isActive, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('initials')) {
      context.handle(_initialsMeta,
          initials.isAcceptableOrUnknown(data['initials']!, _initialsMeta));
    }
    if (data.containsKey('role_key')) {
      context.handle(_roleKeyMeta,
          roleKey.isAcceptableOrUnknown(data['role_key']!, _roleKeyMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
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
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      initials: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}initials']),
      roleKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role_key'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String displayName;
  final String? initials;
  final String roleKey;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const User(
      {required this.id,
      required this.displayName,
      this.initials,
      required this.roleKey,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || initials != null) {
      map['initials'] = Variable<String>(initials);
    }
    map['role_key'] = Variable<String>(roleKey);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      displayName: Value(displayName),
      initials: initials == null && nullToAbsent
          ? const Value.absent()
          : Value(initials),
      roleKey: Value(roleKey),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      initials: serializer.fromJson<String?>(json['initials']),
      roleKey: serializer.fromJson<String>(json['roleKey']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String>(displayName),
      'initials': serializer.toJson<String?>(initials),
      'roleKey': serializer.toJson<String>(roleKey),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  User copyWith(
          {int? id,
          String? displayName,
          Value<String?> initials = const Value.absent(),
          String? roleKey,
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      User(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        initials: initials.present ? initials.value : this.initials,
        roleKey: roleKey ?? this.roleKey,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      initials: data.initials.present ? data.initials.value : this.initials,
      roleKey: data.roleKey.present ? data.roleKey.value : this.roleKey,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('initials: $initials, ')
          ..write('roleKey: $roleKey, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, displayName, initials, roleKey, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.initials == this.initials &&
          other.roleKey == this.roleKey &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> displayName;
  final Value<String?> initials;
  final Value<String> roleKey;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.initials = const Value.absent(),
    this.roleKey = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String displayName,
    this.initials = const Value.absent(),
    this.roleKey = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : displayName = Value(displayName);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<String>? initials,
    Expression<String>? roleKey,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (initials != null) 'initials': initials,
      if (roleKey != null) 'role_key': roleKey,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UsersCompanion copyWith(
      {Value<int>? id,
      Value<String>? displayName,
      Value<String?>? initials,
      Value<String>? roleKey,
      Value<bool>? isActive,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return UsersCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      initials: initials ?? this.initials,
      roleKey: roleKey ?? this.roleKey,
      isActive: isActive ?? this.isActive,
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
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (initials.present) {
      map['initials'] = Variable<String>(initials.value);
    }
    if (roleKey.present) {
      map['role_key'] = Variable<String>(roleKey.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
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
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('initials: $initials, ')
          ..write('roleKey: $roleKey, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _plotDimensionsMeta =
      const VerificationMeta('plotDimensions');
  @override
  late final GeneratedColumn<String> plotDimensions = GeneratedColumn<String>(
      'plot_dimensions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _plotRowsMeta =
      const VerificationMeta('plotRows');
  @override
  late final GeneratedColumn<int> plotRows = GeneratedColumn<int>(
      'plot_rows', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _plotSpacingMeta =
      const VerificationMeta('plotSpacing');
  @override
  late final GeneratedColumn<String> plotSpacing = GeneratedColumn<String>(
      'plot_spacing', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
  List<GeneratedColumn> get $columns => [
        id,
        name,
        crop,
        location,
        season,
        status,
        plotDimensions,
        plotRows,
        plotSpacing,
        createdAt,
        updatedAt
      ];
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
    if (data.containsKey('plot_dimensions')) {
      context.handle(
          _plotDimensionsMeta,
          plotDimensions.isAcceptableOrUnknown(
              data['plot_dimensions']!, _plotDimensionsMeta));
    }
    if (data.containsKey('plot_rows')) {
      context.handle(_plotRowsMeta,
          plotRows.isAcceptableOrUnknown(data['plot_rows']!, _plotRowsMeta));
    }
    if (data.containsKey('plot_spacing')) {
      context.handle(
          _plotSpacingMeta,
          plotSpacing.isAcceptableOrUnknown(
              data['plot_spacing']!, _plotSpacingMeta));
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
      plotDimensions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plot_dimensions']),
      plotRows: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_rows']),
      plotSpacing: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plot_spacing']),
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

  /// Plot dimensions (e.g. "10 m × 2 m"). Trial-level default.
  final String? plotDimensions;

  /// Number of rows per plot. Trial-level default.
  final int? plotRows;

  /// Spacing between plots (e.g. "0.5 m"). Trial-level default.
  final String? plotSpacing;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Trial(
      {required this.id,
      required this.name,
      this.crop,
      this.location,
      this.season,
      required this.status,
      this.plotDimensions,
      this.plotRows,
      this.plotSpacing,
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
    if (!nullToAbsent || plotDimensions != null) {
      map['plot_dimensions'] = Variable<String>(plotDimensions);
    }
    if (!nullToAbsent || plotRows != null) {
      map['plot_rows'] = Variable<int>(plotRows);
    }
    if (!nullToAbsent || plotSpacing != null) {
      map['plot_spacing'] = Variable<String>(plotSpacing);
    }
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
      plotDimensions: plotDimensions == null && nullToAbsent
          ? const Value.absent()
          : Value(plotDimensions),
      plotRows: plotRows == null && nullToAbsent
          ? const Value.absent()
          : Value(plotRows),
      plotSpacing: plotSpacing == null && nullToAbsent
          ? const Value.absent()
          : Value(plotSpacing),
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
      plotDimensions: serializer.fromJson<String?>(json['plotDimensions']),
      plotRows: serializer.fromJson<int?>(json['plotRows']),
      plotSpacing: serializer.fromJson<String?>(json['plotSpacing']),
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
      'plotDimensions': serializer.toJson<String?>(plotDimensions),
      'plotRows': serializer.toJson<int?>(plotRows),
      'plotSpacing': serializer.toJson<String?>(plotSpacing),
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
          Value<String?> plotDimensions = const Value.absent(),
          Value<int?> plotRows = const Value.absent(),
          Value<String?> plotSpacing = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Trial(
        id: id ?? this.id,
        name: name ?? this.name,
        crop: crop.present ? crop.value : this.crop,
        location: location.present ? location.value : this.location,
        season: season.present ? season.value : this.season,
        status: status ?? this.status,
        plotDimensions:
            plotDimensions.present ? plotDimensions.value : this.plotDimensions,
        plotRows: plotRows.present ? plotRows.value : this.plotRows,
        plotSpacing: plotSpacing.present ? plotSpacing.value : this.plotSpacing,
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
      plotDimensions: data.plotDimensions.present
          ? data.plotDimensions.value
          : this.plotDimensions,
      plotRows: data.plotRows.present ? data.plotRows.value : this.plotRows,
      plotSpacing:
          data.plotSpacing.present ? data.plotSpacing.value : this.plotSpacing,
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
          ..write('plotDimensions: $plotDimensions, ')
          ..write('plotRows: $plotRows, ')
          ..write('plotSpacing: $plotSpacing, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, crop, location, season, status,
      plotDimensions, plotRows, plotSpacing, createdAt, updatedAt);
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
          other.plotDimensions == this.plotDimensions &&
          other.plotRows == this.plotRows &&
          other.plotSpacing == this.plotSpacing &&
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
  final Value<String?> plotDimensions;
  final Value<int?> plotRows;
  final Value<String?> plotSpacing;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TrialsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.crop = const Value.absent(),
    this.location = const Value.absent(),
    this.season = const Value.absent(),
    this.status = const Value.absent(),
    this.plotDimensions = const Value.absent(),
    this.plotRows = const Value.absent(),
    this.plotSpacing = const Value.absent(),
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
    this.plotDimensions = const Value.absent(),
    this.plotRows = const Value.absent(),
    this.plotSpacing = const Value.absent(),
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
    Expression<String>? plotDimensions,
    Expression<int>? plotRows,
    Expression<String>? plotSpacing,
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
      if (plotDimensions != null) 'plot_dimensions': plotDimensions,
      if (plotRows != null) 'plot_rows': plotRows,
      if (plotSpacing != null) 'plot_spacing': plotSpacing,
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
      Value<String?>? plotDimensions,
      Value<int?>? plotRows,
      Value<String?>? plotSpacing,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return TrialsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      crop: crop ?? this.crop,
      location: location ?? this.location,
      season: season ?? this.season,
      status: status ?? this.status,
      plotDimensions: plotDimensions ?? this.plotDimensions,
      plotRows: plotRows ?? this.plotRows,
      plotSpacing: plotSpacing ?? this.plotSpacing,
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
    if (plotDimensions.present) {
      map['plot_dimensions'] = Variable<String>(plotDimensions.value);
    }
    if (plotRows.present) {
      map['plot_rows'] = Variable<int>(plotRows.value);
    }
    if (plotSpacing.present) {
      map['plot_spacing'] = Variable<String>(plotSpacing.value);
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
          ..write('plotDimensions: $plotDimensions, ')
          ..write('plotRows: $plotRows, ')
          ..write('plotSpacing: $plotSpacing, ')
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

class $AssessmentDefinitionsTable extends AssessmentDefinitions
    with TableInfo<$AssessmentDefinitionsTable, AssessmentDefinition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssessmentDefinitionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
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
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
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
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scaleMinMeta =
      const VerificationMeta('scaleMin');
  @override
  late final GeneratedColumn<double> scaleMin = GeneratedColumn<double>(
      'scale_min', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _scaleMaxMeta =
      const VerificationMeta('scaleMax');
  @override
  late final GeneratedColumn<double> scaleMax = GeneratedColumn<double>(
      'scale_max', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
      'target', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
      'method', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _defaultInstructionsMeta =
      const VerificationMeta('defaultInstructions');
  @override
  late final GeneratedColumn<String> defaultInstructions =
      GeneratedColumn<String>('default_instructions', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timingTypeMeta =
      const VerificationMeta('timingType');
  @override
  late final GeneratedColumn<String> timingType = GeneratedColumn<String>(
      'timing_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isSystemMeta =
      const VerificationMeta('isSystem');
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
      'is_system', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_system" IN (0, 1))'),
      defaultValue: const Constant(true));
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
  List<GeneratedColumn> get $columns => [
        id,
        code,
        name,
        category,
        dataType,
        unit,
        scaleMin,
        scaleMax,
        target,
        method,
        defaultInstructions,
        timingType,
        isSystem,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assessment_definitions';
  @override
  VerificationContext validateIntegrity(
      Insertable<AssessmentDefinition> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('data_type')) {
      context.handle(_dataTypeMeta,
          dataType.isAcceptableOrUnknown(data['data_type']!, _dataTypeMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('scale_min')) {
      context.handle(_scaleMinMeta,
          scaleMin.isAcceptableOrUnknown(data['scale_min']!, _scaleMinMeta));
    }
    if (data.containsKey('scale_max')) {
      context.handle(_scaleMaxMeta,
          scaleMax.isAcceptableOrUnknown(data['scale_max']!, _scaleMaxMeta));
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta,
          target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    }
    if (data.containsKey('default_instructions')) {
      context.handle(
          _defaultInstructionsMeta,
          defaultInstructions.isAcceptableOrUnknown(
              data['default_instructions']!, _defaultInstructionsMeta));
    }
    if (data.containsKey('timing_type')) {
      context.handle(
          _timingTypeMeta,
          timingType.isAcceptableOrUnknown(
              data['timing_type']!, _timingTypeMeta));
    }
    if (data.containsKey('is_system')) {
      context.handle(_isSystemMeta,
          isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
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
  AssessmentDefinition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssessmentDefinition(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      dataType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_type'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit']),
      scaleMin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}scale_min']),
      scaleMax: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}scale_max']),
      target: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target']),
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method']),
      defaultInstructions: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}default_instructions']),
      timingType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timing_type']),
      isSystem: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_system'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AssessmentDefinitionsTable createAlias(String alias) {
    return $AssessmentDefinitionsTable(attachedDatabase, alias);
  }
}

class AssessmentDefinition extends DataClass
    implements Insertable<AssessmentDefinition> {
  final int id;
  final String code;
  final String name;
  final String category;
  final String dataType;
  final String? unit;
  final double? scaleMin;
  final double? scaleMax;
  final String? target;
  final String? method;
  final String? defaultInstructions;
  final String? timingType;
  final bool isSystem;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AssessmentDefinition(
      {required this.id,
      required this.code,
      required this.name,
      required this.category,
      required this.dataType,
      this.unit,
      this.scaleMin,
      this.scaleMax,
      this.target,
      this.method,
      this.defaultInstructions,
      this.timingType,
      required this.isSystem,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['data_type'] = Variable<String>(dataType);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || scaleMin != null) {
      map['scale_min'] = Variable<double>(scaleMin);
    }
    if (!nullToAbsent || scaleMax != null) {
      map['scale_max'] = Variable<double>(scaleMax);
    }
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    if (!nullToAbsent || method != null) {
      map['method'] = Variable<String>(method);
    }
    if (!nullToAbsent || defaultInstructions != null) {
      map['default_instructions'] = Variable<String>(defaultInstructions);
    }
    if (!nullToAbsent || timingType != null) {
      map['timing_type'] = Variable<String>(timingType);
    }
    map['is_system'] = Variable<bool>(isSystem);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AssessmentDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return AssessmentDefinitionsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      category: Value(category),
      dataType: Value(dataType),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      scaleMin: scaleMin == null && nullToAbsent
          ? const Value.absent()
          : Value(scaleMin),
      scaleMax: scaleMax == null && nullToAbsent
          ? const Value.absent()
          : Value(scaleMax),
      target:
          target == null && nullToAbsent ? const Value.absent() : Value(target),
      method:
          method == null && nullToAbsent ? const Value.absent() : Value(method),
      defaultInstructions: defaultInstructions == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultInstructions),
      timingType: timingType == null && nullToAbsent
          ? const Value.absent()
          : Value(timingType),
      isSystem: Value(isSystem),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssessmentDefinition.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssessmentDefinition(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      dataType: serializer.fromJson<String>(json['dataType']),
      unit: serializer.fromJson<String?>(json['unit']),
      scaleMin: serializer.fromJson<double?>(json['scaleMin']),
      scaleMax: serializer.fromJson<double?>(json['scaleMax']),
      target: serializer.fromJson<String?>(json['target']),
      method: serializer.fromJson<String?>(json['method']),
      defaultInstructions:
          serializer.fromJson<String?>(json['defaultInstructions']),
      timingType: serializer.fromJson<String?>(json['timingType']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'dataType': serializer.toJson<String>(dataType),
      'unit': serializer.toJson<String?>(unit),
      'scaleMin': serializer.toJson<double?>(scaleMin),
      'scaleMax': serializer.toJson<double?>(scaleMax),
      'target': serializer.toJson<String?>(target),
      'method': serializer.toJson<String?>(method),
      'defaultInstructions': serializer.toJson<String?>(defaultInstructions),
      'timingType': serializer.toJson<String?>(timingType),
      'isSystem': serializer.toJson<bool>(isSystem),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssessmentDefinition copyWith(
          {int? id,
          String? code,
          String? name,
          String? category,
          String? dataType,
          Value<String?> unit = const Value.absent(),
          Value<double?> scaleMin = const Value.absent(),
          Value<double?> scaleMax = const Value.absent(),
          Value<String?> target = const Value.absent(),
          Value<String?> method = const Value.absent(),
          Value<String?> defaultInstructions = const Value.absent(),
          Value<String?> timingType = const Value.absent(),
          bool? isSystem,
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      AssessmentDefinition(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        category: category ?? this.category,
        dataType: dataType ?? this.dataType,
        unit: unit.present ? unit.value : this.unit,
        scaleMin: scaleMin.present ? scaleMin.value : this.scaleMin,
        scaleMax: scaleMax.present ? scaleMax.value : this.scaleMax,
        target: target.present ? target.value : this.target,
        method: method.present ? method.value : this.method,
        defaultInstructions: defaultInstructions.present
            ? defaultInstructions.value
            : this.defaultInstructions,
        timingType: timingType.present ? timingType.value : this.timingType,
        isSystem: isSystem ?? this.isSystem,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AssessmentDefinition copyWithCompanion(AssessmentDefinitionsCompanion data) {
    return AssessmentDefinition(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      dataType: data.dataType.present ? data.dataType.value : this.dataType,
      unit: data.unit.present ? data.unit.value : this.unit,
      scaleMin: data.scaleMin.present ? data.scaleMin.value : this.scaleMin,
      scaleMax: data.scaleMax.present ? data.scaleMax.value : this.scaleMax,
      target: data.target.present ? data.target.value : this.target,
      method: data.method.present ? data.method.value : this.method,
      defaultInstructions: data.defaultInstructions.present
          ? data.defaultInstructions.value
          : this.defaultInstructions,
      timingType:
          data.timingType.present ? data.timingType.value : this.timingType,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentDefinition(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('dataType: $dataType, ')
          ..write('unit: $unit, ')
          ..write('scaleMin: $scaleMin, ')
          ..write('scaleMax: $scaleMax, ')
          ..write('target: $target, ')
          ..write('method: $method, ')
          ..write('defaultInstructions: $defaultInstructions, ')
          ..write('timingType: $timingType, ')
          ..write('isSystem: $isSystem, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      code,
      name,
      category,
      dataType,
      unit,
      scaleMin,
      scaleMax,
      target,
      method,
      defaultInstructions,
      timingType,
      isSystem,
      isActive,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssessmentDefinition &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.category == this.category &&
          other.dataType == this.dataType &&
          other.unit == this.unit &&
          other.scaleMin == this.scaleMin &&
          other.scaleMax == this.scaleMax &&
          other.target == this.target &&
          other.method == this.method &&
          other.defaultInstructions == this.defaultInstructions &&
          other.timingType == this.timingType &&
          other.isSystem == this.isSystem &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AssessmentDefinitionsCompanion
    extends UpdateCompanion<AssessmentDefinition> {
  final Value<int> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> category;
  final Value<String> dataType;
  final Value<String?> unit;
  final Value<double?> scaleMin;
  final Value<double?> scaleMax;
  final Value<String?> target;
  final Value<String?> method;
  final Value<String?> defaultInstructions;
  final Value<String?> timingType;
  final Value<bool> isSystem;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AssessmentDefinitionsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.dataType = const Value.absent(),
    this.unit = const Value.absent(),
    this.scaleMin = const Value.absent(),
    this.scaleMax = const Value.absent(),
    this.target = const Value.absent(),
    this.method = const Value.absent(),
    this.defaultInstructions = const Value.absent(),
    this.timingType = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AssessmentDefinitionsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required String name,
    required String category,
    this.dataType = const Value.absent(),
    this.unit = const Value.absent(),
    this.scaleMin = const Value.absent(),
    this.scaleMax = const Value.absent(),
    this.target = const Value.absent(),
    this.method = const Value.absent(),
    this.defaultInstructions = const Value.absent(),
    this.timingType = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : code = Value(code),
        name = Value(name),
        category = Value(category);
  static Insertable<AssessmentDefinition> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? dataType,
    Expression<String>? unit,
    Expression<double>? scaleMin,
    Expression<double>? scaleMax,
    Expression<String>? target,
    Expression<String>? method,
    Expression<String>? defaultInstructions,
    Expression<String>? timingType,
    Expression<bool>? isSystem,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (dataType != null) 'data_type': dataType,
      if (unit != null) 'unit': unit,
      if (scaleMin != null) 'scale_min': scaleMin,
      if (scaleMax != null) 'scale_max': scaleMax,
      if (target != null) 'target': target,
      if (method != null) 'method': method,
      if (defaultInstructions != null)
        'default_instructions': defaultInstructions,
      if (timingType != null) 'timing_type': timingType,
      if (isSystem != null) 'is_system': isSystem,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AssessmentDefinitionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? code,
      Value<String>? name,
      Value<String>? category,
      Value<String>? dataType,
      Value<String?>? unit,
      Value<double?>? scaleMin,
      Value<double?>? scaleMax,
      Value<String?>? target,
      Value<String?>? method,
      Value<String?>? defaultInstructions,
      Value<String?>? timingType,
      Value<bool>? isSystem,
      Value<bool>? isActive,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return AssessmentDefinitionsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      dataType: dataType ?? this.dataType,
      unit: unit ?? this.unit,
      scaleMin: scaleMin ?? this.scaleMin,
      scaleMax: scaleMax ?? this.scaleMax,
      target: target ?? this.target,
      method: method ?? this.method,
      defaultInstructions: defaultInstructions ?? this.defaultInstructions,
      timingType: timingType ?? this.timingType,
      isSystem: isSystem ?? this.isSystem,
      isActive: isActive ?? this.isActive,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (dataType.present) {
      map['data_type'] = Variable<String>(dataType.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (scaleMin.present) {
      map['scale_min'] = Variable<double>(scaleMin.value);
    }
    if (scaleMax.present) {
      map['scale_max'] = Variable<double>(scaleMax.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (defaultInstructions.present) {
      map['default_instructions'] = Variable<String>(defaultInstructions.value);
    }
    if (timingType.present) {
      map['timing_type'] = Variable<String>(timingType.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
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
    return (StringBuffer('AssessmentDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('dataType: $dataType, ')
          ..write('unit: $unit, ')
          ..write('scaleMin: $scaleMin, ')
          ..write('scaleMax: $scaleMax, ')
          ..write('target: $target, ')
          ..write('method: $method, ')
          ..write('defaultInstructions: $defaultInstructions, ')
          ..write('timingType: $timingType, ')
          ..write('isSystem: $isSystem, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TrialAssessmentsTable extends TrialAssessments
    with TableInfo<$TrialAssessmentsTable, TrialAssessment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrialAssessmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _assessmentDefinitionIdMeta =
      const VerificationMeta('assessmentDefinitionId');
  @override
  late final GeneratedColumn<int> assessmentDefinitionId = GeneratedColumn<int>(
      'assessment_definition_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES assessment_definitions (id)'));
  static const VerificationMeta _displayNameOverrideMeta =
      const VerificationMeta('displayNameOverride');
  @override
  late final GeneratedColumn<String> displayNameOverride =
      GeneratedColumn<String>('display_name_override', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _requiredMeta =
      const VerificationMeta('required');
  @override
  late final GeneratedColumn<bool> required = GeneratedColumn<bool>(
      'required', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("required" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _selectedFromProtocolMeta =
      const VerificationMeta('selectedFromProtocol');
  @override
  late final GeneratedColumn<bool> selectedFromProtocol = GeneratedColumn<bool>(
      'selected_from_protocol', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("selected_from_protocol" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _selectedManuallyMeta =
      const VerificationMeta('selectedManually');
  @override
  late final GeneratedColumn<bool> selectedManually = GeneratedColumn<bool>(
      'selected_manually', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("selected_manually" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _defaultInSessionsMeta =
      const VerificationMeta('defaultInSessions');
  @override
  late final GeneratedColumn<bool> defaultInSessions = GeneratedColumn<bool>(
      'default_in_sessions', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("default_in_sessions" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _timingModeMeta =
      const VerificationMeta('timingMode');
  @override
  late final GeneratedColumn<String> timingMode = GeneratedColumn<String>(
      'timing_mode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _daysAfterPlantingMeta =
      const VerificationMeta('daysAfterPlanting');
  @override
  late final GeneratedColumn<int> daysAfterPlanting = GeneratedColumn<int>(
      'days_after_planting', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _daysAfterTreatmentMeta =
      const VerificationMeta('daysAfterTreatment');
  @override
  late final GeneratedColumn<int> daysAfterTreatment = GeneratedColumn<int>(
      'days_after_treatment', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _growthStageMeta =
      const VerificationMeta('growthStage');
  @override
  late final GeneratedColumn<String> growthStage = GeneratedColumn<String>(
      'growth_stage', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _methodOverrideMeta =
      const VerificationMeta('methodOverride');
  @override
  late final GeneratedColumn<String> methodOverride = GeneratedColumn<String>(
      'method_override', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _instructionOverrideMeta =
      const VerificationMeta('instructionOverride');
  @override
  late final GeneratedColumn<String> instructionOverride =
      GeneratedColumn<String>('instruction_override', aliasedName, true,
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
  static const VerificationMeta _legacyAssessmentIdMeta =
      const VerificationMeta('legacyAssessmentId');
  @override
  late final GeneratedColumn<int> legacyAssessmentId = GeneratedColumn<int>(
      'legacy_assessment_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES assessments (id)'));
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
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        assessmentDefinitionId,
        displayNameOverride,
        required,
        selectedFromProtocol,
        selectedManually,
        defaultInSessions,
        sortOrder,
        timingMode,
        daysAfterPlanting,
        daysAfterTreatment,
        growthStage,
        methodOverride,
        instructionOverride,
        isActive,
        legacyAssessmentId,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trial_assessments';
  @override
  VerificationContext validateIntegrity(Insertable<TrialAssessment> instance,
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
    if (data.containsKey('assessment_definition_id')) {
      context.handle(
          _assessmentDefinitionIdMeta,
          assessmentDefinitionId.isAcceptableOrUnknown(
              data['assessment_definition_id']!, _assessmentDefinitionIdMeta));
    } else if (isInserting) {
      context.missing(_assessmentDefinitionIdMeta);
    }
    if (data.containsKey('display_name_override')) {
      context.handle(
          _displayNameOverrideMeta,
          displayNameOverride.isAcceptableOrUnknown(
              data['display_name_override']!, _displayNameOverrideMeta));
    }
    if (data.containsKey('required')) {
      context.handle(_requiredMeta,
          required.isAcceptableOrUnknown(data['required']!, _requiredMeta));
    }
    if (data.containsKey('selected_from_protocol')) {
      context.handle(
          _selectedFromProtocolMeta,
          selectedFromProtocol.isAcceptableOrUnknown(
              data['selected_from_protocol']!, _selectedFromProtocolMeta));
    }
    if (data.containsKey('selected_manually')) {
      context.handle(
          _selectedManuallyMeta,
          selectedManually.isAcceptableOrUnknown(
              data['selected_manually']!, _selectedManuallyMeta));
    }
    if (data.containsKey('default_in_sessions')) {
      context.handle(
          _defaultInSessionsMeta,
          defaultInSessions.isAcceptableOrUnknown(
              data['default_in_sessions']!, _defaultInSessionsMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('timing_mode')) {
      context.handle(
          _timingModeMeta,
          timingMode.isAcceptableOrUnknown(
              data['timing_mode']!, _timingModeMeta));
    }
    if (data.containsKey('days_after_planting')) {
      context.handle(
          _daysAfterPlantingMeta,
          daysAfterPlanting.isAcceptableOrUnknown(
              data['days_after_planting']!, _daysAfterPlantingMeta));
    }
    if (data.containsKey('days_after_treatment')) {
      context.handle(
          _daysAfterTreatmentMeta,
          daysAfterTreatment.isAcceptableOrUnknown(
              data['days_after_treatment']!, _daysAfterTreatmentMeta));
    }
    if (data.containsKey('growth_stage')) {
      context.handle(
          _growthStageMeta,
          growthStage.isAcceptableOrUnknown(
              data['growth_stage']!, _growthStageMeta));
    }
    if (data.containsKey('method_override')) {
      context.handle(
          _methodOverrideMeta,
          methodOverride.isAcceptableOrUnknown(
              data['method_override']!, _methodOverrideMeta));
    }
    if (data.containsKey('instruction_override')) {
      context.handle(
          _instructionOverrideMeta,
          instructionOverride.isAcceptableOrUnknown(
              data['instruction_override']!, _instructionOverrideMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('legacy_assessment_id')) {
      context.handle(
          _legacyAssessmentIdMeta,
          legacyAssessmentId.isAcceptableOrUnknown(
              data['legacy_assessment_id']!, _legacyAssessmentIdMeta));
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
  TrialAssessment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrialAssessment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      assessmentDefinitionId: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}assessment_definition_id'])!,
      displayNameOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}display_name_override']),
      required: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}required'])!,
      selectedFromProtocol: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}selected_from_protocol'])!,
      selectedManually: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}selected_manually'])!,
      defaultInSessions: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}default_in_sessions'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      timingMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timing_mode']),
      daysAfterPlanting: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}days_after_planting']),
      daysAfterTreatment: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}days_after_treatment']),
      growthStage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}growth_stage']),
      methodOverride: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method_override']),
      instructionOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}instruction_override']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      legacyAssessmentId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}legacy_assessment_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TrialAssessmentsTable createAlias(String alias) {
    return $TrialAssessmentsTable(attachedDatabase, alias);
  }
}

class TrialAssessment extends DataClass implements Insertable<TrialAssessment> {
  final int id;
  final int trialId;
  final int assessmentDefinitionId;
  final String? displayNameOverride;
  final bool required;
  final bool selectedFromProtocol;
  final bool selectedManually;
  final bool defaultInSessions;
  final int sortOrder;
  final String? timingMode;
  final int? daysAfterPlanting;
  final int? daysAfterTreatment;
  final String? growthStage;
  final String? methodOverride;
  final String? instructionOverride;
  final bool isActive;
  final int? legacyAssessmentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TrialAssessment(
      {required this.id,
      required this.trialId,
      required this.assessmentDefinitionId,
      this.displayNameOverride,
      required this.required,
      required this.selectedFromProtocol,
      required this.selectedManually,
      required this.defaultInSessions,
      required this.sortOrder,
      this.timingMode,
      this.daysAfterPlanting,
      this.daysAfterTreatment,
      this.growthStage,
      this.methodOverride,
      this.instructionOverride,
      required this.isActive,
      this.legacyAssessmentId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['assessment_definition_id'] = Variable<int>(assessmentDefinitionId);
    if (!nullToAbsent || displayNameOverride != null) {
      map['display_name_override'] = Variable<String>(displayNameOverride);
    }
    map['required'] = Variable<bool>(required);
    map['selected_from_protocol'] = Variable<bool>(selectedFromProtocol);
    map['selected_manually'] = Variable<bool>(selectedManually);
    map['default_in_sessions'] = Variable<bool>(defaultInSessions);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || timingMode != null) {
      map['timing_mode'] = Variable<String>(timingMode);
    }
    if (!nullToAbsent || daysAfterPlanting != null) {
      map['days_after_planting'] = Variable<int>(daysAfterPlanting);
    }
    if (!nullToAbsent || daysAfterTreatment != null) {
      map['days_after_treatment'] = Variable<int>(daysAfterTreatment);
    }
    if (!nullToAbsent || growthStage != null) {
      map['growth_stage'] = Variable<String>(growthStage);
    }
    if (!nullToAbsent || methodOverride != null) {
      map['method_override'] = Variable<String>(methodOverride);
    }
    if (!nullToAbsent || instructionOverride != null) {
      map['instruction_override'] = Variable<String>(instructionOverride);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || legacyAssessmentId != null) {
      map['legacy_assessment_id'] = Variable<int>(legacyAssessmentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrialAssessmentsCompanion toCompanion(bool nullToAbsent) {
    return TrialAssessmentsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      assessmentDefinitionId: Value(assessmentDefinitionId),
      displayNameOverride: displayNameOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(displayNameOverride),
      required: Value(required),
      selectedFromProtocol: Value(selectedFromProtocol),
      selectedManually: Value(selectedManually),
      defaultInSessions: Value(defaultInSessions),
      sortOrder: Value(sortOrder),
      timingMode: timingMode == null && nullToAbsent
          ? const Value.absent()
          : Value(timingMode),
      daysAfterPlanting: daysAfterPlanting == null && nullToAbsent
          ? const Value.absent()
          : Value(daysAfterPlanting),
      daysAfterTreatment: daysAfterTreatment == null && nullToAbsent
          ? const Value.absent()
          : Value(daysAfterTreatment),
      growthStage: growthStage == null && nullToAbsent
          ? const Value.absent()
          : Value(growthStage),
      methodOverride: methodOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(methodOverride),
      instructionOverride: instructionOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(instructionOverride),
      isActive: Value(isActive),
      legacyAssessmentId: legacyAssessmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyAssessmentId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrialAssessment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrialAssessment(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      assessmentDefinitionId:
          serializer.fromJson<int>(json['assessmentDefinitionId']),
      displayNameOverride:
          serializer.fromJson<String?>(json['displayNameOverride']),
      required: serializer.fromJson<bool>(json['required']),
      selectedFromProtocol:
          serializer.fromJson<bool>(json['selectedFromProtocol']),
      selectedManually: serializer.fromJson<bool>(json['selectedManually']),
      defaultInSessions: serializer.fromJson<bool>(json['defaultInSessions']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      timingMode: serializer.fromJson<String?>(json['timingMode']),
      daysAfterPlanting: serializer.fromJson<int?>(json['daysAfterPlanting']),
      daysAfterTreatment: serializer.fromJson<int?>(json['daysAfterTreatment']),
      growthStage: serializer.fromJson<String?>(json['growthStage']),
      methodOverride: serializer.fromJson<String?>(json['methodOverride']),
      instructionOverride:
          serializer.fromJson<String?>(json['instructionOverride']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      legacyAssessmentId: serializer.fromJson<int?>(json['legacyAssessmentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'assessmentDefinitionId': serializer.toJson<int>(assessmentDefinitionId),
      'displayNameOverride': serializer.toJson<String?>(displayNameOverride),
      'required': serializer.toJson<bool>(required),
      'selectedFromProtocol': serializer.toJson<bool>(selectedFromProtocol),
      'selectedManually': serializer.toJson<bool>(selectedManually),
      'defaultInSessions': serializer.toJson<bool>(defaultInSessions),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'timingMode': serializer.toJson<String?>(timingMode),
      'daysAfterPlanting': serializer.toJson<int?>(daysAfterPlanting),
      'daysAfterTreatment': serializer.toJson<int?>(daysAfterTreatment),
      'growthStage': serializer.toJson<String?>(growthStage),
      'methodOverride': serializer.toJson<String?>(methodOverride),
      'instructionOverride': serializer.toJson<String?>(instructionOverride),
      'isActive': serializer.toJson<bool>(isActive),
      'legacyAssessmentId': serializer.toJson<int?>(legacyAssessmentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrialAssessment copyWith(
          {int? id,
          int? trialId,
          int? assessmentDefinitionId,
          Value<String?> displayNameOverride = const Value.absent(),
          bool? required,
          bool? selectedFromProtocol,
          bool? selectedManually,
          bool? defaultInSessions,
          int? sortOrder,
          Value<String?> timingMode = const Value.absent(),
          Value<int?> daysAfterPlanting = const Value.absent(),
          Value<int?> daysAfterTreatment = const Value.absent(),
          Value<String?> growthStage = const Value.absent(),
          Value<String?> methodOverride = const Value.absent(),
          Value<String?> instructionOverride = const Value.absent(),
          bool? isActive,
          Value<int?> legacyAssessmentId = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      TrialAssessment(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        assessmentDefinitionId:
            assessmentDefinitionId ?? this.assessmentDefinitionId,
        displayNameOverride: displayNameOverride.present
            ? displayNameOverride.value
            : this.displayNameOverride,
        required: required ?? this.required,
        selectedFromProtocol: selectedFromProtocol ?? this.selectedFromProtocol,
        selectedManually: selectedManually ?? this.selectedManually,
        defaultInSessions: defaultInSessions ?? this.defaultInSessions,
        sortOrder: sortOrder ?? this.sortOrder,
        timingMode: timingMode.present ? timingMode.value : this.timingMode,
        daysAfterPlanting: daysAfterPlanting.present
            ? daysAfterPlanting.value
            : this.daysAfterPlanting,
        daysAfterTreatment: daysAfterTreatment.present
            ? daysAfterTreatment.value
            : this.daysAfterTreatment,
        growthStage: growthStage.present ? growthStage.value : this.growthStage,
        methodOverride:
            methodOverride.present ? methodOverride.value : this.methodOverride,
        instructionOverride: instructionOverride.present
            ? instructionOverride.value
            : this.instructionOverride,
        isActive: isActive ?? this.isActive,
        legacyAssessmentId: legacyAssessmentId.present
            ? legacyAssessmentId.value
            : this.legacyAssessmentId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  TrialAssessment copyWithCompanion(TrialAssessmentsCompanion data) {
    return TrialAssessment(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      assessmentDefinitionId: data.assessmentDefinitionId.present
          ? data.assessmentDefinitionId.value
          : this.assessmentDefinitionId,
      displayNameOverride: data.displayNameOverride.present
          ? data.displayNameOverride.value
          : this.displayNameOverride,
      required: data.required.present ? data.required.value : this.required,
      selectedFromProtocol: data.selectedFromProtocol.present
          ? data.selectedFromProtocol.value
          : this.selectedFromProtocol,
      selectedManually: data.selectedManually.present
          ? data.selectedManually.value
          : this.selectedManually,
      defaultInSessions: data.defaultInSessions.present
          ? data.defaultInSessions.value
          : this.defaultInSessions,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      timingMode:
          data.timingMode.present ? data.timingMode.value : this.timingMode,
      daysAfterPlanting: data.daysAfterPlanting.present
          ? data.daysAfterPlanting.value
          : this.daysAfterPlanting,
      daysAfterTreatment: data.daysAfterTreatment.present
          ? data.daysAfterTreatment.value
          : this.daysAfterTreatment,
      growthStage:
          data.growthStage.present ? data.growthStage.value : this.growthStage,
      methodOverride: data.methodOverride.present
          ? data.methodOverride.value
          : this.methodOverride,
      instructionOverride: data.instructionOverride.present
          ? data.instructionOverride.value
          : this.instructionOverride,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      legacyAssessmentId: data.legacyAssessmentId.present
          ? data.legacyAssessmentId.value
          : this.legacyAssessmentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrialAssessment(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('assessmentDefinitionId: $assessmentDefinitionId, ')
          ..write('displayNameOverride: $displayNameOverride, ')
          ..write('required: $required, ')
          ..write('selectedFromProtocol: $selectedFromProtocol, ')
          ..write('selectedManually: $selectedManually, ')
          ..write('defaultInSessions: $defaultInSessions, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('timingMode: $timingMode, ')
          ..write('daysAfterPlanting: $daysAfterPlanting, ')
          ..write('daysAfterTreatment: $daysAfterTreatment, ')
          ..write('growthStage: $growthStage, ')
          ..write('methodOverride: $methodOverride, ')
          ..write('instructionOverride: $instructionOverride, ')
          ..write('isActive: $isActive, ')
          ..write('legacyAssessmentId: $legacyAssessmentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trialId,
      assessmentDefinitionId,
      displayNameOverride,
      required,
      selectedFromProtocol,
      selectedManually,
      defaultInSessions,
      sortOrder,
      timingMode,
      daysAfterPlanting,
      daysAfterTreatment,
      growthStage,
      methodOverride,
      instructionOverride,
      isActive,
      legacyAssessmentId,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrialAssessment &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.assessmentDefinitionId == this.assessmentDefinitionId &&
          other.displayNameOverride == this.displayNameOverride &&
          other.required == this.required &&
          other.selectedFromProtocol == this.selectedFromProtocol &&
          other.selectedManually == this.selectedManually &&
          other.defaultInSessions == this.defaultInSessions &&
          other.sortOrder == this.sortOrder &&
          other.timingMode == this.timingMode &&
          other.daysAfterPlanting == this.daysAfterPlanting &&
          other.daysAfterTreatment == this.daysAfterTreatment &&
          other.growthStage == this.growthStage &&
          other.methodOverride == this.methodOverride &&
          other.instructionOverride == this.instructionOverride &&
          other.isActive == this.isActive &&
          other.legacyAssessmentId == this.legacyAssessmentId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TrialAssessmentsCompanion extends UpdateCompanion<TrialAssessment> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> assessmentDefinitionId;
  final Value<String?> displayNameOverride;
  final Value<bool> required;
  final Value<bool> selectedFromProtocol;
  final Value<bool> selectedManually;
  final Value<bool> defaultInSessions;
  final Value<int> sortOrder;
  final Value<String?> timingMode;
  final Value<int?> daysAfterPlanting;
  final Value<int?> daysAfterTreatment;
  final Value<String?> growthStage;
  final Value<String?> methodOverride;
  final Value<String?> instructionOverride;
  final Value<bool> isActive;
  final Value<int?> legacyAssessmentId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TrialAssessmentsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.assessmentDefinitionId = const Value.absent(),
    this.displayNameOverride = const Value.absent(),
    this.required = const Value.absent(),
    this.selectedFromProtocol = const Value.absent(),
    this.selectedManually = const Value.absent(),
    this.defaultInSessions = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.timingMode = const Value.absent(),
    this.daysAfterPlanting = const Value.absent(),
    this.daysAfterTreatment = const Value.absent(),
    this.growthStage = const Value.absent(),
    this.methodOverride = const Value.absent(),
    this.instructionOverride = const Value.absent(),
    this.isActive = const Value.absent(),
    this.legacyAssessmentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TrialAssessmentsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int assessmentDefinitionId,
    this.displayNameOverride = const Value.absent(),
    this.required = const Value.absent(),
    this.selectedFromProtocol = const Value.absent(),
    this.selectedManually = const Value.absent(),
    this.defaultInSessions = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.timingMode = const Value.absent(),
    this.daysAfterPlanting = const Value.absent(),
    this.daysAfterTreatment = const Value.absent(),
    this.growthStage = const Value.absent(),
    this.methodOverride = const Value.absent(),
    this.instructionOverride = const Value.absent(),
    this.isActive = const Value.absent(),
    this.legacyAssessmentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : trialId = Value(trialId),
        assessmentDefinitionId = Value(assessmentDefinitionId);
  static Insertable<TrialAssessment> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? assessmentDefinitionId,
    Expression<String>? displayNameOverride,
    Expression<bool>? required,
    Expression<bool>? selectedFromProtocol,
    Expression<bool>? selectedManually,
    Expression<bool>? defaultInSessions,
    Expression<int>? sortOrder,
    Expression<String>? timingMode,
    Expression<int>? daysAfterPlanting,
    Expression<int>? daysAfterTreatment,
    Expression<String>? growthStage,
    Expression<String>? methodOverride,
    Expression<String>? instructionOverride,
    Expression<bool>? isActive,
    Expression<int>? legacyAssessmentId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (assessmentDefinitionId != null)
        'assessment_definition_id': assessmentDefinitionId,
      if (displayNameOverride != null)
        'display_name_override': displayNameOverride,
      if (required != null) 'required': required,
      if (selectedFromProtocol != null)
        'selected_from_protocol': selectedFromProtocol,
      if (selectedManually != null) 'selected_manually': selectedManually,
      if (defaultInSessions != null) 'default_in_sessions': defaultInSessions,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (timingMode != null) 'timing_mode': timingMode,
      if (daysAfterPlanting != null) 'days_after_planting': daysAfterPlanting,
      if (daysAfterTreatment != null)
        'days_after_treatment': daysAfterTreatment,
      if (growthStage != null) 'growth_stage': growthStage,
      if (methodOverride != null) 'method_override': methodOverride,
      if (instructionOverride != null)
        'instruction_override': instructionOverride,
      if (isActive != null) 'is_active': isActive,
      if (legacyAssessmentId != null)
        'legacy_assessment_id': legacyAssessmentId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TrialAssessmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? assessmentDefinitionId,
      Value<String?>? displayNameOverride,
      Value<bool>? required,
      Value<bool>? selectedFromProtocol,
      Value<bool>? selectedManually,
      Value<bool>? defaultInSessions,
      Value<int>? sortOrder,
      Value<String?>? timingMode,
      Value<int?>? daysAfterPlanting,
      Value<int?>? daysAfterTreatment,
      Value<String?>? growthStage,
      Value<String?>? methodOverride,
      Value<String?>? instructionOverride,
      Value<bool>? isActive,
      Value<int?>? legacyAssessmentId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return TrialAssessmentsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      assessmentDefinitionId:
          assessmentDefinitionId ?? this.assessmentDefinitionId,
      displayNameOverride: displayNameOverride ?? this.displayNameOverride,
      required: required ?? this.required,
      selectedFromProtocol: selectedFromProtocol ?? this.selectedFromProtocol,
      selectedManually: selectedManually ?? this.selectedManually,
      defaultInSessions: defaultInSessions ?? this.defaultInSessions,
      sortOrder: sortOrder ?? this.sortOrder,
      timingMode: timingMode ?? this.timingMode,
      daysAfterPlanting: daysAfterPlanting ?? this.daysAfterPlanting,
      daysAfterTreatment: daysAfterTreatment ?? this.daysAfterTreatment,
      growthStage: growthStage ?? this.growthStage,
      methodOverride: methodOverride ?? this.methodOverride,
      instructionOverride: instructionOverride ?? this.instructionOverride,
      isActive: isActive ?? this.isActive,
      legacyAssessmentId: legacyAssessmentId ?? this.legacyAssessmentId,
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
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (assessmentDefinitionId.present) {
      map['assessment_definition_id'] =
          Variable<int>(assessmentDefinitionId.value);
    }
    if (displayNameOverride.present) {
      map['display_name_override'] =
          Variable<String>(displayNameOverride.value);
    }
    if (required.present) {
      map['required'] = Variable<bool>(required.value);
    }
    if (selectedFromProtocol.present) {
      map['selected_from_protocol'] =
          Variable<bool>(selectedFromProtocol.value);
    }
    if (selectedManually.present) {
      map['selected_manually'] = Variable<bool>(selectedManually.value);
    }
    if (defaultInSessions.present) {
      map['default_in_sessions'] = Variable<bool>(defaultInSessions.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (timingMode.present) {
      map['timing_mode'] = Variable<String>(timingMode.value);
    }
    if (daysAfterPlanting.present) {
      map['days_after_planting'] = Variable<int>(daysAfterPlanting.value);
    }
    if (daysAfterTreatment.present) {
      map['days_after_treatment'] = Variable<int>(daysAfterTreatment.value);
    }
    if (growthStage.present) {
      map['growth_stage'] = Variable<String>(growthStage.value);
    }
    if (methodOverride.present) {
      map['method_override'] = Variable<String>(methodOverride.value);
    }
    if (instructionOverride.present) {
      map['instruction_override'] = Variable<String>(instructionOverride.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (legacyAssessmentId.present) {
      map['legacy_assessment_id'] = Variable<int>(legacyAssessmentId.value);
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
    return (StringBuffer('TrialAssessmentsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('assessmentDefinitionId: $assessmentDefinitionId, ')
          ..write('displayNameOverride: $displayNameOverride, ')
          ..write('required: $required, ')
          ..write('selectedFromProtocol: $selectedFromProtocol, ')
          ..write('selectedManually: $selectedManually, ')
          ..write('defaultInSessions: $defaultInSessions, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('timingMode: $timingMode, ')
          ..write('daysAfterPlanting: $daysAfterPlanting, ')
          ..write('daysAfterTreatment: $daysAfterTreatment, ')
          ..write('growthStage: $growthStage, ')
          ..write('methodOverride: $methodOverride, ')
          ..write('instructionOverride: $instructionOverride, ')
          ..write('isActive: $isActive, ')
          ..write('legacyAssessmentId: $legacyAssessmentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
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
  static const VerificationMeta _fieldRowMeta =
      const VerificationMeta('fieldRow');
  @override
  late final GeneratedColumn<int> fieldRow = GeneratedColumn<int>(
      'field_row', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _fieldColumnMeta =
      const VerificationMeta('fieldColumn');
  @override
  late final GeneratedColumn<int> fieldColumn = GeneratedColumn<int>(
      'field_column', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assignmentSourceMeta =
      const VerificationMeta('assignmentSource');
  @override
  late final GeneratedColumn<String> assignmentSource = GeneratedColumn<String>(
      'assignment_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assignmentUpdatedAtMeta =
      const VerificationMeta('assignmentUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> assignmentUpdatedAt =
      GeneratedColumn<DateTime>('assignment_updated_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
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
        fieldRow,
        fieldColumn,
        notes,
        assignmentSource,
        assignmentUpdatedAt
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
    if (data.containsKey('field_row')) {
      context.handle(_fieldRowMeta,
          fieldRow.isAcceptableOrUnknown(data['field_row']!, _fieldRowMeta));
    }
    if (data.containsKey('field_column')) {
      context.handle(
          _fieldColumnMeta,
          fieldColumn.isAcceptableOrUnknown(
              data['field_column']!, _fieldColumnMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('assignment_source')) {
      context.handle(
          _assignmentSourceMeta,
          assignmentSource.isAcceptableOrUnknown(
              data['assignment_source']!, _assignmentSourceMeta));
    }
    if (data.containsKey('assignment_updated_at')) {
      context.handle(
          _assignmentUpdatedAtMeta,
          assignmentUpdatedAt.isAcceptableOrUnknown(
              data['assignment_updated_at']!, _assignmentUpdatedAtMeta));
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
      fieldRow: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}field_row']),
      fieldColumn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}field_column']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      assignmentSource: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}assignment_source']),
      assignmentUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}assignment_updated_at']),
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
  final int? fieldRow;
  final int? fieldColumn;
  final String? notes;

  /// Assignment provenance: 'imported' | 'manual' | null (unknown).
  final String? assignmentSource;
  final DateTime? assignmentUpdatedAt;
  const Plot(
      {required this.id,
      required this.trialId,
      required this.plotId,
      this.plotSortIndex,
      this.rep,
      this.treatmentId,
      this.row,
      this.column,
      this.fieldRow,
      this.fieldColumn,
      this.notes,
      this.assignmentSource,
      this.assignmentUpdatedAt});
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
    if (!nullToAbsent || fieldRow != null) {
      map['field_row'] = Variable<int>(fieldRow);
    }
    if (!nullToAbsent || fieldColumn != null) {
      map['field_column'] = Variable<int>(fieldColumn);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || assignmentSource != null) {
      map['assignment_source'] = Variable<String>(assignmentSource);
    }
    if (!nullToAbsent || assignmentUpdatedAt != null) {
      map['assignment_updated_at'] = Variable<DateTime>(assignmentUpdatedAt);
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
      fieldRow: fieldRow == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldRow),
      fieldColumn: fieldColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldColumn),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      assignmentSource: assignmentSource == null && nullToAbsent
          ? const Value.absent()
          : Value(assignmentSource),
      assignmentUpdatedAt: assignmentUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(assignmentUpdatedAt),
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
      fieldRow: serializer.fromJson<int?>(json['fieldRow']),
      fieldColumn: serializer.fromJson<int?>(json['fieldColumn']),
      notes: serializer.fromJson<String?>(json['notes']),
      assignmentSource: serializer.fromJson<String?>(json['assignmentSource']),
      assignmentUpdatedAt:
          serializer.fromJson<DateTime?>(json['assignmentUpdatedAt']),
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
      'fieldRow': serializer.toJson<int?>(fieldRow),
      'fieldColumn': serializer.toJson<int?>(fieldColumn),
      'notes': serializer.toJson<String?>(notes),
      'assignmentSource': serializer.toJson<String?>(assignmentSource),
      'assignmentUpdatedAt': serializer.toJson<DateTime?>(assignmentUpdatedAt),
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
          Value<int?> fieldRow = const Value.absent(),
          Value<int?> fieldColumn = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> assignmentSource = const Value.absent(),
          Value<DateTime?> assignmentUpdatedAt = const Value.absent()}) =>
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
        fieldRow: fieldRow.present ? fieldRow.value : this.fieldRow,
        fieldColumn: fieldColumn.present ? fieldColumn.value : this.fieldColumn,
        notes: notes.present ? notes.value : this.notes,
        assignmentSource: assignmentSource.present
            ? assignmentSource.value
            : this.assignmentSource,
        assignmentUpdatedAt: assignmentUpdatedAt.present
            ? assignmentUpdatedAt.value
            : this.assignmentUpdatedAt,
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
      fieldRow: data.fieldRow.present ? data.fieldRow.value : this.fieldRow,
      fieldColumn:
          data.fieldColumn.present ? data.fieldColumn.value : this.fieldColumn,
      notes: data.notes.present ? data.notes.value : this.notes,
      assignmentSource: data.assignmentSource.present
          ? data.assignmentSource.value
          : this.assignmentSource,
      assignmentUpdatedAt: data.assignmentUpdatedAt.present
          ? data.assignmentUpdatedAt.value
          : this.assignmentUpdatedAt,
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
          ..write('fieldRow: $fieldRow, ')
          ..write('fieldColumn: $fieldColumn, ')
          ..write('notes: $notes, ')
          ..write('assignmentSource: $assignmentSource, ')
          ..write('assignmentUpdatedAt: $assignmentUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trialId,
      plotId,
      plotSortIndex,
      rep,
      treatmentId,
      row,
      column,
      fieldRow,
      fieldColumn,
      notes,
      assignmentSource,
      assignmentUpdatedAt);
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
          other.fieldRow == this.fieldRow &&
          other.fieldColumn == this.fieldColumn &&
          other.notes == this.notes &&
          other.assignmentSource == this.assignmentSource &&
          other.assignmentUpdatedAt == this.assignmentUpdatedAt);
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
  final Value<int?> fieldRow;
  final Value<int?> fieldColumn;
  final Value<String?> notes;
  final Value<String?> assignmentSource;
  final Value<DateTime?> assignmentUpdatedAt;
  const PlotsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotId = const Value.absent(),
    this.plotSortIndex = const Value.absent(),
    this.rep = const Value.absent(),
    this.treatmentId = const Value.absent(),
    this.row = const Value.absent(),
    this.column = const Value.absent(),
    this.fieldRow = const Value.absent(),
    this.fieldColumn = const Value.absent(),
    this.notes = const Value.absent(),
    this.assignmentSource = const Value.absent(),
    this.assignmentUpdatedAt = const Value.absent(),
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
    this.fieldRow = const Value.absent(),
    this.fieldColumn = const Value.absent(),
    this.notes = const Value.absent(),
    this.assignmentSource = const Value.absent(),
    this.assignmentUpdatedAt = const Value.absent(),
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
    Expression<int>? fieldRow,
    Expression<int>? fieldColumn,
    Expression<String>? notes,
    Expression<String>? assignmentSource,
    Expression<DateTime>? assignmentUpdatedAt,
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
      if (fieldRow != null) 'field_row': fieldRow,
      if (fieldColumn != null) 'field_column': fieldColumn,
      if (notes != null) 'notes': notes,
      if (assignmentSource != null) 'assignment_source': assignmentSource,
      if (assignmentUpdatedAt != null)
        'assignment_updated_at': assignmentUpdatedAt,
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
      Value<int?>? fieldRow,
      Value<int?>? fieldColumn,
      Value<String?>? notes,
      Value<String?>? assignmentSource,
      Value<DateTime?>? assignmentUpdatedAt}) {
    return PlotsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotId: plotId ?? this.plotId,
      plotSortIndex: plotSortIndex ?? this.plotSortIndex,
      rep: rep ?? this.rep,
      treatmentId: treatmentId ?? this.treatmentId,
      row: row ?? this.row,
      column: column ?? this.column,
      fieldRow: fieldRow ?? this.fieldRow,
      fieldColumn: fieldColumn ?? this.fieldColumn,
      notes: notes ?? this.notes,
      assignmentSource: assignmentSource ?? this.assignmentSource,
      assignmentUpdatedAt: assignmentUpdatedAt ?? this.assignmentUpdatedAt,
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
    if (fieldRow.present) {
      map['field_row'] = Variable<int>(fieldRow.value);
    }
    if (fieldColumn.present) {
      map['field_column'] = Variable<int>(fieldColumn.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (assignmentSource.present) {
      map['assignment_source'] = Variable<String>(assignmentSource.value);
    }
    if (assignmentUpdatedAt.present) {
      map['assignment_updated_at'] =
          Variable<DateTime>(assignmentUpdatedAt.value);
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
          ..write('fieldRow: $fieldRow, ')
          ..write('fieldColumn: $fieldColumn, ')
          ..write('notes: $notes, ')
          ..write('assignmentSource: $assignmentSource, ')
          ..write('assignmentUpdatedAt: $assignmentUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $AssignmentsTable extends Assignments
    with TableInfo<$AssignmentsTable, Assignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssignmentsTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<int> plotId = GeneratedColumn<int>(
      'plot_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES plots (id)'));
  static const VerificationMeta _treatmentIdMeta =
      const VerificationMeta('treatmentId');
  @override
  late final GeneratedColumn<int> treatmentId = GeneratedColumn<int>(
      'treatment_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES treatments (id)'));
  static const VerificationMeta _replicationMeta =
      const VerificationMeta('replication');
  @override
  late final GeneratedColumn<int> replication = GeneratedColumn<int>(
      'replication', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _blockMeta = const VerificationMeta('block');
  @override
  late final GeneratedColumn<int> block = GeneratedColumn<int>(
      'block', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rangeMeta = const VerificationMeta('range');
  @override
  late final GeneratedColumn<int> range = GeneratedColumn<int>(
      'range', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _columnMeta = const VerificationMeta('column');
  @override
  late final GeneratedColumn<int> column = GeneratedColumn<int>(
      'column', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isCheckMeta =
      const VerificationMeta('isCheck');
  @override
  late final GeneratedColumn<bool> isCheck = GeneratedColumn<bool>(
      'is_check', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_check" IN (0, 1))'));
  static const VerificationMeta _isControlMeta =
      const VerificationMeta('isControl');
  @override
  late final GeneratedColumn<bool> isControl = GeneratedColumn<bool>(
      'is_control', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_control" IN (0, 1))'));
  static const VerificationMeta _assignmentSourceMeta =
      const VerificationMeta('assignmentSource');
  @override
  late final GeneratedColumn<String> assignmentSource = GeneratedColumn<String>(
      'assignment_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assignedAtMeta =
      const VerificationMeta('assignedAt');
  @override
  late final GeneratedColumn<DateTime> assignedAt = GeneratedColumn<DateTime>(
      'assigned_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _assignedByMeta =
      const VerificationMeta('assignedBy');
  @override
  late final GeneratedColumn<int> assignedBy = GeneratedColumn<int>(
      'assigned_by', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
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
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotId,
        treatmentId,
        replication,
        block,
        range,
        column,
        position,
        isCheck,
        isControl,
        assignmentSource,
        assignedAt,
        assignedBy,
        notes,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assignments';
  @override
  VerificationContext validateIntegrity(Insertable<Assignment> instance,
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
    if (data.containsKey('treatment_id')) {
      context.handle(
          _treatmentIdMeta,
          treatmentId.isAcceptableOrUnknown(
              data['treatment_id']!, _treatmentIdMeta));
    }
    if (data.containsKey('replication')) {
      context.handle(
          _replicationMeta,
          replication.isAcceptableOrUnknown(
              data['replication']!, _replicationMeta));
    }
    if (data.containsKey('block')) {
      context.handle(
          _blockMeta, block.isAcceptableOrUnknown(data['block']!, _blockMeta));
    }
    if (data.containsKey('range')) {
      context.handle(
          _rangeMeta, range.isAcceptableOrUnknown(data['range']!, _rangeMeta));
    }
    if (data.containsKey('column')) {
      context.handle(_columnMeta,
          column.isAcceptableOrUnknown(data['column']!, _columnMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('is_check')) {
      context.handle(_isCheckMeta,
          isCheck.isAcceptableOrUnknown(data['is_check']!, _isCheckMeta));
    }
    if (data.containsKey('is_control')) {
      context.handle(_isControlMeta,
          isControl.isAcceptableOrUnknown(data['is_control']!, _isControlMeta));
    }
    if (data.containsKey('assignment_source')) {
      context.handle(
          _assignmentSourceMeta,
          assignmentSource.isAcceptableOrUnknown(
              data['assignment_source']!, _assignmentSourceMeta));
    }
    if (data.containsKey('assigned_at')) {
      context.handle(
          _assignedAtMeta,
          assignedAt.isAcceptableOrUnknown(
              data['assigned_at']!, _assignedAtMeta));
    }
    if (data.containsKey('assigned_by')) {
      context.handle(
          _assignedByMeta,
          assignedBy.isAcceptableOrUnknown(
              data['assigned_by']!, _assignedByMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
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
  Assignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Assignment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trialId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trial_id'])!,
      plotId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_id'])!,
      treatmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}treatment_id']),
      replication: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}replication']),
      block: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}block']),
      range: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}range']),
      column: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}column']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position']),
      isCheck: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_check']),
      isControl: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_control']),
      assignmentSource: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}assignment_source']),
      assignedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}assigned_at']),
      assignedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}assigned_by']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AssignmentsTable createAlias(String alias) {
    return $AssignmentsTable(attachedDatabase, alias);
  }
}

class Assignment extends DataClass implements Insertable<Assignment> {
  final int id;
  final int trialId;
  final int plotId;
  final int? treatmentId;
  final int? replication;
  final int? block;
  final int? range;
  final int? column;
  final int? position;
  final bool? isCheck;
  final bool? isControl;
  final String? assignmentSource;
  final DateTime? assignedAt;
  final int? assignedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Assignment(
      {required this.id,
      required this.trialId,
      required this.plotId,
      this.treatmentId,
      this.replication,
      this.block,
      this.range,
      this.column,
      this.position,
      this.isCheck,
      this.isControl,
      this.assignmentSource,
      this.assignedAt,
      this.assignedBy,
      this.notes,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_id'] = Variable<int>(plotId);
    if (!nullToAbsent || treatmentId != null) {
      map['treatment_id'] = Variable<int>(treatmentId);
    }
    if (!nullToAbsent || replication != null) {
      map['replication'] = Variable<int>(replication);
    }
    if (!nullToAbsent || block != null) {
      map['block'] = Variable<int>(block);
    }
    if (!nullToAbsent || range != null) {
      map['range'] = Variable<int>(range);
    }
    if (!nullToAbsent || column != null) {
      map['column'] = Variable<int>(column);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    if (!nullToAbsent || isCheck != null) {
      map['is_check'] = Variable<bool>(isCheck);
    }
    if (!nullToAbsent || isControl != null) {
      map['is_control'] = Variable<bool>(isControl);
    }
    if (!nullToAbsent || assignmentSource != null) {
      map['assignment_source'] = Variable<String>(assignmentSource);
    }
    if (!nullToAbsent || assignedAt != null) {
      map['assigned_at'] = Variable<DateTime>(assignedAt);
    }
    if (!nullToAbsent || assignedBy != null) {
      map['assigned_by'] = Variable<int>(assignedBy);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AssignmentsCompanion toCompanion(bool nullToAbsent) {
    return AssignmentsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotId: Value(plotId),
      treatmentId: treatmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(treatmentId),
      replication: replication == null && nullToAbsent
          ? const Value.absent()
          : Value(replication),
      block:
          block == null && nullToAbsent ? const Value.absent() : Value(block),
      range:
          range == null && nullToAbsent ? const Value.absent() : Value(range),
      column:
          column == null && nullToAbsent ? const Value.absent() : Value(column),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      isCheck: isCheck == null && nullToAbsent
          ? const Value.absent()
          : Value(isCheck),
      isControl: isControl == null && nullToAbsent
          ? const Value.absent()
          : Value(isControl),
      assignmentSource: assignmentSource == null && nullToAbsent
          ? const Value.absent()
          : Value(assignmentSource),
      assignedAt: assignedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedAt),
      assignedBy: assignedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedBy),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Assignment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Assignment(
      id: serializer.fromJson<int>(json['id']),
      trialId: serializer.fromJson<int>(json['trialId']),
      plotId: serializer.fromJson<int>(json['plotId']),
      treatmentId: serializer.fromJson<int?>(json['treatmentId']),
      replication: serializer.fromJson<int?>(json['replication']),
      block: serializer.fromJson<int?>(json['block']),
      range: serializer.fromJson<int?>(json['range']),
      column: serializer.fromJson<int?>(json['column']),
      position: serializer.fromJson<int?>(json['position']),
      isCheck: serializer.fromJson<bool?>(json['isCheck']),
      isControl: serializer.fromJson<bool?>(json['isControl']),
      assignmentSource: serializer.fromJson<String?>(json['assignmentSource']),
      assignedAt: serializer.fromJson<DateTime?>(json['assignedAt']),
      assignedBy: serializer.fromJson<int?>(json['assignedBy']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trialId': serializer.toJson<int>(trialId),
      'plotId': serializer.toJson<int>(plotId),
      'treatmentId': serializer.toJson<int?>(treatmentId),
      'replication': serializer.toJson<int?>(replication),
      'block': serializer.toJson<int?>(block),
      'range': serializer.toJson<int?>(range),
      'column': serializer.toJson<int?>(column),
      'position': serializer.toJson<int?>(position),
      'isCheck': serializer.toJson<bool?>(isCheck),
      'isControl': serializer.toJson<bool?>(isControl),
      'assignmentSource': serializer.toJson<String?>(assignmentSource),
      'assignedAt': serializer.toJson<DateTime?>(assignedAt),
      'assignedBy': serializer.toJson<int?>(assignedBy),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Assignment copyWith(
          {int? id,
          int? trialId,
          int? plotId,
          Value<int?> treatmentId = const Value.absent(),
          Value<int?> replication = const Value.absent(),
          Value<int?> block = const Value.absent(),
          Value<int?> range = const Value.absent(),
          Value<int?> column = const Value.absent(),
          Value<int?> position = const Value.absent(),
          Value<bool?> isCheck = const Value.absent(),
          Value<bool?> isControl = const Value.absent(),
          Value<String?> assignmentSource = const Value.absent(),
          Value<DateTime?> assignedAt = const Value.absent(),
          Value<int?> assignedBy = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Assignment(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotId: plotId ?? this.plotId,
        treatmentId: treatmentId.present ? treatmentId.value : this.treatmentId,
        replication: replication.present ? replication.value : this.replication,
        block: block.present ? block.value : this.block,
        range: range.present ? range.value : this.range,
        column: column.present ? column.value : this.column,
        position: position.present ? position.value : this.position,
        isCheck: isCheck.present ? isCheck.value : this.isCheck,
        isControl: isControl.present ? isControl.value : this.isControl,
        assignmentSource: assignmentSource.present
            ? assignmentSource.value
            : this.assignmentSource,
        assignedAt: assignedAt.present ? assignedAt.value : this.assignedAt,
        assignedBy: assignedBy.present ? assignedBy.value : this.assignedBy,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Assignment copyWithCompanion(AssignmentsCompanion data) {
    return Assignment(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotId: data.plotId.present ? data.plotId.value : this.plotId,
      treatmentId:
          data.treatmentId.present ? data.treatmentId.value : this.treatmentId,
      replication:
          data.replication.present ? data.replication.value : this.replication,
      block: data.block.present ? data.block.value : this.block,
      range: data.range.present ? data.range.value : this.range,
      column: data.column.present ? data.column.value : this.column,
      position: data.position.present ? data.position.value : this.position,
      isCheck: data.isCheck.present ? data.isCheck.value : this.isCheck,
      isControl: data.isControl.present ? data.isControl.value : this.isControl,
      assignmentSource: data.assignmentSource.present
          ? data.assignmentSource.value
          : this.assignmentSource,
      assignedAt:
          data.assignedAt.present ? data.assignedAt.value : this.assignedAt,
      assignedBy:
          data.assignedBy.present ? data.assignedBy.value : this.assignedBy,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Assignment(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotId: $plotId, ')
          ..write('treatmentId: $treatmentId, ')
          ..write('replication: $replication, ')
          ..write('block: $block, ')
          ..write('range: $range, ')
          ..write('column: $column, ')
          ..write('position: $position, ')
          ..write('isCheck: $isCheck, ')
          ..write('isControl: $isControl, ')
          ..write('assignmentSource: $assignmentSource, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('assignedBy: $assignedBy, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trialId,
      plotId,
      treatmentId,
      replication,
      block,
      range,
      column,
      position,
      isCheck,
      isControl,
      assignmentSource,
      assignedAt,
      assignedBy,
      notes,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Assignment &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotId == this.plotId &&
          other.treatmentId == this.treatmentId &&
          other.replication == this.replication &&
          other.block == this.block &&
          other.range == this.range &&
          other.column == this.column &&
          other.position == this.position &&
          other.isCheck == this.isCheck &&
          other.isControl == this.isControl &&
          other.assignmentSource == this.assignmentSource &&
          other.assignedAt == this.assignedAt &&
          other.assignedBy == this.assignedBy &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AssignmentsCompanion extends UpdateCompanion<Assignment> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> plotId;
  final Value<int?> treatmentId;
  final Value<int?> replication;
  final Value<int?> block;
  final Value<int?> range;
  final Value<int?> column;
  final Value<int?> position;
  final Value<bool?> isCheck;
  final Value<bool?> isControl;
  final Value<String?> assignmentSource;
  final Value<DateTime?> assignedAt;
  final Value<int?> assignedBy;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AssignmentsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotId = const Value.absent(),
    this.treatmentId = const Value.absent(),
    this.replication = const Value.absent(),
    this.block = const Value.absent(),
    this.range = const Value.absent(),
    this.column = const Value.absent(),
    this.position = const Value.absent(),
    this.isCheck = const Value.absent(),
    this.isControl = const Value.absent(),
    this.assignmentSource = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.assignedBy = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AssignmentsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int plotId,
    this.treatmentId = const Value.absent(),
    this.replication = const Value.absent(),
    this.block = const Value.absent(),
    this.range = const Value.absent(),
    this.column = const Value.absent(),
    this.position = const Value.absent(),
    this.isCheck = const Value.absent(),
    this.isControl = const Value.absent(),
    this.assignmentSource = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.assignedBy = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : trialId = Value(trialId),
        plotId = Value(plotId);
  static Insertable<Assignment> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotId,
    Expression<int>? treatmentId,
    Expression<int>? replication,
    Expression<int>? block,
    Expression<int>? range,
    Expression<int>? column,
    Expression<int>? position,
    Expression<bool>? isCheck,
    Expression<bool>? isControl,
    Expression<String>? assignmentSource,
    Expression<DateTime>? assignedAt,
    Expression<int>? assignedBy,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotId != null) 'plot_id': plotId,
      if (treatmentId != null) 'treatment_id': treatmentId,
      if (replication != null) 'replication': replication,
      if (block != null) 'block': block,
      if (range != null) 'range': range,
      if (column != null) 'column': column,
      if (position != null) 'position': position,
      if (isCheck != null) 'is_check': isCheck,
      if (isControl != null) 'is_control': isControl,
      if (assignmentSource != null) 'assignment_source': assignmentSource,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (assignedBy != null) 'assigned_by': assignedBy,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AssignmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? plotId,
      Value<int?>? treatmentId,
      Value<int?>? replication,
      Value<int?>? block,
      Value<int?>? range,
      Value<int?>? column,
      Value<int?>? position,
      Value<bool?>? isCheck,
      Value<bool?>? isControl,
      Value<String?>? assignmentSource,
      Value<DateTime?>? assignedAt,
      Value<int?>? assignedBy,
      Value<String?>? notes,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return AssignmentsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotId: plotId ?? this.plotId,
      treatmentId: treatmentId ?? this.treatmentId,
      replication: replication ?? this.replication,
      block: block ?? this.block,
      range: range ?? this.range,
      column: column ?? this.column,
      position: position ?? this.position,
      isCheck: isCheck ?? this.isCheck,
      isControl: isControl ?? this.isControl,
      assignmentSource: assignmentSource ?? this.assignmentSource,
      assignedAt: assignedAt ?? this.assignedAt,
      assignedBy: assignedBy ?? this.assignedBy,
      notes: notes ?? this.notes,
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
    if (trialId.present) {
      map['trial_id'] = Variable<int>(trialId.value);
    }
    if (plotId.present) {
      map['plot_id'] = Variable<int>(plotId.value);
    }
    if (treatmentId.present) {
      map['treatment_id'] = Variable<int>(treatmentId.value);
    }
    if (replication.present) {
      map['replication'] = Variable<int>(replication.value);
    }
    if (block.present) {
      map['block'] = Variable<int>(block.value);
    }
    if (range.present) {
      map['range'] = Variable<int>(range.value);
    }
    if (column.present) {
      map['column'] = Variable<int>(column.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (isCheck.present) {
      map['is_check'] = Variable<bool>(isCheck.value);
    }
    if (isControl.present) {
      map['is_control'] = Variable<bool>(isControl.value);
    }
    if (assignmentSource.present) {
      map['assignment_source'] = Variable<String>(assignmentSource.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<DateTime>(assignedAt.value);
    }
    if (assignedBy.present) {
      map['assigned_by'] = Variable<int>(assignedBy.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('AssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotId: $plotId, ')
          ..write('treatmentId: $treatmentId, ')
          ..write('replication: $replication, ')
          ..write('block: $block, ')
          ..write('range: $range, ')
          ..write('column: $column, ')
          ..write('position: $position, ')
          ..write('isCheck: $isCheck, ')
          ..write('isControl: $isControl, ')
          ..write('assignmentSource: $assignmentSource, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('assignedBy: $assignedBy, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
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
  static const VerificationMeta _createdByUserIdMeta =
      const VerificationMeta('createdByUserId');
  @override
  late final GeneratedColumn<int> createdByUserId = GeneratedColumn<int>(
      'created_by_user_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
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
        createdByUserId,
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
    if (data.containsKey('created_by_user_id')) {
      context.handle(
          _createdByUserIdMeta,
          createdByUserId.isAcceptableOrUnknown(
              data['created_by_user_id']!, _createdByUserIdMeta));
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
      createdByUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_by_user_id']),
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
  final int? createdByUserId;
  final String status;
  const Session(
      {required this.id,
      required this.trialId,
      required this.name,
      required this.startedAt,
      this.endedAt,
      required this.sessionDateLocal,
      this.raterName,
      this.createdByUserId,
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
    if (!nullToAbsent || createdByUserId != null) {
      map['created_by_user_id'] = Variable<int>(createdByUserId);
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
      createdByUserId: createdByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByUserId),
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
      createdByUserId: serializer.fromJson<int?>(json['createdByUserId']),
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
      'createdByUserId': serializer.toJson<int?>(createdByUserId),
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
          Value<int?> createdByUserId = const Value.absent(),
          String? status}) =>
      Session(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        name: name ?? this.name,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        sessionDateLocal: sessionDateLocal ?? this.sessionDateLocal,
        raterName: raterName.present ? raterName.value : this.raterName,
        createdByUserId: createdByUserId.present
            ? createdByUserId.value
            : this.createdByUserId,
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
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
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
          ..write('createdByUserId: $createdByUserId, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, name, startedAt, endedAt,
      sessionDateLocal, raterName, createdByUserId, status);
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
          other.createdByUserId == this.createdByUserId &&
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
  final Value<int?> createdByUserId;
  final Value<String> status;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.sessionDateLocal = const Value.absent(),
    this.raterName = const Value.absent(),
    this.createdByUserId = const Value.absent(),
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
    this.createdByUserId = const Value.absent(),
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
    Expression<int>? createdByUserId,
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
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
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
      Value<int?>? createdByUserId,
      Value<String>? status}) {
    return SessionsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      sessionDateLocal: sessionDateLocal ?? this.sessionDateLocal,
      raterName: raterName ?? this.raterName,
      createdByUserId: createdByUserId ?? this.createdByUserId,
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
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<int>(createdByUserId.value);
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
          ..write('createdByUserId: $createdByUserId, ')
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
  static const VerificationMeta _trialAssessmentIdMeta =
      const VerificationMeta('trialAssessmentId');
  @override
  late final GeneratedColumn<int> trialAssessmentId = GeneratedColumn<int>(
      'trial_assessment_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trial_assessments (id)'));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, assessmentId, trialAssessmentId, sortOrder];
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
    if (data.containsKey('trial_assessment_id')) {
      context.handle(
          _trialAssessmentIdMeta,
          trialAssessmentId.isAcceptableOrUnknown(
              data['trial_assessment_id']!, _trialAssessmentIdMeta));
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
  SessionAssessment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionAssessment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      assessmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}assessment_id'])!,
      trialAssessmentId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}trial_assessment_id']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
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
  final int? trialAssessmentId;

  /// User-defined order for rating flow (0, 1, 2, …). Same sequence applies to every plot.
  final int sortOrder;
  const SessionAssessment(
      {required this.id,
      required this.sessionId,
      required this.assessmentId,
      this.trialAssessmentId,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['assessment_id'] = Variable<int>(assessmentId);
    if (!nullToAbsent || trialAssessmentId != null) {
      map['trial_assessment_id'] = Variable<int>(trialAssessmentId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SessionAssessmentsCompanion toCompanion(bool nullToAbsent) {
    return SessionAssessmentsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      assessmentId: Value(assessmentId),
      trialAssessmentId: trialAssessmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(trialAssessmentId),
      sortOrder: Value(sortOrder),
    );
  }

  factory SessionAssessment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionAssessment(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      assessmentId: serializer.fromJson<int>(json['assessmentId']),
      trialAssessmentId: serializer.fromJson<int?>(json['trialAssessmentId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'assessmentId': serializer.toJson<int>(assessmentId),
      'trialAssessmentId': serializer.toJson<int?>(trialAssessmentId),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SessionAssessment copyWith(
          {int? id,
          int? sessionId,
          int? assessmentId,
          Value<int?> trialAssessmentId = const Value.absent(),
          int? sortOrder}) =>
      SessionAssessment(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        assessmentId: assessmentId ?? this.assessmentId,
        trialAssessmentId: trialAssessmentId.present
            ? trialAssessmentId.value
            : this.trialAssessmentId,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  SessionAssessment copyWithCompanion(SessionAssessmentsCompanion data) {
    return SessionAssessment(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      assessmentId: data.assessmentId.present
          ? data.assessmentId.value
          : this.assessmentId,
      trialAssessmentId: data.trialAssessmentId.present
          ? data.trialAssessmentId.value
          : this.trialAssessmentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionAssessment(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('trialAssessmentId: $trialAssessmentId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, assessmentId, trialAssessmentId, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionAssessment &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.assessmentId == this.assessmentId &&
          other.trialAssessmentId == this.trialAssessmentId &&
          other.sortOrder == this.sortOrder);
}

class SessionAssessmentsCompanion extends UpdateCompanion<SessionAssessment> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> assessmentId;
  final Value<int?> trialAssessmentId;
  final Value<int> sortOrder;
  const SessionAssessmentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.assessmentId = const Value.absent(),
    this.trialAssessmentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  SessionAssessmentsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int assessmentId,
    this.trialAssessmentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
  })  : sessionId = Value(sessionId),
        assessmentId = Value(assessmentId);
  static Insertable<SessionAssessment> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? assessmentId,
    Expression<int>? trialAssessmentId,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (assessmentId != null) 'assessment_id': assessmentId,
      if (trialAssessmentId != null) 'trial_assessment_id': trialAssessmentId,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  SessionAssessmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sessionId,
      Value<int>? assessmentId,
      Value<int?>? trialAssessmentId,
      Value<int>? sortOrder}) {
    return SessionAssessmentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      assessmentId: assessmentId ?? this.assessmentId,
      trialAssessmentId: trialAssessmentId ?? this.trialAssessmentId,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (trialAssessmentId.present) {
      map['trial_assessment_id'] = Variable<int>(trialAssessmentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionAssessmentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('trialAssessmentId: $trialAssessmentId, ')
          ..write('sortOrder: $sortOrder')
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
  static const VerificationMeta _trialAssessmentIdMeta =
      const VerificationMeta('trialAssessmentId');
  @override
  late final GeneratedColumn<int> trialAssessmentId = GeneratedColumn<int>(
      'trial_assessment_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trial_assessments (id)'));
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
  static const VerificationMeta _createdAppVersionMeta =
      const VerificationMeta('createdAppVersion');
  @override
  late final GeneratedColumn<String> createdAppVersion =
      GeneratedColumn<String>('created_app_version', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdDeviceInfoMeta =
      const VerificationMeta('createdDeviceInfo');
  @override
  late final GeneratedColumn<String> createdDeviceInfo =
      GeneratedColumn<String>('created_device_info', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _capturedLatitudeMeta =
      const VerificationMeta('capturedLatitude');
  @override
  late final GeneratedColumn<double> capturedLatitude = GeneratedColumn<double>(
      'captured_latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _capturedLongitudeMeta =
      const VerificationMeta('capturedLongitude');
  @override
  late final GeneratedColumn<double> capturedLongitude =
      GeneratedColumn<double>('captured_longitude', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trialId,
        plotPk,
        assessmentId,
        trialAssessmentId,
        sessionId,
        subUnitId,
        resultStatus,
        numericValue,
        textValue,
        isCurrent,
        previousId,
        createdAt,
        raterName,
        createdAppVersion,
        createdDeviceInfo,
        capturedLatitude,
        capturedLongitude
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
    if (data.containsKey('trial_assessment_id')) {
      context.handle(
          _trialAssessmentIdMeta,
          trialAssessmentId.isAcceptableOrUnknown(
              data['trial_assessment_id']!, _trialAssessmentIdMeta));
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
    if (data.containsKey('created_app_version')) {
      context.handle(
          _createdAppVersionMeta,
          createdAppVersion.isAcceptableOrUnknown(
              data['created_app_version']!, _createdAppVersionMeta));
    }
    if (data.containsKey('created_device_info')) {
      context.handle(
          _createdDeviceInfoMeta,
          createdDeviceInfo.isAcceptableOrUnknown(
              data['created_device_info']!, _createdDeviceInfoMeta));
    }
    if (data.containsKey('captured_latitude')) {
      context.handle(
          _capturedLatitudeMeta,
          capturedLatitude.isAcceptableOrUnknown(
              data['captured_latitude']!, _capturedLatitudeMeta));
    }
    if (data.containsKey('captured_longitude')) {
      context.handle(
          _capturedLongitudeMeta,
          capturedLongitude.isAcceptableOrUnknown(
              data['captured_longitude']!, _capturedLongitudeMeta));
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
      trialAssessmentId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}trial_assessment_id']),
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
      createdAppVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_app_version']),
      createdDeviceInfo: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_device_info']),
      capturedLatitude: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}captured_latitude']),
      capturedLongitude: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}captured_longitude']),
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
  final int? trialAssessmentId;
  final int sessionId;
  final int? subUnitId;
  final String resultStatus;
  final double? numericValue;
  final String? textValue;
  final bool isCurrent;
  final int? previousId;
  final DateTime createdAt;
  final String? raterName;
  final String? createdAppVersion;
  final String? createdDeviceInfo;
  final double? capturedLatitude;
  final double? capturedLongitude;
  const RatingRecord(
      {required this.id,
      required this.trialId,
      required this.plotPk,
      required this.assessmentId,
      this.trialAssessmentId,
      required this.sessionId,
      this.subUnitId,
      required this.resultStatus,
      this.numericValue,
      this.textValue,
      required this.isCurrent,
      this.previousId,
      required this.createdAt,
      this.raterName,
      this.createdAppVersion,
      this.createdDeviceInfo,
      this.capturedLatitude,
      this.capturedLongitude});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trial_id'] = Variable<int>(trialId);
    map['plot_pk'] = Variable<int>(plotPk);
    map['assessment_id'] = Variable<int>(assessmentId);
    if (!nullToAbsent || trialAssessmentId != null) {
      map['trial_assessment_id'] = Variable<int>(trialAssessmentId);
    }
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
    if (!nullToAbsent || createdAppVersion != null) {
      map['created_app_version'] = Variable<String>(createdAppVersion);
    }
    if (!nullToAbsent || createdDeviceInfo != null) {
      map['created_device_info'] = Variable<String>(createdDeviceInfo);
    }
    if (!nullToAbsent || capturedLatitude != null) {
      map['captured_latitude'] = Variable<double>(capturedLatitude);
    }
    if (!nullToAbsent || capturedLongitude != null) {
      map['captured_longitude'] = Variable<double>(capturedLongitude);
    }
    return map;
  }

  RatingRecordsCompanion toCompanion(bool nullToAbsent) {
    return RatingRecordsCompanion(
      id: Value(id),
      trialId: Value(trialId),
      plotPk: Value(plotPk),
      assessmentId: Value(assessmentId),
      trialAssessmentId: trialAssessmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(trialAssessmentId),
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
      createdAppVersion: createdAppVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAppVersion),
      createdDeviceInfo: createdDeviceInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(createdDeviceInfo),
      capturedLatitude: capturedLatitude == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedLatitude),
      capturedLongitude: capturedLongitude == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedLongitude),
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
      trialAssessmentId: serializer.fromJson<int?>(json['trialAssessmentId']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      subUnitId: serializer.fromJson<int?>(json['subUnitId']),
      resultStatus: serializer.fromJson<String>(json['resultStatus']),
      numericValue: serializer.fromJson<double?>(json['numericValue']),
      textValue: serializer.fromJson<String?>(json['textValue']),
      isCurrent: serializer.fromJson<bool>(json['isCurrent']),
      previousId: serializer.fromJson<int?>(json['previousId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      raterName: serializer.fromJson<String?>(json['raterName']),
      createdAppVersion:
          serializer.fromJson<String?>(json['createdAppVersion']),
      createdDeviceInfo:
          serializer.fromJson<String?>(json['createdDeviceInfo']),
      capturedLatitude: serializer.fromJson<double?>(json['capturedLatitude']),
      capturedLongitude:
          serializer.fromJson<double?>(json['capturedLongitude']),
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
      'trialAssessmentId': serializer.toJson<int?>(trialAssessmentId),
      'sessionId': serializer.toJson<int>(sessionId),
      'subUnitId': serializer.toJson<int?>(subUnitId),
      'resultStatus': serializer.toJson<String>(resultStatus),
      'numericValue': serializer.toJson<double?>(numericValue),
      'textValue': serializer.toJson<String?>(textValue),
      'isCurrent': serializer.toJson<bool>(isCurrent),
      'previousId': serializer.toJson<int?>(previousId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'raterName': serializer.toJson<String?>(raterName),
      'createdAppVersion': serializer.toJson<String?>(createdAppVersion),
      'createdDeviceInfo': serializer.toJson<String?>(createdDeviceInfo),
      'capturedLatitude': serializer.toJson<double?>(capturedLatitude),
      'capturedLongitude': serializer.toJson<double?>(capturedLongitude),
    };
  }

  RatingRecord copyWith(
          {int? id,
          int? trialId,
          int? plotPk,
          int? assessmentId,
          Value<int?> trialAssessmentId = const Value.absent(),
          int? sessionId,
          Value<int?> subUnitId = const Value.absent(),
          String? resultStatus,
          Value<double?> numericValue = const Value.absent(),
          Value<String?> textValue = const Value.absent(),
          bool? isCurrent,
          Value<int?> previousId = const Value.absent(),
          DateTime? createdAt,
          Value<String?> raterName = const Value.absent(),
          Value<String?> createdAppVersion = const Value.absent(),
          Value<String?> createdDeviceInfo = const Value.absent(),
          Value<double?> capturedLatitude = const Value.absent(),
          Value<double?> capturedLongitude = const Value.absent()}) =>
      RatingRecord(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        plotPk: plotPk ?? this.plotPk,
        assessmentId: assessmentId ?? this.assessmentId,
        trialAssessmentId: trialAssessmentId.present
            ? trialAssessmentId.value
            : this.trialAssessmentId,
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
        createdAppVersion: createdAppVersion.present
            ? createdAppVersion.value
            : this.createdAppVersion,
        createdDeviceInfo: createdDeviceInfo.present
            ? createdDeviceInfo.value
            : this.createdDeviceInfo,
        capturedLatitude: capturedLatitude.present
            ? capturedLatitude.value
            : this.capturedLatitude,
        capturedLongitude: capturedLongitude.present
            ? capturedLongitude.value
            : this.capturedLongitude,
      );
  RatingRecord copyWithCompanion(RatingRecordsCompanion data) {
    return RatingRecord(
      id: data.id.present ? data.id.value : this.id,
      trialId: data.trialId.present ? data.trialId.value : this.trialId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
      assessmentId: data.assessmentId.present
          ? data.assessmentId.value
          : this.assessmentId,
      trialAssessmentId: data.trialAssessmentId.present
          ? data.trialAssessmentId.value
          : this.trialAssessmentId,
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
      createdAppVersion: data.createdAppVersion.present
          ? data.createdAppVersion.value
          : this.createdAppVersion,
      createdDeviceInfo: data.createdDeviceInfo.present
          ? data.createdDeviceInfo.value
          : this.createdDeviceInfo,
      capturedLatitude: data.capturedLatitude.present
          ? data.capturedLatitude.value
          : this.capturedLatitude,
      capturedLongitude: data.capturedLongitude.present
          ? data.capturedLongitude.value
          : this.capturedLongitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingRecord(')
          ..write('id: $id, ')
          ..write('trialId: $trialId, ')
          ..write('plotPk: $plotPk, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('trialAssessmentId: $trialAssessmentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('subUnitId: $subUnitId, ')
          ..write('resultStatus: $resultStatus, ')
          ..write('numericValue: $numericValue, ')
          ..write('textValue: $textValue, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('previousId: $previousId, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName, ')
          ..write('createdAppVersion: $createdAppVersion, ')
          ..write('createdDeviceInfo: $createdDeviceInfo, ')
          ..write('capturedLatitude: $capturedLatitude, ')
          ..write('capturedLongitude: $capturedLongitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trialId,
      plotPk,
      assessmentId,
      trialAssessmentId,
      sessionId,
      subUnitId,
      resultStatus,
      numericValue,
      textValue,
      isCurrent,
      previousId,
      createdAt,
      raterName,
      createdAppVersion,
      createdDeviceInfo,
      capturedLatitude,
      capturedLongitude);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingRecord &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.plotPk == this.plotPk &&
          other.assessmentId == this.assessmentId &&
          other.trialAssessmentId == this.trialAssessmentId &&
          other.sessionId == this.sessionId &&
          other.subUnitId == this.subUnitId &&
          other.resultStatus == this.resultStatus &&
          other.numericValue == this.numericValue &&
          other.textValue == this.textValue &&
          other.isCurrent == this.isCurrent &&
          other.previousId == this.previousId &&
          other.createdAt == this.createdAt &&
          other.raterName == this.raterName &&
          other.createdAppVersion == this.createdAppVersion &&
          other.createdDeviceInfo == this.createdDeviceInfo &&
          other.capturedLatitude == this.capturedLatitude &&
          other.capturedLongitude == this.capturedLongitude);
}

class RatingRecordsCompanion extends UpdateCompanion<RatingRecord> {
  final Value<int> id;
  final Value<int> trialId;
  final Value<int> plotPk;
  final Value<int> assessmentId;
  final Value<int?> trialAssessmentId;
  final Value<int> sessionId;
  final Value<int?> subUnitId;
  final Value<String> resultStatus;
  final Value<double?> numericValue;
  final Value<String?> textValue;
  final Value<bool> isCurrent;
  final Value<int?> previousId;
  final Value<DateTime> createdAt;
  final Value<String?> raterName;
  final Value<String?> createdAppVersion;
  final Value<String?> createdDeviceInfo;
  final Value<double?> capturedLatitude;
  final Value<double?> capturedLongitude;
  const RatingRecordsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.plotPk = const Value.absent(),
    this.assessmentId = const Value.absent(),
    this.trialAssessmentId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.subUnitId = const Value.absent(),
    this.resultStatus = const Value.absent(),
    this.numericValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.previousId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
    this.createdAppVersion = const Value.absent(),
    this.createdDeviceInfo = const Value.absent(),
    this.capturedLatitude = const Value.absent(),
    this.capturedLongitude = const Value.absent(),
  });
  RatingRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int trialId,
    required int plotPk,
    required int assessmentId,
    this.trialAssessmentId = const Value.absent(),
    required int sessionId,
    this.subUnitId = const Value.absent(),
    this.resultStatus = const Value.absent(),
    this.numericValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.previousId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.raterName = const Value.absent(),
    this.createdAppVersion = const Value.absent(),
    this.createdDeviceInfo = const Value.absent(),
    this.capturedLatitude = const Value.absent(),
    this.capturedLongitude = const Value.absent(),
  })  : trialId = Value(trialId),
        plotPk = Value(plotPk),
        assessmentId = Value(assessmentId),
        sessionId = Value(sessionId);
  static Insertable<RatingRecord> custom({
    Expression<int>? id,
    Expression<int>? trialId,
    Expression<int>? plotPk,
    Expression<int>? assessmentId,
    Expression<int>? trialAssessmentId,
    Expression<int>? sessionId,
    Expression<int>? subUnitId,
    Expression<String>? resultStatus,
    Expression<double>? numericValue,
    Expression<String>? textValue,
    Expression<bool>? isCurrent,
    Expression<int>? previousId,
    Expression<DateTime>? createdAt,
    Expression<String>? raterName,
    Expression<String>? createdAppVersion,
    Expression<String>? createdDeviceInfo,
    Expression<double>? capturedLatitude,
    Expression<double>? capturedLongitude,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trialId != null) 'trial_id': trialId,
      if (plotPk != null) 'plot_pk': plotPk,
      if (assessmentId != null) 'assessment_id': assessmentId,
      if (trialAssessmentId != null) 'trial_assessment_id': trialAssessmentId,
      if (sessionId != null) 'session_id': sessionId,
      if (subUnitId != null) 'sub_unit_id': subUnitId,
      if (resultStatus != null) 'result_status': resultStatus,
      if (numericValue != null) 'numeric_value': numericValue,
      if (textValue != null) 'text_value': textValue,
      if (isCurrent != null) 'is_current': isCurrent,
      if (previousId != null) 'previous_id': previousId,
      if (createdAt != null) 'created_at': createdAt,
      if (raterName != null) 'rater_name': raterName,
      if (createdAppVersion != null) 'created_app_version': createdAppVersion,
      if (createdDeviceInfo != null) 'created_device_info': createdDeviceInfo,
      if (capturedLatitude != null) 'captured_latitude': capturedLatitude,
      if (capturedLongitude != null) 'captured_longitude': capturedLongitude,
    });
  }

  RatingRecordsCompanion copyWith(
      {Value<int>? id,
      Value<int>? trialId,
      Value<int>? plotPk,
      Value<int>? assessmentId,
      Value<int?>? trialAssessmentId,
      Value<int>? sessionId,
      Value<int?>? subUnitId,
      Value<String>? resultStatus,
      Value<double?>? numericValue,
      Value<String?>? textValue,
      Value<bool>? isCurrent,
      Value<int?>? previousId,
      Value<DateTime>? createdAt,
      Value<String?>? raterName,
      Value<String?>? createdAppVersion,
      Value<String?>? createdDeviceInfo,
      Value<double?>? capturedLatitude,
      Value<double?>? capturedLongitude}) {
    return RatingRecordsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      plotPk: plotPk ?? this.plotPk,
      assessmentId: assessmentId ?? this.assessmentId,
      trialAssessmentId: trialAssessmentId ?? this.trialAssessmentId,
      sessionId: sessionId ?? this.sessionId,
      subUnitId: subUnitId ?? this.subUnitId,
      resultStatus: resultStatus ?? this.resultStatus,
      numericValue: numericValue ?? this.numericValue,
      textValue: textValue ?? this.textValue,
      isCurrent: isCurrent ?? this.isCurrent,
      previousId: previousId ?? this.previousId,
      createdAt: createdAt ?? this.createdAt,
      raterName: raterName ?? this.raterName,
      createdAppVersion: createdAppVersion ?? this.createdAppVersion,
      createdDeviceInfo: createdDeviceInfo ?? this.createdDeviceInfo,
      capturedLatitude: capturedLatitude ?? this.capturedLatitude,
      capturedLongitude: capturedLongitude ?? this.capturedLongitude,
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
    if (trialAssessmentId.present) {
      map['trial_assessment_id'] = Variable<int>(trialAssessmentId.value);
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
    if (createdAppVersion.present) {
      map['created_app_version'] = Variable<String>(createdAppVersion.value);
    }
    if (createdDeviceInfo.present) {
      map['created_device_info'] = Variable<String>(createdDeviceInfo.value);
    }
    if (capturedLatitude.present) {
      map['captured_latitude'] = Variable<double>(capturedLatitude.value);
    }
    if (capturedLongitude.present) {
      map['captured_longitude'] = Variable<double>(capturedLongitude.value);
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
          ..write('trialAssessmentId: $trialAssessmentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('subUnitId: $subUnitId, ')
          ..write('resultStatus: $resultStatus, ')
          ..write('numericValue: $numericValue, ')
          ..write('textValue: $textValue, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('previousId: $previousId, ')
          ..write('createdAt: $createdAt, ')
          ..write('raterName: $raterName, ')
          ..write('createdAppVersion: $createdAppVersion, ')
          ..write('createdDeviceInfo: $createdDeviceInfo, ')
          ..write('capturedLatitude: $capturedLatitude, ')
          ..write('capturedLongitude: $capturedLongitude')
          ..write(')'))
        .toString();
  }
}

class $RatingCorrectionsTable extends RatingCorrections
    with TableInfo<$RatingCorrectionsTable, RatingCorrection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatingCorrectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ratingIdMeta =
      const VerificationMeta('ratingId');
  @override
  late final GeneratedColumn<int> ratingId = GeneratedColumn<int>(
      'rating_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES rating_records (id)'));
  static const VerificationMeta _oldNumericValueMeta =
      const VerificationMeta('oldNumericValue');
  @override
  late final GeneratedColumn<double> oldNumericValue = GeneratedColumn<double>(
      'old_numeric_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _newNumericValueMeta =
      const VerificationMeta('newNumericValue');
  @override
  late final GeneratedColumn<double> newNumericValue = GeneratedColumn<double>(
      'new_numeric_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _oldTextValueMeta =
      const VerificationMeta('oldTextValue');
  @override
  late final GeneratedColumn<String> oldTextValue = GeneratedColumn<String>(
      'old_text_value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _newTextValueMeta =
      const VerificationMeta('newTextValue');
  @override
  late final GeneratedColumn<String> newTextValue = GeneratedColumn<String>(
      'new_text_value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _oldResultStatusMeta =
      const VerificationMeta('oldResultStatus');
  @override
  late final GeneratedColumn<String> oldResultStatus = GeneratedColumn<String>(
      'old_result_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _newResultStatusMeta =
      const VerificationMeta('newResultStatus');
  @override
  late final GeneratedColumn<String> newResultStatus = GeneratedColumn<String>(
      'new_result_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _correctedByUserIdMeta =
      const VerificationMeta('correctedByUserId');
  @override
  late final GeneratedColumn<int> correctedByUserId = GeneratedColumn<int>(
      'corrected_by_user_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
  static const VerificationMeta _correctedAtMeta =
      const VerificationMeta('correctedAt');
  @override
  late final GeneratedColumn<DateTime> correctedAt = GeneratedColumn<DateTime>(
      'corrected_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
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
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ratingId,
        oldNumericValue,
        newNumericValue,
        oldTextValue,
        newTextValue,
        oldResultStatus,
        newResultStatus,
        reason,
        correctedByUserId,
        correctedAt,
        sessionId,
        plotPk
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rating_corrections';
  @override
  VerificationContext validateIntegrity(Insertable<RatingCorrection> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rating_id')) {
      context.handle(_ratingIdMeta,
          ratingId.isAcceptableOrUnknown(data['rating_id']!, _ratingIdMeta));
    } else if (isInserting) {
      context.missing(_ratingIdMeta);
    }
    if (data.containsKey('old_numeric_value')) {
      context.handle(
          _oldNumericValueMeta,
          oldNumericValue.isAcceptableOrUnknown(
              data['old_numeric_value']!, _oldNumericValueMeta));
    }
    if (data.containsKey('new_numeric_value')) {
      context.handle(
          _newNumericValueMeta,
          newNumericValue.isAcceptableOrUnknown(
              data['new_numeric_value']!, _newNumericValueMeta));
    }
    if (data.containsKey('old_text_value')) {
      context.handle(
          _oldTextValueMeta,
          oldTextValue.isAcceptableOrUnknown(
              data['old_text_value']!, _oldTextValueMeta));
    }
    if (data.containsKey('new_text_value')) {
      context.handle(
          _newTextValueMeta,
          newTextValue.isAcceptableOrUnknown(
              data['new_text_value']!, _newTextValueMeta));
    }
    if (data.containsKey('old_result_status')) {
      context.handle(
          _oldResultStatusMeta,
          oldResultStatus.isAcceptableOrUnknown(
              data['old_result_status']!, _oldResultStatusMeta));
    } else if (isInserting) {
      context.missing(_oldResultStatusMeta);
    }
    if (data.containsKey('new_result_status')) {
      context.handle(
          _newResultStatusMeta,
          newResultStatus.isAcceptableOrUnknown(
              data['new_result_status']!, _newResultStatusMeta));
    } else if (isInserting) {
      context.missing(_newResultStatusMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('corrected_by_user_id')) {
      context.handle(
          _correctedByUserIdMeta,
          correctedByUserId.isAcceptableOrUnknown(
              data['corrected_by_user_id']!, _correctedByUserIdMeta));
    }
    if (data.containsKey('corrected_at')) {
      context.handle(
          _correctedAtMeta,
          correctedAt.isAcceptableOrUnknown(
              data['corrected_at']!, _correctedAtMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('plot_pk')) {
      context.handle(_plotPkMeta,
          plotPk.isAcceptableOrUnknown(data['plot_pk']!, _plotPkMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RatingCorrection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatingCorrection(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ratingId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating_id'])!,
      oldNumericValue: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}old_numeric_value']),
      newNumericValue: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}new_numeric_value']),
      oldTextValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}old_text_value']),
      newTextValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}new_text_value']),
      oldResultStatus: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}old_result_status'])!,
      newResultStatus: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}new_result_status'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      correctedByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}corrected_by_user_id']),
      correctedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}corrected_at'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id']),
      plotPk: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plot_pk']),
    );
  }

  @override
  $RatingCorrectionsTable createAlias(String alias) {
    return $RatingCorrectionsTable(attachedDatabase, alias);
  }
}

class RatingCorrection extends DataClass
    implements Insertable<RatingCorrection> {
  final int id;
  final int ratingId;
  final double? oldNumericValue;
  final double? newNumericValue;
  final String? oldTextValue;
  final String? newTextValue;
  final String oldResultStatus;
  final String newResultStatus;
  final String reason;
  final int? correctedByUserId;
  final DateTime correctedAt;
  final int? sessionId;
  final int? plotPk;
  const RatingCorrection(
      {required this.id,
      required this.ratingId,
      this.oldNumericValue,
      this.newNumericValue,
      this.oldTextValue,
      this.newTextValue,
      required this.oldResultStatus,
      required this.newResultStatus,
      required this.reason,
      this.correctedByUserId,
      required this.correctedAt,
      this.sessionId,
      this.plotPk});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['rating_id'] = Variable<int>(ratingId);
    if (!nullToAbsent || oldNumericValue != null) {
      map['old_numeric_value'] = Variable<double>(oldNumericValue);
    }
    if (!nullToAbsent || newNumericValue != null) {
      map['new_numeric_value'] = Variable<double>(newNumericValue);
    }
    if (!nullToAbsent || oldTextValue != null) {
      map['old_text_value'] = Variable<String>(oldTextValue);
    }
    if (!nullToAbsent || newTextValue != null) {
      map['new_text_value'] = Variable<String>(newTextValue);
    }
    map['old_result_status'] = Variable<String>(oldResultStatus);
    map['new_result_status'] = Variable<String>(newResultStatus);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || correctedByUserId != null) {
      map['corrected_by_user_id'] = Variable<int>(correctedByUserId);
    }
    map['corrected_at'] = Variable<DateTime>(correctedAt);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    if (!nullToAbsent || plotPk != null) {
      map['plot_pk'] = Variable<int>(plotPk);
    }
    return map;
  }

  RatingCorrectionsCompanion toCompanion(bool nullToAbsent) {
    return RatingCorrectionsCompanion(
      id: Value(id),
      ratingId: Value(ratingId),
      oldNumericValue: oldNumericValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldNumericValue),
      newNumericValue: newNumericValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newNumericValue),
      oldTextValue: oldTextValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldTextValue),
      newTextValue: newTextValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newTextValue),
      oldResultStatus: Value(oldResultStatus),
      newResultStatus: Value(newResultStatus),
      reason: Value(reason),
      correctedByUserId: correctedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(correctedByUserId),
      correctedAt: Value(correctedAt),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      plotPk:
          plotPk == null && nullToAbsent ? const Value.absent() : Value(plotPk),
    );
  }

  factory RatingCorrection.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatingCorrection(
      id: serializer.fromJson<int>(json['id']),
      ratingId: serializer.fromJson<int>(json['ratingId']),
      oldNumericValue: serializer.fromJson<double?>(json['oldNumericValue']),
      newNumericValue: serializer.fromJson<double?>(json['newNumericValue']),
      oldTextValue: serializer.fromJson<String?>(json['oldTextValue']),
      newTextValue: serializer.fromJson<String?>(json['newTextValue']),
      oldResultStatus: serializer.fromJson<String>(json['oldResultStatus']),
      newResultStatus: serializer.fromJson<String>(json['newResultStatus']),
      reason: serializer.fromJson<String>(json['reason']),
      correctedByUserId: serializer.fromJson<int?>(json['correctedByUserId']),
      correctedAt: serializer.fromJson<DateTime>(json['correctedAt']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      plotPk: serializer.fromJson<int?>(json['plotPk']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ratingId': serializer.toJson<int>(ratingId),
      'oldNumericValue': serializer.toJson<double?>(oldNumericValue),
      'newNumericValue': serializer.toJson<double?>(newNumericValue),
      'oldTextValue': serializer.toJson<String?>(oldTextValue),
      'newTextValue': serializer.toJson<String?>(newTextValue),
      'oldResultStatus': serializer.toJson<String>(oldResultStatus),
      'newResultStatus': serializer.toJson<String>(newResultStatus),
      'reason': serializer.toJson<String>(reason),
      'correctedByUserId': serializer.toJson<int?>(correctedByUserId),
      'correctedAt': serializer.toJson<DateTime>(correctedAt),
      'sessionId': serializer.toJson<int?>(sessionId),
      'plotPk': serializer.toJson<int?>(plotPk),
    };
  }

  RatingCorrection copyWith(
          {int? id,
          int? ratingId,
          Value<double?> oldNumericValue = const Value.absent(),
          Value<double?> newNumericValue = const Value.absent(),
          Value<String?> oldTextValue = const Value.absent(),
          Value<String?> newTextValue = const Value.absent(),
          String? oldResultStatus,
          String? newResultStatus,
          String? reason,
          Value<int?> correctedByUserId = const Value.absent(),
          DateTime? correctedAt,
          Value<int?> sessionId = const Value.absent(),
          Value<int?> plotPk = const Value.absent()}) =>
      RatingCorrection(
        id: id ?? this.id,
        ratingId: ratingId ?? this.ratingId,
        oldNumericValue: oldNumericValue.present
            ? oldNumericValue.value
            : this.oldNumericValue,
        newNumericValue: newNumericValue.present
            ? newNumericValue.value
            : this.newNumericValue,
        oldTextValue:
            oldTextValue.present ? oldTextValue.value : this.oldTextValue,
        newTextValue:
            newTextValue.present ? newTextValue.value : this.newTextValue,
        oldResultStatus: oldResultStatus ?? this.oldResultStatus,
        newResultStatus: newResultStatus ?? this.newResultStatus,
        reason: reason ?? this.reason,
        correctedByUserId: correctedByUserId.present
            ? correctedByUserId.value
            : this.correctedByUserId,
        correctedAt: correctedAt ?? this.correctedAt,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        plotPk: plotPk.present ? plotPk.value : this.plotPk,
      );
  RatingCorrection copyWithCompanion(RatingCorrectionsCompanion data) {
    return RatingCorrection(
      id: data.id.present ? data.id.value : this.id,
      ratingId: data.ratingId.present ? data.ratingId.value : this.ratingId,
      oldNumericValue: data.oldNumericValue.present
          ? data.oldNumericValue.value
          : this.oldNumericValue,
      newNumericValue: data.newNumericValue.present
          ? data.newNumericValue.value
          : this.newNumericValue,
      oldTextValue: data.oldTextValue.present
          ? data.oldTextValue.value
          : this.oldTextValue,
      newTextValue: data.newTextValue.present
          ? data.newTextValue.value
          : this.newTextValue,
      oldResultStatus: data.oldResultStatus.present
          ? data.oldResultStatus.value
          : this.oldResultStatus,
      newResultStatus: data.newResultStatus.present
          ? data.newResultStatus.value
          : this.newResultStatus,
      reason: data.reason.present ? data.reason.value : this.reason,
      correctedByUserId: data.correctedByUserId.present
          ? data.correctedByUserId.value
          : this.correctedByUserId,
      correctedAt:
          data.correctedAt.present ? data.correctedAt.value : this.correctedAt,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      plotPk: data.plotPk.present ? data.plotPk.value : this.plotPk,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingCorrection(')
          ..write('id: $id, ')
          ..write('ratingId: $ratingId, ')
          ..write('oldNumericValue: $oldNumericValue, ')
          ..write('newNumericValue: $newNumericValue, ')
          ..write('oldTextValue: $oldTextValue, ')
          ..write('newTextValue: $newTextValue, ')
          ..write('oldResultStatus: $oldResultStatus, ')
          ..write('newResultStatus: $newResultStatus, ')
          ..write('reason: $reason, ')
          ..write('correctedByUserId: $correctedByUserId, ')
          ..write('correctedAt: $correctedAt, ')
          ..write('sessionId: $sessionId, ')
          ..write('plotPk: $plotPk')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ratingId,
      oldNumericValue,
      newNumericValue,
      oldTextValue,
      newTextValue,
      oldResultStatus,
      newResultStatus,
      reason,
      correctedByUserId,
      correctedAt,
      sessionId,
      plotPk);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingCorrection &&
          other.id == this.id &&
          other.ratingId == this.ratingId &&
          other.oldNumericValue == this.oldNumericValue &&
          other.newNumericValue == this.newNumericValue &&
          other.oldTextValue == this.oldTextValue &&
          other.newTextValue == this.newTextValue &&
          other.oldResultStatus == this.oldResultStatus &&
          other.newResultStatus == this.newResultStatus &&
          other.reason == this.reason &&
          other.correctedByUserId == this.correctedByUserId &&
          other.correctedAt == this.correctedAt &&
          other.sessionId == this.sessionId &&
          other.plotPk == this.plotPk);
}

class RatingCorrectionsCompanion extends UpdateCompanion<RatingCorrection> {
  final Value<int> id;
  final Value<int> ratingId;
  final Value<double?> oldNumericValue;
  final Value<double?> newNumericValue;
  final Value<String?> oldTextValue;
  final Value<String?> newTextValue;
  final Value<String> oldResultStatus;
  final Value<String> newResultStatus;
  final Value<String> reason;
  final Value<int?> correctedByUserId;
  final Value<DateTime> correctedAt;
  final Value<int?> sessionId;
  final Value<int?> plotPk;
  const RatingCorrectionsCompanion({
    this.id = const Value.absent(),
    this.ratingId = const Value.absent(),
    this.oldNumericValue = const Value.absent(),
    this.newNumericValue = const Value.absent(),
    this.oldTextValue = const Value.absent(),
    this.newTextValue = const Value.absent(),
    this.oldResultStatus = const Value.absent(),
    this.newResultStatus = const Value.absent(),
    this.reason = const Value.absent(),
    this.correctedByUserId = const Value.absent(),
    this.correctedAt = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.plotPk = const Value.absent(),
  });
  RatingCorrectionsCompanion.insert({
    this.id = const Value.absent(),
    required int ratingId,
    this.oldNumericValue = const Value.absent(),
    this.newNumericValue = const Value.absent(),
    this.oldTextValue = const Value.absent(),
    this.newTextValue = const Value.absent(),
    required String oldResultStatus,
    required String newResultStatus,
    required String reason,
    this.correctedByUserId = const Value.absent(),
    this.correctedAt = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.plotPk = const Value.absent(),
  })  : ratingId = Value(ratingId),
        oldResultStatus = Value(oldResultStatus),
        newResultStatus = Value(newResultStatus),
        reason = Value(reason);
  static Insertable<RatingCorrection> custom({
    Expression<int>? id,
    Expression<int>? ratingId,
    Expression<double>? oldNumericValue,
    Expression<double>? newNumericValue,
    Expression<String>? oldTextValue,
    Expression<String>? newTextValue,
    Expression<String>? oldResultStatus,
    Expression<String>? newResultStatus,
    Expression<String>? reason,
    Expression<int>? correctedByUserId,
    Expression<DateTime>? correctedAt,
    Expression<int>? sessionId,
    Expression<int>? plotPk,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ratingId != null) 'rating_id': ratingId,
      if (oldNumericValue != null) 'old_numeric_value': oldNumericValue,
      if (newNumericValue != null) 'new_numeric_value': newNumericValue,
      if (oldTextValue != null) 'old_text_value': oldTextValue,
      if (newTextValue != null) 'new_text_value': newTextValue,
      if (oldResultStatus != null) 'old_result_status': oldResultStatus,
      if (newResultStatus != null) 'new_result_status': newResultStatus,
      if (reason != null) 'reason': reason,
      if (correctedByUserId != null) 'corrected_by_user_id': correctedByUserId,
      if (correctedAt != null) 'corrected_at': correctedAt,
      if (sessionId != null) 'session_id': sessionId,
      if (plotPk != null) 'plot_pk': plotPk,
    });
  }

  RatingCorrectionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ratingId,
      Value<double?>? oldNumericValue,
      Value<double?>? newNumericValue,
      Value<String?>? oldTextValue,
      Value<String?>? newTextValue,
      Value<String>? oldResultStatus,
      Value<String>? newResultStatus,
      Value<String>? reason,
      Value<int?>? correctedByUserId,
      Value<DateTime>? correctedAt,
      Value<int?>? sessionId,
      Value<int?>? plotPk}) {
    return RatingCorrectionsCompanion(
      id: id ?? this.id,
      ratingId: ratingId ?? this.ratingId,
      oldNumericValue: oldNumericValue ?? this.oldNumericValue,
      newNumericValue: newNumericValue ?? this.newNumericValue,
      oldTextValue: oldTextValue ?? this.oldTextValue,
      newTextValue: newTextValue ?? this.newTextValue,
      oldResultStatus: oldResultStatus ?? this.oldResultStatus,
      newResultStatus: newResultStatus ?? this.newResultStatus,
      reason: reason ?? this.reason,
      correctedByUserId: correctedByUserId ?? this.correctedByUserId,
      correctedAt: correctedAt ?? this.correctedAt,
      sessionId: sessionId ?? this.sessionId,
      plotPk: plotPk ?? this.plotPk,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ratingId.present) {
      map['rating_id'] = Variable<int>(ratingId.value);
    }
    if (oldNumericValue.present) {
      map['old_numeric_value'] = Variable<double>(oldNumericValue.value);
    }
    if (newNumericValue.present) {
      map['new_numeric_value'] = Variable<double>(newNumericValue.value);
    }
    if (oldTextValue.present) {
      map['old_text_value'] = Variable<String>(oldTextValue.value);
    }
    if (newTextValue.present) {
      map['new_text_value'] = Variable<String>(newTextValue.value);
    }
    if (oldResultStatus.present) {
      map['old_result_status'] = Variable<String>(oldResultStatus.value);
    }
    if (newResultStatus.present) {
      map['new_result_status'] = Variable<String>(newResultStatus.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (correctedByUserId.present) {
      map['corrected_by_user_id'] = Variable<int>(correctedByUserId.value);
    }
    if (correctedAt.present) {
      map['corrected_at'] = Variable<DateTime>(correctedAt.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (plotPk.present) {
      map['plot_pk'] = Variable<int>(plotPk.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatingCorrectionsCompanion(')
          ..write('id: $id, ')
          ..write('ratingId: $ratingId, ')
          ..write('oldNumericValue: $oldNumericValue, ')
          ..write('newNumericValue: $newNumericValue, ')
          ..write('oldTextValue: $oldTextValue, ')
          ..write('newTextValue: $newTextValue, ')
          ..write('oldResultStatus: $oldResultStatus, ')
          ..write('newResultStatus: $newResultStatus, ')
          ..write('reason: $reason, ')
          ..write('correctedByUserId: $correctedByUserId, ')
          ..write('correctedAt: $correctedAt, ')
          ..write('sessionId: $sessionId, ')
          ..write('plotPk: $plotPk')
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
  static const VerificationMeta _performedByUserIdMeta =
      const VerificationMeta('performedByUserId');
  @override
  late final GeneratedColumn<int> performedByUserId = GeneratedColumn<int>(
      'performed_by_user_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
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
        performedByUserId,
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
    if (data.containsKey('performed_by_user_id')) {
      context.handle(
          _performedByUserIdMeta,
          performedByUserId.isAcceptableOrUnknown(
              data['performed_by_user_id']!, _performedByUserIdMeta));
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
      performedByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}performed_by_user_id']),
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
  final int? performedByUserId;
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
      this.performedByUserId,
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
    if (!nullToAbsent || performedByUserId != null) {
      map['performed_by_user_id'] = Variable<int>(performedByUserId);
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
      performedByUserId: performedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(performedByUserId),
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
      performedByUserId: serializer.fromJson<int?>(json['performedByUserId']),
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
      'performedByUserId': serializer.toJson<int?>(performedByUserId),
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
          Value<int?> performedByUserId = const Value.absent(),
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
        performedByUserId: performedByUserId.present
            ? performedByUserId.value
            : this.performedByUserId,
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
      performedByUserId: data.performedByUserId.present
          ? data.performedByUserId.value
          : this.performedByUserId,
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
          ..write('performedByUserId: $performedByUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, sessionId, plotPk, eventType,
      description, performedBy, performedByUserId, createdAt, metadata);
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
          other.performedByUserId == this.performedByUserId &&
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
  final Value<int?> performedByUserId;
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
    this.performedByUserId = const Value.absent(),
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
    this.performedByUserId = const Value.absent(),
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
    Expression<int>? performedByUserId,
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
      if (performedByUserId != null) 'performed_by_user_id': performedByUserId,
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
      Value<int?>? performedByUserId,
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
      performedByUserId: performedByUserId ?? this.performedByUserId,
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
    if (performedByUserId.present) {
      map['performed_by_user_id'] = Variable<int>(performedByUserId.value);
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
          ..write('performedByUserId: $performedByUserId, ')
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
  static const VerificationMeta _savedFilePathMeta =
      const VerificationMeta('savedFilePath');
  @override
  late final GeneratedColumn<String> savedFilePath = GeneratedColumn<String>(
      'saved_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        savedFilePath,
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
    if (data.containsKey('saved_file_path')) {
      context.handle(
          _savedFilePathMeta,
          savedFilePath.isAcceptableOrUnknown(
              data['saved_file_path']!, _savedFilePathMeta));
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
      savedFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}saved_file_path']),
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
  final String? savedFilePath;
  final String status;
  final int rowsImported;
  final int rowsSkipped;
  final String? warnings;
  final DateTime createdAt;
  const ImportEvent(
      {required this.id,
      required this.trialId,
      required this.fileName,
      this.savedFilePath,
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
    if (!nullToAbsent || savedFilePath != null) {
      map['saved_file_path'] = Variable<String>(savedFilePath);
    }
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
      savedFilePath: savedFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(savedFilePath),
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
      savedFilePath: serializer.fromJson<String?>(json['savedFilePath']),
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
      'savedFilePath': serializer.toJson<String?>(savedFilePath),
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
          Value<String?> savedFilePath = const Value.absent(),
          String? status,
          int? rowsImported,
          int? rowsSkipped,
          Value<String?> warnings = const Value.absent(),
          DateTime? createdAt}) =>
      ImportEvent(
        id: id ?? this.id,
        trialId: trialId ?? this.trialId,
        fileName: fileName ?? this.fileName,
        savedFilePath:
            savedFilePath.present ? savedFilePath.value : this.savedFilePath,
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
      savedFilePath: data.savedFilePath.present
          ? data.savedFilePath.value
          : this.savedFilePath,
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
          ..write('savedFilePath: $savedFilePath, ')
          ..write('status: $status, ')
          ..write('rowsImported: $rowsImported, ')
          ..write('rowsSkipped: $rowsSkipped, ')
          ..write('warnings: $warnings, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trialId, fileName, savedFilePath, status,
      rowsImported, rowsSkipped, warnings, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportEvent &&
          other.id == this.id &&
          other.trialId == this.trialId &&
          other.fileName == this.fileName &&
          other.savedFilePath == this.savedFilePath &&
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
  final Value<String?> savedFilePath;
  final Value<String> status;
  final Value<int> rowsImported;
  final Value<int> rowsSkipped;
  final Value<String?> warnings;
  final Value<DateTime> createdAt;
  const ImportEventsCompanion({
    this.id = const Value.absent(),
    this.trialId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.savedFilePath = const Value.absent(),
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
    this.savedFilePath = const Value.absent(),
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
    Expression<String>? savedFilePath,
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
      if (savedFilePath != null) 'saved_file_path': savedFilePath,
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
      Value<String?>? savedFilePath,
      Value<String>? status,
      Value<int>? rowsImported,
      Value<int>? rowsSkipped,
      Value<String?>? warnings,
      Value<DateTime>? createdAt}) {
    return ImportEventsCompanion(
      id: id ?? this.id,
      trialId: trialId ?? this.trialId,
      fileName: fileName ?? this.fileName,
      savedFilePath: savedFilePath ?? this.savedFilePath,
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
    if (savedFilePath.present) {
      map['saved_file_path'] = Variable<String>(savedFilePath.value);
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
          ..write('savedFilePath: $savedFilePath, ')
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
  late final $UsersTable users = $UsersTable(this);
  late final $TrialsTable trials = $TrialsTable(this);
  late final $TreatmentsTable treatments = $TreatmentsTable(this);
  late final $TreatmentComponentsTable treatmentComponents =
      $TreatmentComponentsTable(this);
  late final $AssessmentsTable assessments = $AssessmentsTable(this);
  late final $AssessmentDefinitionsTable assessmentDefinitions =
      $AssessmentDefinitionsTable(this);
  late final $TrialAssessmentsTable trialAssessments =
      $TrialAssessmentsTable(this);
  late final $PlotsTable plots = $PlotsTable(this);
  late final $AssignmentsTable assignments = $AssignmentsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionAssessmentsTable sessionAssessments =
      $SessionAssessmentsTable(this);
  late final $RatingRecordsTable ratingRecords = $RatingRecordsTable(this);
  late final $RatingCorrectionsTable ratingCorrections =
      $RatingCorrectionsTable(this);
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
        users,
        trials,
        treatments,
        treatmentComponents,
        assessments,
        assessmentDefinitions,
        trialAssessments,
        plots,
        assignments,
        sessions,
        sessionAssessments,
        ratingRecords,
        ratingCorrections,
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

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  required String displayName,
  Value<String?> initials,
  Value<String> roleKey,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> displayName,
  Value<String?> initials,
  Value<String> roleKey,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$UsersTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$UsersTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> initials = const Value.absent(),
            Value<String> roleKey = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            displayName: displayName,
            initials: initials,
            roleKey: roleKey,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String displayName,
            Value<String?> initials = const Value.absent(),
            Value<String> roleKey = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            displayName: displayName,
            initials: initials,
            roleKey: roleKey,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ));
}

class $$UsersTableFilterComposer
    extends FilterComposer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get displayName => $state.composableBuilder(
      column: $state.table.displayName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get initials => $state.composableBuilder(
      column: $state.table.initials,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get roleKey => $state.composableBuilder(
      column: $state.table.roleKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
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

  ComposableFilter assignmentsRefs(
      ComposableFilter Function($$AssignmentsTableFilterComposer f) f) {
    final $$AssignmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.assignments,
        getReferencedColumn: (t) => t.assignedBy,
        builder: (joinBuilder, parentComposers) =>
            $$AssignmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assignments, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter sessionsRefs(
      ComposableFilter Function($$SessionsTableFilterComposer f) f) {
    final $$SessionsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.sessions,
        getReferencedColumn: (t) => t.createdByUserId,
        builder: (joinBuilder, parentComposers) =>
            $$SessionsTableFilterComposer(ComposerState(
                $state.db, $state.db.sessions, joinBuilder, parentComposers)));
    return f(composer);
  }

  ComposableFilter ratingCorrectionsRefs(
      ComposableFilter Function($$RatingCorrectionsTableFilterComposer f) f) {
    final $$RatingCorrectionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.ratingCorrections,
            getReferencedColumn: (t) => t.correctedByUserId,
            builder: (joinBuilder, parentComposers) =>
                $$RatingCorrectionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.ratingCorrections,
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
        getReferencedColumn: (t) => t.performedByUserId,
        builder: (joinBuilder, parentComposers) =>
            $$AuditEventsTableFilterComposer(ComposerState($state.db,
                $state.db.auditEvents, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get displayName => $state.composableBuilder(
      column: $state.table.displayName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get initials => $state.composableBuilder(
      column: $state.table.initials,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get roleKey => $state.composableBuilder(
      column: $state.table.roleKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
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

typedef $$TrialsTableCreateCompanionBuilder = TrialsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> crop,
  Value<String?> location,
  Value<String?> season,
  Value<String> status,
  Value<String?> plotDimensions,
  Value<int?> plotRows,
  Value<String?> plotSpacing,
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
  Value<String?> plotDimensions,
  Value<int?> plotRows,
  Value<String?> plotSpacing,
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
            Value<String?> plotDimensions = const Value.absent(),
            Value<int?> plotRows = const Value.absent(),
            Value<String?> plotSpacing = const Value.absent(),
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
            plotDimensions: plotDimensions,
            plotRows: plotRows,
            plotSpacing: plotSpacing,
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
            Value<String?> plotDimensions = const Value.absent(),
            Value<int?> plotRows = const Value.absent(),
            Value<String?> plotSpacing = const Value.absent(),
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
            plotDimensions: plotDimensions,
            plotRows: plotRows,
            plotSpacing: plotSpacing,
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

  ColumnFilters<String> get plotDimensions => $state.composableBuilder(
      column: $state.table.plotDimensions,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get plotRows => $state.composableBuilder(
      column: $state.table.plotRows,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get plotSpacing => $state.composableBuilder(
      column: $state.table.plotSpacing,
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

  ComposableFilter trialAssessmentsRefs(
      ComposableFilter Function($$TrialAssessmentsTableFilterComposer f) f) {
    final $$TrialAssessmentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.trialId,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableFilterComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
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

  ComposableFilter assignmentsRefs(
      ComposableFilter Function($$AssignmentsTableFilterComposer f) f) {
    final $$AssignmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.assignments,
        getReferencedColumn: (t) => t.trialId,
        builder: (joinBuilder, parentComposers) =>
            $$AssignmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assignments, joinBuilder, parentComposers)));
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

  ColumnOrderings<String> get plotDimensions => $state.composableBuilder(
      column: $state.table.plotDimensions,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get plotRows => $state.composableBuilder(
      column: $state.table.plotRows,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get plotSpacing => $state.composableBuilder(
      column: $state.table.plotSpacing,
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

  ComposableFilter assignmentsRefs(
      ComposableFilter Function($$AssignmentsTableFilterComposer f) f) {
    final $$AssignmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.assignments,
        getReferencedColumn: (t) => t.treatmentId,
        builder: (joinBuilder, parentComposers) =>
            $$AssignmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assignments, joinBuilder, parentComposers)));
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

  ComposableFilter trialAssessmentsRefs(
      ComposableFilter Function($$TrialAssessmentsTableFilterComposer f) f) {
    final $$TrialAssessmentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.legacyAssessmentId,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableFilterComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
    return f(composer);
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

typedef $$AssessmentDefinitionsTableCreateCompanionBuilder
    = AssessmentDefinitionsCompanion Function({
  Value<int> id,
  required String code,
  required String name,
  required String category,
  Value<String> dataType,
  Value<String?> unit,
  Value<double?> scaleMin,
  Value<double?> scaleMax,
  Value<String?> target,
  Value<String?> method,
  Value<String?> defaultInstructions,
  Value<String?> timingType,
  Value<bool> isSystem,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AssessmentDefinitionsTableUpdateCompanionBuilder
    = AssessmentDefinitionsCompanion Function({
  Value<int> id,
  Value<String> code,
  Value<String> name,
  Value<String> category,
  Value<String> dataType,
  Value<String?> unit,
  Value<double?> scaleMin,
  Value<double?> scaleMax,
  Value<String?> target,
  Value<String?> method,
  Value<String?> defaultInstructions,
  Value<String?> timingType,
  Value<bool> isSystem,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$AssessmentDefinitionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssessmentDefinitionsTable,
    AssessmentDefinition,
    $$AssessmentDefinitionsTableFilterComposer,
    $$AssessmentDefinitionsTableOrderingComposer,
    $$AssessmentDefinitionsTableCreateCompanionBuilder,
    $$AssessmentDefinitionsTableUpdateCompanionBuilder> {
  $$AssessmentDefinitionsTableTableManager(
      _$AppDatabase db, $AssessmentDefinitionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$AssessmentDefinitionsTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$AssessmentDefinitionsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> dataType = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<double?> scaleMin = const Value.absent(),
            Value<double?> scaleMax = const Value.absent(),
            Value<String?> target = const Value.absent(),
            Value<String?> method = const Value.absent(),
            Value<String?> defaultInstructions = const Value.absent(),
            Value<String?> timingType = const Value.absent(),
            Value<bool> isSystem = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AssessmentDefinitionsCompanion(
            id: id,
            code: code,
            name: name,
            category: category,
            dataType: dataType,
            unit: unit,
            scaleMin: scaleMin,
            scaleMax: scaleMax,
            target: target,
            method: method,
            defaultInstructions: defaultInstructions,
            timingType: timingType,
            isSystem: isSystem,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String code,
            required String name,
            required String category,
            Value<String> dataType = const Value.absent(),
            Value<String?> unit = const Value.absent(),
            Value<double?> scaleMin = const Value.absent(),
            Value<double?> scaleMax = const Value.absent(),
            Value<String?> target = const Value.absent(),
            Value<String?> method = const Value.absent(),
            Value<String?> defaultInstructions = const Value.absent(),
            Value<String?> timingType = const Value.absent(),
            Value<bool> isSystem = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AssessmentDefinitionsCompanion.insert(
            id: id,
            code: code,
            name: name,
            category: category,
            dataType: dataType,
            unit: unit,
            scaleMin: scaleMin,
            scaleMax: scaleMax,
            target: target,
            method: method,
            defaultInstructions: defaultInstructions,
            timingType: timingType,
            isSystem: isSystem,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ));
}

class $$AssessmentDefinitionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AssessmentDefinitionsTable> {
  $$AssessmentDefinitionsTableFilterComposer(super.$state);
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

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get dataType => $state.composableBuilder(
      column: $state.table.dataType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get scaleMin => $state.composableBuilder(
      column: $state.table.scaleMin,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get scaleMax => $state.composableBuilder(
      column: $state.table.scaleMax,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get target => $state.composableBuilder(
      column: $state.table.target,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get method => $state.composableBuilder(
      column: $state.table.method,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get defaultInstructions => $state.composableBuilder(
      column: $state.table.defaultInstructions,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timingType => $state.composableBuilder(
      column: $state.table.timingType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSystem => $state.composableBuilder(
      column: $state.table.isSystem,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
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

  ComposableFilter trialAssessmentsRefs(
      ComposableFilter Function($$TrialAssessmentsTableFilterComposer f) f) {
    final $$TrialAssessmentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.assessmentDefinitionId,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableFilterComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$AssessmentDefinitionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AssessmentDefinitionsTable> {
  $$AssessmentDefinitionsTableOrderingComposer(super.$state);
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

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get dataType => $state.composableBuilder(
      column: $state.table.dataType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get unit => $state.composableBuilder(
      column: $state.table.unit,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get scaleMin => $state.composableBuilder(
      column: $state.table.scaleMin,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get scaleMax => $state.composableBuilder(
      column: $state.table.scaleMax,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get target => $state.composableBuilder(
      column: $state.table.target,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get method => $state.composableBuilder(
      column: $state.table.method,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get defaultInstructions => $state.composableBuilder(
      column: $state.table.defaultInstructions,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timingType => $state.composableBuilder(
      column: $state.table.timingType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSystem => $state.composableBuilder(
      column: $state.table.isSystem,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
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

typedef $$TrialAssessmentsTableCreateCompanionBuilder
    = TrialAssessmentsCompanion Function({
  Value<int> id,
  required int trialId,
  required int assessmentDefinitionId,
  Value<String?> displayNameOverride,
  Value<bool> required,
  Value<bool> selectedFromProtocol,
  Value<bool> selectedManually,
  Value<bool> defaultInSessions,
  Value<int> sortOrder,
  Value<String?> timingMode,
  Value<int?> daysAfterPlanting,
  Value<int?> daysAfterTreatment,
  Value<String?> growthStage,
  Value<String?> methodOverride,
  Value<String?> instructionOverride,
  Value<bool> isActive,
  Value<int?> legacyAssessmentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$TrialAssessmentsTableUpdateCompanionBuilder
    = TrialAssessmentsCompanion Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> assessmentDefinitionId,
  Value<String?> displayNameOverride,
  Value<bool> required,
  Value<bool> selectedFromProtocol,
  Value<bool> selectedManually,
  Value<bool> defaultInSessions,
  Value<int> sortOrder,
  Value<String?> timingMode,
  Value<int?> daysAfterPlanting,
  Value<int?> daysAfterTreatment,
  Value<String?> growthStage,
  Value<String?> methodOverride,
  Value<String?> instructionOverride,
  Value<bool> isActive,
  Value<int?> legacyAssessmentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$TrialAssessmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrialAssessmentsTable,
    TrialAssessment,
    $$TrialAssessmentsTableFilterComposer,
    $$TrialAssessmentsTableOrderingComposer,
    $$TrialAssessmentsTableCreateCompanionBuilder,
    $$TrialAssessmentsTableUpdateCompanionBuilder> {
  $$TrialAssessmentsTableTableManager(
      _$AppDatabase db, $TrialAssessmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$TrialAssessmentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$TrialAssessmentsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int> assessmentDefinitionId = const Value.absent(),
            Value<String?> displayNameOverride = const Value.absent(),
            Value<bool> required = const Value.absent(),
            Value<bool> selectedFromProtocol = const Value.absent(),
            Value<bool> selectedManually = const Value.absent(),
            Value<bool> defaultInSessions = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> timingMode = const Value.absent(),
            Value<int?> daysAfterPlanting = const Value.absent(),
            Value<int?> daysAfterTreatment = const Value.absent(),
            Value<String?> growthStage = const Value.absent(),
            Value<String?> methodOverride = const Value.absent(),
            Value<String?> instructionOverride = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int?> legacyAssessmentId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              TrialAssessmentsCompanion(
            id: id,
            trialId: trialId,
            assessmentDefinitionId: assessmentDefinitionId,
            displayNameOverride: displayNameOverride,
            required: required,
            selectedFromProtocol: selectedFromProtocol,
            selectedManually: selectedManually,
            defaultInSessions: defaultInSessions,
            sortOrder: sortOrder,
            timingMode: timingMode,
            daysAfterPlanting: daysAfterPlanting,
            daysAfterTreatment: daysAfterTreatment,
            growthStage: growthStage,
            methodOverride: methodOverride,
            instructionOverride: instructionOverride,
            isActive: isActive,
            legacyAssessmentId: legacyAssessmentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int assessmentDefinitionId,
            Value<String?> displayNameOverride = const Value.absent(),
            Value<bool> required = const Value.absent(),
            Value<bool> selectedFromProtocol = const Value.absent(),
            Value<bool> selectedManually = const Value.absent(),
            Value<bool> defaultInSessions = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> timingMode = const Value.absent(),
            Value<int?> daysAfterPlanting = const Value.absent(),
            Value<int?> daysAfterTreatment = const Value.absent(),
            Value<String?> growthStage = const Value.absent(),
            Value<String?> methodOverride = const Value.absent(),
            Value<String?> instructionOverride = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int?> legacyAssessmentId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              TrialAssessmentsCompanion.insert(
            id: id,
            trialId: trialId,
            assessmentDefinitionId: assessmentDefinitionId,
            displayNameOverride: displayNameOverride,
            required: required,
            selectedFromProtocol: selectedFromProtocol,
            selectedManually: selectedManually,
            defaultInSessions: defaultInSessions,
            sortOrder: sortOrder,
            timingMode: timingMode,
            daysAfterPlanting: daysAfterPlanting,
            daysAfterTreatment: daysAfterTreatment,
            growthStage: growthStage,
            methodOverride: methodOverride,
            instructionOverride: instructionOverride,
            isActive: isActive,
            legacyAssessmentId: legacyAssessmentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ));
}

class $$TrialAssessmentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $TrialAssessmentsTable> {
  $$TrialAssessmentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get displayNameOverride => $state.composableBuilder(
      column: $state.table.displayNameOverride,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get required => $state.composableBuilder(
      column: $state.table.required,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get selectedFromProtocol => $state.composableBuilder(
      column: $state.table.selectedFromProtocol,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get selectedManually => $state.composableBuilder(
      column: $state.table.selectedManually,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get defaultInSessions => $state.composableBuilder(
      column: $state.table.defaultInSessions,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get timingMode => $state.composableBuilder(
      column: $state.table.timingMode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get daysAfterPlanting => $state.composableBuilder(
      column: $state.table.daysAfterPlanting,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get daysAfterTreatment => $state.composableBuilder(
      column: $state.table.daysAfterTreatment,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get growthStage => $state.composableBuilder(
      column: $state.table.growthStage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get methodOverride => $state.composableBuilder(
      column: $state.table.methodOverride,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get instructionOverride => $state.composableBuilder(
      column: $state.table.instructionOverride,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
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

  $$AssessmentDefinitionsTableFilterComposer get assessmentDefinitionId {
    final $$AssessmentDefinitionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.assessmentDefinitionId,
            referencedTable: $state.db.assessmentDefinitions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$AssessmentDefinitionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.assessmentDefinitions,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  $$AssessmentsTableFilterComposer get legacyAssessmentId {
    final $$AssessmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.legacyAssessmentId,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
    return composer;
  }

  ComposableFilter sessionAssessmentsRefs(
      ComposableFilter Function($$SessionAssessmentsTableFilterComposer f) f) {
    final $$SessionAssessmentsTableFilterComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.sessionAssessments,
            getReferencedColumn: (t) => t.trialAssessmentId,
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
        getReferencedColumn: (t) => t.trialAssessmentId,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$TrialAssessmentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $TrialAssessmentsTable> {
  $$TrialAssessmentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get displayNameOverride => $state.composableBuilder(
      column: $state.table.displayNameOverride,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get required => $state.composableBuilder(
      column: $state.table.required,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get selectedFromProtocol => $state.composableBuilder(
      column: $state.table.selectedFromProtocol,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get selectedManually => $state.composableBuilder(
      column: $state.table.selectedManually,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get defaultInSessions => $state.composableBuilder(
      column: $state.table.defaultInSessions,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get timingMode => $state.composableBuilder(
      column: $state.table.timingMode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get daysAfterPlanting => $state.composableBuilder(
      column: $state.table.daysAfterPlanting,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get daysAfterTreatment => $state.composableBuilder(
      column: $state.table.daysAfterTreatment,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get growthStage => $state.composableBuilder(
      column: $state.table.growthStage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get methodOverride => $state.composableBuilder(
      column: $state.table.methodOverride,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get instructionOverride => $state.composableBuilder(
      column: $state.table.instructionOverride,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
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

  $$AssessmentDefinitionsTableOrderingComposer get assessmentDefinitionId {
    final $$AssessmentDefinitionsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.assessmentDefinitionId,
            referencedTable: $state.db.assessmentDefinitions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$AssessmentDefinitionsTableOrderingComposer(ComposerState(
                    $state.db,
                    $state.db.assessmentDefinitions,
                    joinBuilder,
                    parentComposers)));
    return composer;
  }

  $$AssessmentsTableOrderingComposer get legacyAssessmentId {
    final $$AssessmentsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.legacyAssessmentId,
        referencedTable: $state.db.assessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$AssessmentsTableOrderingComposer(ComposerState($state.db,
                $state.db.assessments, joinBuilder, parentComposers)));
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
  Value<int?> fieldRow,
  Value<int?> fieldColumn,
  Value<String?> notes,
  Value<String?> assignmentSource,
  Value<DateTime?> assignmentUpdatedAt,
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
  Value<int?> fieldRow,
  Value<int?> fieldColumn,
  Value<String?> notes,
  Value<String?> assignmentSource,
  Value<DateTime?> assignmentUpdatedAt,
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
            Value<int?> fieldRow = const Value.absent(),
            Value<int?> fieldColumn = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> assignmentSource = const Value.absent(),
            Value<DateTime?> assignmentUpdatedAt = const Value.absent(),
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
            fieldRow: fieldRow,
            fieldColumn: fieldColumn,
            notes: notes,
            assignmentSource: assignmentSource,
            assignmentUpdatedAt: assignmentUpdatedAt,
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
            Value<int?> fieldRow = const Value.absent(),
            Value<int?> fieldColumn = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> assignmentSource = const Value.absent(),
            Value<DateTime?> assignmentUpdatedAt = const Value.absent(),
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
            fieldRow: fieldRow,
            fieldColumn: fieldColumn,
            notes: notes,
            assignmentSource: assignmentSource,
            assignmentUpdatedAt: assignmentUpdatedAt,
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

  ColumnFilters<int> get fieldRow => $state.composableBuilder(
      column: $state.table.fieldRow,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get fieldColumn => $state.composableBuilder(
      column: $state.table.fieldColumn,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get assignmentSource => $state.composableBuilder(
      column: $state.table.assignmentSource,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get assignmentUpdatedAt => $state.composableBuilder(
      column: $state.table.assignmentUpdatedAt,
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

  ComposableFilter assignmentsRefs(
      ComposableFilter Function($$AssignmentsTableFilterComposer f) f) {
    final $$AssignmentsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.assignments,
        getReferencedColumn: (t) => t.plotId,
        builder: (joinBuilder, parentComposers) =>
            $$AssignmentsTableFilterComposer(ComposerState($state.db,
                $state.db.assignments, joinBuilder, parentComposers)));
    return f(composer);
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

  ComposableFilter ratingCorrectionsRefs(
      ComposableFilter Function($$RatingCorrectionsTableFilterComposer f) f) {
    final $$RatingCorrectionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.ratingCorrections,
            getReferencedColumn: (t) => t.plotPk,
            builder: (joinBuilder, parentComposers) =>
                $$RatingCorrectionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.ratingCorrections,
                    joinBuilder,
                    parentComposers)));
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

  ColumnOrderings<int> get fieldRow => $state.composableBuilder(
      column: $state.table.fieldRow,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get fieldColumn => $state.composableBuilder(
      column: $state.table.fieldColumn,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get notes => $state.composableBuilder(
      column: $state.table.notes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get assignmentSource => $state.composableBuilder(
      column: $state.table.assignmentSource,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get assignmentUpdatedAt => $state.composableBuilder(
      column: $state.table.assignmentUpdatedAt,
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

typedef $$AssignmentsTableCreateCompanionBuilder = AssignmentsCompanion
    Function({
  Value<int> id,
  required int trialId,
  required int plotId,
  Value<int?> treatmentId,
  Value<int?> replication,
  Value<int?> block,
  Value<int?> range,
  Value<int?> column,
  Value<int?> position,
  Value<bool?> isCheck,
  Value<bool?> isControl,
  Value<String?> assignmentSource,
  Value<DateTime?> assignedAt,
  Value<int?> assignedBy,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AssignmentsTableUpdateCompanionBuilder = AssignmentsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> plotId,
  Value<int?> treatmentId,
  Value<int?> replication,
  Value<int?> block,
  Value<int?> range,
  Value<int?> column,
  Value<int?> position,
  Value<bool?> isCheck,
  Value<bool?> isControl,
  Value<String?> assignmentSource,
  Value<DateTime?> assignedAt,
  Value<int?> assignedBy,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$AssignmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssignmentsTable,
    Assignment,
    $$AssignmentsTableFilterComposer,
    $$AssignmentsTableOrderingComposer,
    $$AssignmentsTableCreateCompanionBuilder,
    $$AssignmentsTableUpdateCompanionBuilder> {
  $$AssignmentsTableTableManager(_$AppDatabase db, $AssignmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AssignmentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AssignmentsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> trialId = const Value.absent(),
            Value<int> plotId = const Value.absent(),
            Value<int?> treatmentId = const Value.absent(),
            Value<int?> replication = const Value.absent(),
            Value<int?> block = const Value.absent(),
            Value<int?> range = const Value.absent(),
            Value<int?> column = const Value.absent(),
            Value<int?> position = const Value.absent(),
            Value<bool?> isCheck = const Value.absent(),
            Value<bool?> isControl = const Value.absent(),
            Value<String?> assignmentSource = const Value.absent(),
            Value<DateTime?> assignedAt = const Value.absent(),
            Value<int?> assignedBy = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AssignmentsCompanion(
            id: id,
            trialId: trialId,
            plotId: plotId,
            treatmentId: treatmentId,
            replication: replication,
            block: block,
            range: range,
            column: column,
            position: position,
            isCheck: isCheck,
            isControl: isControl,
            assignmentSource: assignmentSource,
            assignedAt: assignedAt,
            assignedBy: assignedBy,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int plotId,
            Value<int?> treatmentId = const Value.absent(),
            Value<int?> replication = const Value.absent(),
            Value<int?> block = const Value.absent(),
            Value<int?> range = const Value.absent(),
            Value<int?> column = const Value.absent(),
            Value<int?> position = const Value.absent(),
            Value<bool?> isCheck = const Value.absent(),
            Value<bool?> isControl = const Value.absent(),
            Value<String?> assignmentSource = const Value.absent(),
            Value<DateTime?> assignedAt = const Value.absent(),
            Value<int?> assignedBy = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AssignmentsCompanion.insert(
            id: id,
            trialId: trialId,
            plotId: plotId,
            treatmentId: treatmentId,
            replication: replication,
            block: block,
            range: range,
            column: column,
            position: position,
            isCheck: isCheck,
            isControl: isControl,
            assignmentSource: assignmentSource,
            assignedAt: assignedAt,
            assignedBy: assignedBy,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ));
}

class $$AssignmentsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AssignmentsTable> {
  $$AssignmentsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get replication => $state.composableBuilder(
      column: $state.table.replication,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get block => $state.composableBuilder(
      column: $state.table.block,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get range => $state.composableBuilder(
      column: $state.table.range,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get column => $state.composableBuilder(
      column: $state.table.column,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get position => $state.composableBuilder(
      column: $state.table.position,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCheck => $state.composableBuilder(
      column: $state.table.isCheck,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isControl => $state.composableBuilder(
      column: $state.table.isControl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get assignmentSource => $state.composableBuilder(
      column: $state.table.assignmentSource,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get assignedAt => $state.composableBuilder(
      column: $state.table.assignedAt,
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

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
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

  $$PlotsTableFilterComposer get plotId {
    final $$PlotsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotId,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
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

  $$UsersTableFilterComposer get assignedBy {
    final $$UsersTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assignedBy,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableFilterComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$AssignmentsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AssignmentsTable> {
  $$AssignmentsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get replication => $state.composableBuilder(
      column: $state.table.replication,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get block => $state.composableBuilder(
      column: $state.table.block,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get range => $state.composableBuilder(
      column: $state.table.range,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get column => $state.composableBuilder(
      column: $state.table.column,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get position => $state.composableBuilder(
      column: $state.table.position,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCheck => $state.composableBuilder(
      column: $state.table.isCheck,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isControl => $state.composableBuilder(
      column: $state.table.isControl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get assignmentSource => $state.composableBuilder(
      column: $state.table.assignmentSource,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get assignedAt => $state.composableBuilder(
      column: $state.table.assignedAt,
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

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
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

  $$PlotsTableOrderingComposer get plotId {
    final $$PlotsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.plotId,
        referencedTable: $state.db.plots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$PlotsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.plots, joinBuilder, parentComposers)));
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

  $$UsersTableOrderingComposer get assignedBy {
    final $$UsersTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assignedBy,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
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
  Value<int?> createdByUserId,
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
  Value<int?> createdByUserId,
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
            Value<int?> createdByUserId = const Value.absent(),
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
            createdByUserId: createdByUserId,
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
            Value<int?> createdByUserId = const Value.absent(),
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
            createdByUserId: createdByUserId,
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

  $$UsersTableFilterComposer get createdByUserId {
    final $$UsersTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.createdByUserId,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableFilterComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
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

  ComposableFilter ratingCorrectionsRefs(
      ComposableFilter Function($$RatingCorrectionsTableFilterComposer f) f) {
    final $$RatingCorrectionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.ratingCorrections,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder, parentComposers) =>
                $$RatingCorrectionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.ratingCorrections,
                    joinBuilder,
                    parentComposers)));
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

  $$UsersTableOrderingComposer get createdByUserId {
    final $$UsersTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.createdByUserId,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$SessionAssessmentsTableCreateCompanionBuilder
    = SessionAssessmentsCompanion Function({
  Value<int> id,
  required int sessionId,
  required int assessmentId,
  Value<int?> trialAssessmentId,
  Value<int> sortOrder,
});
typedef $$SessionAssessmentsTableUpdateCompanionBuilder
    = SessionAssessmentsCompanion Function({
  Value<int> id,
  Value<int> sessionId,
  Value<int> assessmentId,
  Value<int?> trialAssessmentId,
  Value<int> sortOrder,
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
            Value<int?> trialAssessmentId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SessionAssessmentsCompanion(
            id: id,
            sessionId: sessionId,
            assessmentId: assessmentId,
            trialAssessmentId: trialAssessmentId,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required int assessmentId,
            Value<int?> trialAssessmentId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SessionAssessmentsCompanion.insert(
            id: id,
            sessionId: sessionId,
            assessmentId: assessmentId,
            trialAssessmentId: trialAssessmentId,
            sortOrder: sortOrder,
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

  ColumnFilters<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
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

  $$TrialAssessmentsTableFilterComposer get trialAssessmentId {
    final $$TrialAssessmentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.trialAssessmentId,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableFilterComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
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

  ColumnOrderings<int> get sortOrder => $state.composableBuilder(
      column: $state.table.sortOrder,
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

  $$TrialAssessmentsTableOrderingComposer get trialAssessmentId {
    final $$TrialAssessmentsTableOrderingComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.trialAssessmentId,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableOrderingComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$RatingRecordsTableCreateCompanionBuilder = RatingRecordsCompanion
    Function({
  Value<int> id,
  required int trialId,
  required int plotPk,
  required int assessmentId,
  Value<int?> trialAssessmentId,
  required int sessionId,
  Value<int?> subUnitId,
  Value<String> resultStatus,
  Value<double?> numericValue,
  Value<String?> textValue,
  Value<bool> isCurrent,
  Value<int?> previousId,
  Value<DateTime> createdAt,
  Value<String?> raterName,
  Value<String?> createdAppVersion,
  Value<String?> createdDeviceInfo,
  Value<double?> capturedLatitude,
  Value<double?> capturedLongitude,
});
typedef $$RatingRecordsTableUpdateCompanionBuilder = RatingRecordsCompanion
    Function({
  Value<int> id,
  Value<int> trialId,
  Value<int> plotPk,
  Value<int> assessmentId,
  Value<int?> trialAssessmentId,
  Value<int> sessionId,
  Value<int?> subUnitId,
  Value<String> resultStatus,
  Value<double?> numericValue,
  Value<String?> textValue,
  Value<bool> isCurrent,
  Value<int?> previousId,
  Value<DateTime> createdAt,
  Value<String?> raterName,
  Value<String?> createdAppVersion,
  Value<String?> createdDeviceInfo,
  Value<double?> capturedLatitude,
  Value<double?> capturedLongitude,
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
            Value<int?> trialAssessmentId = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<int?> subUnitId = const Value.absent(),
            Value<String> resultStatus = const Value.absent(),
            Value<double?> numericValue = const Value.absent(),
            Value<String?> textValue = const Value.absent(),
            Value<bool> isCurrent = const Value.absent(),
            Value<int?> previousId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
            Value<String?> createdAppVersion = const Value.absent(),
            Value<String?> createdDeviceInfo = const Value.absent(),
            Value<double?> capturedLatitude = const Value.absent(),
            Value<double?> capturedLongitude = const Value.absent(),
          }) =>
              RatingRecordsCompanion(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            trialAssessmentId: trialAssessmentId,
            sessionId: sessionId,
            subUnitId: subUnitId,
            resultStatus: resultStatus,
            numericValue: numericValue,
            textValue: textValue,
            isCurrent: isCurrent,
            previousId: previousId,
            createdAt: createdAt,
            raterName: raterName,
            createdAppVersion: createdAppVersion,
            createdDeviceInfo: createdDeviceInfo,
            capturedLatitude: capturedLatitude,
            capturedLongitude: capturedLongitude,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int trialId,
            required int plotPk,
            required int assessmentId,
            Value<int?> trialAssessmentId = const Value.absent(),
            required int sessionId,
            Value<int?> subUnitId = const Value.absent(),
            Value<String> resultStatus = const Value.absent(),
            Value<double?> numericValue = const Value.absent(),
            Value<String?> textValue = const Value.absent(),
            Value<bool> isCurrent = const Value.absent(),
            Value<int?> previousId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> raterName = const Value.absent(),
            Value<String?> createdAppVersion = const Value.absent(),
            Value<String?> createdDeviceInfo = const Value.absent(),
            Value<double?> capturedLatitude = const Value.absent(),
            Value<double?> capturedLongitude = const Value.absent(),
          }) =>
              RatingRecordsCompanion.insert(
            id: id,
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            trialAssessmentId: trialAssessmentId,
            sessionId: sessionId,
            subUnitId: subUnitId,
            resultStatus: resultStatus,
            numericValue: numericValue,
            textValue: textValue,
            isCurrent: isCurrent,
            previousId: previousId,
            createdAt: createdAt,
            raterName: raterName,
            createdAppVersion: createdAppVersion,
            createdDeviceInfo: createdDeviceInfo,
            capturedLatitude: capturedLatitude,
            capturedLongitude: capturedLongitude,
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

  ColumnFilters<String> get createdAppVersion => $state.composableBuilder(
      column: $state.table.createdAppVersion,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get createdDeviceInfo => $state.composableBuilder(
      column: $state.table.createdDeviceInfo,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get capturedLatitude => $state.composableBuilder(
      column: $state.table.capturedLatitude,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get capturedLongitude => $state.composableBuilder(
      column: $state.table.capturedLongitude,
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

  $$TrialAssessmentsTableFilterComposer get trialAssessmentId {
    final $$TrialAssessmentsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.trialAssessmentId,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableFilterComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
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

  ComposableFilter ratingCorrectionsRefs(
      ComposableFilter Function($$RatingCorrectionsTableFilterComposer f) f) {
    final $$RatingCorrectionsTableFilterComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $state.db.ratingCorrections,
            getReferencedColumn: (t) => t.ratingId,
            builder: (joinBuilder, parentComposers) =>
                $$RatingCorrectionsTableFilterComposer(ComposerState(
                    $state.db,
                    $state.db.ratingCorrections,
                    joinBuilder,
                    parentComposers)));
    return f(composer);
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

  ColumnOrderings<String> get createdAppVersion => $state.composableBuilder(
      column: $state.table.createdAppVersion,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get createdDeviceInfo => $state.composableBuilder(
      column: $state.table.createdDeviceInfo,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get capturedLatitude => $state.composableBuilder(
      column: $state.table.capturedLatitude,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get capturedLongitude => $state.composableBuilder(
      column: $state.table.capturedLongitude,
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

  $$TrialAssessmentsTableOrderingComposer get trialAssessmentId {
    final $$TrialAssessmentsTableOrderingComposer composer = $state
        .composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.trialAssessmentId,
            referencedTable: $state.db.trialAssessments,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$TrialAssessmentsTableOrderingComposer(ComposerState($state.db,
                    $state.db.trialAssessments, joinBuilder, parentComposers)));
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

typedef $$RatingCorrectionsTableCreateCompanionBuilder
    = RatingCorrectionsCompanion Function({
  Value<int> id,
  required int ratingId,
  Value<double?> oldNumericValue,
  Value<double?> newNumericValue,
  Value<String?> oldTextValue,
  Value<String?> newTextValue,
  required String oldResultStatus,
  required String newResultStatus,
  required String reason,
  Value<int?> correctedByUserId,
  Value<DateTime> correctedAt,
  Value<int?> sessionId,
  Value<int?> plotPk,
});
typedef $$RatingCorrectionsTableUpdateCompanionBuilder
    = RatingCorrectionsCompanion Function({
  Value<int> id,
  Value<int> ratingId,
  Value<double?> oldNumericValue,
  Value<double?> newNumericValue,
  Value<String?> oldTextValue,
  Value<String?> newTextValue,
  Value<String> oldResultStatus,
  Value<String> newResultStatus,
  Value<String> reason,
  Value<int?> correctedByUserId,
  Value<DateTime> correctedAt,
  Value<int?> sessionId,
  Value<int?> plotPk,
});

class $$RatingCorrectionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RatingCorrectionsTable,
    RatingCorrection,
    $$RatingCorrectionsTableFilterComposer,
    $$RatingCorrectionsTableOrderingComposer,
    $$RatingCorrectionsTableCreateCompanionBuilder,
    $$RatingCorrectionsTableUpdateCompanionBuilder> {
  $$RatingCorrectionsTableTableManager(
      _$AppDatabase db, $RatingCorrectionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$RatingCorrectionsTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$RatingCorrectionsTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ratingId = const Value.absent(),
            Value<double?> oldNumericValue = const Value.absent(),
            Value<double?> newNumericValue = const Value.absent(),
            Value<String?> oldTextValue = const Value.absent(),
            Value<String?> newTextValue = const Value.absent(),
            Value<String> oldResultStatus = const Value.absent(),
            Value<String> newResultStatus = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<int?> correctedByUserId = const Value.absent(),
            Value<DateTime> correctedAt = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            Value<int?> plotPk = const Value.absent(),
          }) =>
              RatingCorrectionsCompanion(
            id: id,
            ratingId: ratingId,
            oldNumericValue: oldNumericValue,
            newNumericValue: newNumericValue,
            oldTextValue: oldTextValue,
            newTextValue: newTextValue,
            oldResultStatus: oldResultStatus,
            newResultStatus: newResultStatus,
            reason: reason,
            correctedByUserId: correctedByUserId,
            correctedAt: correctedAt,
            sessionId: sessionId,
            plotPk: plotPk,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ratingId,
            Value<double?> oldNumericValue = const Value.absent(),
            Value<double?> newNumericValue = const Value.absent(),
            Value<String?> oldTextValue = const Value.absent(),
            Value<String?> newTextValue = const Value.absent(),
            required String oldResultStatus,
            required String newResultStatus,
            required String reason,
            Value<int?> correctedByUserId = const Value.absent(),
            Value<DateTime> correctedAt = const Value.absent(),
            Value<int?> sessionId = const Value.absent(),
            Value<int?> plotPk = const Value.absent(),
          }) =>
              RatingCorrectionsCompanion.insert(
            id: id,
            ratingId: ratingId,
            oldNumericValue: oldNumericValue,
            newNumericValue: newNumericValue,
            oldTextValue: oldTextValue,
            newTextValue: newTextValue,
            oldResultStatus: oldResultStatus,
            newResultStatus: newResultStatus,
            reason: reason,
            correctedByUserId: correctedByUserId,
            correctedAt: correctedAt,
            sessionId: sessionId,
            plotPk: plotPk,
          ),
        ));
}

class $$RatingCorrectionsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $RatingCorrectionsTable> {
  $$RatingCorrectionsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get oldNumericValue => $state.composableBuilder(
      column: $state.table.oldNumericValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get newNumericValue => $state.composableBuilder(
      column: $state.table.newNumericValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get oldTextValue => $state.composableBuilder(
      column: $state.table.oldTextValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get newTextValue => $state.composableBuilder(
      column: $state.table.newTextValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get oldResultStatus => $state.composableBuilder(
      column: $state.table.oldResultStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get newResultStatus => $state.composableBuilder(
      column: $state.table.newResultStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get reason => $state.composableBuilder(
      column: $state.table.reason,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get correctedAt => $state.composableBuilder(
      column: $state.table.correctedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$RatingRecordsTableFilterComposer get ratingId {
    final $$RatingRecordsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.ratingId,
        referencedTable: $state.db.ratingRecords,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$RatingRecordsTableFilterComposer(ComposerState($state.db,
                $state.db.ratingRecords, joinBuilder, parentComposers)));
    return composer;
  }

  $$UsersTableFilterComposer get correctedByUserId {
    final $$UsersTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.correctedByUserId,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableFilterComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
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

class $$RatingCorrectionsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $RatingCorrectionsTable> {
  $$RatingCorrectionsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get oldNumericValue => $state.composableBuilder(
      column: $state.table.oldNumericValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get newNumericValue => $state.composableBuilder(
      column: $state.table.newNumericValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get oldTextValue => $state.composableBuilder(
      column: $state.table.oldTextValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get newTextValue => $state.composableBuilder(
      column: $state.table.newTextValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get oldResultStatus => $state.composableBuilder(
      column: $state.table.oldResultStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get newResultStatus => $state.composableBuilder(
      column: $state.table.newResultStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get reason => $state.composableBuilder(
      column: $state.table.reason,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get correctedAt => $state.composableBuilder(
      column: $state.table.correctedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$RatingRecordsTableOrderingComposer get ratingId {
    final $$RatingRecordsTableOrderingComposer composer =
        $state.composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.ratingId,
            referencedTable: $state.db.ratingRecords,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder, parentComposers) =>
                $$RatingRecordsTableOrderingComposer(ComposerState($state.db,
                    $state.db.ratingRecords, joinBuilder, parentComposers)));
    return composer;
  }

  $$UsersTableOrderingComposer get correctedByUserId {
    final $$UsersTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.correctedByUserId,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
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
  Value<int?> performedByUserId,
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
  Value<int?> performedByUserId,
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
            Value<int?> performedByUserId = const Value.absent(),
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
            performedByUserId: performedByUserId,
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
            Value<int?> performedByUserId = const Value.absent(),
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
            performedByUserId: performedByUserId,
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

  $$UsersTableFilterComposer get performedByUserId {
    final $$UsersTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.performedByUserId,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableFilterComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
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

  $$UsersTableOrderingComposer get performedByUserId {
    final $$UsersTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.performedByUserId,
        referencedTable: $state.db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) => $$UsersTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.users, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$ImportEventsTableCreateCompanionBuilder = ImportEventsCompanion
    Function({
  Value<int> id,
  required int trialId,
  required String fileName,
  Value<String?> savedFilePath,
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
  Value<String?> savedFilePath,
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
            Value<String?> savedFilePath = const Value.absent(),
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
            savedFilePath: savedFilePath,
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
            Value<String?> savedFilePath = const Value.absent(),
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
            savedFilePath: savedFilePath,
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

  ColumnFilters<String> get savedFilePath => $state.composableBuilder(
      column: $state.table.savedFilePath,
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

  ColumnOrderings<String> get savedFilePath => $state.composableBuilder(
      column: $state.table.savedFilePath,
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
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$TrialsTableTableManager get trials =>
      $$TrialsTableTableManager(_db, _db.trials);
  $$TreatmentsTableTableManager get treatments =>
      $$TreatmentsTableTableManager(_db, _db.treatments);
  $$TreatmentComponentsTableTableManager get treatmentComponents =>
      $$TreatmentComponentsTableTableManager(_db, _db.treatmentComponents);
  $$AssessmentsTableTableManager get assessments =>
      $$AssessmentsTableTableManager(_db, _db.assessments);
  $$AssessmentDefinitionsTableTableManager get assessmentDefinitions =>
      $$AssessmentDefinitionsTableTableManager(_db, _db.assessmentDefinitions);
  $$TrialAssessmentsTableTableManager get trialAssessments =>
      $$TrialAssessmentsTableTableManager(_db, _db.trialAssessments);
  $$PlotsTableTableManager get plots =>
      $$PlotsTableTableManager(_db, _db.plots);
  $$AssignmentsTableTableManager get assignments =>
      $$AssignmentsTableTableManager(_db, _db.assignments);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionAssessmentsTableTableManager get sessionAssessments =>
      $$SessionAssessmentsTableTableManager(_db, _db.sessionAssessments);
  $$RatingRecordsTableTableManager get ratingRecords =>
      $$RatingRecordsTableTableManager(_db, _db.ratingRecords);
  $$RatingCorrectionsTableTableManager get ratingCorrections =>
      $$RatingCorrectionsTableTableManager(_db, _db.ratingCorrections);
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
