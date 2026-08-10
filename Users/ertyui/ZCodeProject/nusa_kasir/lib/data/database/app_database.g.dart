// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  const Category({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(id: Value(id), name: Value(name));
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Category copyWith({int? id, String? name}) =>
      Category(id: id ?? this.id, name: name ?? this.name);
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category && other.id == this.id && other.name == this.name);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  CategoriesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return CategoriesCompanion(id: id ?? this.id, name: name ?? this.name);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Lainnya'),
  );
  static const VerificationMeta _buyPriceMeta = const VerificationMeta(
    'buyPrice',
  );
  @override
  late final GeneratedColumn<int> buyPrice = GeneratedColumn<int>(
    'buy_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sellPriceMeta = const VerificationMeta(
    'sellPrice',
  );
  @override
  late final GeneratedColumn<int> sellPrice = GeneratedColumn<int>(
    'sell_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockMeta = const VerificationMeta('stock');
  @override
  late final GeneratedColumn<int> stock = GeneratedColumn<int>(
    'stock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minStockMeta = const VerificationMeta(
    'minStock',
  );
  @override
  late final GeneratedColumn<int> minStock = GeneratedColumn<int>(
    'min_stock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOnlineMeta = const VerificationMeta(
    'isOnline',
  );
  @override
  late final GeneratedColumn<bool> isOnline = GeneratedColumn<bool>(
    'is_online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_online" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productTypeMeta = const VerificationMeta(
    'productType',
  );
  @override
  late final GeneratedColumn<String> productType = GeneratedColumn<String>(
    'product_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variantsJsonMeta = const VerificationMeta(
    'variantsJson',
  );
  @override
  late final GeneratedColumn<String> variantsJson = GeneratedColumn<String>(
    'variants_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wholesaleJsonMeta = const VerificationMeta(
    'wholesaleJson',
  );
  @override
  late final GeneratedColumn<String> wholesaleJson = GeneratedColumn<String>(
    'wholesale_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceTypeMeta = const VerificationMeta(
    'priceType',
  );
  @override
  late final GeneratedColumn<String> priceType = GeneratedColumn<String>(
    'price_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pcs'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sku,
    barcode,
    category,
    buyPrice,
    sellPrice,
    stock,
    minStock,
    imagePath,
    isOnline,
    expiryDate,
    productType,
    variantsJson,
    wholesaleJson,
    priceType,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('buy_price')) {
      context.handle(
        _buyPriceMeta,
        buyPrice.isAcceptableOrUnknown(data['buy_price']!, _buyPriceMeta),
      );
    }
    if (data.containsKey('sell_price')) {
      context.handle(
        _sellPriceMeta,
        sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_sellPriceMeta);
    }
    if (data.containsKey('stock')) {
      context.handle(
        _stockMeta,
        stock.isAcceptableOrUnknown(data['stock']!, _stockMeta),
      );
    }
    if (data.containsKey('min_stock')) {
      context.handle(
        _minStockMeta,
        minStock.isAcceptableOrUnknown(data['min_stock']!, _minStockMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('is_online')) {
      context.handle(
        _isOnlineMeta,
        isOnline.isAcceptableOrUnknown(data['is_online']!, _isOnlineMeta),
      );
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('product_type')) {
      context.handle(
        _productTypeMeta,
        productType.isAcceptableOrUnknown(
          data['product_type']!,
          _productTypeMeta,
        ),
      );
    }
    if (data.containsKey('variants_json')) {
      context.handle(
        _variantsJsonMeta,
        variantsJson.isAcceptableOrUnknown(
          data['variants_json']!,
          _variantsJsonMeta,
        ),
      );
    }
    if (data.containsKey('wholesale_json')) {
      context.handle(
        _wholesaleJsonMeta,
        wholesaleJson.isAcceptableOrUnknown(
          data['wholesale_json']!,
          _wholesaleJsonMeta,
        ),
      );
    }
    if (data.containsKey('price_type')) {
      context.handle(
        _priceTypeMeta,
        priceType.isAcceptableOrUnknown(data['price_type']!, _priceTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      buyPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buy_price'],
      )!,
      sellPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sell_price'],
      )!,
      stock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock'],
      )!,
      minStock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_stock'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      isOnline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_online'],
      )!,
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expiry_date'],
      ),
      productType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_type'],
      ),
      variantsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variants_json'],
      ),
      wholesaleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wholesale_json'],
      ),
      priceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;
  final String name;
  final String? sku;
  final String? barcode;
  final String category;
  final int buyPrice;
  final int sellPrice;
  final int stock;
  final int minStock;
  final String? imagePath;
  final bool isOnline;
  final DateTime? expiryDate;
  final String? productType;
  final String? variantsJson;
  final String? wholesaleJson;
  final String priceType;
  final DateTime createdAt;
  const Product({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.category,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    required this.minStock,
    this.imagePath,
    required this.isOnline,
    this.expiryDate,
    this.productType,
    this.variantsJson,
    this.wholesaleJson,
    required this.priceType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['category'] = Variable<String>(category);
    map['buy_price'] = Variable<int>(buyPrice);
    map['sell_price'] = Variable<int>(sellPrice);
    map['stock'] = Variable<int>(stock);
    map['min_stock'] = Variable<int>(minStock);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['is_online'] = Variable<bool>(isOnline);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    if (!nullToAbsent || productType != null) {
      map['product_type'] = Variable<String>(productType);
    }
    if (!nullToAbsent || variantsJson != null) {
      map['variants_json'] = Variable<String>(variantsJson);
    }
    if (!nullToAbsent || wholesaleJson != null) {
      map['wholesale_json'] = Variable<String>(wholesaleJson);
    }
    map['price_type'] = Variable<String>(priceType);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      category: Value(category),
      buyPrice: Value(buyPrice),
      sellPrice: Value(sellPrice),
      stock: Value(stock),
      minStock: Value(minStock),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      isOnline: Value(isOnline),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      productType: productType == null && nullToAbsent
          ? const Value.absent()
          : Value(productType),
      variantsJson: variantsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(variantsJson),
      wholesaleJson: wholesaleJson == null && nullToAbsent
          ? const Value.absent()
          : Value(wholesaleJson),
      priceType: Value(priceType),
      createdAt: Value(createdAt),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      category: serializer.fromJson<String>(json['category']),
      buyPrice: serializer.fromJson<int>(json['buyPrice']),
      sellPrice: serializer.fromJson<int>(json['sellPrice']),
      stock: serializer.fromJson<int>(json['stock']),
      minStock: serializer.fromJson<int>(json['minStock']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      isOnline: serializer.fromJson<bool>(json['isOnline']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      productType: serializer.fromJson<String?>(json['productType']),
      variantsJson: serializer.fromJson<String?>(json['variantsJson']),
      wholesaleJson: serializer.fromJson<String?>(json['wholesaleJson']),
      priceType: serializer.fromJson<String>(json['priceType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'barcode': serializer.toJson<String?>(barcode),
      'category': serializer.toJson<String>(category),
      'buyPrice': serializer.toJson<int>(buyPrice),
      'sellPrice': serializer.toJson<int>(sellPrice),
      'stock': serializer.toJson<int>(stock),
      'minStock': serializer.toJson<int>(minStock),
      'imagePath': serializer.toJson<String?>(imagePath),
      'isOnline': serializer.toJson<bool>(isOnline),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'productType': serializer.toJson<String?>(productType),
      'variantsJson': serializer.toJson<String?>(variantsJson),
      'wholesaleJson': serializer.toJson<String?>(wholesaleJson),
      'priceType': serializer.toJson<String>(priceType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Product copyWith({
    int? id,
    String? name,
    Value<String?> sku = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    String? category,
    int? buyPrice,
    int? sellPrice,
    int? stock,
    int? minStock,
    Value<String?> imagePath = const Value.absent(),
    bool? isOnline,
    Value<DateTime?> expiryDate = const Value.absent(),
    Value<String?> productType = const Value.absent(),
    Value<String?> variantsJson = const Value.absent(),
    Value<String?> wholesaleJson = const Value.absent(),
    String? priceType,
    DateTime? createdAt,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    sku: sku.present ? sku.value : this.sku,
    barcode: barcode.present ? barcode.value : this.barcode,
    category: category ?? this.category,
    buyPrice: buyPrice ?? this.buyPrice,
    sellPrice: sellPrice ?? this.sellPrice,
    stock: stock ?? this.stock,
    minStock: minStock ?? this.minStock,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    isOnline: isOnline ?? this.isOnline,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    productType: productType.present ? productType.value : this.productType,
    variantsJson: variantsJson.present ? variantsJson.value : this.variantsJson,
    wholesaleJson: wholesaleJson.present
        ? wholesaleJson.value
        : this.wholesaleJson,
    priceType: priceType ?? this.priceType,
    createdAt: createdAt ?? this.createdAt,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      category: data.category.present ? data.category.value : this.category,
      buyPrice: data.buyPrice.present ? data.buyPrice.value : this.buyPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      stock: data.stock.present ? data.stock.value : this.stock,
      minStock: data.minStock.present ? data.minStock.value : this.minStock,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      isOnline: data.isOnline.present ? data.isOnline.value : this.isOnline,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      productType: data.productType.present
          ? data.productType.value
          : this.productType,
      variantsJson: data.variantsJson.present
          ? data.variantsJson.value
          : this.variantsJson,
      wholesaleJson: data.wholesaleJson.present
          ? data.wholesaleJson.value
          : this.wholesaleJson,
      priceType: data.priceType.present ? data.priceType.value : this.priceType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('category: $category, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('stock: $stock, ')
          ..write('minStock: $minStock, ')
          ..write('imagePath: $imagePath, ')
          ..write('isOnline: $isOnline, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('productType: $productType, ')
          ..write('variantsJson: $variantsJson, ')
          ..write('wholesaleJson: $wholesaleJson, ')
          ..write('priceType: $priceType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sku,
    barcode,
    category,
    buyPrice,
    sellPrice,
    stock,
    minStock,
    imagePath,
    isOnline,
    expiryDate,
    productType,
    variantsJson,
    wholesaleJson,
    priceType,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.barcode == this.barcode &&
          other.category == this.category &&
          other.buyPrice == this.buyPrice &&
          other.sellPrice == this.sellPrice &&
          other.stock == this.stock &&
          other.minStock == this.minStock &&
          other.imagePath == this.imagePath &&
          other.isOnline == this.isOnline &&
          other.expiryDate == this.expiryDate &&
          other.productType == this.productType &&
          other.variantsJson == this.variantsJson &&
          other.wholesaleJson == this.wholesaleJson &&
          other.priceType == this.priceType &&
          other.createdAt == this.createdAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> sku;
  final Value<String?> barcode;
  final Value<String> category;
  final Value<int> buyPrice;
  final Value<int> sellPrice;
  final Value<int> stock;
  final Value<int> minStock;
  final Value<String?> imagePath;
  final Value<bool> isOnline;
  final Value<DateTime?> expiryDate;
  final Value<String?> productType;
  final Value<String?> variantsJson;
  final Value<String?> wholesaleJson;
  final Value<String> priceType;
  final Value<DateTime> createdAt;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.category = const Value.absent(),
    this.buyPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.stock = const Value.absent(),
    this.minStock = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.productType = const Value.absent(),
    this.variantsJson = const Value.absent(),
    this.wholesaleJson = const Value.absent(),
    this.priceType = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.category = const Value.absent(),
    this.buyPrice = const Value.absent(),
    required int sellPrice,
    this.stock = const Value.absent(),
    this.minStock = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.productType = const Value.absent(),
    this.variantsJson = const Value.absent(),
    this.wholesaleJson = const Value.absent(),
    this.priceType = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       sellPrice = Value(sellPrice);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? barcode,
    Expression<String>? category,
    Expression<int>? buyPrice,
    Expression<int>? sellPrice,
    Expression<int>? stock,
    Expression<int>? minStock,
    Expression<String>? imagePath,
    Expression<bool>? isOnline,
    Expression<DateTime>? expiryDate,
    Expression<String>? productType,
    Expression<String>? variantsJson,
    Expression<String>? wholesaleJson,
    Expression<String>? priceType,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (category != null) 'category': category,
      if (buyPrice != null) 'buy_price': buyPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (stock != null) 'stock': stock,
      if (minStock != null) 'min_stock': minStock,
      if (imagePath != null) 'image_path': imagePath,
      if (isOnline != null) 'is_online': isOnline,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (productType != null) 'product_type': productType,
      if (variantsJson != null) 'variants_json': variantsJson,
      if (wholesaleJson != null) 'wholesale_json': wholesaleJson,
      if (priceType != null) 'price_type': priceType,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ProductsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? sku,
    Value<String?>? barcode,
    Value<String>? category,
    Value<int>? buyPrice,
    Value<int>? sellPrice,
    Value<int>? stock,
    Value<int>? minStock,
    Value<String?>? imagePath,
    Value<bool>? isOnline,
    Value<DateTime?>? expiryDate,
    Value<String?>? productType,
    Value<String?>? variantsJson,
    Value<String?>? wholesaleJson,
    Value<String>? priceType,
    Value<DateTime>? createdAt,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      imagePath: imagePath ?? this.imagePath,
      isOnline: isOnline ?? this.isOnline,
      expiryDate: expiryDate ?? this.expiryDate,
      productType: productType ?? this.productType,
      variantsJson: variantsJson ?? this.variantsJson,
      wholesaleJson: wholesaleJson ?? this.wholesaleJson,
      priceType: priceType ?? this.priceType,
      createdAt: createdAt ?? this.createdAt,
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
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (buyPrice.present) {
      map['buy_price'] = Variable<int>(buyPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<int>(sellPrice.value);
    }
    if (stock.present) {
      map['stock'] = Variable<int>(stock.value);
    }
    if (minStock.present) {
      map['min_stock'] = Variable<int>(minStock.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (isOnline.present) {
      map['is_online'] = Variable<bool>(isOnline.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (productType.present) {
      map['product_type'] = Variable<String>(productType.value);
    }
    if (variantsJson.present) {
      map['variants_json'] = Variable<String>(variantsJson.value);
    }
    if (wholesaleJson.present) {
      map['wholesale_json'] = Variable<String>(wholesaleJson.value);
    }
    if (priceType.present) {
      map['price_type'] = Variable<String>(priceType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('category: $category, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('stock: $stock, ')
          ..write('minStock: $minStock, ')
          ..write('imagePath: $imagePath, ')
          ..write('isOnline: $isOnline, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('productType: $productType, ')
          ..write('variantsJson: $variantsJson, ')
          ..write('wholesaleJson: $wholesaleJson, ')
          ..write('priceType: $priceType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTable extends StockMovements
    with TableInfo<$StockMovementsTable, StockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, productId, type, qty, note, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $StockMovementsTable createAlias(String alias) {
    return $StockMovementsTable(attachedDatabase, alias);
  }
}

class StockMovement extends DataClass implements Insertable<StockMovement> {
  final int id;
  final int productId;
  final String type;
  final int qty;
  final String? note;
  final DateTime date;
  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.qty,
    this.note,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['type'] = Variable<String>(type);
    map['qty'] = Variable<int>(qty);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      type: Value(type),
      qty: Value(qty),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      date: Value(date),
    );
  }

  factory StockMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovement(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      type: serializer.fromJson<String>(json['type']),
      qty: serializer.fromJson<int>(json['qty']),
      note: serializer.fromJson<String?>(json['note']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'type': serializer.toJson<String>(type),
      'qty': serializer.toJson<int>(qty),
      'note': serializer.toJson<String?>(note),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  StockMovement copyWith({
    int? id,
    int? productId,
    String? type,
    int? qty,
    Value<String?> note = const Value.absent(),
    DateTime? date,
  }) => StockMovement(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    type: type ?? this.type,
    qty: qty ?? this.qty,
    note: note.present ? note.value : this.note,
    date: date ?? this.date,
  );
  StockMovement copyWithCompanion(StockMovementsCompanion data) {
    return StockMovement(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      type: data.type.present ? data.type.value : this.type,
      qty: data.qty.present ? data.qty.value : this.qty,
      note: data.note.present ? data.note.value : this.note,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovement(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('type: $type, ')
          ..write('qty: $qty, ')
          ..write('note: $note, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, type, qty, note, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovement &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.type == this.type &&
          other.qty == this.qty &&
          other.note == this.note &&
          other.date == this.date);
}

class StockMovementsCompanion extends UpdateCompanion<StockMovement> {
  final Value<int> id;
  final Value<int> productId;
  final Value<String> type;
  final Value<int> qty;
  final Value<String?> note;
  final Value<DateTime> date;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.type = const Value.absent(),
    this.qty = const Value.absent(),
    this.note = const Value.absent(),
    this.date = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required String type,
    required int qty,
    this.note = const Value.absent(),
    this.date = const Value.absent(),
  }) : productId = Value(productId),
       type = Value(type),
       qty = Value(qty);
  static Insertable<StockMovement> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<String>? type,
    Expression<int>? qty,
    Expression<String>? note,
    Expression<DateTime>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (type != null) 'type': type,
      if (qty != null) 'qty': qty,
      if (note != null) 'note': note,
      if (date != null) 'date': date,
    });
  }

  StockMovementsCompanion copyWith({
    Value<int>? id,
    Value<int>? productId,
    Value<String>? type,
    Value<int>? qty,
    Value<String?>? note,
    Value<DateTime>? date,
  }) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      qty: qty ?? this.qty,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('type: $type, ')
          ..write('qty: $qty, ')
          ..write('note: $note, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _invoiceMeta = const VerificationMeta(
    'invoice',
  );
  @override
  late final GeneratedColumn<String> invoice = GeneratedColumn<String>(
    'invoice',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<int> discount = GeneratedColumn<int>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tunai'),
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<int> customerId = GeneratedColumn<int>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashGivenMeta = const VerificationMeta(
    'cashGiven',
  );
  @override
  late final GeneratedColumn<int> cashGiven = GeneratedColumn<int>(
    'cash_given',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashReturnMeta = const VerificationMeta(
    'cashReturn',
  );
  @override
  late final GeneratedColumn<int> cashReturn = GeneratedColumn<int>(
    'cash_return',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashierNameMeta = const VerificationMeta(
    'cashierName',
  );
  @override
  late final GeneratedColumn<String> cashierName = GeneratedColumn<String>(
    'cashier_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchIdMeta = const VerificationMeta(
    'branchId',
  );
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Normal'),
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<DateTime> voidedAt = GeneratedColumn<DateTime>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderTypeMeta = const VerificationMeta(
    'orderType',
  );
  @override
  late final GeneratedColumn<String> orderType = GeneratedColumn<String>(
    'order_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tableIdMeta = const VerificationMeta(
    'tableId',
  );
  @override
  late final GeneratedColumn<int> tableId = GeneratedColumn<int>(
    'table_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    invoice,
    date,
    items,
    total,
    discount,
    paymentMethod,
    customerId,
    cashGiven,
    cashReturn,
    cashierName,
    branchId,
    status,
    voidReason,
    voidedAt,
    orderType,
    tableId,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('invoice')) {
      context.handle(
        _invoiceMeta,
        invoice.isAcceptableOrUnknown(data['invoice']!, _invoiceMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('cash_given')) {
      context.handle(
        _cashGivenMeta,
        cashGiven.isAcceptableOrUnknown(data['cash_given']!, _cashGivenMeta),
      );
    }
    if (data.containsKey('cash_return')) {
      context.handle(
        _cashReturnMeta,
        cashReturn.isAcceptableOrUnknown(data['cash_return']!, _cashReturnMeta),
      );
    }
    if (data.containsKey('cashier_name')) {
      context.handle(
        _cashierNameMeta,
        cashierName.isAcceptableOrUnknown(
          data['cashier_name']!,
          _cashierNameMeta,
        ),
      );
    }
    if (data.containsKey('branch_id')) {
      context.handle(
        _branchIdMeta,
        branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('order_type')) {
      context.handle(
        _orderTypeMeta,
        orderType.isAcceptableOrUnknown(data['order_type']!, _orderTypeMeta),
      );
    }
    if (data.containsKey('table_id')) {
      context.handle(
        _tableIdMeta,
        tableId.isAcceptableOrUnknown(data['table_id']!, _tableIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      invoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}customer_id'],
      ),
      cashGiven: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cash_given'],
      ),
      cashReturn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cash_return'],
      ),
      cashierName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashier_name'],
      ),
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}voided_at'],
      ),
      orderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_type'],
      ),
      tableId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}table_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final String invoice;
  final DateTime date;
  final String items;
  final int total;
  final int discount;
  final String paymentMethod;
  final int? customerId;
  final int? cashGiven;
  final int? cashReturn;
  final String? cashierName;
  final int? branchId;
  final String status;
  final String? voidReason;
  final DateTime? voidedAt;
  final String? orderType;
  final int? tableId;
  final String? notes;
  const Transaction({
    required this.id,
    required this.invoice,
    required this.date,
    required this.items,
    required this.total,
    required this.discount,
    required this.paymentMethod,
    this.customerId,
    this.cashGiven,
    this.cashReturn,
    this.cashierName,
    this.branchId,
    required this.status,
    this.voidReason,
    this.voidedAt,
    this.orderType,
    this.tableId,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['invoice'] = Variable<String>(invoice);
    map['date'] = Variable<DateTime>(date);
    map['items'] = Variable<String>(items);
    map['total'] = Variable<int>(total);
    map['discount'] = Variable<int>(discount);
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<int>(customerId);
    }
    if (!nullToAbsent || cashGiven != null) {
      map['cash_given'] = Variable<int>(cashGiven);
    }
    if (!nullToAbsent || cashReturn != null) {
      map['cash_return'] = Variable<int>(cashReturn);
    }
    if (!nullToAbsent || cashierName != null) {
      map['cashier_name'] = Variable<String>(cashierName);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<DateTime>(voidedAt);
    }
    if (!nullToAbsent || orderType != null) {
      map['order_type'] = Variable<String>(orderType);
    }
    if (!nullToAbsent || tableId != null) {
      map['table_id'] = Variable<int>(tableId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      invoice: Value(invoice),
      date: Value(date),
      items: Value(items),
      total: Value(total),
      discount: Value(discount),
      paymentMethod: Value(paymentMethod),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      cashGiven: cashGiven == null && nullToAbsent
          ? const Value.absent()
          : Value(cashGiven),
      cashReturn: cashReturn == null && nullToAbsent
          ? const Value.absent()
          : Value(cashReturn),
      cashierName: cashierName == null && nullToAbsent
          ? const Value.absent()
          : Value(cashierName),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      status: Value(status),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      orderType: orderType == null && nullToAbsent
          ? const Value.absent()
          : Value(orderType),
      tableId: tableId == null && nullToAbsent
          ? const Value.absent()
          : Value(tableId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      invoice: serializer.fromJson<String>(json['invoice']),
      date: serializer.fromJson<DateTime>(json['date']),
      items: serializer.fromJson<String>(json['items']),
      total: serializer.fromJson<int>(json['total']),
      discount: serializer.fromJson<int>(json['discount']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      customerId: serializer.fromJson<int?>(json['customerId']),
      cashGiven: serializer.fromJson<int?>(json['cashGiven']),
      cashReturn: serializer.fromJson<int?>(json['cashReturn']),
      cashierName: serializer.fromJson<String?>(json['cashierName']),
      branchId: serializer.fromJson<int?>(json['branchId']),
      status: serializer.fromJson<String>(json['status']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      voidedAt: serializer.fromJson<DateTime?>(json['voidedAt']),
      orderType: serializer.fromJson<String?>(json['orderType']),
      tableId: serializer.fromJson<int?>(json['tableId']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'invoice': serializer.toJson<String>(invoice),
      'date': serializer.toJson<DateTime>(date),
      'items': serializer.toJson<String>(items),
      'total': serializer.toJson<int>(total),
      'discount': serializer.toJson<int>(discount),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'customerId': serializer.toJson<int?>(customerId),
      'cashGiven': serializer.toJson<int?>(cashGiven),
      'cashReturn': serializer.toJson<int?>(cashReturn),
      'cashierName': serializer.toJson<String?>(cashierName),
      'branchId': serializer.toJson<int?>(branchId),
      'status': serializer.toJson<String>(status),
      'voidReason': serializer.toJson<String?>(voidReason),
      'voidedAt': serializer.toJson<DateTime?>(voidedAt),
      'orderType': serializer.toJson<String?>(orderType),
      'tableId': serializer.toJson<int?>(tableId),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Transaction copyWith({
    int? id,
    String? invoice,
    DateTime? date,
    String? items,
    int? total,
    int? discount,
    String? paymentMethod,
    Value<int?> customerId = const Value.absent(),
    Value<int?> cashGiven = const Value.absent(),
    Value<int?> cashReturn = const Value.absent(),
    Value<String?> cashierName = const Value.absent(),
    Value<int?> branchId = const Value.absent(),
    String? status,
    Value<String?> voidReason = const Value.absent(),
    Value<DateTime?> voidedAt = const Value.absent(),
    Value<String?> orderType = const Value.absent(),
    Value<int?> tableId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    invoice: invoice ?? this.invoice,
    date: date ?? this.date,
    items: items ?? this.items,
    total: total ?? this.total,
    discount: discount ?? this.discount,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    customerId: customerId.present ? customerId.value : this.customerId,
    cashGiven: cashGiven.present ? cashGiven.value : this.cashGiven,
    cashReturn: cashReturn.present ? cashReturn.value : this.cashReturn,
    cashierName: cashierName.present ? cashierName.value : this.cashierName,
    branchId: branchId.present ? branchId.value : this.branchId,
    status: status ?? this.status,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    orderType: orderType.present ? orderType.value : this.orderType,
    tableId: tableId.present ? tableId.value : this.tableId,
    notes: notes.present ? notes.value : this.notes,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      invoice: data.invoice.present ? data.invoice.value : this.invoice,
      date: data.date.present ? data.date.value : this.date,
      items: data.items.present ? data.items.value : this.items,
      total: data.total.present ? data.total.value : this.total,
      discount: data.discount.present ? data.discount.value : this.discount,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      cashGiven: data.cashGiven.present ? data.cashGiven.value : this.cashGiven,
      cashReturn: data.cashReturn.present
          ? data.cashReturn.value
          : this.cashReturn,
      cashierName: data.cashierName.present
          ? data.cashierName.value
          : this.cashierName,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      status: data.status.present ? data.status.value : this.status,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      orderType: data.orderType.present ? data.orderType.value : this.orderType,
      tableId: data.tableId.present ? data.tableId.value : this.tableId,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('invoice: $invoice, ')
          ..write('date: $date, ')
          ..write('items: $items, ')
          ..write('total: $total, ')
          ..write('discount: $discount, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('customerId: $customerId, ')
          ..write('cashGiven: $cashGiven, ')
          ..write('cashReturn: $cashReturn, ')
          ..write('cashierName: $cashierName, ')
          ..write('branchId: $branchId, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('orderType: $orderType, ')
          ..write('tableId: $tableId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    invoice,
    date,
    items,
    total,
    discount,
    paymentMethod,
    customerId,
    cashGiven,
    cashReturn,
    cashierName,
    branchId,
    status,
    voidReason,
    voidedAt,
    orderType,
    tableId,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.invoice == this.invoice &&
          other.date == this.date &&
          other.items == this.items &&
          other.total == this.total &&
          other.discount == this.discount &&
          other.paymentMethod == this.paymentMethod &&
          other.customerId == this.customerId &&
          other.cashGiven == this.cashGiven &&
          other.cashReturn == this.cashReturn &&
          other.cashierName == this.cashierName &&
          other.branchId == this.branchId &&
          other.status == this.status &&
          other.voidReason == this.voidReason &&
          other.voidedAt == this.voidedAt &&
          other.orderType == this.orderType &&
          other.tableId == this.tableId &&
          other.notes == this.notes);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<String> invoice;
  final Value<DateTime> date;
  final Value<String> items;
  final Value<int> total;
  final Value<int> discount;
  final Value<String> paymentMethod;
  final Value<int?> customerId;
  final Value<int?> cashGiven;
  final Value<int?> cashReturn;
  final Value<String?> cashierName;
  final Value<int?> branchId;
  final Value<String> status;
  final Value<String?> voidReason;
  final Value<DateTime?> voidedAt;
  final Value<String?> orderType;
  final Value<int?> tableId;
  final Value<String?> notes;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.invoice = const Value.absent(),
    this.date = const Value.absent(),
    this.items = const Value.absent(),
    this.total = const Value.absent(),
    this.discount = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.customerId = const Value.absent(),
    this.cashGiven = const Value.absent(),
    this.cashReturn = const Value.absent(),
    this.cashierName = const Value.absent(),
    this.branchId = const Value.absent(),
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.orderType = const Value.absent(),
    this.tableId = const Value.absent(),
    this.notes = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String invoice,
    this.date = const Value.absent(),
    required String items,
    this.total = const Value.absent(),
    this.discount = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.customerId = const Value.absent(),
    this.cashGiven = const Value.absent(),
    this.cashReturn = const Value.absent(),
    this.cashierName = const Value.absent(),
    this.branchId = const Value.absent(),
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.orderType = const Value.absent(),
    this.tableId = const Value.absent(),
    this.notes = const Value.absent(),
  }) : invoice = Value(invoice),
       items = Value(items);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<String>? invoice,
    Expression<DateTime>? date,
    Expression<String>? items,
    Expression<int>? total,
    Expression<int>? discount,
    Expression<String>? paymentMethod,
    Expression<int>? customerId,
    Expression<int>? cashGiven,
    Expression<int>? cashReturn,
    Expression<String>? cashierName,
    Expression<int>? branchId,
    Expression<String>? status,
    Expression<String>? voidReason,
    Expression<DateTime>? voidedAt,
    Expression<String>? orderType,
    Expression<int>? tableId,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoice != null) 'invoice': invoice,
      if (date != null) 'date': date,
      if (items != null) 'items': items,
      if (total != null) 'total': total,
      if (discount != null) 'discount': discount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (customerId != null) 'customer_id': customerId,
      if (cashGiven != null) 'cash_given': cashGiven,
      if (cashReturn != null) 'cash_return': cashReturn,
      if (cashierName != null) 'cashier_name': cashierName,
      if (branchId != null) 'branch_id': branchId,
      if (status != null) 'status': status,
      if (voidReason != null) 'void_reason': voidReason,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (orderType != null) 'order_type': orderType,
      if (tableId != null) 'table_id': tableId,
      if (notes != null) 'notes': notes,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? invoice,
    Value<DateTime>? date,
    Value<String>? items,
    Value<int>? total,
    Value<int>? discount,
    Value<String>? paymentMethod,
    Value<int?>? customerId,
    Value<int?>? cashGiven,
    Value<int?>? cashReturn,
    Value<String?>? cashierName,
    Value<int?>? branchId,
    Value<String>? status,
    Value<String?>? voidReason,
    Value<DateTime?>? voidedAt,
    Value<String?>? orderType,
    Value<int?>? tableId,
    Value<String?>? notes,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      invoice: invoice ?? this.invoice,
      date: date ?? this.date,
      items: items ?? this.items,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      cashGiven: cashGiven ?? this.cashGiven,
      cashReturn: cashReturn ?? this.cashReturn,
      cashierName: cashierName ?? this.cashierName,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      voidedAt: voidedAt ?? this.voidedAt,
      orderType: orderType ?? this.orderType,
      tableId: tableId ?? this.tableId,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (invoice.present) {
      map['invoice'] = Variable<String>(invoice.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (discount.present) {
      map['discount'] = Variable<int>(discount.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<int>(customerId.value);
    }
    if (cashGiven.present) {
      map['cash_given'] = Variable<int>(cashGiven.value);
    }
    if (cashReturn.present) {
      map['cash_return'] = Variable<int>(cashReturn.value);
    }
    if (cashierName.present) {
      map['cashier_name'] = Variable<String>(cashierName.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<DateTime>(voidedAt.value);
    }
    if (orderType.present) {
      map['order_type'] = Variable<String>(orderType.value);
    }
    if (tableId.present) {
      map['table_id'] = Variable<int>(tableId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('invoice: $invoice, ')
          ..write('date: $date, ')
          ..write('items: $items, ')
          ..write('total: $total, ')
          ..write('discount: $discount, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('customerId: $customerId, ')
          ..write('cashGiven: $cashGiven, ')
          ..write('cashReturn: $cashReturn, ')
          ..write('cashierName: $cashierName, ')
          ..write('branchId: $branchId, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('orderType: $orderType, ')
          ..write('tableId: $tableId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalSpentMeta = const VerificationMeta(
    'totalSpent',
  );
  @override
  late final GeneratedColumn<int> totalSpent = GeneratedColumn<int>(
    'total_spent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Silver'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    address,
    points,
    totalSpent,
    level,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('total_spent')) {
      context.handle(
        _totalSpentMeta,
        totalSpent.isAcceptableOrUnknown(data['total_spent']!, _totalSpentMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      totalSpent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_spent'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final int points;
  final int totalSpent;
  final String level;
  final DateTime createdAt;
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.points,
    required this.totalSpent,
    required this.level,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['points'] = Variable<int>(points);
    map['total_spent'] = Variable<int>(totalSpent);
    map['level'] = Variable<String>(level);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      points: Value(points),
      totalSpent: Value(totalSpent),
      level: Value(level),
      createdAt: Value(createdAt),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      points: serializer.fromJson<int>(json['points']),
      totalSpent: serializer.fromJson<int>(json['totalSpent']),
      level: serializer.fromJson<String>(json['level']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'points': serializer.toJson<int>(points),
      'totalSpent': serializer.toJson<int>(totalSpent),
      'level': serializer.toJson<String>(level),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    int? points,
    int? totalSpent,
    String? level,
    DateTime? createdAt,
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    points: points ?? this.points,
    totalSpent: totalSpent ?? this.totalSpent,
    level: level ?? this.level,
    createdAt: createdAt ?? this.createdAt,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      points: data.points.present ? data.points.value : this.points,
      totalSpent: data.totalSpent.present
          ? data.totalSpent.value
          : this.totalSpent,
      level: data.level.present ? data.level.value : this.level,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('points: $points, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('level: $level, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    address,
    points,
    totalSpent,
    level,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.points == this.points &&
          other.totalSpent == this.totalSpent &&
          other.level == this.level &&
          other.createdAt == this.createdAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<int> points;
  final Value<int> totalSpent;
  final Value<String> level;
  final Value<DateTime> createdAt;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.points = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.level = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CustomersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.points = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.level = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Customer> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<int>? points,
    Expression<int>? totalSpent,
    Expression<String>? level,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (points != null) 'points': points,
      if (totalSpent != null) 'total_spent': totalSpent,
      if (level != null) 'level': level,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CustomersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? address,
    Value<int>? points,
    Value<int>? totalSpent,
    Value<String>? level,
    Value<DateTime>? createdAt,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      points: points ?? this.points,
      totalSpent: totalSpent ?? this.totalSpent,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
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
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (totalSpent.present) {
      map['total_spent'] = Variable<int>(totalSpent.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('points: $points, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('level: $level, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PromosTable extends Promos with TableInfo<$PromosTable, Promo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PromosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minBelanjaMeta = const VerificationMeta(
    'minBelanja',
  );
  @override
  late final GeneratedColumn<int> minBelanja = GeneratedColumn<int>(
    'min_belanja',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxUsesMeta = const VerificationMeta(
    'maxUses',
  );
  @override
  late final GeneratedColumn<int> maxUses = GeneratedColumn<int>(
    'max_uses',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usedCountMeta = const VerificationMeta(
    'usedCount',
  );
  @override
  late final GeneratedColumn<int> usedCount = GeneratedColumn<int>(
    'used_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Aktif'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    code,
    type,
    value,
    minBelanja,
    startDate,
    endDate,
    maxUses,
    usedCount,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'promos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Promo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('min_belanja')) {
      context.handle(
        _minBelanjaMeta,
        minBelanja.isAcceptableOrUnknown(data['min_belanja']!, _minBelanjaMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('max_uses')) {
      context.handle(
        _maxUsesMeta,
        maxUses.isAcceptableOrUnknown(data['max_uses']!, _maxUsesMeta),
      );
    }
    if (data.containsKey('used_count')) {
      context.handle(
        _usedCountMeta,
        usedCount.isAcceptableOrUnknown(data['used_count']!, _usedCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Promo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Promo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
      minBelanja: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_belanja'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      maxUses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_uses'],
      ),
      usedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $PromosTable createAlias(String alias) {
    return $PromosTable(attachedDatabase, alias);
  }
}

class Promo extends DataClass implements Insertable<Promo> {
  final int id;
  final String name;
  final String code;
  final String type;
  final int value;
  final int minBelanja;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxUses;
  final int usedCount;
  final String status;
  const Promo({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.value,
    required this.minBelanja,
    this.startDate,
    this.endDate,
    this.maxUses,
    required this.usedCount,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['type'] = Variable<String>(type);
    map['value'] = Variable<int>(value);
    map['min_belanja'] = Variable<int>(minBelanja);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || maxUses != null) {
      map['max_uses'] = Variable<int>(maxUses);
    }
    map['used_count'] = Variable<int>(usedCount);
    map['status'] = Variable<String>(status);
    return map;
  }

  PromosCompanion toCompanion(bool nullToAbsent) {
    return PromosCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      type: Value(type),
      value: Value(value),
      minBelanja: Value(minBelanja),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      maxUses: maxUses == null && nullToAbsent
          ? const Value.absent()
          : Value(maxUses),
      usedCount: Value(usedCount),
      status: Value(status),
    );
  }

  factory Promo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Promo(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      type: serializer.fromJson<String>(json['type']),
      value: serializer.fromJson<int>(json['value']),
      minBelanja: serializer.fromJson<int>(json['minBelanja']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      maxUses: serializer.fromJson<int?>(json['maxUses']),
      usedCount: serializer.fromJson<int>(json['usedCount']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'type': serializer.toJson<String>(type),
      'value': serializer.toJson<int>(value),
      'minBelanja': serializer.toJson<int>(minBelanja),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'maxUses': serializer.toJson<int?>(maxUses),
      'usedCount': serializer.toJson<int>(usedCount),
      'status': serializer.toJson<String>(status),
    };
  }

  Promo copyWith({
    int? id,
    String? name,
    String? code,
    String? type,
    int? value,
    int? minBelanja,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    Value<int?> maxUses = const Value.absent(),
    int? usedCount,
    String? status,
  }) => Promo(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    type: type ?? this.type,
    value: value ?? this.value,
    minBelanja: minBelanja ?? this.minBelanja,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    maxUses: maxUses.present ? maxUses.value : this.maxUses,
    usedCount: usedCount ?? this.usedCount,
    status: status ?? this.status,
  );
  Promo copyWithCompanion(PromosCompanion data) {
    return Promo(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      type: data.type.present ? data.type.value : this.type,
      value: data.value.present ? data.value.value : this.value,
      minBelanja: data.minBelanja.present
          ? data.minBelanja.value
          : this.minBelanja,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      maxUses: data.maxUses.present ? data.maxUses.value : this.maxUses,
      usedCount: data.usedCount.present ? data.usedCount.value : this.usedCount,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Promo(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('minBelanja: $minBelanja, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('maxUses: $maxUses, ')
          ..write('usedCount: $usedCount, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    code,
    type,
    value,
    minBelanja,
    startDate,
    endDate,
    maxUses,
    usedCount,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Promo &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.type == this.type &&
          other.value == this.value &&
          other.minBelanja == this.minBelanja &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.maxUses == this.maxUses &&
          other.usedCount == this.usedCount &&
          other.status == this.status);
}

class PromosCompanion extends UpdateCompanion<Promo> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> code;
  final Value<String> type;
  final Value<int> value;
  final Value<int> minBelanja;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<int?> maxUses;
  final Value<int> usedCount;
  final Value<String> status;
  const PromosCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.type = const Value.absent(),
    this.value = const Value.absent(),
    this.minBelanja = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.maxUses = const Value.absent(),
    this.usedCount = const Value.absent(),
    this.status = const Value.absent(),
  });
  PromosCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String code,
    required String type,
    required int value,
    this.minBelanja = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.maxUses = const Value.absent(),
    this.usedCount = const Value.absent(),
    this.status = const Value.absent(),
  }) : name = Value(name),
       code = Value(code),
       type = Value(type),
       value = Value(value);
  static Insertable<Promo> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? type,
    Expression<int>? value,
    Expression<int>? minBelanja,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? maxUses,
    Expression<int>? usedCount,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (minBelanja != null) 'min_belanja': minBelanja,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (maxUses != null) 'max_uses': maxUses,
      if (usedCount != null) 'used_count': usedCount,
      if (status != null) 'status': status,
    });
  }

  PromosCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? code,
    Value<String>? type,
    Value<int>? value,
    Value<int>? minBelanja,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
    Value<int?>? maxUses,
    Value<int>? usedCount,
    Value<String>? status,
  }) {
    return PromosCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      value: value ?? this.value,
      minBelanja: minBelanja ?? this.minBelanja,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      status: status ?? this.status,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (minBelanja.present) {
      map['min_belanja'] = Variable<int>(minBelanja.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (maxUses.present) {
      map['max_uses'] = Variable<int>(maxUses.value);
    }
    if (usedCount.present) {
      map['used_count'] = Variable<int>(usedCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PromosCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('minBelanja: $minBelanja, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('maxUses: $maxUses, ')
          ..write('usedCount: $usedCount, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $EmployeesTable extends Employees
    with TableInfo<$EmployeesTable, Employee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinMeta = const VerificationMeta('pin');
  @override
  late final GeneratedColumn<String> pin = GeneratedColumn<String>(
    'pin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchIdMeta = const VerificationMeta(
    'branchId',
  );
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseSalaryMeta = const VerificationMeta(
    'baseSalary',
  );
  @override
  late final GeneratedColumn<int> baseSalary = GeneratedColumn<int>(
    'base_salary',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nfcTagMeta = const VerificationMeta('nfcTag');
  @override
  late final GeneratedColumn<String> nfcTag = GeneratedColumn<String>(
    'nfc_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workStartMeta = const VerificationMeta(
    'workStart',
  );
  @override
  late final GeneratedColumn<String> workStart = GeneratedColumn<String>(
    'work_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workEndMeta = const VerificationMeta(
    'workEnd',
  );
  @override
  late final GeneratedColumn<String> workEnd = GeneratedColumn<String>(
    'work_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresAttendanceMeta =
      const VerificationMeta('requiresAttendance');
  @override
  late final GeneratedColumn<bool> requiresAttendance = GeneratedColumn<bool>(
    'requires_attendance',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_attendance" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _requiresCashOpenMeta = const VerificationMeta(
    'requiresCashOpen',
  );
  @override
  late final GeneratedColumn<bool> requiresCashOpen = GeneratedColumn<bool>(
    'requires_cash_open',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_cash_open" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _requiresCashCloseMeta = const VerificationMeta(
    'requiresCashClose',
  );
  @override
  late final GeneratedColumn<bool> requiresCashClose = GeneratedColumn<bool>(
    'requires_cash_close',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_cash_close" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    pin,
    role,
    branchId,
    status,
    phone,
    photoPath,
    baseSalary,
    startDate,
    nfcTag,
    workStart,
    workEnd,
    requiresAttendance,
    requiresCashOpen,
    requiresCashClose,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Employee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pin')) {
      context.handle(
        _pinMeta,
        pin.isAcceptableOrUnknown(data['pin']!, _pinMeta),
      );
    } else if (isInserting) {
      context.missing(_pinMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(
        _branchIdMeta,
        branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('base_salary')) {
      context.handle(
        _baseSalaryMeta,
        baseSalary.isAcceptableOrUnknown(data['base_salary']!, _baseSalaryMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('nfc_tag')) {
      context.handle(
        _nfcTagMeta,
        nfcTag.isAcceptableOrUnknown(data['nfc_tag']!, _nfcTagMeta),
      );
    }
    if (data.containsKey('work_start')) {
      context.handle(
        _workStartMeta,
        workStart.isAcceptableOrUnknown(data['work_start']!, _workStartMeta),
      );
    }
    if (data.containsKey('work_end')) {
      context.handle(
        _workEndMeta,
        workEnd.isAcceptableOrUnknown(data['work_end']!, _workEndMeta),
      );
    }
    if (data.containsKey('requires_attendance')) {
      context.handle(
        _requiresAttendanceMeta,
        requiresAttendance.isAcceptableOrUnknown(
          data['requires_attendance']!,
          _requiresAttendanceMeta,
        ),
      );
    }
    if (data.containsKey('requires_cash_open')) {
      context.handle(
        _requiresCashOpenMeta,
        requiresCashOpen.isAcceptableOrUnknown(
          data['requires_cash_open']!,
          _requiresCashOpenMeta,
        ),
      );
    }
    if (data.containsKey('requires_cash_close')) {
      context.handle(
        _requiresCashCloseMeta,
        requiresCashClose.isAcceptableOrUnknown(
          data['requires_cash_close']!,
          _requiresCashCloseMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Employee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Employee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      baseSalary: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_salary'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      nfcTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nfc_tag'],
      ),
      workStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_start'],
      ),
      workEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_end'],
      ),
      requiresAttendance: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_attendance'],
      )!,
      requiresCashOpen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_cash_open'],
      )!,
      requiresCashClose: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_cash_close'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EmployeesTable createAlias(String alias) {
    return $EmployeesTable(attachedDatabase, alias);
  }
}

class Employee extends DataClass implements Insertable<Employee> {
  final int id;
  final String name;
  final String pin;
  final String role;
  final int? branchId;
  final String? status;
  final String? phone;
  final String? photoPath;
  final int? baseSalary;
  final DateTime? startDate;
  final String? nfcTag;
  final String? workStart;
  final String? workEnd;
  final bool requiresAttendance;
  final bool requiresCashOpen;
  final bool requiresCashClose;
  final DateTime createdAt;
  const Employee({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.branchId,
    this.status,
    this.phone,
    this.photoPath,
    this.baseSalary,
    this.startDate,
    this.nfcTag,
    this.workStart,
    this.workEnd,
    required this.requiresAttendance,
    required this.requiresCashOpen,
    required this.requiresCashClose,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['pin'] = Variable<String>(pin);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || baseSalary != null) {
      map['base_salary'] = Variable<int>(baseSalary);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || nfcTag != null) {
      map['nfc_tag'] = Variable<String>(nfcTag);
    }
    if (!nullToAbsent || workStart != null) {
      map['work_start'] = Variable<String>(workStart);
    }
    if (!nullToAbsent || workEnd != null) {
      map['work_end'] = Variable<String>(workEnd);
    }
    map['requires_attendance'] = Variable<bool>(requiresAttendance);
    map['requires_cash_open'] = Variable<bool>(requiresCashOpen);
    map['requires_cash_close'] = Variable<bool>(requiresCashClose);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EmployeesCompanion toCompanion(bool nullToAbsent) {
    return EmployeesCompanion(
      id: Value(id),
      name: Value(name),
      pin: Value(pin),
      role: Value(role),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      baseSalary: baseSalary == null && nullToAbsent
          ? const Value.absent()
          : Value(baseSalary),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      nfcTag: nfcTag == null && nullToAbsent
          ? const Value.absent()
          : Value(nfcTag),
      workStart: workStart == null && nullToAbsent
          ? const Value.absent()
          : Value(workStart),
      workEnd: workEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(workEnd),
      requiresAttendance: Value(requiresAttendance),
      requiresCashOpen: Value(requiresCashOpen),
      requiresCashClose: Value(requiresCashClose),
      createdAt: Value(createdAt),
    );
  }

  factory Employee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Employee(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pin: serializer.fromJson<String>(json['pin']),
      role: serializer.fromJson<String>(json['role']),
      branchId: serializer.fromJson<int?>(json['branchId']),
      status: serializer.fromJson<String?>(json['status']),
      phone: serializer.fromJson<String?>(json['phone']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      baseSalary: serializer.fromJson<int?>(json['baseSalary']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      nfcTag: serializer.fromJson<String?>(json['nfcTag']),
      workStart: serializer.fromJson<String?>(json['workStart']),
      workEnd: serializer.fromJson<String?>(json['workEnd']),
      requiresAttendance: serializer.fromJson<bool>(json['requiresAttendance']),
      requiresCashOpen: serializer.fromJson<bool>(json['requiresCashOpen']),
      requiresCashClose: serializer.fromJson<bool>(json['requiresCashClose']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'pin': serializer.toJson<String>(pin),
      'role': serializer.toJson<String>(role),
      'branchId': serializer.toJson<int?>(branchId),
      'status': serializer.toJson<String?>(status),
      'phone': serializer.toJson<String?>(phone),
      'photoPath': serializer.toJson<String?>(photoPath),
      'baseSalary': serializer.toJson<int?>(baseSalary),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'nfcTag': serializer.toJson<String?>(nfcTag),
      'workStart': serializer.toJson<String?>(workStart),
      'workEnd': serializer.toJson<String?>(workEnd),
      'requiresAttendance': serializer.toJson<bool>(requiresAttendance),
      'requiresCashOpen': serializer.toJson<bool>(requiresCashOpen),
      'requiresCashClose': serializer.toJson<bool>(requiresCashClose),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Employee copyWith({
    int? id,
    String? name,
    String? pin,
    String? role,
    Value<int?> branchId = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> photoPath = const Value.absent(),
    Value<int?> baseSalary = const Value.absent(),
    Value<DateTime?> startDate = const Value.absent(),
    Value<String?> nfcTag = const Value.absent(),
    Value<String?> workStart = const Value.absent(),
    Value<String?> workEnd = const Value.absent(),
    bool? requiresAttendance,
    bool? requiresCashOpen,
    bool? requiresCashClose,
    DateTime? createdAt,
  }) => Employee(
    id: id ?? this.id,
    name: name ?? this.name,
    pin: pin ?? this.pin,
    role: role ?? this.role,
    branchId: branchId.present ? branchId.value : this.branchId,
    status: status.present ? status.value : this.status,
    phone: phone.present ? phone.value : this.phone,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    baseSalary: baseSalary.present ? baseSalary.value : this.baseSalary,
    startDate: startDate.present ? startDate.value : this.startDate,
    nfcTag: nfcTag.present ? nfcTag.value : this.nfcTag,
    workStart: workStart.present ? workStart.value : this.workStart,
    workEnd: workEnd.present ? workEnd.value : this.workEnd,
    requiresAttendance: requiresAttendance ?? this.requiresAttendance,
    requiresCashOpen: requiresCashOpen ?? this.requiresCashOpen,
    requiresCashClose: requiresCashClose ?? this.requiresCashClose,
    createdAt: createdAt ?? this.createdAt,
  );
  Employee copyWithCompanion(EmployeesCompanion data) {
    return Employee(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pin: data.pin.present ? data.pin.value : this.pin,
      role: data.role.present ? data.role.value : this.role,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      status: data.status.present ? data.status.value : this.status,
      phone: data.phone.present ? data.phone.value : this.phone,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      baseSalary: data.baseSalary.present
          ? data.baseSalary.value
          : this.baseSalary,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      nfcTag: data.nfcTag.present ? data.nfcTag.value : this.nfcTag,
      workStart: data.workStart.present ? data.workStart.value : this.workStart,
      workEnd: data.workEnd.present ? data.workEnd.value : this.workEnd,
      requiresAttendance: data.requiresAttendance.present
          ? data.requiresAttendance.value
          : this.requiresAttendance,
      requiresCashOpen: data.requiresCashOpen.present
          ? data.requiresCashOpen.value
          : this.requiresCashOpen,
      requiresCashClose: data.requiresCashClose.present
          ? data.requiresCashClose.value
          : this.requiresCashClose,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Employee(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pin: $pin, ')
          ..write('role: $role, ')
          ..write('branchId: $branchId, ')
          ..write('status: $status, ')
          ..write('phone: $phone, ')
          ..write('photoPath: $photoPath, ')
          ..write('baseSalary: $baseSalary, ')
          ..write('startDate: $startDate, ')
          ..write('nfcTag: $nfcTag, ')
          ..write('workStart: $workStart, ')
          ..write('workEnd: $workEnd, ')
          ..write('requiresAttendance: $requiresAttendance, ')
          ..write('requiresCashOpen: $requiresCashOpen, ')
          ..write('requiresCashClose: $requiresCashClose, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    pin,
    role,
    branchId,
    status,
    phone,
    photoPath,
    baseSalary,
    startDate,
    nfcTag,
    workStart,
    workEnd,
    requiresAttendance,
    requiresCashOpen,
    requiresCashClose,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Employee &&
          other.id == this.id &&
          other.name == this.name &&
          other.pin == this.pin &&
          other.role == this.role &&
          other.branchId == this.branchId &&
          other.status == this.status &&
          other.phone == this.phone &&
          other.photoPath == this.photoPath &&
          other.baseSalary == this.baseSalary &&
          other.startDate == this.startDate &&
          other.nfcTag == this.nfcTag &&
          other.workStart == this.workStart &&
          other.workEnd == this.workEnd &&
          other.requiresAttendance == this.requiresAttendance &&
          other.requiresCashOpen == this.requiresCashOpen &&
          other.requiresCashClose == this.requiresCashClose &&
          other.createdAt == this.createdAt);
}

class EmployeesCompanion extends UpdateCompanion<Employee> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> pin;
  final Value<String> role;
  final Value<int?> branchId;
  final Value<String?> status;
  final Value<String?> phone;
  final Value<String?> photoPath;
  final Value<int?> baseSalary;
  final Value<DateTime?> startDate;
  final Value<String?> nfcTag;
  final Value<String?> workStart;
  final Value<String?> workEnd;
  final Value<bool> requiresAttendance;
  final Value<bool> requiresCashOpen;
  final Value<bool> requiresCashClose;
  final Value<DateTime> createdAt;
  const EmployeesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pin = const Value.absent(),
    this.role = const Value.absent(),
    this.branchId = const Value.absent(),
    this.status = const Value.absent(),
    this.phone = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.baseSalary = const Value.absent(),
    this.startDate = const Value.absent(),
    this.nfcTag = const Value.absent(),
    this.workStart = const Value.absent(),
    this.workEnd = const Value.absent(),
    this.requiresAttendance = const Value.absent(),
    this.requiresCashOpen = const Value.absent(),
    this.requiresCashClose = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EmployeesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String pin,
    required String role,
    this.branchId = const Value.absent(),
    this.status = const Value.absent(),
    this.phone = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.baseSalary = const Value.absent(),
    this.startDate = const Value.absent(),
    this.nfcTag = const Value.absent(),
    this.workStart = const Value.absent(),
    this.workEnd = const Value.absent(),
    this.requiresAttendance = const Value.absent(),
    this.requiresCashOpen = const Value.absent(),
    this.requiresCashClose = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       pin = Value(pin),
       role = Value(role);
  static Insertable<Employee> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? pin,
    Expression<String>? role,
    Expression<int>? branchId,
    Expression<String>? status,
    Expression<String>? phone,
    Expression<String>? photoPath,
    Expression<int>? baseSalary,
    Expression<DateTime>? startDate,
    Expression<String>? nfcTag,
    Expression<String>? workStart,
    Expression<String>? workEnd,
    Expression<bool>? requiresAttendance,
    Expression<bool>? requiresCashOpen,
    Expression<bool>? requiresCashClose,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pin != null) 'pin': pin,
      if (role != null) 'role': role,
      if (branchId != null) 'branch_id': branchId,
      if (status != null) 'status': status,
      if (phone != null) 'phone': phone,
      if (photoPath != null) 'photo_path': photoPath,
      if (baseSalary != null) 'base_salary': baseSalary,
      if (startDate != null) 'start_date': startDate,
      if (nfcTag != null) 'nfc_tag': nfcTag,
      if (workStart != null) 'work_start': workStart,
      if (workEnd != null) 'work_end': workEnd,
      if (requiresAttendance != null) 'requires_attendance': requiresAttendance,
      if (requiresCashOpen != null) 'requires_cash_open': requiresCashOpen,
      if (requiresCashClose != null) 'requires_cash_close': requiresCashClose,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EmployeesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? pin,
    Value<String>? role,
    Value<int?>? branchId,
    Value<String?>? status,
    Value<String?>? phone,
    Value<String?>? photoPath,
    Value<int?>? baseSalary,
    Value<DateTime?>? startDate,
    Value<String?>? nfcTag,
    Value<String?>? workStart,
    Value<String?>? workEnd,
    Value<bool>? requiresAttendance,
    Value<bool>? requiresCashOpen,
    Value<bool>? requiresCashClose,
    Value<DateTime>? createdAt,
  }) {
    return EmployeesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
      baseSalary: baseSalary ?? this.baseSalary,
      startDate: startDate ?? this.startDate,
      nfcTag: nfcTag ?? this.nfcTag,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
      requiresAttendance: requiresAttendance ?? this.requiresAttendance,
      requiresCashOpen: requiresCashOpen ?? this.requiresCashOpen,
      requiresCashClose: requiresCashClose ?? this.requiresCashClose,
      createdAt: createdAt ?? this.createdAt,
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
    if (pin.present) {
      map['pin'] = Variable<String>(pin.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (baseSalary.present) {
      map['base_salary'] = Variable<int>(baseSalary.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (nfcTag.present) {
      map['nfc_tag'] = Variable<String>(nfcTag.value);
    }
    if (workStart.present) {
      map['work_start'] = Variable<String>(workStart.value);
    }
    if (workEnd.present) {
      map['work_end'] = Variable<String>(workEnd.value);
    }
    if (requiresAttendance.present) {
      map['requires_attendance'] = Variable<bool>(requiresAttendance.value);
    }
    if (requiresCashOpen.present) {
      map['requires_cash_open'] = Variable<bool>(requiresCashOpen.value);
    }
    if (requiresCashClose.present) {
      map['requires_cash_close'] = Variable<bool>(requiresCashClose.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pin: $pin, ')
          ..write('role: $role, ')
          ..write('branchId: $branchId, ')
          ..write('status: $status, ')
          ..write('phone: $phone, ')
          ..write('photoPath: $photoPath, ')
          ..write('baseSalary: $baseSalary, ')
          ..write('startDate: $startDate, ')
          ..write('nfcTag: $nfcTag, ')
          ..write('workStart: $workStart, ')
          ..write('workEnd: $workEnd, ')
          ..write('requiresAttendance: $requiresAttendance, ')
          ..write('requiresCashOpen: $requiresCashOpen, ')
          ..write('requiresCashClose: $requiresCashClose, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AttendanceTable extends Attendance
    with TableInfo<$AttendanceTable, AttendanceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _checkInMeta = const VerificationMeta(
    'checkIn',
  );
  @override
  late final GeneratedColumn<String> checkIn = GeneratedColumn<String>(
    'check_in',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkOutMeta = const VerificationMeta(
    'checkOut',
  );
  @override
  late final GeneratedColumn<String> checkOut = GeneratedColumn<String>(
    'check_out',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pettyCashMeta = const VerificationMeta(
    'pettyCash',
  );
  @override
  late final GeneratedColumn<int> pettyCash = GeneratedColumn<int>(
    'petty_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalCashMeta = const VerificationMeta(
    'finalCash',
  );
  @override
  late final GeneratedColumn<int> finalCash = GeneratedColumn<int>(
    'final_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedCashMeta = const VerificationMeta(
    'expectedCash',
  );
  @override
  late final GeneratedColumn<int> expectedCash = GeneratedColumn<int>(
    'expected_cash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shiftNotesMeta = const VerificationMeta(
    'shiftNotes',
  );
  @override
  late final GeneratedColumn<String> shiftNotes = GeneratedColumn<String>(
    'shift_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    date,
    checkIn,
    checkOut,
    pettyCash,
    finalCash,
    status,
    expectedCash,
    shiftNotes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('check_in')) {
      context.handle(
        _checkInMeta,
        checkIn.isAcceptableOrUnknown(data['check_in']!, _checkInMeta),
      );
    }
    if (data.containsKey('check_out')) {
      context.handle(
        _checkOutMeta,
        checkOut.isAcceptableOrUnknown(data['check_out']!, _checkOutMeta),
      );
    }
    if (data.containsKey('petty_cash')) {
      context.handle(
        _pettyCashMeta,
        pettyCash.isAcceptableOrUnknown(data['petty_cash']!, _pettyCashMeta),
      );
    }
    if (data.containsKey('final_cash')) {
      context.handle(
        _finalCashMeta,
        finalCash.isAcceptableOrUnknown(data['final_cash']!, _finalCashMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('expected_cash')) {
      context.handle(
        _expectedCashMeta,
        expectedCash.isAcceptableOrUnknown(
          data['expected_cash']!,
          _expectedCashMeta,
        ),
      );
    }
    if (data.containsKey('shift_notes')) {
      context.handle(
        _shiftNotesMeta,
        shiftNotes.isAcceptableOrUnknown(data['shift_notes']!, _shiftNotesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendanceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      checkIn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_in'],
      ),
      checkOut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_out'],
      ),
      pettyCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}petty_cash'],
      ),
      finalCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}final_cash'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      expectedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_cash'],
      ),
      shiftNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_notes'],
      ),
    );
  }

  @override
  $AttendanceTable createAlias(String alias) {
    return $AttendanceTable(attachedDatabase, alias);
  }
}

class AttendanceData extends DataClass implements Insertable<AttendanceData> {
  final int id;
  final int employeeId;
  final DateTime date;
  final String? checkIn;
  final String? checkOut;
  final int? pettyCash;
  final int? finalCash;
  final String? status;
  final int? expectedCash;
  final String? shiftNotes;
  const AttendanceData({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.pettyCash,
    this.finalCash,
    this.status,
    this.expectedCash,
    this.shiftNotes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || checkIn != null) {
      map['check_in'] = Variable<String>(checkIn);
    }
    if (!nullToAbsent || checkOut != null) {
      map['check_out'] = Variable<String>(checkOut);
    }
    if (!nullToAbsent || pettyCash != null) {
      map['petty_cash'] = Variable<int>(pettyCash);
    }
    if (!nullToAbsent || finalCash != null) {
      map['final_cash'] = Variable<int>(finalCash);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || expectedCash != null) {
      map['expected_cash'] = Variable<int>(expectedCash);
    }
    if (!nullToAbsent || shiftNotes != null) {
      map['shift_notes'] = Variable<String>(shiftNotes);
    }
    return map;
  }

  AttendanceCompanion toCompanion(bool nullToAbsent) {
    return AttendanceCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      date: Value(date),
      checkIn: checkIn == null && nullToAbsent
          ? const Value.absent()
          : Value(checkIn),
      checkOut: checkOut == null && nullToAbsent
          ? const Value.absent()
          : Value(checkOut),
      pettyCash: pettyCash == null && nullToAbsent
          ? const Value.absent()
          : Value(pettyCash),
      finalCash: finalCash == null && nullToAbsent
          ? const Value.absent()
          : Value(finalCash),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      expectedCash: expectedCash == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCash),
      shiftNotes: shiftNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftNotes),
    );
  }

  factory AttendanceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceData(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      date: serializer.fromJson<DateTime>(json['date']),
      checkIn: serializer.fromJson<String?>(json['checkIn']),
      checkOut: serializer.fromJson<String?>(json['checkOut']),
      pettyCash: serializer.fromJson<int?>(json['pettyCash']),
      finalCash: serializer.fromJson<int?>(json['finalCash']),
      status: serializer.fromJson<String?>(json['status']),
      expectedCash: serializer.fromJson<int?>(json['expectedCash']),
      shiftNotes: serializer.fromJson<String?>(json['shiftNotes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'date': serializer.toJson<DateTime>(date),
      'checkIn': serializer.toJson<String?>(checkIn),
      'checkOut': serializer.toJson<String?>(checkOut),
      'pettyCash': serializer.toJson<int?>(pettyCash),
      'finalCash': serializer.toJson<int?>(finalCash),
      'status': serializer.toJson<String?>(status),
      'expectedCash': serializer.toJson<int?>(expectedCash),
      'shiftNotes': serializer.toJson<String?>(shiftNotes),
    };
  }

  AttendanceData copyWith({
    int? id,
    int? employeeId,
    DateTime? date,
    Value<String?> checkIn = const Value.absent(),
    Value<String?> checkOut = const Value.absent(),
    Value<int?> pettyCash = const Value.absent(),
    Value<int?> finalCash = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<int?> expectedCash = const Value.absent(),
    Value<String?> shiftNotes = const Value.absent(),
  }) => AttendanceData(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    date: date ?? this.date,
    checkIn: checkIn.present ? checkIn.value : this.checkIn,
    checkOut: checkOut.present ? checkOut.value : this.checkOut,
    pettyCash: pettyCash.present ? pettyCash.value : this.pettyCash,
    finalCash: finalCash.present ? finalCash.value : this.finalCash,
    status: status.present ? status.value : this.status,
    expectedCash: expectedCash.present ? expectedCash.value : this.expectedCash,
    shiftNotes: shiftNotes.present ? shiftNotes.value : this.shiftNotes,
  );
  AttendanceData copyWithCompanion(AttendanceCompanion data) {
    return AttendanceData(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      date: data.date.present ? data.date.value : this.date,
      checkIn: data.checkIn.present ? data.checkIn.value : this.checkIn,
      checkOut: data.checkOut.present ? data.checkOut.value : this.checkOut,
      pettyCash: data.pettyCash.present ? data.pettyCash.value : this.pettyCash,
      finalCash: data.finalCash.present ? data.finalCash.value : this.finalCash,
      status: data.status.present ? data.status.value : this.status,
      expectedCash: data.expectedCash.present
          ? data.expectedCash.value
          : this.expectedCash,
      shiftNotes: data.shiftNotes.present
          ? data.shiftNotes.value
          : this.shiftNotes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceData(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('date: $date, ')
          ..write('checkIn: $checkIn, ')
          ..write('checkOut: $checkOut, ')
          ..write('pettyCash: $pettyCash, ')
          ..write('finalCash: $finalCash, ')
          ..write('status: $status, ')
          ..write('expectedCash: $expectedCash, ')
          ..write('shiftNotes: $shiftNotes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    date,
    checkIn,
    checkOut,
    pettyCash,
    finalCash,
    status,
    expectedCash,
    shiftNotes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceData &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.date == this.date &&
          other.checkIn == this.checkIn &&
          other.checkOut == this.checkOut &&
          other.pettyCash == this.pettyCash &&
          other.finalCash == this.finalCash &&
          other.status == this.status &&
          other.expectedCash == this.expectedCash &&
          other.shiftNotes == this.shiftNotes);
}

class AttendanceCompanion extends UpdateCompanion<AttendanceData> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<DateTime> date;
  final Value<String?> checkIn;
  final Value<String?> checkOut;
  final Value<int?> pettyCash;
  final Value<int?> finalCash;
  final Value<String?> status;
  final Value<int?> expectedCash;
  final Value<String?> shiftNotes;
  const AttendanceCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.date = const Value.absent(),
    this.checkIn = const Value.absent(),
    this.checkOut = const Value.absent(),
    this.pettyCash = const Value.absent(),
    this.finalCash = const Value.absent(),
    this.status = const Value.absent(),
    this.expectedCash = const Value.absent(),
    this.shiftNotes = const Value.absent(),
  });
  AttendanceCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    this.date = const Value.absent(),
    this.checkIn = const Value.absent(),
    this.checkOut = const Value.absent(),
    this.pettyCash = const Value.absent(),
    this.finalCash = const Value.absent(),
    this.status = const Value.absent(),
    this.expectedCash = const Value.absent(),
    this.shiftNotes = const Value.absent(),
  }) : employeeId = Value(employeeId);
  static Insertable<AttendanceData> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<DateTime>? date,
    Expression<String>? checkIn,
    Expression<String>? checkOut,
    Expression<int>? pettyCash,
    Expression<int>? finalCash,
    Expression<String>? status,
    Expression<int>? expectedCash,
    Expression<String>? shiftNotes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (date != null) 'date': date,
      if (checkIn != null) 'check_in': checkIn,
      if (checkOut != null) 'check_out': checkOut,
      if (pettyCash != null) 'petty_cash': pettyCash,
      if (finalCash != null) 'final_cash': finalCash,
      if (status != null) 'status': status,
      if (expectedCash != null) 'expected_cash': expectedCash,
      if (shiftNotes != null) 'shift_notes': shiftNotes,
    });
  }

  AttendanceCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<DateTime>? date,
    Value<String?>? checkIn,
    Value<String?>? checkOut,
    Value<int?>? pettyCash,
    Value<int?>? finalCash,
    Value<String?>? status,
    Value<int?>? expectedCash,
    Value<String?>? shiftNotes,
  }) {
    return AttendanceCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      pettyCash: pettyCash ?? this.pettyCash,
      finalCash: finalCash ?? this.finalCash,
      status: status ?? this.status,
      expectedCash: expectedCash ?? this.expectedCash,
      shiftNotes: shiftNotes ?? this.shiftNotes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (checkIn.present) {
      map['check_in'] = Variable<String>(checkIn.value);
    }
    if (checkOut.present) {
      map['check_out'] = Variable<String>(checkOut.value);
    }
    if (pettyCash.present) {
      map['petty_cash'] = Variable<int>(pettyCash.value);
    }
    if (finalCash.present) {
      map['final_cash'] = Variable<int>(finalCash.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (expectedCash.present) {
      map['expected_cash'] = Variable<int>(expectedCash.value);
    }
    if (shiftNotes.present) {
      map['shift_notes'] = Variable<String>(shiftNotes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('date: $date, ')
          ..write('checkIn: $checkIn, ')
          ..write('checkOut: $checkOut, ')
          ..write('pettyCash: $pettyCash, ')
          ..write('finalCash: $finalCash, ')
          ..write('status: $status, ')
          ..write('expectedCash: $expectedCash, ')
          ..write('shiftNotes: $shiftNotes')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchIdMeta = const VerificationMeta(
    'branchId',
  );
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    category,
    description,
    amount,
    branchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(
        _branchIdMeta,
        branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_id'],
      ),
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class Expense extends DataClass implements Insertable<Expense> {
  final int id;
  final DateTime date;
  final String category;
  final String description;
  final int amount;
  final int? branchId;
  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    this.branchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      date: Value(date),
      category: Value(category),
      description: Value(description),
      amount: Value(amount),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<int>(json['amount']),
      branchId: serializer.fromJson<int?>(json['branchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<int>(amount),
      'branchId': serializer.toJson<int?>(branchId),
    };
  }

  Expense copyWith({
    int? id,
    DateTime? date,
    String? category,
    String? description,
    int? amount,
    Value<int?> branchId = const Value.absent(),
  }) => Expense(
    id: id ?? this.id,
    date: date ?? this.date,
    category: category ?? this.category,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    branchId: branchId.present ? branchId.value : this.branchId,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, category, description, amount, branchId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.date == this.date &&
          other.category == this.category &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.branchId == this.branchId);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> category;
  final Value<String> description;
  final Value<int> amount;
  final Value<int?> branchId;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.branchId = const Value.absent(),
  });
  ExpensesCompanion.insert({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    required String category,
    required String description,
    required int amount,
    this.branchId = const Value.absent(),
  }) : category = Value(category),
       description = Value(description),
       amount = Value(amount);
  static Insertable<Expense> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? category,
    Expression<String>? description,
    Expression<int>? amount,
    Expression<int>? branchId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (branchId != null) 'branch_id': branchId,
    });
  }

  ExpensesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? category,
    Value<String>? description,
    Value<int>? amount,
    Value<int?>? branchId,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      branchId: branchId ?? this.branchId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }
}

class $ExpenseCategoriesTable extends ExpenseCategories
    with TableInfo<$ExpenseCategoriesTable, ExpenseCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ExpenseCategoriesTable createAlias(String alias) {
    return $ExpenseCategoriesTable(attachedDatabase, alias);
  }
}

class ExpenseCategory extends DataClass implements Insertable<ExpenseCategory> {
  final int id;
  final String name;
  const ExpenseCategory({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  ExpenseCategoriesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseCategoriesCompanion(id: Value(id), name: Value(name));
  }

  factory ExpenseCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseCategory(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  ExpenseCategory copyWith({int? id, String? name}) =>
      ExpenseCategory(id: id ?? this.id, name: name ?? this.name);
  ExpenseCategory copyWithCompanion(ExpenseCategoriesCompanion data) {
    return ExpenseCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseCategory(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseCategory &&
          other.id == this.id &&
          other.name == this.name);
}

class ExpenseCategoriesCompanion extends UpdateCompanion<ExpenseCategory> {
  final Value<int> id;
  final Value<String> name;
  const ExpenseCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  ExpenseCategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<ExpenseCategory> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  ExpenseCategoriesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return ExpenseCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $RecurringExpensesTable extends RecurringExpenses
    with TableInfo<$RecurringExpensesTable, RecurringExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextDateMeta = const VerificationMeta(
    'nextDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDate = GeneratedColumn<DateTime>(
    'next_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    amount,
    description,
    frequency,
    nextDate,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringExpense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('next_date')) {
      context.handle(
        _nextDateMeta,
        nextDate.isAcceptableOrUnknown(data['next_date']!, _nextDateMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDateMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringExpense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      nextDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_date'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $RecurringExpensesTable createAlias(String alias) {
    return $RecurringExpensesTable(attachedDatabase, alias);
  }
}

class RecurringExpense extends DataClass
    implements Insertable<RecurringExpense> {
  final int id;
  final String category;
  final int amount;
  final String description;
  final String frequency;
  final DateTime nextDate;
  final bool active;
  const RecurringExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.frequency,
    required this.nextDate,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category'] = Variable<String>(category);
    map['amount'] = Variable<int>(amount);
    map['description'] = Variable<String>(description);
    map['frequency'] = Variable<String>(frequency);
    map['next_date'] = Variable<DateTime>(nextDate);
    map['active'] = Variable<bool>(active);
    return map;
  }

  RecurringExpensesCompanion toCompanion(bool nullToAbsent) {
    return RecurringExpensesCompanion(
      id: Value(id),
      category: Value(category),
      amount: Value(amount),
      description: Value(description),
      frequency: Value(frequency),
      nextDate: Value(nextDate),
      active: Value(active),
    );
  }

  factory RecurringExpense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringExpense(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<int>(json['amount']),
      description: serializer.fromJson<String>(json['description']),
      frequency: serializer.fromJson<String>(json['frequency']),
      nextDate: serializer.fromJson<DateTime>(json['nextDate']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<int>(amount),
      'description': serializer.toJson<String>(description),
      'frequency': serializer.toJson<String>(frequency),
      'nextDate': serializer.toJson<DateTime>(nextDate),
      'active': serializer.toJson<bool>(active),
    };
  }

  RecurringExpense copyWith({
    int? id,
    String? category,
    int? amount,
    String? description,
    String? frequency,
    DateTime? nextDate,
    bool? active,
  }) => RecurringExpense(
    id: id ?? this.id,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    frequency: frequency ?? this.frequency,
    nextDate: nextDate ?? this.nextDate,
    active: active ?? this.active,
  );
  RecurringExpense copyWithCompanion(RecurringExpensesCompanion data) {
    return RecurringExpense(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      nextDate: data.nextDate.present ? data.nextDate.value : this.nextDate,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringExpense(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('frequency: $frequency, ')
          ..write('nextDate: $nextDate, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    amount,
    description,
    frequency,
    nextDate,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringExpense &&
          other.id == this.id &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.frequency == this.frequency &&
          other.nextDate == this.nextDate &&
          other.active == this.active);
}

class RecurringExpensesCompanion extends UpdateCompanion<RecurringExpense> {
  final Value<int> id;
  final Value<String> category;
  final Value<int> amount;
  final Value<String> description;
  final Value<String> frequency;
  final Value<DateTime> nextDate;
  final Value<bool> active;
  const RecurringExpensesCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.frequency = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.active = const Value.absent(),
  });
  RecurringExpensesCompanion.insert({
    this.id = const Value.absent(),
    required String category,
    required int amount,
    required String description,
    required String frequency,
    required DateTime nextDate,
    this.active = const Value.absent(),
  }) : category = Value(category),
       amount = Value(amount),
       description = Value(description),
       frequency = Value(frequency),
       nextDate = Value(nextDate);
  static Insertable<RecurringExpense> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<int>? amount,
    Expression<String>? description,
    Expression<String>? frequency,
    Expression<DateTime>? nextDate,
    Expression<bool>? active,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (frequency != null) 'frequency': frequency,
      if (nextDate != null) 'next_date': nextDate,
      if (active != null) 'active': active,
    });
  }

  RecurringExpensesCompanion copyWith({
    Value<int>? id,
    Value<String>? category,
    Value<int>? amount,
    Value<String>? description,
    Value<String>? frequency,
    Value<DateTime>? nextDate,
    Value<bool>? active,
  }) {
    return RecurringExpensesCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      nextDate: nextDate ?? this.nextDate,
      active: active ?? this.active,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (nextDate.present) {
      map['next_date'] = Variable<DateTime>(nextDate.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringExpensesCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('frequency: $frequency, ')
          ..write('nextDate: $nextDate, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }
}

class $PayrollTable extends Payroll with TableInfo<$PayrollTable, PayrollData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayrollTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _salaryMeta = const VerificationMeta('salary');
  @override
  late final GeneratedColumn<int> salary = GeneratedColumn<int>(
    'salary',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bonusMeta = const VerificationMeta('bonus');
  @override
  late final GeneratedColumn<int> bonus = GeneratedColumn<int>(
    'bonus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deductionMeta = const VerificationMeta(
    'deduction',
  );
  @override
  late final GeneratedColumn<int> deduction = GeneratedColumn<int>(
    'deduction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    period,
    salary,
    bonus,
    deduction,
    notes,
    date,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payroll';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayrollData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('salary')) {
      context.handle(
        _salaryMeta,
        salary.isAcceptableOrUnknown(data['salary']!, _salaryMeta),
      );
    } else if (isInserting) {
      context.missing(_salaryMeta);
    }
    if (data.containsKey('bonus')) {
      context.handle(
        _bonusMeta,
        bonus.isAcceptableOrUnknown(data['bonus']!, _bonusMeta),
      );
    }
    if (data.containsKey('deduction')) {
      context.handle(
        _deductionMeta,
        deduction.isAcceptableOrUnknown(data['deduction']!, _deductionMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PayrollData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayrollData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      salary: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}salary'],
      )!,
      bonus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bonus'],
      )!,
      deduction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deduction'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $PayrollTable createAlias(String alias) {
    return $PayrollTable(attachedDatabase, alias);
  }
}

class PayrollData extends DataClass implements Insertable<PayrollData> {
  final int id;
  final int employeeId;
  final String period;
  final int salary;
  final int bonus;
  final int deduction;
  final String? notes;
  final DateTime date;
  final String status;
  const PayrollData({
    required this.id,
    required this.employeeId,
    required this.period,
    required this.salary,
    required this.bonus,
    required this.deduction,
    this.notes,
    required this.date,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['period'] = Variable<String>(period);
    map['salary'] = Variable<int>(salary);
    map['bonus'] = Variable<int>(bonus);
    map['deduction'] = Variable<int>(deduction);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['date'] = Variable<DateTime>(date);
    map['status'] = Variable<String>(status);
    return map;
  }

  PayrollCompanion toCompanion(bool nullToAbsent) {
    return PayrollCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      period: Value(period),
      salary: Value(salary),
      bonus: Value(bonus),
      deduction: Value(deduction),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      date: Value(date),
      status: Value(status),
    );
  }

  factory PayrollData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayrollData(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      period: serializer.fromJson<String>(json['period']),
      salary: serializer.fromJson<int>(json['salary']),
      bonus: serializer.fromJson<int>(json['bonus']),
      deduction: serializer.fromJson<int>(json['deduction']),
      notes: serializer.fromJson<String?>(json['notes']),
      date: serializer.fromJson<DateTime>(json['date']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'period': serializer.toJson<String>(period),
      'salary': serializer.toJson<int>(salary),
      'bonus': serializer.toJson<int>(bonus),
      'deduction': serializer.toJson<int>(deduction),
      'notes': serializer.toJson<String?>(notes),
      'date': serializer.toJson<DateTime>(date),
      'status': serializer.toJson<String>(status),
    };
  }

  PayrollData copyWith({
    int? id,
    int? employeeId,
    String? period,
    int? salary,
    int? bonus,
    int? deduction,
    Value<String?> notes = const Value.absent(),
    DateTime? date,
    String? status,
  }) => PayrollData(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    period: period ?? this.period,
    salary: salary ?? this.salary,
    bonus: bonus ?? this.bonus,
    deduction: deduction ?? this.deduction,
    notes: notes.present ? notes.value : this.notes,
    date: date ?? this.date,
    status: status ?? this.status,
  );
  PayrollData copyWithCompanion(PayrollCompanion data) {
    return PayrollData(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      period: data.period.present ? data.period.value : this.period,
      salary: data.salary.present ? data.salary.value : this.salary,
      bonus: data.bonus.present ? data.bonus.value : this.bonus,
      deduction: data.deduction.present ? data.deduction.value : this.deduction,
      notes: data.notes.present ? data.notes.value : this.notes,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayrollData(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('period: $period, ')
          ..write('salary: $salary, ')
          ..write('bonus: $bonus, ')
          ..write('deduction: $deduction, ')
          ..write('notes: $notes, ')
          ..write('date: $date, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    period,
    salary,
    bonus,
    deduction,
    notes,
    date,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayrollData &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.period == this.period &&
          other.salary == this.salary &&
          other.bonus == this.bonus &&
          other.deduction == this.deduction &&
          other.notes == this.notes &&
          other.date == this.date &&
          other.status == this.status);
}

class PayrollCompanion extends UpdateCompanion<PayrollData> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<String> period;
  final Value<int> salary;
  final Value<int> bonus;
  final Value<int> deduction;
  final Value<String?> notes;
  final Value<DateTime> date;
  final Value<String> status;
  const PayrollCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.period = const Value.absent(),
    this.salary = const Value.absent(),
    this.bonus = const Value.absent(),
    this.deduction = const Value.absent(),
    this.notes = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
  });
  PayrollCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required String period,
    required int salary,
    this.bonus = const Value.absent(),
    this.deduction = const Value.absent(),
    this.notes = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
  }) : employeeId = Value(employeeId),
       period = Value(period),
       salary = Value(salary);
  static Insertable<PayrollData> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<String>? period,
    Expression<int>? salary,
    Expression<int>? bonus,
    Expression<int>? deduction,
    Expression<String>? notes,
    Expression<DateTime>? date,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (period != null) 'period': period,
      if (salary != null) 'salary': salary,
      if (bonus != null) 'bonus': bonus,
      if (deduction != null) 'deduction': deduction,
      if (notes != null) 'notes': notes,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
    });
  }

  PayrollCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<String>? period,
    Value<int>? salary,
    Value<int>? bonus,
    Value<int>? deduction,
    Value<String?>? notes,
    Value<DateTime>? date,
    Value<String>? status,
  }) {
    return PayrollCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      period: period ?? this.period,
      salary: salary ?? this.salary,
      bonus: bonus ?? this.bonus,
      deduction: deduction ?? this.deduction,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (salary.present) {
      map['salary'] = Variable<int>(salary.value);
    }
    if (bonus.present) {
      map['bonus'] = Variable<int>(bonus.value);
    }
    if (deduction.present) {
      map['deduction'] = Variable<int>(deduction.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayrollCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('period: $period, ')
          ..write('salary: $salary, ')
          ..write('bonus: $bonus, ')
          ..write('deduction: $deduction, ')
          ..write('notes: $notes, ')
          ..write('date: $date, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $WasteTable extends Waste with TableInfo<$WasteTable, WasteData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WasteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Expired'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    qty,
    reason,
    type,
    date,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'waste';
  @override
  VerificationContext validateIntegrity(
    Insertable<WasteData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WasteData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WasteData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $WasteTable createAlias(String alias) {
    return $WasteTable(attachedDatabase, alias);
  }
}

class WasteData extends DataClass implements Insertable<WasteData> {
  final int id;
  final int productId;
  final int qty;
  final String? reason;
  final String type;
  final DateTime date;
  const WasteData({
    required this.id,
    required this.productId,
    required this.qty,
    this.reason,
    required this.type,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['qty'] = Variable<int>(qty);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['type'] = Variable<String>(type);
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  WasteCompanion toCompanion(bool nullToAbsent) {
    return WasteCompanion(
      id: Value(id),
      productId: Value(productId),
      qty: Value(qty),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      type: Value(type),
      date: Value(date),
    );
  }

  factory WasteData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WasteData(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      qty: serializer.fromJson<int>(json['qty']),
      reason: serializer.fromJson<String?>(json['reason']),
      type: serializer.fromJson<String>(json['type']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'qty': serializer.toJson<int>(qty),
      'reason': serializer.toJson<String?>(reason),
      'type': serializer.toJson<String>(type),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  WasteData copyWith({
    int? id,
    int? productId,
    int? qty,
    Value<String?> reason = const Value.absent(),
    String? type,
    DateTime? date,
  }) => WasteData(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    qty: qty ?? this.qty,
    reason: reason.present ? reason.value : this.reason,
    type: type ?? this.type,
    date: date ?? this.date,
  );
  WasteData copyWithCompanion(WasteCompanion data) {
    return WasteData(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      qty: data.qty.present ? data.qty.value : this.qty,
      reason: data.reason.present ? data.reason.value : this.reason,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WasteData(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('qty: $qty, ')
          ..write('reason: $reason, ')
          ..write('type: $type, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, qty, reason, type, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WasteData &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.qty == this.qty &&
          other.reason == this.reason &&
          other.type == this.type &&
          other.date == this.date);
}

class WasteCompanion extends UpdateCompanion<WasteData> {
  final Value<int> id;
  final Value<int> productId;
  final Value<int> qty;
  final Value<String?> reason;
  final Value<String> type;
  final Value<DateTime> date;
  const WasteCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.qty = const Value.absent(),
    this.reason = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
  });
  WasteCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required int qty,
    this.reason = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
  }) : productId = Value(productId),
       qty = Value(qty);
  static Insertable<WasteData> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<int>? qty,
    Expression<String>? reason,
    Expression<String>? type,
    Expression<DateTime>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (qty != null) 'qty': qty,
      if (reason != null) 'reason': reason,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
    });
  }

  WasteCompanion copyWith({
    Value<int>? id,
    Value<int>? productId,
    Value<int>? qty,
    Value<String?>? reason,
    Value<String>? type,
    Value<DateTime>? date,
  }) {
    return WasteCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      reason: reason ?? this.reason,
      type: type ?? this.type,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WasteCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('qty: $qty, ')
          ..write('reason: $reason, ')
          ..write('type: $type, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $LiquidityTable extends Liquidity
    with TableInfo<$LiquidityTable, LiquidityData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LiquidityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchIdMeta = const VerificationMeta(
    'branchId',
  );
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    type,
    category,
    description,
    amount,
    method,
    branchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'liquidity';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiquidityData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('branch_id')) {
      context.handle(
        _branchIdMeta,
        branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LiquidityData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiquidityData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      ),
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_id'],
      ),
    );
  }

  @override
  $LiquidityTable createAlias(String alias) {
    return $LiquidityTable(attachedDatabase, alias);
  }
}

class LiquidityData extends DataClass implements Insertable<LiquidityData> {
  final int id;
  final DateTime date;
  final String type;
  final String category;
  final String description;
  final int amount;
  final String? method;
  final int? branchId;
  const LiquidityData({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    this.method,
    this.branchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['type'] = Variable<String>(type);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || method != null) {
      map['method'] = Variable<String>(method);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    return map;
  }

  LiquidityCompanion toCompanion(bool nullToAbsent) {
    return LiquidityCompanion(
      id: Value(id),
      date: Value(date),
      type: Value(type),
      category: Value(category),
      description: Value(description),
      amount: Value(amount),
      method: method == null && nullToAbsent
          ? const Value.absent()
          : Value(method),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
    );
  }

  factory LiquidityData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiquidityData(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      type: serializer.fromJson<String>(json['type']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<int>(json['amount']),
      method: serializer.fromJson<String?>(json['method']),
      branchId: serializer.fromJson<int?>(json['branchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'type': serializer.toJson<String>(type),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<int>(amount),
      'method': serializer.toJson<String?>(method),
      'branchId': serializer.toJson<int?>(branchId),
    };
  }

  LiquidityData copyWith({
    int? id,
    DateTime? date,
    String? type,
    String? category,
    String? description,
    int? amount,
    Value<String?> method = const Value.absent(),
    Value<int?> branchId = const Value.absent(),
  }) => LiquidityData(
    id: id ?? this.id,
    date: date ?? this.date,
    type: type ?? this.type,
    category: category ?? this.category,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    method: method.present ? method.value : this.method,
    branchId: branchId.present ? branchId.value : this.branchId,
  );
  LiquidityData copyWithCompanion(LiquidityCompanion data) {
    return LiquidityData(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      method: data.method.present ? data.method.value : this.method,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiquidityData(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('method: $method, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    type,
    category,
    description,
    amount,
    method,
    branchId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiquidityData &&
          other.id == this.id &&
          other.date == this.date &&
          other.type == this.type &&
          other.category == this.category &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.method == this.method &&
          other.branchId == this.branchId);
}

class LiquidityCompanion extends UpdateCompanion<LiquidityData> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> type;
  final Value<String> category;
  final Value<String> description;
  final Value<int> amount;
  final Value<String?> method;
  final Value<int?> branchId;
  const LiquidityCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.method = const Value.absent(),
    this.branchId = const Value.absent(),
  });
  LiquidityCompanion.insert({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    required String type,
    required String category,
    required String description,
    required int amount,
    this.method = const Value.absent(),
    this.branchId = const Value.absent(),
  }) : type = Value(type),
       category = Value(category),
       description = Value(description),
       amount = Value(amount);
  static Insertable<LiquidityData> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? type,
    Expression<String>? category,
    Expression<String>? description,
    Expression<int>? amount,
    Expression<String>? method,
    Expression<int>? branchId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (method != null) 'method': method,
      if (branchId != null) 'branch_id': branchId,
    });
  }

  LiquidityCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? type,
    Value<String>? category,
    Value<String>? description,
    Value<int>? amount,
    Value<String?>? method,
    Value<int?>? branchId,
  }) {
    return LiquidityCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      branchId: branchId ?? this.branchId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiquidityCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('method: $method, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactPersonMeta = const VerificationMeta(
    'contactPerson',
  );
  @override
  late final GeneratedColumn<String> contactPerson = GeneratedColumn<String>(
    'contact_person',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    address,
    contactPerson,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Supplier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('contact_person')) {
      context.handle(
        _contactPersonMeta,
        contactPerson.isAcceptableOrUnknown(
          data['contact_person']!,
          _contactPersonMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      contactPerson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_person'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? note;
  final DateTime createdAt;
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || contactPerson != null) {
      map['contact_person'] = Variable<String>(contactPerson);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      contactPerson: contactPerson == null && nullToAbsent
          ? const Value.absent()
          : Value(contactPerson),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory Supplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      contactPerson: serializer.fromJson<String?>(json['contactPerson']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'contactPerson': serializer.toJson<String?>(contactPerson),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Supplier copyWith({
    int? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> contactPerson = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => Supplier(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    contactPerson: contactPerson.present
        ? contactPerson.value
        : this.contactPerson,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      contactPerson: data.contactPerson.present
          ? data.contactPerson.value
          : this.contactPerson,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, phone, address, contactPerson, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.contactPerson == this.contactPerson &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<String?> contactPerson;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SuppliersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Supplier> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? contactPerson,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SuppliersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? address,
    Value<String?>? contactPerson,
    Value<String?>? note,
    Value<DateTime>? createdAt,
  }) {
    return SuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
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
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (contactPerson.present) {
      map['contact_person'] = Variable<String>(contactPerson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BranchesTable extends Branches with TableInfo<$BranchesTable, Branche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BranchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Aktif'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, address, phone, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'branches';
  @override
  VerificationContext validateIntegrity(
    Insertable<Branche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Branche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Branche(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $BranchesTable createAlias(String alias) {
    return $BranchesTable(attachedDatabase, alias);
  }
}

class Branche extends DataClass implements Insertable<Branche> {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String status;
  const Branche({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  BranchesCompanion toCompanion(bool nullToAbsent) {
    return BranchesCompanion(
      id: Value(id),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      status: Value(status),
    );
  }

  factory Branche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Branche(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      phone: serializer.fromJson<String?>(json['phone']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'phone': serializer.toJson<String?>(phone),
      'status': serializer.toJson<String>(status),
    };
  }

  Branche copyWith({
    int? id,
    String? name,
    Value<String?> address = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    String? status,
  }) => Branche(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address.present ? address.value : this.address,
    phone: phone.present ? phone.value : this.phone,
    status: status ?? this.status,
  );
  Branche copyWithCompanion(BranchesCompanion data) {
    return Branche(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      phone: data.phone.present ? data.phone.value : this.phone,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Branche(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, address, phone, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Branche &&
          other.id == this.id &&
          other.name == this.name &&
          other.address == this.address &&
          other.phone == this.phone &&
          other.status == this.status);
}

class BranchesCompanion extends UpdateCompanion<Branche> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> address;
  final Value<String?> phone;
  final Value<String> status;
  const BranchesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.status = const Value.absent(),
  });
  BranchesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.status = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Branche> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? phone,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (status != null) 'status': status,
    });
  }

  BranchesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? address,
    Value<String?>? phone,
    Value<String>? status,
  }) {
    return BranchesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      status: status ?? this.status,
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
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BranchesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _storeNameMeta = const VerificationMeta(
    'storeName',
  );
  @override
  late final GeneratedColumn<String> storeName = GeneratedColumn<String>(
    'store_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _storeAddressMeta = const VerificationMeta(
    'storeAddress',
  );
  @override
  late final GeneratedColumn<String> storeAddress = GeneratedColumn<String>(
    'store_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storePhoneMeta = const VerificationMeta(
    'storePhone',
  );
  @override
  late final GeneratedColumn<String> storePhone = GeneratedColumn<String>(
    'store_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posPrefixMeta = const VerificationMeta(
    'posPrefix',
  );
  @override
  late final GeneratedColumn<String> posPrefix = GeneratedColumn<String>(
    'pos_prefix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trxCounterMeta = const VerificationMeta(
    'trxCounter',
  );
  @override
  late final GeneratedColumn<int> trxCounter = GeneratedColumn<int>(
    'trx_counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minStockAlertMeta = const VerificationMeta(
    'minStockAlert',
  );
  @override
  late final GeneratedColumn<int> minStockAlert = GeneratedColumn<int>(
    'min_stock_alert',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _qrisStringMeta = const VerificationMeta(
    'qrisString',
  );
  @override
  late final GeneratedColumn<String> qrisString = GeneratedColumn<String>(
    'qris_string',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posGridColumnsMeta = const VerificationMeta(
    'posGridColumns',
  );
  @override
  late final GeneratedColumn<int> posGridColumns = GeneratedColumn<int>(
    'pos_grid_columns',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _bankNameMeta = const VerificationMeta(
    'bankName',
  );
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
    'bank_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bankAccountMeta = const VerificationMeta(
    'bankAccount',
  );
  @override
  late final GeneratedColumn<String> bankAccount = GeneratedColumn<String>(
    'bank_account',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bankHolderMeta = const VerificationMeta(
    'bankHolder',
  );
  @override
  late final GeneratedColumn<String> bankHolder = GeneratedColumn<String>(
    'bank_holder',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptFooterMeta = const VerificationMeta(
    'receiptFooter',
  );
  @override
  late final GeneratedColumn<String> receiptFooter = GeneratedColumn<String>(
    'receipt_footer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storeLogoPathMeta = const VerificationMeta(
    'storeLogoPath',
  );
  @override
  late final GeneratedColumn<String> storeLogoPath = GeneratedColumn<String>(
    'store_logo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waTemplatesMeta = const VerificationMeta(
    'waTemplates',
  );
  @override
  late final GeneratedColumn<String> waTemplates = GeneratedColumn<String>(
    'wa_templates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsPerRupiahMeta = const VerificationMeta(
    'pointsPerRupiah',
  );
  @override
  late final GeneratedColumn<int> pointsPerRupiah = GeneratedColumn<int>(
    'points_per_rupiah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _silverThresholdMeta = const VerificationMeta(
    'silverThreshold',
  );
  @override
  late final GeneratedColumn<int> silverThreshold = GeneratedColumn<int>(
    'silver_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goldThresholdMeta = const VerificationMeta(
    'goldThreshold',
  );
  @override
  late final GeneratedColumn<int> goldThreshold = GeneratedColumn<int>(
    'gold_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1000),
  );
  static const VerificationMeta _platinumThresholdMeta = const VerificationMeta(
    'platinumThreshold',
  );
  @override
  late final GeneratedColumn<int> platinumThreshold = GeneratedColumn<int>(
    'platinum_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5000),
  );
  static const VerificationMeta _qrisImagePathMeta = const VerificationMeta(
    'qrisImagePath',
  );
  @override
  late final GeneratedColumn<String> qrisImagePath = GeneratedColumn<String>(
    'qris_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptHeaderMeta = const VerificationMeta(
    'receiptHeader',
  );
  @override
  late final GeneratedColumn<String> receiptHeader = GeneratedColumn<String>(
    'receipt_header',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptPaperSizeMeta = const VerificationMeta(
    'receiptPaperSize',
  );
  @override
  late final GeneratedColumn<String> receiptPaperSize = GeneratedColumn<String>(
    'receipt_paper_size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('58mm'),
  );
  static const VerificationMeta _pinLengthMeta = const VerificationMeta(
    'pinLength',
  );
  @override
  late final GeneratedColumn<int> pinLength = GeneratedColumn<int>(
    'pin_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(6),
  );
  static const VerificationMeta _receiptShowLogoMeta = const VerificationMeta(
    'receiptShowLogo',
  );
  @override
  late final GeneratedColumn<bool> receiptShowLogo = GeneratedColumn<bool>(
    'receipt_show_logo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_show_logo" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _receiptShowCashierMeta =
      const VerificationMeta('receiptShowCashier');
  @override
  late final GeneratedColumn<bool> receiptShowCashier = GeneratedColumn<bool>(
    'receipt_show_cashier',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_show_cashier" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _receiptShowInvoiceMeta =
      const VerificationMeta('receiptShowInvoice');
  @override
  late final GeneratedColumn<bool> receiptShowInvoice = GeneratedColumn<bool>(
    'receipt_show_invoice',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_show_invoice" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _receiptShowDateMeta = const VerificationMeta(
    'receiptShowDate',
  );
  @override
  late final GeneratedColumn<bool> receiptShowDate = GeneratedColumn<bool>(
    'receipt_show_date',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_show_date" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _receiptShowBarcodeMeta =
      const VerificationMeta('receiptShowBarcode');
  @override
  late final GeneratedColumn<bool> receiptShowBarcode = GeneratedColumn<bool>(
    'receipt_show_barcode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_show_barcode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _kitchenPrinterAddressMeta =
      const VerificationMeta('kitchenPrinterAddress');
  @override
  late final GeneratedColumn<String> kitchenPrinterAddress =
      GeneratedColumn<String>(
        'kitchen_printer_address',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _kitchenPrinterEnabledMeta =
      const VerificationMeta('kitchenPrinterEnabled');
  @override
  late final GeneratedColumn<bool> kitchenPrinterEnabled =
      GeneratedColumn<bool>(
        'kitchen_printer_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("kitchen_printer_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeName,
    storeAddress,
    storePhone,
    posPrefix,
    trxCounter,
    minStockAlert,
    qrisString,
    themeMode,
    posGridColumns,
    bankName,
    bankAccount,
    bankHolder,
    receiptFooter,
    storeLogoPath,
    waTemplates,
    pointsPerRupiah,
    silverThreshold,
    goldThreshold,
    platinumThreshold,
    qrisImagePath,
    receiptHeader,
    receiptPaperSize,
    pinLength,
    receiptShowLogo,
    receiptShowCashier,
    receiptShowInvoice,
    receiptShowDate,
    receiptShowBarcode,
    kitchenPrinterAddress,
    kitchenPrinterEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('store_name')) {
      context.handle(
        _storeNameMeta,
        storeName.isAcceptableOrUnknown(data['store_name']!, _storeNameMeta),
      );
    }
    if (data.containsKey('store_address')) {
      context.handle(
        _storeAddressMeta,
        storeAddress.isAcceptableOrUnknown(
          data['store_address']!,
          _storeAddressMeta,
        ),
      );
    }
    if (data.containsKey('store_phone')) {
      context.handle(
        _storePhoneMeta,
        storePhone.isAcceptableOrUnknown(data['store_phone']!, _storePhoneMeta),
      );
    }
    if (data.containsKey('pos_prefix')) {
      context.handle(
        _posPrefixMeta,
        posPrefix.isAcceptableOrUnknown(data['pos_prefix']!, _posPrefixMeta),
      );
    }
    if (data.containsKey('trx_counter')) {
      context.handle(
        _trxCounterMeta,
        trxCounter.isAcceptableOrUnknown(data['trx_counter']!, _trxCounterMeta),
      );
    }
    if (data.containsKey('min_stock_alert')) {
      context.handle(
        _minStockAlertMeta,
        minStockAlert.isAcceptableOrUnknown(
          data['min_stock_alert']!,
          _minStockAlertMeta,
        ),
      );
    }
    if (data.containsKey('qris_string')) {
      context.handle(
        _qrisStringMeta,
        qrisString.isAcceptableOrUnknown(data['qris_string']!, _qrisStringMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('pos_grid_columns')) {
      context.handle(
        _posGridColumnsMeta,
        posGridColumns.isAcceptableOrUnknown(
          data['pos_grid_columns']!,
          _posGridColumnsMeta,
        ),
      );
    }
    if (data.containsKey('bank_name')) {
      context.handle(
        _bankNameMeta,
        bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta),
      );
    }
    if (data.containsKey('bank_account')) {
      context.handle(
        _bankAccountMeta,
        bankAccount.isAcceptableOrUnknown(
          data['bank_account']!,
          _bankAccountMeta,
        ),
      );
    }
    if (data.containsKey('bank_holder')) {
      context.handle(
        _bankHolderMeta,
        bankHolder.isAcceptableOrUnknown(data['bank_holder']!, _bankHolderMeta),
      );
    }
    if (data.containsKey('receipt_footer')) {
      context.handle(
        _receiptFooterMeta,
        receiptFooter.isAcceptableOrUnknown(
          data['receipt_footer']!,
          _receiptFooterMeta,
        ),
      );
    }
    if (data.containsKey('store_logo_path')) {
      context.handle(
        _storeLogoPathMeta,
        storeLogoPath.isAcceptableOrUnknown(
          data['store_logo_path']!,
          _storeLogoPathMeta,
        ),
      );
    }
    if (data.containsKey('wa_templates')) {
      context.handle(
        _waTemplatesMeta,
        waTemplates.isAcceptableOrUnknown(
          data['wa_templates']!,
          _waTemplatesMeta,
        ),
      );
    }
    if (data.containsKey('points_per_rupiah')) {
      context.handle(
        _pointsPerRupiahMeta,
        pointsPerRupiah.isAcceptableOrUnknown(
          data['points_per_rupiah']!,
          _pointsPerRupiahMeta,
        ),
      );
    }
    if (data.containsKey('silver_threshold')) {
      context.handle(
        _silverThresholdMeta,
        silverThreshold.isAcceptableOrUnknown(
          data['silver_threshold']!,
          _silverThresholdMeta,
        ),
      );
    }
    if (data.containsKey('gold_threshold')) {
      context.handle(
        _goldThresholdMeta,
        goldThreshold.isAcceptableOrUnknown(
          data['gold_threshold']!,
          _goldThresholdMeta,
        ),
      );
    }
    if (data.containsKey('platinum_threshold')) {
      context.handle(
        _platinumThresholdMeta,
        platinumThreshold.isAcceptableOrUnknown(
          data['platinum_threshold']!,
          _platinumThresholdMeta,
        ),
      );
    }
    if (data.containsKey('qris_image_path')) {
      context.handle(
        _qrisImagePathMeta,
        qrisImagePath.isAcceptableOrUnknown(
          data['qris_image_path']!,
          _qrisImagePathMeta,
        ),
      );
    }
    if (data.containsKey('receipt_header')) {
      context.handle(
        _receiptHeaderMeta,
        receiptHeader.isAcceptableOrUnknown(
          data['receipt_header']!,
          _receiptHeaderMeta,
        ),
      );
    }
    if (data.containsKey('receipt_paper_size')) {
      context.handle(
        _receiptPaperSizeMeta,
        receiptPaperSize.isAcceptableOrUnknown(
          data['receipt_paper_size']!,
          _receiptPaperSizeMeta,
        ),
      );
    }
    if (data.containsKey('pin_length')) {
      context.handle(
        _pinLengthMeta,
        pinLength.isAcceptableOrUnknown(data['pin_length']!, _pinLengthMeta),
      );
    }
    if (data.containsKey('receipt_show_logo')) {
      context.handle(
        _receiptShowLogoMeta,
        receiptShowLogo.isAcceptableOrUnknown(
          data['receipt_show_logo']!,
          _receiptShowLogoMeta,
        ),
      );
    }
    if (data.containsKey('receipt_show_cashier')) {
      context.handle(
        _receiptShowCashierMeta,
        receiptShowCashier.isAcceptableOrUnknown(
          data['receipt_show_cashier']!,
          _receiptShowCashierMeta,
        ),
      );
    }
    if (data.containsKey('receipt_show_invoice')) {
      context.handle(
        _receiptShowInvoiceMeta,
        receiptShowInvoice.isAcceptableOrUnknown(
          data['receipt_show_invoice']!,
          _receiptShowInvoiceMeta,
        ),
      );
    }
    if (data.containsKey('receipt_show_date')) {
      context.handle(
        _receiptShowDateMeta,
        receiptShowDate.isAcceptableOrUnknown(
          data['receipt_show_date']!,
          _receiptShowDateMeta,
        ),
      );
    }
    if (data.containsKey('receipt_show_barcode')) {
      context.handle(
        _receiptShowBarcodeMeta,
        receiptShowBarcode.isAcceptableOrUnknown(
          data['receipt_show_barcode']!,
          _receiptShowBarcodeMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_printer_address')) {
      context.handle(
        _kitchenPrinterAddressMeta,
        kitchenPrinterAddress.isAcceptableOrUnknown(
          data['kitchen_printer_address']!,
          _kitchenPrinterAddressMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_printer_enabled')) {
      context.handle(
        _kitchenPrinterEnabledMeta,
        kitchenPrinterEnabled.isAcceptableOrUnknown(
          data['kitchen_printer_enabled']!,
          _kitchenPrinterEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      storeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_name'],
      )!,
      storeAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_address'],
      ),
      storePhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_phone'],
      ),
      posPrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos_prefix'],
      ),
      trxCounter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trx_counter'],
      )!,
      minStockAlert: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_stock_alert'],
      )!,
      qrisString: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qris_string'],
      ),
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      ),
      posGridColumns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pos_grid_columns'],
      )!,
      bankName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_name'],
      ),
      bankAccount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_account'],
      ),
      bankHolder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_holder'],
      ),
      receiptFooter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_footer'],
      ),
      storeLogoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_logo_path'],
      ),
      waTemplates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wa_templates'],
      ),
      pointsPerRupiah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_per_rupiah'],
      )!,
      silverThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}silver_threshold'],
      )!,
      goldThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gold_threshold'],
      )!,
      platinumThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}platinum_threshold'],
      )!,
      qrisImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qris_image_path'],
      ),
      receiptHeader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_header'],
      ),
      receiptPaperSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_paper_size'],
      )!,
      pinLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pin_length'],
      )!,
      receiptShowLogo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_show_logo'],
      )!,
      receiptShowCashier: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_show_cashier'],
      )!,
      receiptShowInvoice: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_show_invoice'],
      )!,
      receiptShowDate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_show_date'],
      )!,
      receiptShowBarcode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_show_barcode'],
      )!,
      kitchenPrinterAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_printer_address'],
      ),
      kitchenPrinterEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kitchen_printer_enabled'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;
  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? posPrefix;
  final int trxCounter;
  final int minStockAlert;
  final String? qrisString;
  final String? themeMode;
  final int posGridColumns;
  final String? bankName;
  final String? bankAccount;
  final String? bankHolder;
  final String? receiptFooter;
  final String? storeLogoPath;
  final String? waTemplates;
  final int pointsPerRupiah;
  final int silverThreshold;
  final int goldThreshold;
  final int platinumThreshold;
  final String? qrisImagePath;
  final String? receiptHeader;
  final String receiptPaperSize;
  final int pinLength;
  final bool receiptShowLogo;
  final bool receiptShowCashier;
  final bool receiptShowInvoice;
  final bool receiptShowDate;
  final bool receiptShowBarcode;
  final String? kitchenPrinterAddress;
  final bool kitchenPrinterEnabled;
  const Setting({
    required this.id,
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    this.posPrefix,
    required this.trxCounter,
    required this.minStockAlert,
    this.qrisString,
    this.themeMode,
    required this.posGridColumns,
    this.bankName,
    this.bankAccount,
    this.bankHolder,
    this.receiptFooter,
    this.storeLogoPath,
    this.waTemplates,
    required this.pointsPerRupiah,
    required this.silverThreshold,
    required this.goldThreshold,
    required this.platinumThreshold,
    this.qrisImagePath,
    this.receiptHeader,
    required this.receiptPaperSize,
    required this.pinLength,
    required this.receiptShowLogo,
    required this.receiptShowCashier,
    required this.receiptShowInvoice,
    required this.receiptShowDate,
    required this.receiptShowBarcode,
    this.kitchenPrinterAddress,
    required this.kitchenPrinterEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['store_name'] = Variable<String>(storeName);
    if (!nullToAbsent || storeAddress != null) {
      map['store_address'] = Variable<String>(storeAddress);
    }
    if (!nullToAbsent || storePhone != null) {
      map['store_phone'] = Variable<String>(storePhone);
    }
    if (!nullToAbsent || posPrefix != null) {
      map['pos_prefix'] = Variable<String>(posPrefix);
    }
    map['trx_counter'] = Variable<int>(trxCounter);
    map['min_stock_alert'] = Variable<int>(minStockAlert);
    if (!nullToAbsent || qrisString != null) {
      map['qris_string'] = Variable<String>(qrisString);
    }
    if (!nullToAbsent || themeMode != null) {
      map['theme_mode'] = Variable<String>(themeMode);
    }
    map['pos_grid_columns'] = Variable<int>(posGridColumns);
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    if (!nullToAbsent || bankAccount != null) {
      map['bank_account'] = Variable<String>(bankAccount);
    }
    if (!nullToAbsent || bankHolder != null) {
      map['bank_holder'] = Variable<String>(bankHolder);
    }
    if (!nullToAbsent || receiptFooter != null) {
      map['receipt_footer'] = Variable<String>(receiptFooter);
    }
    if (!nullToAbsent || storeLogoPath != null) {
      map['store_logo_path'] = Variable<String>(storeLogoPath);
    }
    if (!nullToAbsent || waTemplates != null) {
      map['wa_templates'] = Variable<String>(waTemplates);
    }
    map['points_per_rupiah'] = Variable<int>(pointsPerRupiah);
    map['silver_threshold'] = Variable<int>(silverThreshold);
    map['gold_threshold'] = Variable<int>(goldThreshold);
    map['platinum_threshold'] = Variable<int>(platinumThreshold);
    if (!nullToAbsent || qrisImagePath != null) {
      map['qris_image_path'] = Variable<String>(qrisImagePath);
    }
    if (!nullToAbsent || receiptHeader != null) {
      map['receipt_header'] = Variable<String>(receiptHeader);
    }
    map['receipt_paper_size'] = Variable<String>(receiptPaperSize);
    map['pin_length'] = Variable<int>(pinLength);
    map['receipt_show_logo'] = Variable<bool>(receiptShowLogo);
    map['receipt_show_cashier'] = Variable<bool>(receiptShowCashier);
    map['receipt_show_invoice'] = Variable<bool>(receiptShowInvoice);
    map['receipt_show_date'] = Variable<bool>(receiptShowDate);
    map['receipt_show_barcode'] = Variable<bool>(receiptShowBarcode);
    if (!nullToAbsent || kitchenPrinterAddress != null) {
      map['kitchen_printer_address'] = Variable<String>(kitchenPrinterAddress);
    }
    map['kitchen_printer_enabled'] = Variable<bool>(kitchenPrinterEnabled);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      storeName: Value(storeName),
      storeAddress: storeAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(storeAddress),
      storePhone: storePhone == null && nullToAbsent
          ? const Value.absent()
          : Value(storePhone),
      posPrefix: posPrefix == null && nullToAbsent
          ? const Value.absent()
          : Value(posPrefix),
      trxCounter: Value(trxCounter),
      minStockAlert: Value(minStockAlert),
      qrisString: qrisString == null && nullToAbsent
          ? const Value.absent()
          : Value(qrisString),
      themeMode: themeMode == null && nullToAbsent
          ? const Value.absent()
          : Value(themeMode),
      posGridColumns: Value(posGridColumns),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      bankAccount: bankAccount == null && nullToAbsent
          ? const Value.absent()
          : Value(bankAccount),
      bankHolder: bankHolder == null && nullToAbsent
          ? const Value.absent()
          : Value(bankHolder),
      receiptFooter: receiptFooter == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptFooter),
      storeLogoPath: storeLogoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(storeLogoPath),
      waTemplates: waTemplates == null && nullToAbsent
          ? const Value.absent()
          : Value(waTemplates),
      pointsPerRupiah: Value(pointsPerRupiah),
      silverThreshold: Value(silverThreshold),
      goldThreshold: Value(goldThreshold),
      platinumThreshold: Value(platinumThreshold),
      qrisImagePath: qrisImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(qrisImagePath),
      receiptHeader: receiptHeader == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptHeader),
      receiptPaperSize: Value(receiptPaperSize),
      pinLength: Value(pinLength),
      receiptShowLogo: Value(receiptShowLogo),
      receiptShowCashier: Value(receiptShowCashier),
      receiptShowInvoice: Value(receiptShowInvoice),
      receiptShowDate: Value(receiptShowDate),
      receiptShowBarcode: Value(receiptShowBarcode),
      kitchenPrinterAddress: kitchenPrinterAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(kitchenPrinterAddress),
      kitchenPrinterEnabled: Value(kitchenPrinterEnabled),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      storeName: serializer.fromJson<String>(json['storeName']),
      storeAddress: serializer.fromJson<String?>(json['storeAddress']),
      storePhone: serializer.fromJson<String?>(json['storePhone']),
      posPrefix: serializer.fromJson<String?>(json['posPrefix']),
      trxCounter: serializer.fromJson<int>(json['trxCounter']),
      minStockAlert: serializer.fromJson<int>(json['minStockAlert']),
      qrisString: serializer.fromJson<String?>(json['qrisString']),
      themeMode: serializer.fromJson<String?>(json['themeMode']),
      posGridColumns: serializer.fromJson<int>(json['posGridColumns']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      bankAccount: serializer.fromJson<String?>(json['bankAccount']),
      bankHolder: serializer.fromJson<String?>(json['bankHolder']),
      receiptFooter: serializer.fromJson<String?>(json['receiptFooter']),
      storeLogoPath: serializer.fromJson<String?>(json['storeLogoPath']),
      waTemplates: serializer.fromJson<String?>(json['waTemplates']),
      pointsPerRupiah: serializer.fromJson<int>(json['pointsPerRupiah']),
      silverThreshold: serializer.fromJson<int>(json['silverThreshold']),
      goldThreshold: serializer.fromJson<int>(json['goldThreshold']),
      platinumThreshold: serializer.fromJson<int>(json['platinumThreshold']),
      qrisImagePath: serializer.fromJson<String?>(json['qrisImagePath']),
      receiptHeader: serializer.fromJson<String?>(json['receiptHeader']),
      receiptPaperSize: serializer.fromJson<String>(json['receiptPaperSize']),
      pinLength: serializer.fromJson<int>(json['pinLength']),
      receiptShowLogo: serializer.fromJson<bool>(json['receiptShowLogo']),
      receiptShowCashier: serializer.fromJson<bool>(json['receiptShowCashier']),
      receiptShowInvoice: serializer.fromJson<bool>(json['receiptShowInvoice']),
      receiptShowDate: serializer.fromJson<bool>(json['receiptShowDate']),
      receiptShowBarcode: serializer.fromJson<bool>(json['receiptShowBarcode']),
      kitchenPrinterAddress: serializer.fromJson<String?>(
        json['kitchenPrinterAddress'],
      ),
      kitchenPrinterEnabled: serializer.fromJson<bool>(
        json['kitchenPrinterEnabled'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'storeName': serializer.toJson<String>(storeName),
      'storeAddress': serializer.toJson<String?>(storeAddress),
      'storePhone': serializer.toJson<String?>(storePhone),
      'posPrefix': serializer.toJson<String?>(posPrefix),
      'trxCounter': serializer.toJson<int>(trxCounter),
      'minStockAlert': serializer.toJson<int>(minStockAlert),
      'qrisString': serializer.toJson<String?>(qrisString),
      'themeMode': serializer.toJson<String?>(themeMode),
      'posGridColumns': serializer.toJson<int>(posGridColumns),
      'bankName': serializer.toJson<String?>(bankName),
      'bankAccount': serializer.toJson<String?>(bankAccount),
      'bankHolder': serializer.toJson<String?>(bankHolder),
      'receiptFooter': serializer.toJson<String?>(receiptFooter),
      'storeLogoPath': serializer.toJson<String?>(storeLogoPath),
      'waTemplates': serializer.toJson<String?>(waTemplates),
      'pointsPerRupiah': serializer.toJson<int>(pointsPerRupiah),
      'silverThreshold': serializer.toJson<int>(silverThreshold),
      'goldThreshold': serializer.toJson<int>(goldThreshold),
      'platinumThreshold': serializer.toJson<int>(platinumThreshold),
      'qrisImagePath': serializer.toJson<String?>(qrisImagePath),
      'receiptHeader': serializer.toJson<String?>(receiptHeader),
      'receiptPaperSize': serializer.toJson<String>(receiptPaperSize),
      'pinLength': serializer.toJson<int>(pinLength),
      'receiptShowLogo': serializer.toJson<bool>(receiptShowLogo),
      'receiptShowCashier': serializer.toJson<bool>(receiptShowCashier),
      'receiptShowInvoice': serializer.toJson<bool>(receiptShowInvoice),
      'receiptShowDate': serializer.toJson<bool>(receiptShowDate),
      'receiptShowBarcode': serializer.toJson<bool>(receiptShowBarcode),
      'kitchenPrinterAddress': serializer.toJson<String?>(
        kitchenPrinterAddress,
      ),
      'kitchenPrinterEnabled': serializer.toJson<bool>(kitchenPrinterEnabled),
    };
  }

  Setting copyWith({
    int? id,
    String? storeName,
    Value<String?> storeAddress = const Value.absent(),
    Value<String?> storePhone = const Value.absent(),
    Value<String?> posPrefix = const Value.absent(),
    int? trxCounter,
    int? minStockAlert,
    Value<String?> qrisString = const Value.absent(),
    Value<String?> themeMode = const Value.absent(),
    int? posGridColumns,
    Value<String?> bankName = const Value.absent(),
    Value<String?> bankAccount = const Value.absent(),
    Value<String?> bankHolder = const Value.absent(),
    Value<String?> receiptFooter = const Value.absent(),
    Value<String?> storeLogoPath = const Value.absent(),
    Value<String?> waTemplates = const Value.absent(),
    int? pointsPerRupiah,
    int? silverThreshold,
    int? goldThreshold,
    int? platinumThreshold,
    Value<String?> qrisImagePath = const Value.absent(),
    Value<String?> receiptHeader = const Value.absent(),
    String? receiptPaperSize,
    int? pinLength,
    bool? receiptShowLogo,
    bool? receiptShowCashier,
    bool? receiptShowInvoice,
    bool? receiptShowDate,
    bool? receiptShowBarcode,
    Value<String?> kitchenPrinterAddress = const Value.absent(),
    bool? kitchenPrinterEnabled,
  }) => Setting(
    id: id ?? this.id,
    storeName: storeName ?? this.storeName,
    storeAddress: storeAddress.present ? storeAddress.value : this.storeAddress,
    storePhone: storePhone.present ? storePhone.value : this.storePhone,
    posPrefix: posPrefix.present ? posPrefix.value : this.posPrefix,
    trxCounter: trxCounter ?? this.trxCounter,
    minStockAlert: minStockAlert ?? this.minStockAlert,
    qrisString: qrisString.present ? qrisString.value : this.qrisString,
    themeMode: themeMode.present ? themeMode.value : this.themeMode,
    posGridColumns: posGridColumns ?? this.posGridColumns,
    bankName: bankName.present ? bankName.value : this.bankName,
    bankAccount: bankAccount.present ? bankAccount.value : this.bankAccount,
    bankHolder: bankHolder.present ? bankHolder.value : this.bankHolder,
    receiptFooter: receiptFooter.present
        ? receiptFooter.value
        : this.receiptFooter,
    storeLogoPath: storeLogoPath.present
        ? storeLogoPath.value
        : this.storeLogoPath,
    waTemplates: waTemplates.present ? waTemplates.value : this.waTemplates,
    pointsPerRupiah: pointsPerRupiah ?? this.pointsPerRupiah,
    silverThreshold: silverThreshold ?? this.silverThreshold,
    goldThreshold: goldThreshold ?? this.goldThreshold,
    platinumThreshold: platinumThreshold ?? this.platinumThreshold,
    qrisImagePath: qrisImagePath.present
        ? qrisImagePath.value
        : this.qrisImagePath,
    receiptHeader: receiptHeader.present
        ? receiptHeader.value
        : this.receiptHeader,
    receiptPaperSize: receiptPaperSize ?? this.receiptPaperSize,
    pinLength: pinLength ?? this.pinLength,
    receiptShowLogo: receiptShowLogo ?? this.receiptShowLogo,
    receiptShowCashier: receiptShowCashier ?? this.receiptShowCashier,
    receiptShowInvoice: receiptShowInvoice ?? this.receiptShowInvoice,
    receiptShowDate: receiptShowDate ?? this.receiptShowDate,
    receiptShowBarcode: receiptShowBarcode ?? this.receiptShowBarcode,
    kitchenPrinterAddress: kitchenPrinterAddress.present
        ? kitchenPrinterAddress.value
        : this.kitchenPrinterAddress,
    kitchenPrinterEnabled: kitchenPrinterEnabled ?? this.kitchenPrinterEnabled,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      storeName: data.storeName.present ? data.storeName.value : this.storeName,
      storeAddress: data.storeAddress.present
          ? data.storeAddress.value
          : this.storeAddress,
      storePhone: data.storePhone.present
          ? data.storePhone.value
          : this.storePhone,
      posPrefix: data.posPrefix.present ? data.posPrefix.value : this.posPrefix,
      trxCounter: data.trxCounter.present
          ? data.trxCounter.value
          : this.trxCounter,
      minStockAlert: data.minStockAlert.present
          ? data.minStockAlert.value
          : this.minStockAlert,
      qrisString: data.qrisString.present
          ? data.qrisString.value
          : this.qrisString,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      posGridColumns: data.posGridColumns.present
          ? data.posGridColumns.value
          : this.posGridColumns,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      bankAccount: data.bankAccount.present
          ? data.bankAccount.value
          : this.bankAccount,
      bankHolder: data.bankHolder.present
          ? data.bankHolder.value
          : this.bankHolder,
      receiptFooter: data.receiptFooter.present
          ? data.receiptFooter.value
          : this.receiptFooter,
      storeLogoPath: data.storeLogoPath.present
          ? data.storeLogoPath.value
          : this.storeLogoPath,
      waTemplates: data.waTemplates.present
          ? data.waTemplates.value
          : this.waTemplates,
      pointsPerRupiah: data.pointsPerRupiah.present
          ? data.pointsPerRupiah.value
          : this.pointsPerRupiah,
      silverThreshold: data.silverThreshold.present
          ? data.silverThreshold.value
          : this.silverThreshold,
      goldThreshold: data.goldThreshold.present
          ? data.goldThreshold.value
          : this.goldThreshold,
      platinumThreshold: data.platinumThreshold.present
          ? data.platinumThreshold.value
          : this.platinumThreshold,
      qrisImagePath: data.qrisImagePath.present
          ? data.qrisImagePath.value
          : this.qrisImagePath,
      receiptHeader: data.receiptHeader.present
          ? data.receiptHeader.value
          : this.receiptHeader,
      receiptPaperSize: data.receiptPaperSize.present
          ? data.receiptPaperSize.value
          : this.receiptPaperSize,
      pinLength: data.pinLength.present ? data.pinLength.value : this.pinLength,
      receiptShowLogo: data.receiptShowLogo.present
          ? data.receiptShowLogo.value
          : this.receiptShowLogo,
      receiptShowCashier: data.receiptShowCashier.present
          ? data.receiptShowCashier.value
          : this.receiptShowCashier,
      receiptShowInvoice: data.receiptShowInvoice.present
          ? data.receiptShowInvoice.value
          : this.receiptShowInvoice,
      receiptShowDate: data.receiptShowDate.present
          ? data.receiptShowDate.value
          : this.receiptShowDate,
      receiptShowBarcode: data.receiptShowBarcode.present
          ? data.receiptShowBarcode.value
          : this.receiptShowBarcode,
      kitchenPrinterAddress: data.kitchenPrinterAddress.present
          ? data.kitchenPrinterAddress.value
          : this.kitchenPrinterAddress,
      kitchenPrinterEnabled: data.kitchenPrinterEnabled.present
          ? data.kitchenPrinterEnabled.value
          : this.kitchenPrinterEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('storeName: $storeName, ')
          ..write('storeAddress: $storeAddress, ')
          ..write('storePhone: $storePhone, ')
          ..write('posPrefix: $posPrefix, ')
          ..write('trxCounter: $trxCounter, ')
          ..write('minStockAlert: $minStockAlert, ')
          ..write('qrisString: $qrisString, ')
          ..write('themeMode: $themeMode, ')
          ..write('posGridColumns: $posGridColumns, ')
          ..write('bankName: $bankName, ')
          ..write('bankAccount: $bankAccount, ')
          ..write('bankHolder: $bankHolder, ')
          ..write('receiptFooter: $receiptFooter, ')
          ..write('storeLogoPath: $storeLogoPath, ')
          ..write('waTemplates: $waTemplates, ')
          ..write('pointsPerRupiah: $pointsPerRupiah, ')
          ..write('silverThreshold: $silverThreshold, ')
          ..write('goldThreshold: $goldThreshold, ')
          ..write('platinumThreshold: $platinumThreshold, ')
          ..write('qrisImagePath: $qrisImagePath, ')
          ..write('receiptHeader: $receiptHeader, ')
          ..write('receiptPaperSize: $receiptPaperSize, ')
          ..write('pinLength: $pinLength, ')
          ..write('receiptShowLogo: $receiptShowLogo, ')
          ..write('receiptShowCashier: $receiptShowCashier, ')
          ..write('receiptShowInvoice: $receiptShowInvoice, ')
          ..write('receiptShowDate: $receiptShowDate, ')
          ..write('receiptShowBarcode: $receiptShowBarcode, ')
          ..write('kitchenPrinterAddress: $kitchenPrinterAddress, ')
          ..write('kitchenPrinterEnabled: $kitchenPrinterEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    storeName,
    storeAddress,
    storePhone,
    posPrefix,
    trxCounter,
    minStockAlert,
    qrisString,
    themeMode,
    posGridColumns,
    bankName,
    bankAccount,
    bankHolder,
    receiptFooter,
    storeLogoPath,
    waTemplates,
    pointsPerRupiah,
    silverThreshold,
    goldThreshold,
    platinumThreshold,
    qrisImagePath,
    receiptHeader,
    receiptPaperSize,
    pinLength,
    receiptShowLogo,
    receiptShowCashier,
    receiptShowInvoice,
    receiptShowDate,
    receiptShowBarcode,
    kitchenPrinterAddress,
    kitchenPrinterEnabled,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.storeName == this.storeName &&
          other.storeAddress == this.storeAddress &&
          other.storePhone == this.storePhone &&
          other.posPrefix == this.posPrefix &&
          other.trxCounter == this.trxCounter &&
          other.minStockAlert == this.minStockAlert &&
          other.qrisString == this.qrisString &&
          other.themeMode == this.themeMode &&
          other.posGridColumns == this.posGridColumns &&
          other.bankName == this.bankName &&
          other.bankAccount == this.bankAccount &&
          other.bankHolder == this.bankHolder &&
          other.receiptFooter == this.receiptFooter &&
          other.storeLogoPath == this.storeLogoPath &&
          other.waTemplates == this.waTemplates &&
          other.pointsPerRupiah == this.pointsPerRupiah &&
          other.silverThreshold == this.silverThreshold &&
          other.goldThreshold == this.goldThreshold &&
          other.platinumThreshold == this.platinumThreshold &&
          other.qrisImagePath == this.qrisImagePath &&
          other.receiptHeader == this.receiptHeader &&
          other.receiptPaperSize == this.receiptPaperSize &&
          other.pinLength == this.pinLength &&
          other.receiptShowLogo == this.receiptShowLogo &&
          other.receiptShowCashier == this.receiptShowCashier &&
          other.receiptShowInvoice == this.receiptShowInvoice &&
          other.receiptShowDate == this.receiptShowDate &&
          other.receiptShowBarcode == this.receiptShowBarcode &&
          other.kitchenPrinterAddress == this.kitchenPrinterAddress &&
          other.kitchenPrinterEnabled == this.kitchenPrinterEnabled);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<String> storeName;
  final Value<String?> storeAddress;
  final Value<String?> storePhone;
  final Value<String?> posPrefix;
  final Value<int> trxCounter;
  final Value<int> minStockAlert;
  final Value<String?> qrisString;
  final Value<String?> themeMode;
  final Value<int> posGridColumns;
  final Value<String?> bankName;
  final Value<String?> bankAccount;
  final Value<String?> bankHolder;
  final Value<String?> receiptFooter;
  final Value<String?> storeLogoPath;
  final Value<String?> waTemplates;
  final Value<int> pointsPerRupiah;
  final Value<int> silverThreshold;
  final Value<int> goldThreshold;
  final Value<int> platinumThreshold;
  final Value<String?> qrisImagePath;
  final Value<String?> receiptHeader;
  final Value<String> receiptPaperSize;
  final Value<int> pinLength;
  final Value<bool> receiptShowLogo;
  final Value<bool> receiptShowCashier;
  final Value<bool> receiptShowInvoice;
  final Value<bool> receiptShowDate;
  final Value<bool> receiptShowBarcode;
  final Value<String?> kitchenPrinterAddress;
  final Value<bool> kitchenPrinterEnabled;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.storeName = const Value.absent(),
    this.storeAddress = const Value.absent(),
    this.storePhone = const Value.absent(),
    this.posPrefix = const Value.absent(),
    this.trxCounter = const Value.absent(),
    this.minStockAlert = const Value.absent(),
    this.qrisString = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.posGridColumns = const Value.absent(),
    this.bankName = const Value.absent(),
    this.bankAccount = const Value.absent(),
    this.bankHolder = const Value.absent(),
    this.receiptFooter = const Value.absent(),
    this.storeLogoPath = const Value.absent(),
    this.waTemplates = const Value.absent(),
    this.pointsPerRupiah = const Value.absent(),
    this.silverThreshold = const Value.absent(),
    this.goldThreshold = const Value.absent(),
    this.platinumThreshold = const Value.absent(),
    this.qrisImagePath = const Value.absent(),
    this.receiptHeader = const Value.absent(),
    this.receiptPaperSize = const Value.absent(),
    this.pinLength = const Value.absent(),
    this.receiptShowLogo = const Value.absent(),
    this.receiptShowCashier = const Value.absent(),
    this.receiptShowInvoice = const Value.absent(),
    this.receiptShowDate = const Value.absent(),
    this.receiptShowBarcode = const Value.absent(),
    this.kitchenPrinterAddress = const Value.absent(),
    this.kitchenPrinterEnabled = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.storeName = const Value.absent(),
    this.storeAddress = const Value.absent(),
    this.storePhone = const Value.absent(),
    this.posPrefix = const Value.absent(),
    this.trxCounter = const Value.absent(),
    this.minStockAlert = const Value.absent(),
    this.qrisString = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.posGridColumns = const Value.absent(),
    this.bankName = const Value.absent(),
    this.bankAccount = const Value.absent(),
    this.bankHolder = const Value.absent(),
    this.receiptFooter = const Value.absent(),
    this.storeLogoPath = const Value.absent(),
    this.waTemplates = const Value.absent(),
    this.pointsPerRupiah = const Value.absent(),
    this.silverThreshold = const Value.absent(),
    this.goldThreshold = const Value.absent(),
    this.platinumThreshold = const Value.absent(),
    this.qrisImagePath = const Value.absent(),
    this.receiptHeader = const Value.absent(),
    this.receiptPaperSize = const Value.absent(),
    this.pinLength = const Value.absent(),
    this.receiptShowLogo = const Value.absent(),
    this.receiptShowCashier = const Value.absent(),
    this.receiptShowInvoice = const Value.absent(),
    this.receiptShowDate = const Value.absent(),
    this.receiptShowBarcode = const Value.absent(),
    this.kitchenPrinterAddress = const Value.absent(),
    this.kitchenPrinterEnabled = const Value.absent(),
  });
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? storeName,
    Expression<String>? storeAddress,
    Expression<String>? storePhone,
    Expression<String>? posPrefix,
    Expression<int>? trxCounter,
    Expression<int>? minStockAlert,
    Expression<String>? qrisString,
    Expression<String>? themeMode,
    Expression<int>? posGridColumns,
    Expression<String>? bankName,
    Expression<String>? bankAccount,
    Expression<String>? bankHolder,
    Expression<String>? receiptFooter,
    Expression<String>? storeLogoPath,
    Expression<String>? waTemplates,
    Expression<int>? pointsPerRupiah,
    Expression<int>? silverThreshold,
    Expression<int>? goldThreshold,
    Expression<int>? platinumThreshold,
    Expression<String>? qrisImagePath,
    Expression<String>? receiptHeader,
    Expression<String>? receiptPaperSize,
    Expression<int>? pinLength,
    Expression<bool>? receiptShowLogo,
    Expression<bool>? receiptShowCashier,
    Expression<bool>? receiptShowInvoice,
    Expression<bool>? receiptShowDate,
    Expression<bool>? receiptShowBarcode,
    Expression<String>? kitchenPrinterAddress,
    Expression<bool>? kitchenPrinterEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeName != null) 'store_name': storeName,
      if (storeAddress != null) 'store_address': storeAddress,
      if (storePhone != null) 'store_phone': storePhone,
      if (posPrefix != null) 'pos_prefix': posPrefix,
      if (trxCounter != null) 'trx_counter': trxCounter,
      if (minStockAlert != null) 'min_stock_alert': minStockAlert,
      if (qrisString != null) 'qris_string': qrisString,
      if (themeMode != null) 'theme_mode': themeMode,
      if (posGridColumns != null) 'pos_grid_columns': posGridColumns,
      if (bankName != null) 'bank_name': bankName,
      if (bankAccount != null) 'bank_account': bankAccount,
      if (bankHolder != null) 'bank_holder': bankHolder,
      if (receiptFooter != null) 'receipt_footer': receiptFooter,
      if (storeLogoPath != null) 'store_logo_path': storeLogoPath,
      if (waTemplates != null) 'wa_templates': waTemplates,
      if (pointsPerRupiah != null) 'points_per_rupiah': pointsPerRupiah,
      if (silverThreshold != null) 'silver_threshold': silverThreshold,
      if (goldThreshold != null) 'gold_threshold': goldThreshold,
      if (platinumThreshold != null) 'platinum_threshold': platinumThreshold,
      if (qrisImagePath != null) 'qris_image_path': qrisImagePath,
      if (receiptHeader != null) 'receipt_header': receiptHeader,
      if (receiptPaperSize != null) 'receipt_paper_size': receiptPaperSize,
      if (pinLength != null) 'pin_length': pinLength,
      if (receiptShowLogo != null) 'receipt_show_logo': receiptShowLogo,
      if (receiptShowCashier != null)
        'receipt_show_cashier': receiptShowCashier,
      if (receiptShowInvoice != null)
        'receipt_show_invoice': receiptShowInvoice,
      if (receiptShowDate != null) 'receipt_show_date': receiptShowDate,
      if (receiptShowBarcode != null)
        'receipt_show_barcode': receiptShowBarcode,
      if (kitchenPrinterAddress != null)
        'kitchen_printer_address': kitchenPrinterAddress,
      if (kitchenPrinterEnabled != null)
        'kitchen_printer_enabled': kitchenPrinterEnabled,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? storeName,
    Value<String?>? storeAddress,
    Value<String?>? storePhone,
    Value<String?>? posPrefix,
    Value<int>? trxCounter,
    Value<int>? minStockAlert,
    Value<String?>? qrisString,
    Value<String?>? themeMode,
    Value<int>? posGridColumns,
    Value<String?>? bankName,
    Value<String?>? bankAccount,
    Value<String?>? bankHolder,
    Value<String?>? receiptFooter,
    Value<String?>? storeLogoPath,
    Value<String?>? waTemplates,
    Value<int>? pointsPerRupiah,
    Value<int>? silverThreshold,
    Value<int>? goldThreshold,
    Value<int>? platinumThreshold,
    Value<String?>? qrisImagePath,
    Value<String?>? receiptHeader,
    Value<String>? receiptPaperSize,
    Value<int>? pinLength,
    Value<bool>? receiptShowLogo,
    Value<bool>? receiptShowCashier,
    Value<bool>? receiptShowInvoice,
    Value<bool>? receiptShowDate,
    Value<bool>? receiptShowBarcode,
    Value<String?>? kitchenPrinterAddress,
    Value<bool>? kitchenPrinterEnabled,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      posPrefix: posPrefix ?? this.posPrefix,
      trxCounter: trxCounter ?? this.trxCounter,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      qrisString: qrisString ?? this.qrisString,
      themeMode: themeMode ?? this.themeMode,
      posGridColumns: posGridColumns ?? this.posGridColumns,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankHolder: bankHolder ?? this.bankHolder,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      storeLogoPath: storeLogoPath ?? this.storeLogoPath,
      waTemplates: waTemplates ?? this.waTemplates,
      pointsPerRupiah: pointsPerRupiah ?? this.pointsPerRupiah,
      silverThreshold: silverThreshold ?? this.silverThreshold,
      goldThreshold: goldThreshold ?? this.goldThreshold,
      platinumThreshold: platinumThreshold ?? this.platinumThreshold,
      qrisImagePath: qrisImagePath ?? this.qrisImagePath,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptPaperSize: receiptPaperSize ?? this.receiptPaperSize,
      pinLength: pinLength ?? this.pinLength,
      receiptShowLogo: receiptShowLogo ?? this.receiptShowLogo,
      receiptShowCashier: receiptShowCashier ?? this.receiptShowCashier,
      receiptShowInvoice: receiptShowInvoice ?? this.receiptShowInvoice,
      receiptShowDate: receiptShowDate ?? this.receiptShowDate,
      receiptShowBarcode: receiptShowBarcode ?? this.receiptShowBarcode,
      kitchenPrinterAddress:
          kitchenPrinterAddress ?? this.kitchenPrinterAddress,
      kitchenPrinterEnabled:
          kitchenPrinterEnabled ?? this.kitchenPrinterEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (storeName.present) {
      map['store_name'] = Variable<String>(storeName.value);
    }
    if (storeAddress.present) {
      map['store_address'] = Variable<String>(storeAddress.value);
    }
    if (storePhone.present) {
      map['store_phone'] = Variable<String>(storePhone.value);
    }
    if (posPrefix.present) {
      map['pos_prefix'] = Variable<String>(posPrefix.value);
    }
    if (trxCounter.present) {
      map['trx_counter'] = Variable<int>(trxCounter.value);
    }
    if (minStockAlert.present) {
      map['min_stock_alert'] = Variable<int>(minStockAlert.value);
    }
    if (qrisString.present) {
      map['qris_string'] = Variable<String>(qrisString.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (posGridColumns.present) {
      map['pos_grid_columns'] = Variable<int>(posGridColumns.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (bankAccount.present) {
      map['bank_account'] = Variable<String>(bankAccount.value);
    }
    if (bankHolder.present) {
      map['bank_holder'] = Variable<String>(bankHolder.value);
    }
    if (receiptFooter.present) {
      map['receipt_footer'] = Variable<String>(receiptFooter.value);
    }
    if (storeLogoPath.present) {
      map['store_logo_path'] = Variable<String>(storeLogoPath.value);
    }
    if (waTemplates.present) {
      map['wa_templates'] = Variable<String>(waTemplates.value);
    }
    if (pointsPerRupiah.present) {
      map['points_per_rupiah'] = Variable<int>(pointsPerRupiah.value);
    }
    if (silverThreshold.present) {
      map['silver_threshold'] = Variable<int>(silverThreshold.value);
    }
    if (goldThreshold.present) {
      map['gold_threshold'] = Variable<int>(goldThreshold.value);
    }
    if (platinumThreshold.present) {
      map['platinum_threshold'] = Variable<int>(platinumThreshold.value);
    }
    if (qrisImagePath.present) {
      map['qris_image_path'] = Variable<String>(qrisImagePath.value);
    }
    if (receiptHeader.present) {
      map['receipt_header'] = Variable<String>(receiptHeader.value);
    }
    if (receiptPaperSize.present) {
      map['receipt_paper_size'] = Variable<String>(receiptPaperSize.value);
    }
    if (pinLength.present) {
      map['pin_length'] = Variable<int>(pinLength.value);
    }
    if (receiptShowLogo.present) {
      map['receipt_show_logo'] = Variable<bool>(receiptShowLogo.value);
    }
    if (receiptShowCashier.present) {
      map['receipt_show_cashier'] = Variable<bool>(receiptShowCashier.value);
    }
    if (receiptShowInvoice.present) {
      map['receipt_show_invoice'] = Variable<bool>(receiptShowInvoice.value);
    }
    if (receiptShowDate.present) {
      map['receipt_show_date'] = Variable<bool>(receiptShowDate.value);
    }
    if (receiptShowBarcode.present) {
      map['receipt_show_barcode'] = Variable<bool>(receiptShowBarcode.value);
    }
    if (kitchenPrinterAddress.present) {
      map['kitchen_printer_address'] = Variable<String>(
        kitchenPrinterAddress.value,
      );
    }
    if (kitchenPrinterEnabled.present) {
      map['kitchen_printer_enabled'] = Variable<bool>(
        kitchenPrinterEnabled.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('storeName: $storeName, ')
          ..write('storeAddress: $storeAddress, ')
          ..write('storePhone: $storePhone, ')
          ..write('posPrefix: $posPrefix, ')
          ..write('trxCounter: $trxCounter, ')
          ..write('minStockAlert: $minStockAlert, ')
          ..write('qrisString: $qrisString, ')
          ..write('themeMode: $themeMode, ')
          ..write('posGridColumns: $posGridColumns, ')
          ..write('bankName: $bankName, ')
          ..write('bankAccount: $bankAccount, ')
          ..write('bankHolder: $bankHolder, ')
          ..write('receiptFooter: $receiptFooter, ')
          ..write('storeLogoPath: $storeLogoPath, ')
          ..write('waTemplates: $waTemplates, ')
          ..write('pointsPerRupiah: $pointsPerRupiah, ')
          ..write('silverThreshold: $silverThreshold, ')
          ..write('goldThreshold: $goldThreshold, ')
          ..write('platinumThreshold: $platinumThreshold, ')
          ..write('qrisImagePath: $qrisImagePath, ')
          ..write('receiptHeader: $receiptHeader, ')
          ..write('receiptPaperSize: $receiptPaperSize, ')
          ..write('pinLength: $pinLength, ')
          ..write('receiptShowLogo: $receiptShowLogo, ')
          ..write('receiptShowCashier: $receiptShowCashier, ')
          ..write('receiptShowInvoice: $receiptShowInvoice, ')
          ..write('receiptShowDate: $receiptShowDate, ')
          ..write('receiptShowBarcode: $receiptShowBarcode, ')
          ..write('kitchenPrinterAddress: $kitchenPrinterAddress, ')
          ..write('kitchenPrinterEnabled: $kitchenPrinterEnabled')
          ..write(')'))
        .toString();
  }
}

class $ActivationsLocalTable extends ActivationsLocal
    with TableInfo<$ActivationsLocalTable, ActivationsLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivationsLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activatedAtMeta = const VerificationMeta(
    'activatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> activatedAt = GeneratedColumn<DateTime>(
    'activated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    key,
    deviceId,
    activatedAt,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activations_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivationsLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('activated_at')) {
      context.handle(
        _activatedAtMeta,
        activatedAt.isAcceptableOrUnknown(
          data['activated_at']!,
          _activatedAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivationsLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivationsLocalData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      activatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}activated_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $ActivationsLocalTable createAlias(String alias) {
    return $ActivationsLocalTable(attachedDatabase, alias);
  }
}

class ActivationsLocalData extends DataClass
    implements Insertable<ActivationsLocalData> {
  final int id;
  final String key;
  final String deviceId;
  final DateTime activatedAt;
  final String status;
  const ActivationsLocalData({
    required this.id,
    required this.key,
    required this.deviceId,
    required this.activatedAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['device_id'] = Variable<String>(deviceId);
    map['activated_at'] = Variable<DateTime>(activatedAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  ActivationsLocalCompanion toCompanion(bool nullToAbsent) {
    return ActivationsLocalCompanion(
      id: Value(id),
      key: Value(key),
      deviceId: Value(deviceId),
      activatedAt: Value(activatedAt),
      status: Value(status),
    );
  }

  factory ActivationsLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivationsLocalData(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      activatedAt: serializer.fromJson<DateTime>(json['activatedAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'deviceId': serializer.toJson<String>(deviceId),
      'activatedAt': serializer.toJson<DateTime>(activatedAt),
      'status': serializer.toJson<String>(status),
    };
  }

  ActivationsLocalData copyWith({
    int? id,
    String? key,
    String? deviceId,
    DateTime? activatedAt,
    String? status,
  }) => ActivationsLocalData(
    id: id ?? this.id,
    key: key ?? this.key,
    deviceId: deviceId ?? this.deviceId,
    activatedAt: activatedAt ?? this.activatedAt,
    status: status ?? this.status,
  );
  ActivationsLocalData copyWithCompanion(ActivationsLocalCompanion data) {
    return ActivationsLocalData(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      activatedAt: data.activatedAt.present
          ? data.activatedAt.value
          : this.activatedAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivationsLocalData(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('deviceId: $deviceId, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, deviceId, activatedAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivationsLocalData &&
          other.id == this.id &&
          other.key == this.key &&
          other.deviceId == this.deviceId &&
          other.activatedAt == this.activatedAt &&
          other.status == this.status);
}

class ActivationsLocalCompanion extends UpdateCompanion<ActivationsLocalData> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> deviceId;
  final Value<DateTime> activatedAt;
  final Value<String> status;
  const ActivationsLocalCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.status = const Value.absent(),
  });
  ActivationsLocalCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String deviceId,
    this.activatedAt = const Value.absent(),
    this.status = const Value.absent(),
  }) : key = Value(key),
       deviceId = Value(deviceId);
  static Insertable<ActivationsLocalData> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? deviceId,
    Expression<DateTime>? activatedAt,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (deviceId != null) 'device_id': deviceId,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (status != null) 'status': status,
    });
  }

  ActivationsLocalCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? deviceId,
    Value<DateTime>? activatedAt,
    Value<String>? status,
  }) {
    return ActivationsLocalCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      deviceId: deviceId ?? this.deviceId,
      activatedAt: activatedAt ?? this.activatedAt,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<DateTime>(activatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivationsLocalCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('deviceId: $deviceId, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskTypeMeta = const VerificationMeta(
    'taskType',
  );
  @override
  late final GeneratedColumn<String> taskType = GeneratedColumn<String>(
    'task_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskType,
    payload,
    status,
    retryCount,
    errorMessage,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String taskType;
  final String payload;
  final String status;
  final int retryCount;
  final String? errorMessage;
  final DateTime createdAt;
  const SyncQueueData({
    required this.id,
    required this.taskType,
    required this.payload,
    required this.status,
    required this.retryCount,
    this.errorMessage,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_type'] = Variable<String>(taskType);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      taskType: Value(taskType),
      payload: Value(payload),
      status: Value(status),
      retryCount: Value(retryCount),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      taskType: serializer.fromJson<String>(json['taskType']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskType': serializer.toJson<String>(taskType),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? taskType,
    String? payload,
    String? status,
    int? retryCount,
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
  }) => SyncQueueData(
    id: id ?? this.id,
    taskType: taskType ?? this.taskType,
    payload: payload ?? this.payload,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('taskType: $taskType, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskType,
    payload,
    status,
    retryCount,
    errorMessage,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.taskType == this.taskType &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> taskType;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.taskType = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String taskType,
    required String payload,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : taskType = Value(taskType),
       payload = Value(payload);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? taskType,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskType != null) 'task_type': taskType,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? taskType,
    Value<String>? payload,
    Value<String>? status,
    Value<int>? retryCount,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('taskType: $taskType, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CashierSessionsTable extends CashierSessions
    with TableInfo<$CashierSessionsTable, CashierSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CashierSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startingCashMeta = const VerificationMeta(
    'startingCash',
  );
  @override
  late final GeneratedColumn<int> startingCash = GeneratedColumn<int>(
    'starting_cash',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _branchIdMeta = const VerificationMeta(
    'branchId',
  );
  @override
  late final GeneratedColumn<int> branchId = GeneratedColumn<int>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    openedAt,
    closedAt,
    startingCash,
    branchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cashier_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CashierSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('starting_cash')) {
      context.handle(
        _startingCashMeta,
        startingCash.isAcceptableOrUnknown(
          data['starting_cash']!,
          _startingCashMeta,
        ),
      );
    }
    if (data.containsKey('branch_id')) {
      context.handle(
        _branchIdMeta,
        branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CashierSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CashierSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      startingCash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_cash'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}branch_id'],
      ),
    );
  }

  @override
  $CashierSessionsTable createAlias(String alias) {
    return $CashierSessionsTable(attachedDatabase, alias);
  }
}

class CashierSession extends DataClass implements Insertable<CashierSession> {
  final int id;
  final int employeeId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int startingCash;
  final int? branchId;
  const CashierSession({
    required this.id,
    required this.employeeId,
    required this.openedAt,
    this.closedAt,
    required this.startingCash,
    this.branchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['opened_at'] = Variable<DateTime>(openedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    map['starting_cash'] = Variable<int>(startingCash);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<int>(branchId);
    }
    return map;
  }

  CashierSessionsCompanion toCompanion(bool nullToAbsent) {
    return CashierSessionsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      openedAt: Value(openedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      startingCash: Value(startingCash),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
    );
  }

  factory CashierSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CashierSession(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      startingCash: serializer.fromJson<int>(json['startingCash']),
      branchId: serializer.fromJson<int?>(json['branchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'startingCash': serializer.toJson<int>(startingCash),
      'branchId': serializer.toJson<int?>(branchId),
    };
  }

  CashierSession copyWith({
    int? id,
    int? employeeId,
    DateTime? openedAt,
    Value<DateTime?> closedAt = const Value.absent(),
    int? startingCash,
    Value<int?> branchId = const Value.absent(),
  }) => CashierSession(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    openedAt: openedAt ?? this.openedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    startingCash: startingCash ?? this.startingCash,
    branchId: branchId.present ? branchId.value : this.branchId,
  );
  CashierSession copyWithCompanion(CashierSessionsCompanion data) {
    return CashierSession(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      startingCash: data.startingCash.present
          ? data.startingCash.value
          : this.startingCash,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CashierSession(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('startingCash: $startingCash, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, employeeId, openedAt, closedAt, startingCash, branchId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CashierSession &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.openedAt == this.openedAt &&
          other.closedAt == this.closedAt &&
          other.startingCash == this.startingCash &&
          other.branchId == this.branchId);
}

class CashierSessionsCompanion extends UpdateCompanion<CashierSession> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<DateTime> openedAt;
  final Value<DateTime?> closedAt;
  final Value<int> startingCash;
  final Value<int?> branchId;
  const CashierSessionsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.startingCash = const Value.absent(),
    this.branchId = const Value.absent(),
  });
  CashierSessionsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    this.openedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.startingCash = const Value.absent(),
    this.branchId = const Value.absent(),
  }) : employeeId = Value(employeeId);
  static Insertable<CashierSession> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? closedAt,
    Expression<int>? startingCash,
    Expression<int>? branchId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (startingCash != null) 'starting_cash': startingCash,
      if (branchId != null) 'branch_id': branchId,
    });
  }

  CashierSessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<DateTime>? openedAt,
    Value<DateTime?>? closedAt,
    Value<int>? startingCash,
    Value<int?>? branchId,
  }) {
    return CashierSessionsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      startingCash: startingCash ?? this.startingCash,
      branchId: branchId ?? this.branchId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (startingCash.present) {
      map['starting_cash'] = Variable<int>(startingCash.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<int>(branchId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashierSessionsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('startingCash: $startingCash, ')
          ..write('branchId: $branchId')
          ..write(')'))
        .toString();
  }
}

class $OnlineOrdersTable extends OnlineOrders
    with TableInfo<$OnlineOrdersTable, OnlineOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnlineOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _invoiceMeta = const VerificationMeta(
    'invoice',
  );
  @override
  late final GeneratedColumn<String> invoice = GeneratedColumn<String>(
    'invoice',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<int> subtotal = GeneratedColumn<int>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<int> discount = GeneratedColumn<int>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _handlingFeeMeta = const VerificationMeta(
    'handlingFee',
  );
  @override
  late final GeneratedColumn<int> handlingFee = GeneratedColumn<int>(
    'handling_fee',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Tunai'),
  );
  static const VerificationMeta _pickupTimeMeta = const VerificationMeta(
    'pickupTime',
  );
  @override
  late final GeneratedColumn<String> pickupTime = GeneratedColumn<String>(
    'pickup_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Pusat'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Online Baru'),
  );
  static const VerificationMeta _processedByMeta = const VerificationMeta(
    'processedBy',
  );
  @override
  late final GeneratedColumn<String> processedBy = GeneratedColumn<String>(
    'processed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    invoice,
    customerName,
    customerPhone,
    items,
    subtotal,
    discount,
    handlingFee,
    total,
    paymentMethod,
    pickupTime,
    branch,
    notes,
    status,
    processedBy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'online_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnlineOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('invoice')) {
      context.handle(
        _invoiceMeta,
        invoice.isAcceptableOrUnknown(data['invoice']!, _invoiceMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerPhoneMeta);
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('handling_fee')) {
      context.handle(
        _handlingFeeMeta,
        handlingFee.isAcceptableOrUnknown(
          data['handling_fee']!,
          _handlingFeeMeta,
        ),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('pickup_time')) {
      context.handle(
        _pickupTimeMeta,
        pickupTime.isAcceptableOrUnknown(data['pickup_time']!, _pickupTimeMeta),
      );
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('processed_by')) {
      context.handle(
        _processedByMeta,
        processedBy.isAcceptableOrUnknown(
          data['processed_by']!,
          _processedByMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnlineOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnlineOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      invoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      )!,
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount'],
      )!,
      handlingFee: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}handling_fee'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      pickupTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pickup_time'],
      ),
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      processedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processed_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OnlineOrdersTable createAlias(String alias) {
    return $OnlineOrdersTable(attachedDatabase, alias);
  }
}

class OnlineOrder extends DataClass implements Insertable<OnlineOrder> {
  final int id;
  final String invoice;
  final String customerName;
  final String customerPhone;
  final String items;
  final int subtotal;
  final int discount;
  final int handlingFee;
  final int total;
  final String paymentMethod;
  final String? pickupTime;
  final String branch;
  final String? notes;
  final String status;
  final String? processedBy;
  final DateTime createdAt;
  const OnlineOrder({
    required this.id,
    required this.invoice,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.handlingFee,
    required this.total,
    required this.paymentMethod,
    this.pickupTime,
    required this.branch,
    this.notes,
    required this.status,
    this.processedBy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['invoice'] = Variable<String>(invoice);
    map['customer_name'] = Variable<String>(customerName);
    map['customer_phone'] = Variable<String>(customerPhone);
    map['items'] = Variable<String>(items);
    map['subtotal'] = Variable<int>(subtotal);
    map['discount'] = Variable<int>(discount);
    map['handling_fee'] = Variable<int>(handlingFee);
    map['total'] = Variable<int>(total);
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || pickupTime != null) {
      map['pickup_time'] = Variable<String>(pickupTime);
    }
    map['branch'] = Variable<String>(branch);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || processedBy != null) {
      map['processed_by'] = Variable<String>(processedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OnlineOrdersCompanion toCompanion(bool nullToAbsent) {
    return OnlineOrdersCompanion(
      id: Value(id),
      invoice: Value(invoice),
      customerName: Value(customerName),
      customerPhone: Value(customerPhone),
      items: Value(items),
      subtotal: Value(subtotal),
      discount: Value(discount),
      handlingFee: Value(handlingFee),
      total: Value(total),
      paymentMethod: Value(paymentMethod),
      pickupTime: pickupTime == null && nullToAbsent
          ? const Value.absent()
          : Value(pickupTime),
      branch: Value(branch),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      status: Value(status),
      processedBy: processedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(processedBy),
      createdAt: Value(createdAt),
    );
  }

  factory OnlineOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnlineOrder(
      id: serializer.fromJson<int>(json['id']),
      invoice: serializer.fromJson<String>(json['invoice']),
      customerName: serializer.fromJson<String>(json['customerName']),
      customerPhone: serializer.fromJson<String>(json['customerPhone']),
      items: serializer.fromJson<String>(json['items']),
      subtotal: serializer.fromJson<int>(json['subtotal']),
      discount: serializer.fromJson<int>(json['discount']),
      handlingFee: serializer.fromJson<int>(json['handlingFee']),
      total: serializer.fromJson<int>(json['total']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      pickupTime: serializer.fromJson<String?>(json['pickupTime']),
      branch: serializer.fromJson<String>(json['branch']),
      notes: serializer.fromJson<String?>(json['notes']),
      status: serializer.fromJson<String>(json['status']),
      processedBy: serializer.fromJson<String?>(json['processedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'invoice': serializer.toJson<String>(invoice),
      'customerName': serializer.toJson<String>(customerName),
      'customerPhone': serializer.toJson<String>(customerPhone),
      'items': serializer.toJson<String>(items),
      'subtotal': serializer.toJson<int>(subtotal),
      'discount': serializer.toJson<int>(discount),
      'handlingFee': serializer.toJson<int>(handlingFee),
      'total': serializer.toJson<int>(total),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'pickupTime': serializer.toJson<String?>(pickupTime),
      'branch': serializer.toJson<String>(branch),
      'notes': serializer.toJson<String?>(notes),
      'status': serializer.toJson<String>(status),
      'processedBy': serializer.toJson<String?>(processedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OnlineOrder copyWith({
    int? id,
    String? invoice,
    String? customerName,
    String? customerPhone,
    String? items,
    int? subtotal,
    int? discount,
    int? handlingFee,
    int? total,
    String? paymentMethod,
    Value<String?> pickupTime = const Value.absent(),
    String? branch,
    Value<String?> notes = const Value.absent(),
    String? status,
    Value<String?> processedBy = const Value.absent(),
    DateTime? createdAt,
  }) => OnlineOrder(
    id: id ?? this.id,
    invoice: invoice ?? this.invoice,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    items: items ?? this.items,
    subtotal: subtotal ?? this.subtotal,
    discount: discount ?? this.discount,
    handlingFee: handlingFee ?? this.handlingFee,
    total: total ?? this.total,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    pickupTime: pickupTime.present ? pickupTime.value : this.pickupTime,
    branch: branch ?? this.branch,
    notes: notes.present ? notes.value : this.notes,
    status: status ?? this.status,
    processedBy: processedBy.present ? processedBy.value : this.processedBy,
    createdAt: createdAt ?? this.createdAt,
  );
  OnlineOrder copyWithCompanion(OnlineOrdersCompanion data) {
    return OnlineOrder(
      id: data.id.present ? data.id.value : this.id,
      invoice: data.invoice.present ? data.invoice.value : this.invoice,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      items: data.items.present ? data.items.value : this.items,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      discount: data.discount.present ? data.discount.value : this.discount,
      handlingFee: data.handlingFee.present
          ? data.handlingFee.value
          : this.handlingFee,
      total: data.total.present ? data.total.value : this.total,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      pickupTime: data.pickupTime.present
          ? data.pickupTime.value
          : this.pickupTime,
      branch: data.branch.present ? data.branch.value : this.branch,
      notes: data.notes.present ? data.notes.value : this.notes,
      status: data.status.present ? data.status.value : this.status,
      processedBy: data.processedBy.present
          ? data.processedBy.value
          : this.processedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnlineOrder(')
          ..write('id: $id, ')
          ..write('invoice: $invoice, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('items: $items, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('handlingFee: $handlingFee, ')
          ..write('total: $total, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('pickupTime: $pickupTime, ')
          ..write('branch: $branch, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('processedBy: $processedBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    invoice,
    customerName,
    customerPhone,
    items,
    subtotal,
    discount,
    handlingFee,
    total,
    paymentMethod,
    pickupTime,
    branch,
    notes,
    status,
    processedBy,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnlineOrder &&
          other.id == this.id &&
          other.invoice == this.invoice &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.items == this.items &&
          other.subtotal == this.subtotal &&
          other.discount == this.discount &&
          other.handlingFee == this.handlingFee &&
          other.total == this.total &&
          other.paymentMethod == this.paymentMethod &&
          other.pickupTime == this.pickupTime &&
          other.branch == this.branch &&
          other.notes == this.notes &&
          other.status == this.status &&
          other.processedBy == this.processedBy &&
          other.createdAt == this.createdAt);
}

class OnlineOrdersCompanion extends UpdateCompanion<OnlineOrder> {
  final Value<int> id;
  final Value<String> invoice;
  final Value<String> customerName;
  final Value<String> customerPhone;
  final Value<String> items;
  final Value<int> subtotal;
  final Value<int> discount;
  final Value<int> handlingFee;
  final Value<int> total;
  final Value<String> paymentMethod;
  final Value<String?> pickupTime;
  final Value<String> branch;
  final Value<String?> notes;
  final Value<String> status;
  final Value<String?> processedBy;
  final Value<DateTime> createdAt;
  const OnlineOrdersCompanion({
    this.id = const Value.absent(),
    this.invoice = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.items = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.discount = const Value.absent(),
    this.handlingFee = const Value.absent(),
    this.total = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.pickupTime = const Value.absent(),
    this.branch = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.processedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OnlineOrdersCompanion.insert({
    this.id = const Value.absent(),
    required String invoice,
    required String customerName,
    required String customerPhone,
    required String items,
    this.subtotal = const Value.absent(),
    this.discount = const Value.absent(),
    this.handlingFee = const Value.absent(),
    required int total,
    this.paymentMethod = const Value.absent(),
    this.pickupTime = const Value.absent(),
    this.branch = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.processedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : invoice = Value(invoice),
       customerName = Value(customerName),
       customerPhone = Value(customerPhone),
       items = Value(items),
       total = Value(total);
  static Insertable<OnlineOrder> custom({
    Expression<int>? id,
    Expression<String>? invoice,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<String>? items,
    Expression<int>? subtotal,
    Expression<int>? discount,
    Expression<int>? handlingFee,
    Expression<int>? total,
    Expression<String>? paymentMethod,
    Expression<String>? pickupTime,
    Expression<String>? branch,
    Expression<String>? notes,
    Expression<String>? status,
    Expression<String>? processedBy,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoice != null) 'invoice': invoice,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (items != null) 'items': items,
      if (subtotal != null) 'subtotal': subtotal,
      if (discount != null) 'discount': discount,
      if (handlingFee != null) 'handling_fee': handlingFee,
      if (total != null) 'total': total,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (pickupTime != null) 'pickup_time': pickupTime,
      if (branch != null) 'branch': branch,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (processedBy != null) 'processed_by': processedBy,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OnlineOrdersCompanion copyWith({
    Value<int>? id,
    Value<String>? invoice,
    Value<String>? customerName,
    Value<String>? customerPhone,
    Value<String>? items,
    Value<int>? subtotal,
    Value<int>? discount,
    Value<int>? handlingFee,
    Value<int>? total,
    Value<String>? paymentMethod,
    Value<String?>? pickupTime,
    Value<String>? branch,
    Value<String?>? notes,
    Value<String>? status,
    Value<String?>? processedBy,
    Value<DateTime>? createdAt,
  }) {
    return OnlineOrdersCompanion(
      id: id ?? this.id,
      invoice: invoice ?? this.invoice,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      handlingFee: handlingFee ?? this.handlingFee,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      pickupTime: pickupTime ?? this.pickupTime,
      branch: branch ?? this.branch,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      processedBy: processedBy ?? this.processedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (invoice.present) {
      map['invoice'] = Variable<String>(invoice.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<int>(subtotal.value);
    }
    if (discount.present) {
      map['discount'] = Variable<int>(discount.value);
    }
    if (handlingFee.present) {
      map['handling_fee'] = Variable<int>(handlingFee.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (pickupTime.present) {
      map['pickup_time'] = Variable<String>(pickupTime.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (processedBy.present) {
      map['processed_by'] = Variable<String>(processedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnlineOrdersCompanion(')
          ..write('id: $id, ')
          ..write('invoice: $invoice, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('items: $items, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('handlingFee: $handlingFee, ')
          ..write('total: $total, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('pickupTime: $pickupTime, ')
          ..write('branch: $branch, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('processedBy: $processedBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CustomerDebtsTable extends CustomerDebts
    with TableInfo<$CustomerDebtsTable, CustomerDebt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomerDebtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<int> customerId = GeneratedColumn<int>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingAmountMeta = const VerificationMeta(
    'remainingAmount',
  );
  @override
  late final GeneratedColumn<int> remainingAmount = GeneratedColumn<int>(
    'remaining_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _debtDateMeta = const VerificationMeta(
    'debtDate',
  );
  @override
  late final GeneratedColumn<DateTime> debtDate = GeneratedColumn<DateTime>(
    'debt_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Belum Lunas'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    customerName,
    amount,
    remainingAmount,
    description,
    debtDate,
    dueDate,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customer_debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomerDebt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('remaining_amount')) {
      context.handle(
        _remainingAmountMeta,
        remainingAmount.isAcceptableOrUnknown(
          data['remaining_amount']!,
          _remainingAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingAmountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('debt_date')) {
      context.handle(
        _debtDateMeta,
        debtDate.isAcceptableOrUnknown(data['debt_date']!, _debtDateMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomerDebt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerDebt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}customer_id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      remainingAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_amount'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      debtDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}debt_date'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $CustomerDebtsTable createAlias(String alias) {
    return $CustomerDebtsTable(attachedDatabase, alias);
  }
}

class CustomerDebt extends DataClass implements Insertable<CustomerDebt> {
  final int id;
  final int customerId;
  final String customerName;
  final int amount;
  final int remainingAmount;
  final String? description;
  final DateTime debtDate;
  final DateTime? dueDate;
  final String status;
  const CustomerDebt({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.remainingAmount,
    this.description,
    required this.debtDate,
    this.dueDate,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['customer_id'] = Variable<int>(customerId);
    map['customer_name'] = Variable<String>(customerName);
    map['amount'] = Variable<int>(amount);
    map['remaining_amount'] = Variable<int>(remainingAmount);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['debt_date'] = Variable<DateTime>(debtDate);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  CustomerDebtsCompanion toCompanion(bool nullToAbsent) {
    return CustomerDebtsCompanion(
      id: Value(id),
      customerId: Value(customerId),
      customerName: Value(customerName),
      amount: Value(amount),
      remainingAmount: Value(remainingAmount),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      debtDate: Value(debtDate),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      status: Value(status),
    );
  }

  factory CustomerDebt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerDebt(
      id: serializer.fromJson<int>(json['id']),
      customerId: serializer.fromJson<int>(json['customerId']),
      customerName: serializer.fromJson<String>(json['customerName']),
      amount: serializer.fromJson<int>(json['amount']),
      remainingAmount: serializer.fromJson<int>(json['remainingAmount']),
      description: serializer.fromJson<String?>(json['description']),
      debtDate: serializer.fromJson<DateTime>(json['debtDate']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'customerId': serializer.toJson<int>(customerId),
      'customerName': serializer.toJson<String>(customerName),
      'amount': serializer.toJson<int>(amount),
      'remainingAmount': serializer.toJson<int>(remainingAmount),
      'description': serializer.toJson<String?>(description),
      'debtDate': serializer.toJson<DateTime>(debtDate),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'status': serializer.toJson<String>(status),
    };
  }

  CustomerDebt copyWith({
    int? id,
    int? customerId,
    String? customerName,
    int? amount,
    int? remainingAmount,
    Value<String?> description = const Value.absent(),
    DateTime? debtDate,
    Value<DateTime?> dueDate = const Value.absent(),
    String? status,
  }) => CustomerDebt(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    amount: amount ?? this.amount,
    remainingAmount: remainingAmount ?? this.remainingAmount,
    description: description.present ? description.value : this.description,
    debtDate: debtDate ?? this.debtDate,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    status: status ?? this.status,
  );
  CustomerDebt copyWithCompanion(CustomerDebtsCompanion data) {
    return CustomerDebt(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      amount: data.amount.present ? data.amount.value : this.amount,
      remainingAmount: data.remainingAmount.present
          ? data.remainingAmount.value
          : this.remainingAmount,
      description: data.description.present
          ? data.description.value
          : this.description,
      debtDate: data.debtDate.present ? data.debtDate.value : this.debtDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerDebt(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('amount: $amount, ')
          ..write('remainingAmount: $remainingAmount, ')
          ..write('description: $description, ')
          ..write('debtDate: $debtDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    customerName,
    amount,
    remainingAmount,
    description,
    debtDate,
    dueDate,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerDebt &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.amount == this.amount &&
          other.remainingAmount == this.remainingAmount &&
          other.description == this.description &&
          other.debtDate == this.debtDate &&
          other.dueDate == this.dueDate &&
          other.status == this.status);
}

class CustomerDebtsCompanion extends UpdateCompanion<CustomerDebt> {
  final Value<int> id;
  final Value<int> customerId;
  final Value<String> customerName;
  final Value<int> amount;
  final Value<int> remainingAmount;
  final Value<String?> description;
  final Value<DateTime> debtDate;
  final Value<DateTime?> dueDate;
  final Value<String> status;
  const CustomerDebtsCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.amount = const Value.absent(),
    this.remainingAmount = const Value.absent(),
    this.description = const Value.absent(),
    this.debtDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
  });
  CustomerDebtsCompanion.insert({
    this.id = const Value.absent(),
    required int customerId,
    required String customerName,
    required int amount,
    required int remainingAmount,
    this.description = const Value.absent(),
    this.debtDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
  }) : customerId = Value(customerId),
       customerName = Value(customerName),
       amount = Value(amount),
       remainingAmount = Value(remainingAmount);
  static Insertable<CustomerDebt> custom({
    Expression<int>? id,
    Expression<int>? customerId,
    Expression<String>? customerName,
    Expression<int>? amount,
    Expression<int>? remainingAmount,
    Expression<String>? description,
    Expression<DateTime>? debtDate,
    Expression<DateTime>? dueDate,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (amount != null) 'amount': amount,
      if (remainingAmount != null) 'remaining_amount': remainingAmount,
      if (description != null) 'description': description,
      if (debtDate != null) 'debt_date': debtDate,
      if (dueDate != null) 'due_date': dueDate,
      if (status != null) 'status': status,
    });
  }

  CustomerDebtsCompanion copyWith({
    Value<int>? id,
    Value<int>? customerId,
    Value<String>? customerName,
    Value<int>? amount,
    Value<int>? remainingAmount,
    Value<String?>? description,
    Value<DateTime>? debtDate,
    Value<DateTime?>? dueDate,
    Value<String>? status,
  }) {
    return CustomerDebtsCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      description: description ?? this.description,
      debtDate: debtDate ?? this.debtDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<int>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (remainingAmount.present) {
      map['remaining_amount'] = Variable<int>(remainingAmount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (debtDate.present) {
      map['debt_date'] = Variable<DateTime>(debtDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomerDebtsCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('amount: $amount, ')
          ..write('remainingAmount: $remainingAmount, ')
          ..write('description: $description, ')
          ..write('debtDate: $debtDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $DebtPaymentsTable extends DebtPayments
    with TableInfo<$DebtPaymentsTable, DebtPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _debtIdMeta = const VerificationMeta('debtId');
  @override
  late final GeneratedColumn<int> debtId = GeneratedColumn<int>(
    'debt_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Tunai'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    debtId,
    amount,
    method,
    notes,
    paidAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('debt_id')) {
      context.handle(
        _debtIdMeta,
        debtId.isAcceptableOrUnknown(data['debt_id']!, _debtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_debtIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebtPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtPayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      debtId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}debt_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      )!,
    );
  }

  @override
  $DebtPaymentsTable createAlias(String alias) {
    return $DebtPaymentsTable(attachedDatabase, alias);
  }
}

class DebtPayment extends DataClass implements Insertable<DebtPayment> {
  final int id;
  final int debtId;
  final int amount;
  final String method;
  final String? notes;
  final DateTime paidAt;
  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.method,
    this.notes,
    required this.paidAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['debt_id'] = Variable<int>(debtId);
    map['amount'] = Variable<int>(amount);
    map['method'] = Variable<String>(method);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['paid_at'] = Variable<DateTime>(paidAt);
    return map;
  }

  DebtPaymentsCompanion toCompanion(bool nullToAbsent) {
    return DebtPaymentsCompanion(
      id: Value(id),
      debtId: Value(debtId),
      amount: Value(amount),
      method: Value(method),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      paidAt: Value(paidAt),
    );
  }

  factory DebtPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtPayment(
      id: serializer.fromJson<int>(json['id']),
      debtId: serializer.fromJson<int>(json['debtId']),
      amount: serializer.fromJson<int>(json['amount']),
      method: serializer.fromJson<String>(json['method']),
      notes: serializer.fromJson<String?>(json['notes']),
      paidAt: serializer.fromJson<DateTime>(json['paidAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'debtId': serializer.toJson<int>(debtId),
      'amount': serializer.toJson<int>(amount),
      'method': serializer.toJson<String>(method),
      'notes': serializer.toJson<String?>(notes),
      'paidAt': serializer.toJson<DateTime>(paidAt),
    };
  }

  DebtPayment copyWith({
    int? id,
    int? debtId,
    int? amount,
    String? method,
    Value<String?> notes = const Value.absent(),
    DateTime? paidAt,
  }) => DebtPayment(
    id: id ?? this.id,
    debtId: debtId ?? this.debtId,
    amount: amount ?? this.amount,
    method: method ?? this.method,
    notes: notes.present ? notes.value : this.notes,
    paidAt: paidAt ?? this.paidAt,
  );
  DebtPayment copyWithCompanion(DebtPaymentsCompanion data) {
    return DebtPayment(
      id: data.id.present ? data.id.value : this.id,
      debtId: data.debtId.present ? data.debtId.value : this.debtId,
      amount: data.amount.present ? data.amount.value : this.amount,
      method: data.method.present ? data.method.value : this.method,
      notes: data.notes.present ? data.notes.value : this.notes,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtPayment(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('amount: $amount, ')
          ..write('method: $method, ')
          ..write('notes: $notes, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, debtId, amount, method, notes, paidAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtPayment &&
          other.id == this.id &&
          other.debtId == this.debtId &&
          other.amount == this.amount &&
          other.method == this.method &&
          other.notes == this.notes &&
          other.paidAt == this.paidAt);
}

class DebtPaymentsCompanion extends UpdateCompanion<DebtPayment> {
  final Value<int> id;
  final Value<int> debtId;
  final Value<int> amount;
  final Value<String> method;
  final Value<String?> notes;
  final Value<DateTime> paidAt;
  const DebtPaymentsCompanion({
    this.id = const Value.absent(),
    this.debtId = const Value.absent(),
    this.amount = const Value.absent(),
    this.method = const Value.absent(),
    this.notes = const Value.absent(),
    this.paidAt = const Value.absent(),
  });
  DebtPaymentsCompanion.insert({
    this.id = const Value.absent(),
    required int debtId,
    required int amount,
    this.method = const Value.absent(),
    this.notes = const Value.absent(),
    this.paidAt = const Value.absent(),
  }) : debtId = Value(debtId),
       amount = Value(amount);
  static Insertable<DebtPayment> custom({
    Expression<int>? id,
    Expression<int>? debtId,
    Expression<int>? amount,
    Expression<String>? method,
    Expression<String>? notes,
    Expression<DateTime>? paidAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (debtId != null) 'debt_id': debtId,
      if (amount != null) 'amount': amount,
      if (method != null) 'method': method,
      if (notes != null) 'notes': notes,
      if (paidAt != null) 'paid_at': paidAt,
    });
  }

  DebtPaymentsCompanion copyWith({
    Value<int>? id,
    Value<int>? debtId,
    Value<int>? amount,
    Value<String>? method,
    Value<String?>? notes,
    Value<DateTime>? paidAt,
  }) {
    return DebtPaymentsCompanion(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      notes: notes ?? this.notes,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (debtId.present) {
      map['debt_id'] = Variable<int>(debtId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('amount: $amount, ')
          ..write('method: $method, ')
          ..write('notes: $notes, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }
}

class $StockCountsTable extends StockCounts
    with TableInfo<$StockCountsTable, StockCount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockCountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Draft'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalProductsMeta = const VerificationMeta(
    'totalProducts',
  );
  @override
  late final GeneratedColumn<int> totalProducts = GeneratedColumn<int>(
    'total_products',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _matchCountMeta = const VerificationMeta(
    'matchCount',
  );
  @override
  late final GeneratedColumn<int> matchCount = GeneratedColumn<int>(
    'match_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _diffCountMeta = const VerificationMeta(
    'diffCount',
  );
  @override
  late final GeneratedColumn<int> diffCount = GeneratedColumn<int>(
    'diff_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    status,
    createdAt,
    completedAt,
    totalProducts,
    matchCount,
    diffCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_counts';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockCount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('total_products')) {
      context.handle(
        _totalProductsMeta,
        totalProducts.isAcceptableOrUnknown(
          data['total_products']!,
          _totalProductsMeta,
        ),
      );
    }
    if (data.containsKey('match_count')) {
      context.handle(
        _matchCountMeta,
        matchCount.isAcceptableOrUnknown(data['match_count']!, _matchCountMeta),
      );
    }
    if (data.containsKey('diff_count')) {
      context.handle(
        _diffCountMeta,
        diffCount.isAcceptableOrUnknown(data['diff_count']!, _diffCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockCount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockCount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      totalProducts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_products'],
      )!,
      matchCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}match_count'],
      )!,
      diffCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diff_count'],
      )!,
    );
  }

  @override
  $StockCountsTable createAlias(String alias) {
    return $StockCountsTable(attachedDatabase, alias);
  }
}

class StockCount extends DataClass implements Insertable<StockCount> {
  final int id;
  final String? name;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int totalProducts;
  final int matchCount;
  final int diffCount;
  const StockCount({
    required this.id,
    this.name,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.totalProducts,
    required this.matchCount,
    required this.diffCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['total_products'] = Variable<int>(totalProducts);
    map['match_count'] = Variable<int>(matchCount);
    map['diff_count'] = Variable<int>(diffCount);
    return map;
  }

  StockCountsCompanion toCompanion(bool nullToAbsent) {
    return StockCountsCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      status: Value(status),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      totalProducts: Value(totalProducts),
      matchCount: Value(matchCount),
      diffCount: Value(diffCount),
    );
  }

  factory StockCount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockCount(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      totalProducts: serializer.fromJson<int>(json['totalProducts']),
      matchCount: serializer.fromJson<int>(json['matchCount']),
      diffCount: serializer.fromJson<int>(json['diffCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'totalProducts': serializer.toJson<int>(totalProducts),
      'matchCount': serializer.toJson<int>(matchCount),
      'diffCount': serializer.toJson<int>(diffCount),
    };
  }

  StockCount copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    String? status,
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
    int? totalProducts,
    int? matchCount,
    int? diffCount,
  }) => StockCount(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    totalProducts: totalProducts ?? this.totalProducts,
    matchCount: matchCount ?? this.matchCount,
    diffCount: diffCount ?? this.diffCount,
  );
  StockCount copyWithCompanion(StockCountsCompanion data) {
    return StockCount(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      totalProducts: data.totalProducts.present
          ? data.totalProducts.value
          : this.totalProducts,
      matchCount: data.matchCount.present
          ? data.matchCount.value
          : this.matchCount,
      diffCount: data.diffCount.present ? data.diffCount.value : this.diffCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockCount(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('totalProducts: $totalProducts, ')
          ..write('matchCount: $matchCount, ')
          ..write('diffCount: $diffCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    status,
    createdAt,
    completedAt,
    totalProducts,
    matchCount,
    diffCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockCount &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.totalProducts == this.totalProducts &&
          other.matchCount == this.matchCount &&
          other.diffCount == this.diffCount);
}

class StockCountsCompanion extends UpdateCompanion<StockCount> {
  final Value<int> id;
  final Value<String?> name;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> totalProducts;
  final Value<int> matchCount;
  final Value<int> diffCount;
  const StockCountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.totalProducts = const Value.absent(),
    this.matchCount = const Value.absent(),
    this.diffCount = const Value.absent(),
  });
  StockCountsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.totalProducts = const Value.absent(),
    this.matchCount = const Value.absent(),
    this.diffCount = const Value.absent(),
  });
  static Insertable<StockCount> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? totalProducts,
    Expression<int>? matchCount,
    Expression<int>? diffCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (totalProducts != null) 'total_products': totalProducts,
      if (matchCount != null) 'match_count': matchCount,
      if (diffCount != null) 'diff_count': diffCount,
    });
  }

  StockCountsCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? totalProducts,
    Value<int>? matchCount,
    Value<int>? diffCount,
  }) {
    return StockCountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      totalProducts: totalProducts ?? this.totalProducts,
      matchCount: matchCount ?? this.matchCount,
      diffCount: diffCount ?? this.diffCount,
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
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (totalProducts.present) {
      map['total_products'] = Variable<int>(totalProducts.value);
    }
    if (matchCount.present) {
      map['match_count'] = Variable<int>(matchCount.value);
    }
    if (diffCount.present) {
      map['diff_count'] = Variable<int>(diffCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('totalProducts: $totalProducts, ')
          ..write('matchCount: $matchCount, ')
          ..write('diffCount: $diffCount')
          ..write(')'))
        .toString();
  }
}

class $StockCountItemsTable extends StockCountItems
    with TableInfo<$StockCountItemsTable, StockCountItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockCountItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _countSessionIdMeta = const VerificationMeta(
    'countSessionId',
  );
  @override
  late final GeneratedColumn<int> countSessionId = GeneratedColumn<int>(
    'count_session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _systemStockMeta = const VerificationMeta(
    'systemStock',
  );
  @override
  late final GeneratedColumn<int> systemStock = GeneratedColumn<int>(
    'system_stock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _physicalStockMeta = const VerificationMeta(
    'physicalStock',
  );
  @override
  late final GeneratedColumn<int> physicalStock = GeneratedColumn<int>(
    'physical_stock',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _differenceMeta = const VerificationMeta(
    'difference',
  );
  @override
  late final GeneratedColumn<int> difference = GeneratedColumn<int>(
    'difference',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _buyPriceMeta = const VerificationMeta(
    'buyPrice',
  );
  @override
  late final GeneratedColumn<int> buyPrice = GeneratedColumn<int>(
    'buy_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sellPriceMeta = const VerificationMeta(
    'sellPrice',
  );
  @override
  late final GeneratedColumn<int> sellPrice = GeneratedColumn<int>(
    'sell_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    countSessionId,
    productId,
    productName,
    systemStock,
    physicalStock,
    difference,
    buyPrice,
    sellPrice,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_count_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockCountItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('count_session_id')) {
      context.handle(
        _countSessionIdMeta,
        countSessionId.isAcceptableOrUnknown(
          data['count_session_id']!,
          _countSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countSessionIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('system_stock')) {
      context.handle(
        _systemStockMeta,
        systemStock.isAcceptableOrUnknown(
          data['system_stock']!,
          _systemStockMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_systemStockMeta);
    }
    if (data.containsKey('physical_stock')) {
      context.handle(
        _physicalStockMeta,
        physicalStock.isAcceptableOrUnknown(
          data['physical_stock']!,
          _physicalStockMeta,
        ),
      );
    }
    if (data.containsKey('difference')) {
      context.handle(
        _differenceMeta,
        difference.isAcceptableOrUnknown(data['difference']!, _differenceMeta),
      );
    }
    if (data.containsKey('buy_price')) {
      context.handle(
        _buyPriceMeta,
        buyPrice.isAcceptableOrUnknown(data['buy_price']!, _buyPriceMeta),
      );
    }
    if (data.containsKey('sell_price')) {
      context.handle(
        _sellPriceMeta,
        sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockCountItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockCountItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      countSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count_session_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      systemStock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}system_stock'],
      )!,
      physicalStock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}physical_stock'],
      ),
      difference: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difference'],
      )!,
      buyPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buy_price'],
      )!,
      sellPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sell_price'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $StockCountItemsTable createAlias(String alias) {
    return $StockCountItemsTable(attachedDatabase, alias);
  }
}

class StockCountItem extends DataClass implements Insertable<StockCountItem> {
  final int id;
  final int countSessionId;
  final int productId;
  final String productName;
  final int systemStock;
  final int? physicalStock;
  final int difference;
  final int buyPrice;
  final int sellPrice;
  final String? notes;
  const StockCountItem({
    required this.id,
    required this.countSessionId,
    required this.productId,
    required this.productName,
    required this.systemStock,
    this.physicalStock,
    required this.difference,
    required this.buyPrice,
    required this.sellPrice,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['count_session_id'] = Variable<int>(countSessionId);
    map['product_id'] = Variable<int>(productId);
    map['product_name'] = Variable<String>(productName);
    map['system_stock'] = Variable<int>(systemStock);
    if (!nullToAbsent || physicalStock != null) {
      map['physical_stock'] = Variable<int>(physicalStock);
    }
    map['difference'] = Variable<int>(difference);
    map['buy_price'] = Variable<int>(buyPrice);
    map['sell_price'] = Variable<int>(sellPrice);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  StockCountItemsCompanion toCompanion(bool nullToAbsent) {
    return StockCountItemsCompanion(
      id: Value(id),
      countSessionId: Value(countSessionId),
      productId: Value(productId),
      productName: Value(productName),
      systemStock: Value(systemStock),
      physicalStock: physicalStock == null && nullToAbsent
          ? const Value.absent()
          : Value(physicalStock),
      difference: Value(difference),
      buyPrice: Value(buyPrice),
      sellPrice: Value(sellPrice),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory StockCountItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockCountItem(
      id: serializer.fromJson<int>(json['id']),
      countSessionId: serializer.fromJson<int>(json['countSessionId']),
      productId: serializer.fromJson<int>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      systemStock: serializer.fromJson<int>(json['systemStock']),
      physicalStock: serializer.fromJson<int?>(json['physicalStock']),
      difference: serializer.fromJson<int>(json['difference']),
      buyPrice: serializer.fromJson<int>(json['buyPrice']),
      sellPrice: serializer.fromJson<int>(json['sellPrice']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'countSessionId': serializer.toJson<int>(countSessionId),
      'productId': serializer.toJson<int>(productId),
      'productName': serializer.toJson<String>(productName),
      'systemStock': serializer.toJson<int>(systemStock),
      'physicalStock': serializer.toJson<int?>(physicalStock),
      'difference': serializer.toJson<int>(difference),
      'buyPrice': serializer.toJson<int>(buyPrice),
      'sellPrice': serializer.toJson<int>(sellPrice),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  StockCountItem copyWith({
    int? id,
    int? countSessionId,
    int? productId,
    String? productName,
    int? systemStock,
    Value<int?> physicalStock = const Value.absent(),
    int? difference,
    int? buyPrice,
    int? sellPrice,
    Value<String?> notes = const Value.absent(),
  }) => StockCountItem(
    id: id ?? this.id,
    countSessionId: countSessionId ?? this.countSessionId,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    systemStock: systemStock ?? this.systemStock,
    physicalStock: physicalStock.present
        ? physicalStock.value
        : this.physicalStock,
    difference: difference ?? this.difference,
    buyPrice: buyPrice ?? this.buyPrice,
    sellPrice: sellPrice ?? this.sellPrice,
    notes: notes.present ? notes.value : this.notes,
  );
  StockCountItem copyWithCompanion(StockCountItemsCompanion data) {
    return StockCountItem(
      id: data.id.present ? data.id.value : this.id,
      countSessionId: data.countSessionId.present
          ? data.countSessionId.value
          : this.countSessionId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      systemStock: data.systemStock.present
          ? data.systemStock.value
          : this.systemStock,
      physicalStock: data.physicalStock.present
          ? data.physicalStock.value
          : this.physicalStock,
      difference: data.difference.present
          ? data.difference.value
          : this.difference,
      buyPrice: data.buyPrice.present ? data.buyPrice.value : this.buyPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockCountItem(')
          ..write('id: $id, ')
          ..write('countSessionId: $countSessionId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('systemStock: $systemStock, ')
          ..write('physicalStock: $physicalStock, ')
          ..write('difference: $difference, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    countSessionId,
    productId,
    productName,
    systemStock,
    physicalStock,
    difference,
    buyPrice,
    sellPrice,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockCountItem &&
          other.id == this.id &&
          other.countSessionId == this.countSessionId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.systemStock == this.systemStock &&
          other.physicalStock == this.physicalStock &&
          other.difference == this.difference &&
          other.buyPrice == this.buyPrice &&
          other.sellPrice == this.sellPrice &&
          other.notes == this.notes);
}

class StockCountItemsCompanion extends UpdateCompanion<StockCountItem> {
  final Value<int> id;
  final Value<int> countSessionId;
  final Value<int> productId;
  final Value<String> productName;
  final Value<int> systemStock;
  final Value<int?> physicalStock;
  final Value<int> difference;
  final Value<int> buyPrice;
  final Value<int> sellPrice;
  final Value<String?> notes;
  const StockCountItemsCompanion({
    this.id = const Value.absent(),
    this.countSessionId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.systemStock = const Value.absent(),
    this.physicalStock = const Value.absent(),
    this.difference = const Value.absent(),
    this.buyPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.notes = const Value.absent(),
  });
  StockCountItemsCompanion.insert({
    this.id = const Value.absent(),
    required int countSessionId,
    required int productId,
    required String productName,
    required int systemStock,
    this.physicalStock = const Value.absent(),
    this.difference = const Value.absent(),
    this.buyPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.notes = const Value.absent(),
  }) : countSessionId = Value(countSessionId),
       productId = Value(productId),
       productName = Value(productName),
       systemStock = Value(systemStock);
  static Insertable<StockCountItem> custom({
    Expression<int>? id,
    Expression<int>? countSessionId,
    Expression<int>? productId,
    Expression<String>? productName,
    Expression<int>? systemStock,
    Expression<int>? physicalStock,
    Expression<int>? difference,
    Expression<int>? buyPrice,
    Expression<int>? sellPrice,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (countSessionId != null) 'count_session_id': countSessionId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (systemStock != null) 'system_stock': systemStock,
      if (physicalStock != null) 'physical_stock': physicalStock,
      if (difference != null) 'difference': difference,
      if (buyPrice != null) 'buy_price': buyPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (notes != null) 'notes': notes,
    });
  }

  StockCountItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? countSessionId,
    Value<int>? productId,
    Value<String>? productName,
    Value<int>? systemStock,
    Value<int?>? physicalStock,
    Value<int>? difference,
    Value<int>? buyPrice,
    Value<int>? sellPrice,
    Value<String?>? notes,
  }) {
    return StockCountItemsCompanion(
      id: id ?? this.id,
      countSessionId: countSessionId ?? this.countSessionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      systemStock: systemStock ?? this.systemStock,
      physicalStock: physicalStock ?? this.physicalStock,
      difference: difference ?? this.difference,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (countSessionId.present) {
      map['count_session_id'] = Variable<int>(countSessionId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (systemStock.present) {
      map['system_stock'] = Variable<int>(systemStock.value);
    }
    if (physicalStock.present) {
      map['physical_stock'] = Variable<int>(physicalStock.value);
    }
    if (difference.present) {
      map['difference'] = Variable<int>(difference.value);
    }
    if (buyPrice.present) {
      map['buy_price'] = Variable<int>(buyPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<int>(sellPrice.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCountItemsCompanion(')
          ..write('id: $id, ')
          ..write('countSessionId: $countSessionId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('systemStock: $systemStock, ')
          ..write('physicalStock: $physicalStock, ')
          ..write('difference: $difference, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $ChatSessionsTable extends ChatSessions
    with TableInfo<$ChatSessionsTable, ChatSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messagesJsonMeta = const VerificationMeta(
    'messagesJson',
  );
  @override
  late final GeneratedColumn<String> messagesJson = GeneratedColumn<String>(
    'messages_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    messagesJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('messages_json')) {
      context.handle(
        _messagesJsonMeta,
        messagesJson.isAcceptableOrUnknown(
          data['messages_json']!,
          _messagesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messagesJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      messagesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messages_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChatSessionsTable createAlias(String alias) {
    return $ChatSessionsTable(attachedDatabase, alias);
  }
}

class ChatSession extends DataClass implements Insertable<ChatSession> {
  final int id;
  final String title;
  final String messagesJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChatSession({
    required this.id,
    required this.title,
    required this.messagesJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['messages_json'] = Variable<String>(messagesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChatSessionsCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsCompanion(
      id: Value(id),
      title: Value(title),
      messagesJson: Value(messagesJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChatSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSession(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      messagesJson: serializer.fromJson<String>(json['messagesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'messagesJson': serializer.toJson<String>(messagesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChatSession copyWith({
    int? id,
    String? title,
    String? messagesJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChatSession(
    id: id ?? this.id,
    title: title ?? this.title,
    messagesJson: messagesJson ?? this.messagesJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChatSession copyWithCompanion(ChatSessionsCompanion data) {
    return ChatSession(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      messagesJson: data.messagesJson.present
          ? data.messagesJson.value
          : this.messagesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSession(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('messagesJson: $messagesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, messagesJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSession &&
          other.id == this.id &&
          other.title == this.title &&
          other.messagesJson == this.messagesJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChatSessionsCompanion extends UpdateCompanion<ChatSession> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> messagesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ChatSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.messagesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChatSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String messagesJson,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title),
       messagesJson = Value(messagesJson);
  static Insertable<ChatSession> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? messagesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (messagesJson != null) 'messages_json': messagesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChatSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? messagesJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ChatSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      messagesJson: messagesJson ?? this.messagesJson,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (messagesJson.present) {
      map['messages_json'] = Variable<String>(messagesJson.value);
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
    return (StringBuffer('ChatSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('messagesJson: $messagesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DiningTablesTable extends DiningTables
    with TableInfo<$DiningTablesTable, DiningTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiningTablesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capacityMeta = const VerificationMeta(
    'capacity',
  );
  @override
  late final GeneratedColumn<int> capacity = GeneratedColumn<int>(
    'capacity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Kosong'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, capacity, status, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dining_tables';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiningTable> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('capacity')) {
      context.handle(
        _capacityMeta,
        capacity.isAcceptableOrUnknown(data['capacity']!, _capacityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiningTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiningTable(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DiningTablesTable createAlias(String alias) {
    return $DiningTablesTable(attachedDatabase, alias);
  }
}

class DiningTable extends DataClass implements Insertable<DiningTable> {
  final int id;
  final String name;
  final int capacity;
  final String status;
  final DateTime createdAt;
  const DiningTable({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['capacity'] = Variable<int>(capacity);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DiningTablesCompanion toCompanion(bool nullToAbsent) {
    return DiningTablesCompanion(
      id: Value(id),
      name: Value(name),
      capacity: Value(capacity),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory DiningTable.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiningTable(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      capacity: serializer.fromJson<int>(json['capacity']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'capacity': serializer.toJson<int>(capacity),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DiningTable copyWith({
    int? id,
    String? name,
    int? capacity,
    String? status,
    DateTime? createdAt,
  }) => DiningTable(
    id: id ?? this.id,
    name: name ?? this.name,
    capacity: capacity ?? this.capacity,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  DiningTable copyWithCompanion(DiningTablesCompanion data) {
    return DiningTable(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      capacity: data.capacity.present ? data.capacity.value : this.capacity,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiningTable(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('capacity: $capacity, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, capacity, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiningTable &&
          other.id == this.id &&
          other.name == this.name &&
          other.capacity == this.capacity &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class DiningTablesCompanion extends UpdateCompanion<DiningTable> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> capacity;
  final Value<String> status;
  final Value<DateTime> createdAt;
  const DiningTablesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.capacity = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DiningTablesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.capacity = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<DiningTable> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? capacity,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (capacity != null) 'capacity': capacity,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DiningTablesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? capacity,
    Value<String>? status,
    Value<DateTime>? createdAt,
  }) {
    return DiningTablesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
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
    if (capacity.present) {
      map['capacity'] = Variable<int>(capacity.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiningTablesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('capacity: $capacity, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LaundryOrdersTable extends LaundryOrders
    with TableInfo<$LaundryOrdersTable, LaundryOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LaundryOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Baru'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedReadyMeta = const VerificationMeta(
    'estimatedReady',
  );
  @override
  late final GeneratedColumn<DateTime> estimatedReady =
      GeneratedColumn<DateTime>(
        'estimated_ready',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerName,
    customerPhone,
    itemsJson,
    total,
    status,
    notes,
    estimatedReady,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'laundry_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LaundryOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('estimated_ready')) {
      context.handle(
        _estimatedReadyMeta,
        estimatedReady.isAcceptableOrUnknown(
          data['estimated_ready']!,
          _estimatedReadyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LaundryOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LaundryOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      estimatedReady: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}estimated_ready'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LaundryOrdersTable createAlias(String alias) {
    return $LaundryOrdersTable(attachedDatabase, alias);
  }
}

class LaundryOrder extends DataClass implements Insertable<LaundryOrder> {
  final int id;
  final String customerName;
  final String? customerPhone;
  final String itemsJson;
  final int total;
  final String status;
  final String? notes;
  final DateTime? estimatedReady;
  final DateTime createdAt;
  const LaundryOrder({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.itemsJson,
    required this.total,
    required this.status,
    this.notes,
    this.estimatedReady,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['customer_name'] = Variable<String>(customerName);
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['items_json'] = Variable<String>(itemsJson);
    map['total'] = Variable<int>(total);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || estimatedReady != null) {
      map['estimated_ready'] = Variable<DateTime>(estimatedReady);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LaundryOrdersCompanion toCompanion(bool nullToAbsent) {
    return LaundryOrdersCompanion(
      id: Value(id),
      customerName: Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      itemsJson: Value(itemsJson),
      total: Value(total),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      estimatedReady: estimatedReady == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedReady),
      createdAt: Value(createdAt),
    );
  }

  factory LaundryOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LaundryOrder(
      id: serializer.fromJson<int>(json['id']),
      customerName: serializer.fromJson<String>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      total: serializer.fromJson<int>(json['total']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      estimatedReady: serializer.fromJson<DateTime?>(json['estimatedReady']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'customerName': serializer.toJson<String>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'total': serializer.toJson<int>(total),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'estimatedReady': serializer.toJson<DateTime?>(estimatedReady),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LaundryOrder copyWith({
    int? id,
    String? customerName,
    Value<String?> customerPhone = const Value.absent(),
    String? itemsJson,
    int? total,
    String? status,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> estimatedReady = const Value.absent(),
    DateTime? createdAt,
  }) => LaundryOrder(
    id: id ?? this.id,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    itemsJson: itemsJson ?? this.itemsJson,
    total: total ?? this.total,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    estimatedReady: estimatedReady.present
        ? estimatedReady.value
        : this.estimatedReady,
    createdAt: createdAt ?? this.createdAt,
  );
  LaundryOrder copyWithCompanion(LaundryOrdersCompanion data) {
    return LaundryOrder(
      id: data.id.present ? data.id.value : this.id,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      total: data.total.present ? data.total.value : this.total,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      estimatedReady: data.estimatedReady.present
          ? data.estimatedReady.value
          : this.estimatedReady,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LaundryOrder(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('estimatedReady: $estimatedReady, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerName,
    customerPhone,
    itemsJson,
    total,
    status,
    notes,
    estimatedReady,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LaundryOrder &&
          other.id == this.id &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.itemsJson == this.itemsJson &&
          other.total == this.total &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.estimatedReady == this.estimatedReady &&
          other.createdAt == this.createdAt);
}

class LaundryOrdersCompanion extends UpdateCompanion<LaundryOrder> {
  final Value<int> id;
  final Value<String> customerName;
  final Value<String?> customerPhone;
  final Value<String> itemsJson;
  final Value<int> total;
  final Value<String> status;
  final Value<String?> notes;
  final Value<DateTime?> estimatedReady;
  final Value<DateTime> createdAt;
  const LaundryOrdersCompanion({
    this.id = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.estimatedReady = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LaundryOrdersCompanion.insert({
    this.id = const Value.absent(),
    required String customerName,
    this.customerPhone = const Value.absent(),
    required String itemsJson,
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.estimatedReady = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : customerName = Value(customerName),
       itemsJson = Value(itemsJson);
  static Insertable<LaundryOrder> custom({
    Expression<int>? id,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<String>? itemsJson,
    Expression<int>? total,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<DateTime>? estimatedReady,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (itemsJson != null) 'items_json': itemsJson,
      if (total != null) 'total': total,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (estimatedReady != null) 'estimated_ready': estimatedReady,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LaundryOrdersCompanion copyWith({
    Value<int>? id,
    Value<String>? customerName,
    Value<String?>? customerPhone,
    Value<String>? itemsJson,
    Value<int>? total,
    Value<String>? status,
    Value<String?>? notes,
    Value<DateTime?>? estimatedReady,
    Value<DateTime>? createdAt,
  }) {
    return LaundryOrdersCompanion(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      itemsJson: itemsJson ?? this.itemsJson,
      total: total ?? this.total,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      estimatedReady: estimatedReady ?? this.estimatedReady,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (estimatedReady.present) {
      map['estimated_ready'] = Variable<DateTime>(estimatedReady.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LaundryOrdersCompanion(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('estimatedReady: $estimatedReady, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ServiceTicketsTable extends ServiceTickets
    with TableInfo<$ServiceTicketsTable, ServiceTicket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issueMeta = const VerificationMeta('issue');
  @override
  late final GeneratedColumn<String> issue = GeneratedColumn<String>(
    'issue',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimatedCostMeta = const VerificationMeta(
    'estimatedCost',
  );
  @override
  late final GeneratedColumn<int> estimatedCost = GeneratedColumn<int>(
    'estimated_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _finalCostMeta = const VerificationMeta(
    'finalCost',
  );
  @override
  late final GeneratedColumn<int> finalCost = GeneratedColumn<int>(
    'final_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Diagnosa'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _plateNumberMeta = const VerificationMeta(
    'plateNumber',
  );
  @override
  late final GeneratedColumn<String> plateNumber = GeneratedColumn<String>(
    'plate_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleBrandMeta = const VerificationMeta(
    'vehicleBrand',
  );
  @override
  late final GeneratedColumn<String> vehicleBrand = GeneratedColumn<String>(
    'vehicle_brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleYearMeta = const VerificationMeta(
    'vehicleYear',
  );
  @override
  late final GeneratedColumn<int> vehicleYear = GeneratedColumn<int>(
    'vehicle_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _technicianMeta = const VerificationMeta(
    'technician',
  );
  @override
  late final GeneratedColumn<String> technician = GeneratedColumn<String>(
    'technician',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sparepartCostMeta = const VerificationMeta(
    'sparepartCost',
  );
  @override
  late final GeneratedColumn<int> sparepartCost = GeneratedColumn<int>(
    'sparepart_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serviceCostMeta = const VerificationMeta(
    'serviceCost',
  );
  @override
  late final GeneratedColumn<int> serviceCost = GeneratedColumn<int>(
    'service_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _queueNumberMeta = const VerificationMeta(
    'queueNumber',
  );
  @override
  late final GeneratedColumn<int> queueNumber = GeneratedColumn<int>(
    'queue_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerName,
    customerPhone,
    deviceName,
    issue,
    estimatedCost,
    finalCost,
    status,
    notes,
    createdAt,
    plateNumber,
    vehicleBrand,
    vehicleYear,
    technician,
    sparepartCost,
    serviceCost,
    queueNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_tickets';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceTicket> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceNameMeta);
    }
    if (data.containsKey('issue')) {
      context.handle(
        _issueMeta,
        issue.isAcceptableOrUnknown(data['issue']!, _issueMeta),
      );
    } else if (isInserting) {
      context.missing(_issueMeta);
    }
    if (data.containsKey('estimated_cost')) {
      context.handle(
        _estimatedCostMeta,
        estimatedCost.isAcceptableOrUnknown(
          data['estimated_cost']!,
          _estimatedCostMeta,
        ),
      );
    }
    if (data.containsKey('final_cost')) {
      context.handle(
        _finalCostMeta,
        finalCost.isAcceptableOrUnknown(data['final_cost']!, _finalCostMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('plate_number')) {
      context.handle(
        _plateNumberMeta,
        plateNumber.isAcceptableOrUnknown(
          data['plate_number']!,
          _plateNumberMeta,
        ),
      );
    }
    if (data.containsKey('vehicle_brand')) {
      context.handle(
        _vehicleBrandMeta,
        vehicleBrand.isAcceptableOrUnknown(
          data['vehicle_brand']!,
          _vehicleBrandMeta,
        ),
      );
    }
    if (data.containsKey('vehicle_year')) {
      context.handle(
        _vehicleYearMeta,
        vehicleYear.isAcceptableOrUnknown(
          data['vehicle_year']!,
          _vehicleYearMeta,
        ),
      );
    }
    if (data.containsKey('technician')) {
      context.handle(
        _technicianMeta,
        technician.isAcceptableOrUnknown(data['technician']!, _technicianMeta),
      );
    }
    if (data.containsKey('sparepart_cost')) {
      context.handle(
        _sparepartCostMeta,
        sparepartCost.isAcceptableOrUnknown(
          data['sparepart_cost']!,
          _sparepartCostMeta,
        ),
      );
    }
    if (data.containsKey('service_cost')) {
      context.handle(
        _serviceCostMeta,
        serviceCost.isAcceptableOrUnknown(
          data['service_cost']!,
          _serviceCostMeta,
        ),
      );
    }
    if (data.containsKey('queue_number')) {
      context.handle(
        _queueNumberMeta,
        queueNumber.isAcceptableOrUnknown(
          data['queue_number']!,
          _queueNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceTicket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceTicket(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
      issue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue'],
      )!,
      estimatedCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_cost'],
      )!,
      finalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}final_cost'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      plateNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate_number'],
      ),
      vehicleBrand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_brand'],
      ),
      vehicleYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vehicle_year'],
      ),
      technician: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}technician'],
      ),
      sparepartCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sparepart_cost'],
      )!,
      serviceCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}service_cost'],
      )!,
      queueNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_number'],
      ),
    );
  }

  @override
  $ServiceTicketsTable createAlias(String alias) {
    return $ServiceTicketsTable(attachedDatabase, alias);
  }
}

class ServiceTicket extends DataClass implements Insertable<ServiceTicket> {
  final int id;
  final String customerName;
  final String? customerPhone;
  final String deviceName;
  final String issue;
  final int estimatedCost;
  final int finalCost;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final String? plateNumber;
  final String? vehicleBrand;
  final int? vehicleYear;
  final String? technician;
  final int sparepartCost;
  final int serviceCost;
  final int? queueNumber;
  const ServiceTicket({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.deviceName,
    required this.issue,
    required this.estimatedCost,
    required this.finalCost,
    required this.status,
    this.notes,
    required this.createdAt,
    this.plateNumber,
    this.vehicleBrand,
    this.vehicleYear,
    this.technician,
    required this.sparepartCost,
    required this.serviceCost,
    this.queueNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['customer_name'] = Variable<String>(customerName);
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['device_name'] = Variable<String>(deviceName);
    map['issue'] = Variable<String>(issue);
    map['estimated_cost'] = Variable<int>(estimatedCost);
    map['final_cost'] = Variable<int>(finalCost);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || plateNumber != null) {
      map['plate_number'] = Variable<String>(plateNumber);
    }
    if (!nullToAbsent || vehicleBrand != null) {
      map['vehicle_brand'] = Variable<String>(vehicleBrand);
    }
    if (!nullToAbsent || vehicleYear != null) {
      map['vehicle_year'] = Variable<int>(vehicleYear);
    }
    if (!nullToAbsent || technician != null) {
      map['technician'] = Variable<String>(technician);
    }
    map['sparepart_cost'] = Variable<int>(sparepartCost);
    map['service_cost'] = Variable<int>(serviceCost);
    if (!nullToAbsent || queueNumber != null) {
      map['queue_number'] = Variable<int>(queueNumber);
    }
    return map;
  }

  ServiceTicketsCompanion toCompanion(bool nullToAbsent) {
    return ServiceTicketsCompanion(
      id: Value(id),
      customerName: Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      deviceName: Value(deviceName),
      issue: Value(issue),
      estimatedCost: Value(estimatedCost),
      finalCost: Value(finalCost),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      plateNumber: plateNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(plateNumber),
      vehicleBrand: vehicleBrand == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleBrand),
      vehicleYear: vehicleYear == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleYear),
      technician: technician == null && nullToAbsent
          ? const Value.absent()
          : Value(technician),
      sparepartCost: Value(sparepartCost),
      serviceCost: Value(serviceCost),
      queueNumber: queueNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(queueNumber),
    );
  }

  factory ServiceTicket.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceTicket(
      id: serializer.fromJson<int>(json['id']),
      customerName: serializer.fromJson<String>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      deviceName: serializer.fromJson<String>(json['deviceName']),
      issue: serializer.fromJson<String>(json['issue']),
      estimatedCost: serializer.fromJson<int>(json['estimatedCost']),
      finalCost: serializer.fromJson<int>(json['finalCost']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      plateNumber: serializer.fromJson<String?>(json['plateNumber']),
      vehicleBrand: serializer.fromJson<String?>(json['vehicleBrand']),
      vehicleYear: serializer.fromJson<int?>(json['vehicleYear']),
      technician: serializer.fromJson<String?>(json['technician']),
      sparepartCost: serializer.fromJson<int>(json['sparepartCost']),
      serviceCost: serializer.fromJson<int>(json['serviceCost']),
      queueNumber: serializer.fromJson<int?>(json['queueNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'customerName': serializer.toJson<String>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'deviceName': serializer.toJson<String>(deviceName),
      'issue': serializer.toJson<String>(issue),
      'estimatedCost': serializer.toJson<int>(estimatedCost),
      'finalCost': serializer.toJson<int>(finalCost),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'plateNumber': serializer.toJson<String?>(plateNumber),
      'vehicleBrand': serializer.toJson<String?>(vehicleBrand),
      'vehicleYear': serializer.toJson<int?>(vehicleYear),
      'technician': serializer.toJson<String?>(technician),
      'sparepartCost': serializer.toJson<int>(sparepartCost),
      'serviceCost': serializer.toJson<int>(serviceCost),
      'queueNumber': serializer.toJson<int?>(queueNumber),
    };
  }

  ServiceTicket copyWith({
    int? id,
    String? customerName,
    Value<String?> customerPhone = const Value.absent(),
    String? deviceName,
    String? issue,
    int? estimatedCost,
    int? finalCost,
    String? status,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    Value<String?> plateNumber = const Value.absent(),
    Value<String?> vehicleBrand = const Value.absent(),
    Value<int?> vehicleYear = const Value.absent(),
    Value<String?> technician = const Value.absent(),
    int? sparepartCost,
    int? serviceCost,
    Value<int?> queueNumber = const Value.absent(),
  }) => ServiceTicket(
    id: id ?? this.id,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    deviceName: deviceName ?? this.deviceName,
    issue: issue ?? this.issue,
    estimatedCost: estimatedCost ?? this.estimatedCost,
    finalCost: finalCost ?? this.finalCost,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    plateNumber: plateNumber.present ? plateNumber.value : this.plateNumber,
    vehicleBrand: vehicleBrand.present ? vehicleBrand.value : this.vehicleBrand,
    vehicleYear: vehicleYear.present ? vehicleYear.value : this.vehicleYear,
    technician: technician.present ? technician.value : this.technician,
    sparepartCost: sparepartCost ?? this.sparepartCost,
    serviceCost: serviceCost ?? this.serviceCost,
    queueNumber: queueNumber.present ? queueNumber.value : this.queueNumber,
  );
  ServiceTicket copyWithCompanion(ServiceTicketsCompanion data) {
    return ServiceTicket(
      id: data.id.present ? data.id.value : this.id,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      issue: data.issue.present ? data.issue.value : this.issue,
      estimatedCost: data.estimatedCost.present
          ? data.estimatedCost.value
          : this.estimatedCost,
      finalCost: data.finalCost.present ? data.finalCost.value : this.finalCost,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      plateNumber: data.plateNumber.present
          ? data.plateNumber.value
          : this.plateNumber,
      vehicleBrand: data.vehicleBrand.present
          ? data.vehicleBrand.value
          : this.vehicleBrand,
      vehicleYear: data.vehicleYear.present
          ? data.vehicleYear.value
          : this.vehicleYear,
      technician: data.technician.present
          ? data.technician.value
          : this.technician,
      sparepartCost: data.sparepartCost.present
          ? data.sparepartCost.value
          : this.sparepartCost,
      serviceCost: data.serviceCost.present
          ? data.serviceCost.value
          : this.serviceCost,
      queueNumber: data.queueNumber.present
          ? data.queueNumber.value
          : this.queueNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceTicket(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('deviceName: $deviceName, ')
          ..write('issue: $issue, ')
          ..write('estimatedCost: $estimatedCost, ')
          ..write('finalCost: $finalCost, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('plateNumber: $plateNumber, ')
          ..write('vehicleBrand: $vehicleBrand, ')
          ..write('vehicleYear: $vehicleYear, ')
          ..write('technician: $technician, ')
          ..write('sparepartCost: $sparepartCost, ')
          ..write('serviceCost: $serviceCost, ')
          ..write('queueNumber: $queueNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerName,
    customerPhone,
    deviceName,
    issue,
    estimatedCost,
    finalCost,
    status,
    notes,
    createdAt,
    plateNumber,
    vehicleBrand,
    vehicleYear,
    technician,
    sparepartCost,
    serviceCost,
    queueNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceTicket &&
          other.id == this.id &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.deviceName == this.deviceName &&
          other.issue == this.issue &&
          other.estimatedCost == this.estimatedCost &&
          other.finalCost == this.finalCost &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.plateNumber == this.plateNumber &&
          other.vehicleBrand == this.vehicleBrand &&
          other.vehicleYear == this.vehicleYear &&
          other.technician == this.technician &&
          other.sparepartCost == this.sparepartCost &&
          other.serviceCost == this.serviceCost &&
          other.queueNumber == this.queueNumber);
}

class ServiceTicketsCompanion extends UpdateCompanion<ServiceTicket> {
  final Value<int> id;
  final Value<String> customerName;
  final Value<String?> customerPhone;
  final Value<String> deviceName;
  final Value<String> issue;
  final Value<int> estimatedCost;
  final Value<int> finalCost;
  final Value<String> status;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<String?> plateNumber;
  final Value<String?> vehicleBrand;
  final Value<int?> vehicleYear;
  final Value<String?> technician;
  final Value<int> sparepartCost;
  final Value<int> serviceCost;
  final Value<int?> queueNumber;
  const ServiceTicketsCompanion({
    this.id = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.issue = const Value.absent(),
    this.estimatedCost = const Value.absent(),
    this.finalCost = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.plateNumber = const Value.absent(),
    this.vehicleBrand = const Value.absent(),
    this.vehicleYear = const Value.absent(),
    this.technician = const Value.absent(),
    this.sparepartCost = const Value.absent(),
    this.serviceCost = const Value.absent(),
    this.queueNumber = const Value.absent(),
  });
  ServiceTicketsCompanion.insert({
    this.id = const Value.absent(),
    required String customerName,
    this.customerPhone = const Value.absent(),
    required String deviceName,
    required String issue,
    this.estimatedCost = const Value.absent(),
    this.finalCost = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.plateNumber = const Value.absent(),
    this.vehicleBrand = const Value.absent(),
    this.vehicleYear = const Value.absent(),
    this.technician = const Value.absent(),
    this.sparepartCost = const Value.absent(),
    this.serviceCost = const Value.absent(),
    this.queueNumber = const Value.absent(),
  }) : customerName = Value(customerName),
       deviceName = Value(deviceName),
       issue = Value(issue);
  static Insertable<ServiceTicket> custom({
    Expression<int>? id,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<String>? deviceName,
    Expression<String>? issue,
    Expression<int>? estimatedCost,
    Expression<int>? finalCost,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<String>? plateNumber,
    Expression<String>? vehicleBrand,
    Expression<int>? vehicleYear,
    Expression<String>? technician,
    Expression<int>? sparepartCost,
    Expression<int>? serviceCost,
    Expression<int>? queueNumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (deviceName != null) 'device_name': deviceName,
      if (issue != null) 'issue': issue,
      if (estimatedCost != null) 'estimated_cost': estimatedCost,
      if (finalCost != null) 'final_cost': finalCost,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (plateNumber != null) 'plate_number': plateNumber,
      if (vehicleBrand != null) 'vehicle_brand': vehicleBrand,
      if (vehicleYear != null) 'vehicle_year': vehicleYear,
      if (technician != null) 'technician': technician,
      if (sparepartCost != null) 'sparepart_cost': sparepartCost,
      if (serviceCost != null) 'service_cost': serviceCost,
      if (queueNumber != null) 'queue_number': queueNumber,
    });
  }

  ServiceTicketsCompanion copyWith({
    Value<int>? id,
    Value<String>? customerName,
    Value<String?>? customerPhone,
    Value<String>? deviceName,
    Value<String>? issue,
    Value<int>? estimatedCost,
    Value<int>? finalCost,
    Value<String>? status,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<String?>? plateNumber,
    Value<String?>? vehicleBrand,
    Value<int?>? vehicleYear,
    Value<String?>? technician,
    Value<int>? sparepartCost,
    Value<int>? serviceCost,
    Value<int?>? queueNumber,
  }) {
    return ServiceTicketsCompanion(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deviceName: deviceName ?? this.deviceName,
      issue: issue ?? this.issue,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      finalCost: finalCost ?? this.finalCost,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      technician: technician ?? this.technician,
      sparepartCost: sparepartCost ?? this.sparepartCost,
      serviceCost: serviceCost ?? this.serviceCost,
      queueNumber: queueNumber ?? this.queueNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (issue.present) {
      map['issue'] = Variable<String>(issue.value);
    }
    if (estimatedCost.present) {
      map['estimated_cost'] = Variable<int>(estimatedCost.value);
    }
    if (finalCost.present) {
      map['final_cost'] = Variable<int>(finalCost.value);
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
    if (plateNumber.present) {
      map['plate_number'] = Variable<String>(plateNumber.value);
    }
    if (vehicleBrand.present) {
      map['vehicle_brand'] = Variable<String>(vehicleBrand.value);
    }
    if (vehicleYear.present) {
      map['vehicle_year'] = Variable<int>(vehicleYear.value);
    }
    if (technician.present) {
      map['technician'] = Variable<String>(technician.value);
    }
    if (sparepartCost.present) {
      map['sparepart_cost'] = Variable<int>(sparepartCost.value);
    }
    if (serviceCost.present) {
      map['service_cost'] = Variable<int>(serviceCost.value);
    }
    if (queueNumber.present) {
      map['queue_number'] = Variable<int>(queueNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceTicketsCompanion(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('deviceName: $deviceName, ')
          ..write('issue: $issue, ')
          ..write('estimatedCost: $estimatedCost, ')
          ..write('finalCost: $finalCost, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('plateNumber: $plateNumber, ')
          ..write('vehicleBrand: $vehicleBrand, ')
          ..write('vehicleYear: $vehicleYear, ')
          ..write('technician: $technician, ')
          ..write('sparepartCost: $sparepartCost, ')
          ..write('serviceCost: $serviceCost, ')
          ..write('queueNumber: $queueNumber')
          ..write(')'))
        .toString();
  }
}

class $AppointmentsTable extends Appointments
    with TableInfo<$AppointmentsTable, Appointment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppointmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceMeta = const VerificationMeta(
    'service',
  );
  @override
  late final GeneratedColumn<String> service = GeneratedColumn<String>(
    'service',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stylistMeta = const VerificationMeta(
    'stylist',
  );
  @override
  late final GeneratedColumn<String> stylist = GeneratedColumn<String>(
    'stylist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeSlotMeta = const VerificationMeta(
    'timeSlot',
  );
  @override
  late final GeneratedColumn<String> timeSlot = GeneratedColumn<String>(
    'time_slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Dikonfirmasi'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedDurationMeta = const VerificationMeta(
    'estimatedDuration',
  );
  @override
  late final GeneratedColumn<int> estimatedDuration = GeneratedColumn<int>(
    'estimated_duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _counterIdMeta = const VerificationMeta(
    'counterId',
  );
  @override
  late final GeneratedColumn<int> counterId = GeneratedColumn<int>(
    'counter_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerName,
    customerPhone,
    service,
    stylist,
    date,
    timeSlot,
    status,
    notes,
    estimatedDuration,
    counterId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'appointments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Appointment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('service')) {
      context.handle(
        _serviceMeta,
        service.isAcceptableOrUnknown(data['service']!, _serviceMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceMeta);
    }
    if (data.containsKey('stylist')) {
      context.handle(
        _stylistMeta,
        stylist.isAcceptableOrUnknown(data['stylist']!, _stylistMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time_slot')) {
      context.handle(
        _timeSlotMeta,
        timeSlot.isAcceptableOrUnknown(data['time_slot']!, _timeSlotMeta),
      );
    } else if (isInserting) {
      context.missing(_timeSlotMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('estimated_duration')) {
      context.handle(
        _estimatedDurationMeta,
        estimatedDuration.isAcceptableOrUnknown(
          data['estimated_duration']!,
          _estimatedDurationMeta,
        ),
      );
    }
    if (data.containsKey('counter_id')) {
      context.handle(
        _counterIdMeta,
        counterId.isAcceptableOrUnknown(data['counter_id']!, _counterIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Appointment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Appointment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      service: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service'],
      )!,
      stylist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stylist'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      timeSlot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_slot'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      estimatedDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_duration'],
      ),
      counterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counter_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AppointmentsTable createAlias(String alias) {
    return $AppointmentsTable(attachedDatabase, alias);
  }
}

class Appointment extends DataClass implements Insertable<Appointment> {
  final int id;
  final String customerName;
  final String? customerPhone;
  final String service;
  final String? stylist;
  final DateTime date;
  final String timeSlot;
  final String status;
  final String? notes;
  final int? estimatedDuration;
  final int? counterId;
  final DateTime createdAt;
  const Appointment({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.service,
    this.stylist,
    required this.date,
    required this.timeSlot,
    required this.status,
    this.notes,
    this.estimatedDuration,
    this.counterId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['customer_name'] = Variable<String>(customerName);
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['service'] = Variable<String>(service);
    if (!nullToAbsent || stylist != null) {
      map['stylist'] = Variable<String>(stylist);
    }
    map['date'] = Variable<DateTime>(date);
    map['time_slot'] = Variable<String>(timeSlot);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || estimatedDuration != null) {
      map['estimated_duration'] = Variable<int>(estimatedDuration);
    }
    if (!nullToAbsent || counterId != null) {
      map['counter_id'] = Variable<int>(counterId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AppointmentsCompanion toCompanion(bool nullToAbsent) {
    return AppointmentsCompanion(
      id: Value(id),
      customerName: Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      service: Value(service),
      stylist: stylist == null && nullToAbsent
          ? const Value.absent()
          : Value(stylist),
      date: Value(date),
      timeSlot: Value(timeSlot),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      estimatedDuration: estimatedDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedDuration),
      counterId: counterId == null && nullToAbsent
          ? const Value.absent()
          : Value(counterId),
      createdAt: Value(createdAt),
    );
  }

  factory Appointment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Appointment(
      id: serializer.fromJson<int>(json['id']),
      customerName: serializer.fromJson<String>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      service: serializer.fromJson<String>(json['service']),
      stylist: serializer.fromJson<String?>(json['stylist']),
      date: serializer.fromJson<DateTime>(json['date']),
      timeSlot: serializer.fromJson<String>(json['timeSlot']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      estimatedDuration: serializer.fromJson<int?>(json['estimatedDuration']),
      counterId: serializer.fromJson<int?>(json['counterId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'customerName': serializer.toJson<String>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'service': serializer.toJson<String>(service),
      'stylist': serializer.toJson<String?>(stylist),
      'date': serializer.toJson<DateTime>(date),
      'timeSlot': serializer.toJson<String>(timeSlot),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'estimatedDuration': serializer.toJson<int?>(estimatedDuration),
      'counterId': serializer.toJson<int?>(counterId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Appointment copyWith({
    int? id,
    String? customerName,
    Value<String?> customerPhone = const Value.absent(),
    String? service,
    Value<String?> stylist = const Value.absent(),
    DateTime? date,
    String? timeSlot,
    String? status,
    Value<String?> notes = const Value.absent(),
    Value<int?> estimatedDuration = const Value.absent(),
    Value<int?> counterId = const Value.absent(),
    DateTime? createdAt,
  }) => Appointment(
    id: id ?? this.id,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    service: service ?? this.service,
    stylist: stylist.present ? stylist.value : this.stylist,
    date: date ?? this.date,
    timeSlot: timeSlot ?? this.timeSlot,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    estimatedDuration: estimatedDuration.present
        ? estimatedDuration.value
        : this.estimatedDuration,
    counterId: counterId.present ? counterId.value : this.counterId,
    createdAt: createdAt ?? this.createdAt,
  );
  Appointment copyWithCompanion(AppointmentsCompanion data) {
    return Appointment(
      id: data.id.present ? data.id.value : this.id,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      service: data.service.present ? data.service.value : this.service,
      stylist: data.stylist.present ? data.stylist.value : this.stylist,
      date: data.date.present ? data.date.value : this.date,
      timeSlot: data.timeSlot.present ? data.timeSlot.value : this.timeSlot,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      estimatedDuration: data.estimatedDuration.present
          ? data.estimatedDuration.value
          : this.estimatedDuration,
      counterId: data.counterId.present ? data.counterId.value : this.counterId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Appointment(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('service: $service, ')
          ..write('stylist: $stylist, ')
          ..write('date: $date, ')
          ..write('timeSlot: $timeSlot, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('estimatedDuration: $estimatedDuration, ')
          ..write('counterId: $counterId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerName,
    customerPhone,
    service,
    stylist,
    date,
    timeSlot,
    status,
    notes,
    estimatedDuration,
    counterId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Appointment &&
          other.id == this.id &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.service == this.service &&
          other.stylist == this.stylist &&
          other.date == this.date &&
          other.timeSlot == this.timeSlot &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.estimatedDuration == this.estimatedDuration &&
          other.counterId == this.counterId &&
          other.createdAt == this.createdAt);
}

class AppointmentsCompanion extends UpdateCompanion<Appointment> {
  final Value<int> id;
  final Value<String> customerName;
  final Value<String?> customerPhone;
  final Value<String> service;
  final Value<String?> stylist;
  final Value<DateTime> date;
  final Value<String> timeSlot;
  final Value<String> status;
  final Value<String?> notes;
  final Value<int?> estimatedDuration;
  final Value<int?> counterId;
  final Value<DateTime> createdAt;
  const AppointmentsCompanion({
    this.id = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.service = const Value.absent(),
    this.stylist = const Value.absent(),
    this.date = const Value.absent(),
    this.timeSlot = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.estimatedDuration = const Value.absent(),
    this.counterId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AppointmentsCompanion.insert({
    this.id = const Value.absent(),
    required String customerName,
    this.customerPhone = const Value.absent(),
    required String service,
    this.stylist = const Value.absent(),
    required DateTime date,
    required String timeSlot,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.estimatedDuration = const Value.absent(),
    this.counterId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : customerName = Value(customerName),
       service = Value(service),
       date = Value(date),
       timeSlot = Value(timeSlot);
  static Insertable<Appointment> custom({
    Expression<int>? id,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<String>? service,
    Expression<String>? stylist,
    Expression<DateTime>? date,
    Expression<String>? timeSlot,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<int>? estimatedDuration,
    Expression<int>? counterId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (service != null) 'service': service,
      if (stylist != null) 'stylist': stylist,
      if (date != null) 'date': date,
      if (timeSlot != null) 'time_slot': timeSlot,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (estimatedDuration != null) 'estimated_duration': estimatedDuration,
      if (counterId != null) 'counter_id': counterId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AppointmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? customerName,
    Value<String?>? customerPhone,
    Value<String>? service,
    Value<String?>? stylist,
    Value<DateTime>? date,
    Value<String>? timeSlot,
    Value<String>? status,
    Value<String?>? notes,
    Value<int?>? estimatedDuration,
    Value<int?>? counterId,
    Value<DateTime>? createdAt,
  }) {
    return AppointmentsCompanion(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      service: service ?? this.service,
      stylist: stylist ?? this.stylist,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      counterId: counterId ?? this.counterId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (service.present) {
      map['service'] = Variable<String>(service.value);
    }
    if (stylist.present) {
      map['stylist'] = Variable<String>(stylist.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (timeSlot.present) {
      map['time_slot'] = Variable<String>(timeSlot.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (estimatedDuration.present) {
      map['estimated_duration'] = Variable<int>(estimatedDuration.value);
    }
    if (counterId.present) {
      map['counter_id'] = Variable<int>(counterId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppointmentsCompanion(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('service: $service, ')
          ..write('stylist: $stylist, ')
          ..write('date: $date, ')
          ..write('timeSlot: $timeSlot, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('estimatedDuration: $estimatedDuration, ')
          ..write('counterId: $counterId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PrescriptionsTable extends Prescriptions
    with TableInfo<$PrescriptionsTable, Prescription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrescriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _patientNameMeta = const VerificationMeta(
    'patientName',
  );
  @override
  late final GeneratedColumn<String> patientName = GeneratedColumn<String>(
    'patient_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doctorNameMeta = const VerificationMeta(
    'doctorName',
  );
  @override
  late final GeneratedColumn<String> doctorName = GeneratedColumn<String>(
    'doctor_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dosageMeta = const VerificationMeta('dosage');
  @override
  late final GeneratedColumn<String> dosage = GeneratedColumn<String>(
    'dosage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Baru'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    patientName,
    doctorName,
    itemsJson,
    dosage,
    total,
    status,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prescriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Prescription> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('patient_name')) {
      context.handle(
        _patientNameMeta,
        patientName.isAcceptableOrUnknown(
          data['patient_name']!,
          _patientNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_patientNameMeta);
    }
    if (data.containsKey('doctor_name')) {
      context.handle(
        _doctorNameMeta,
        doctorName.isAcceptableOrUnknown(data['doctor_name']!, _doctorNameMeta),
      );
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('dosage')) {
      context.handle(
        _dosageMeta,
        dosage.isAcceptableOrUnknown(data['dosage']!, _dosageMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Prescription map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Prescription(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      patientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_name'],
      )!,
      doctorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doctor_name'],
      ),
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      dosage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosage'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PrescriptionsTable createAlias(String alias) {
    return $PrescriptionsTable(attachedDatabase, alias);
  }
}

class Prescription extends DataClass implements Insertable<Prescription> {
  final int id;
  final String patientName;
  final String? doctorName;
  final String itemsJson;
  final String? dosage;
  final int total;
  final String status;
  final String? notes;
  final DateTime createdAt;
  const Prescription({
    required this.id,
    required this.patientName,
    this.doctorName,
    required this.itemsJson,
    this.dosage,
    required this.total,
    required this.status,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['patient_name'] = Variable<String>(patientName);
    if (!nullToAbsent || doctorName != null) {
      map['doctor_name'] = Variable<String>(doctorName);
    }
    map['items_json'] = Variable<String>(itemsJson);
    if (!nullToAbsent || dosage != null) {
      map['dosage'] = Variable<String>(dosage);
    }
    map['total'] = Variable<int>(total);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PrescriptionsCompanion toCompanion(bool nullToAbsent) {
    return PrescriptionsCompanion(
      id: Value(id),
      patientName: Value(patientName),
      doctorName: doctorName == null && nullToAbsent
          ? const Value.absent()
          : Value(doctorName),
      itemsJson: Value(itemsJson),
      dosage: dosage == null && nullToAbsent
          ? const Value.absent()
          : Value(dosage),
      total: Value(total),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Prescription.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Prescription(
      id: serializer.fromJson<int>(json['id']),
      patientName: serializer.fromJson<String>(json['patientName']),
      doctorName: serializer.fromJson<String?>(json['doctorName']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      dosage: serializer.fromJson<String?>(json['dosage']),
      total: serializer.fromJson<int>(json['total']),
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
      'patientName': serializer.toJson<String>(patientName),
      'doctorName': serializer.toJson<String?>(doctorName),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'dosage': serializer.toJson<String?>(dosage),
      'total': serializer.toJson<int>(total),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Prescription copyWith({
    int? id,
    String? patientName,
    Value<String?> doctorName = const Value.absent(),
    String? itemsJson,
    Value<String?> dosage = const Value.absent(),
    int? total,
    String? status,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => Prescription(
    id: id ?? this.id,
    patientName: patientName ?? this.patientName,
    doctorName: doctorName.present ? doctorName.value : this.doctorName,
    itemsJson: itemsJson ?? this.itemsJson,
    dosage: dosage.present ? dosage.value : this.dosage,
    total: total ?? this.total,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  Prescription copyWithCompanion(PrescriptionsCompanion data) {
    return Prescription(
      id: data.id.present ? data.id.value : this.id,
      patientName: data.patientName.present
          ? data.patientName.value
          : this.patientName,
      doctorName: data.doctorName.present
          ? data.doctorName.value
          : this.doctorName,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      dosage: data.dosage.present ? data.dosage.value : this.dosage,
      total: data.total.present ? data.total.value : this.total,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Prescription(')
          ..write('id: $id, ')
          ..write('patientName: $patientName, ')
          ..write('doctorName: $doctorName, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('dosage: $dosage, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    patientName,
    doctorName,
    itemsJson,
    dosage,
    total,
    status,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Prescription &&
          other.id == this.id &&
          other.patientName == this.patientName &&
          other.doctorName == this.doctorName &&
          other.itemsJson == this.itemsJson &&
          other.dosage == this.dosage &&
          other.total == this.total &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class PrescriptionsCompanion extends UpdateCompanion<Prescription> {
  final Value<int> id;
  final Value<String> patientName;
  final Value<String?> doctorName;
  final Value<String> itemsJson;
  final Value<String?> dosage;
  final Value<int> total;
  final Value<String> status;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const PrescriptionsCompanion({
    this.id = const Value.absent(),
    this.patientName = const Value.absent(),
    this.doctorName = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.dosage = const Value.absent(),
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PrescriptionsCompanion.insert({
    this.id = const Value.absent(),
    required String patientName,
    this.doctorName = const Value.absent(),
    required String itemsJson,
    this.dosage = const Value.absent(),
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : patientName = Value(patientName),
       itemsJson = Value(itemsJson);
  static Insertable<Prescription> custom({
    Expression<int>? id,
    Expression<String>? patientName,
    Expression<String>? doctorName,
    Expression<String>? itemsJson,
    Expression<String>? dosage,
    Expression<int>? total,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientName != null) 'patient_name': patientName,
      if (doctorName != null) 'doctor_name': doctorName,
      if (itemsJson != null) 'items_json': itemsJson,
      if (dosage != null) 'dosage': dosage,
      if (total != null) 'total': total,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PrescriptionsCompanion copyWith({
    Value<int>? id,
    Value<String>? patientName,
    Value<String?>? doctorName,
    Value<String>? itemsJson,
    Value<String?>? dosage,
    Value<int>? total,
    Value<String>? status,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return PrescriptionsCompanion(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      itemsJson: itemsJson ?? this.itemsJson,
      dosage: dosage ?? this.dosage,
      total: total ?? this.total,
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
    if (patientName.present) {
      map['patient_name'] = Variable<String>(patientName.value);
    }
    if (doctorName.present) {
      map['doctor_name'] = Variable<String>(doctorName.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (dosage.present) {
      map['dosage'] = Variable<String>(dosage.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
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
    return (StringBuffer('PrescriptionsCompanion(')
          ..write('id: $id, ')
          ..write('patientName: $patientName, ')
          ..write('doctorName: $doctorName, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('dosage: $dosage, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PrintOrdersTable extends PrintOrders
    with TableInfo<$PrintOrdersTable, PrintOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrintOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceTypeMeta = const VerificationMeta(
    'serviceType',
  );
  @override
  late final GeneratedColumn<String> serviceType = GeneratedColumn<String>(
    'service_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _copiesMeta = const VerificationMeta('copies');
  @override
  late final GeneratedColumn<int> copies = GeneratedColumn<int>(
    'copies',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _paperSizeMeta = const VerificationMeta(
    'paperSize',
  );
  @override
  late final GeneratedColumn<String> paperSize = GeneratedColumn<String>(
    'paper_size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('A4'),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Baru'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerName,
    customerPhone,
    serviceType,
    pages,
    copies,
    paperSize,
    total,
    status,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'print_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrintOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('service_type')) {
      context.handle(
        _serviceTypeMeta,
        serviceType.isAcceptableOrUnknown(
          data['service_type']!,
          _serviceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceTypeMeta);
    }
    if (data.containsKey('pages')) {
      context.handle(
        _pagesMeta,
        pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta),
      );
    }
    if (data.containsKey('copies')) {
      context.handle(
        _copiesMeta,
        copies.isAcceptableOrUnknown(data['copies']!, _copiesMeta),
      );
    }
    if (data.containsKey('paper_size')) {
      context.handle(
        _paperSizeMeta,
        paperSize.isAcceptableOrUnknown(data['paper_size']!, _paperSizeMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrintOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrintOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      serviceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_type'],
      )!,
      pages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages'],
      )!,
      copies: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}copies'],
      )!,
      paperSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paper_size'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PrintOrdersTable createAlias(String alias) {
    return $PrintOrdersTable(attachedDatabase, alias);
  }
}

class PrintOrder extends DataClass implements Insertable<PrintOrder> {
  final int id;
  final String customerName;
  final String? customerPhone;
  final String serviceType;
  final int pages;
  final int copies;
  final String paperSize;
  final int total;
  final String status;
  final String? notes;
  final DateTime createdAt;
  const PrintOrder({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.serviceType,
    required this.pages,
    required this.copies,
    required this.paperSize,
    required this.total,
    required this.status,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['customer_name'] = Variable<String>(customerName);
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['service_type'] = Variable<String>(serviceType);
    map['pages'] = Variable<int>(pages);
    map['copies'] = Variable<int>(copies);
    map['paper_size'] = Variable<String>(paperSize);
    map['total'] = Variable<int>(total);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PrintOrdersCompanion toCompanion(bool nullToAbsent) {
    return PrintOrdersCompanion(
      id: Value(id),
      customerName: Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      serviceType: Value(serviceType),
      pages: Value(pages),
      copies: Value(copies),
      paperSize: Value(paperSize),
      total: Value(total),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory PrintOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrintOrder(
      id: serializer.fromJson<int>(json['id']),
      customerName: serializer.fromJson<String>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      serviceType: serializer.fromJson<String>(json['serviceType']),
      pages: serializer.fromJson<int>(json['pages']),
      copies: serializer.fromJson<int>(json['copies']),
      paperSize: serializer.fromJson<String>(json['paperSize']),
      total: serializer.fromJson<int>(json['total']),
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
      'customerName': serializer.toJson<String>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'serviceType': serializer.toJson<String>(serviceType),
      'pages': serializer.toJson<int>(pages),
      'copies': serializer.toJson<int>(copies),
      'paperSize': serializer.toJson<String>(paperSize),
      'total': serializer.toJson<int>(total),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PrintOrder copyWith({
    int? id,
    String? customerName,
    Value<String?> customerPhone = const Value.absent(),
    String? serviceType,
    int? pages,
    int? copies,
    String? paperSize,
    int? total,
    String? status,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => PrintOrder(
    id: id ?? this.id,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    serviceType: serviceType ?? this.serviceType,
    pages: pages ?? this.pages,
    copies: copies ?? this.copies,
    paperSize: paperSize ?? this.paperSize,
    total: total ?? this.total,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  PrintOrder copyWithCompanion(PrintOrdersCompanion data) {
    return PrintOrder(
      id: data.id.present ? data.id.value : this.id,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      serviceType: data.serviceType.present
          ? data.serviceType.value
          : this.serviceType,
      pages: data.pages.present ? data.pages.value : this.pages,
      copies: data.copies.present ? data.copies.value : this.copies,
      paperSize: data.paperSize.present ? data.paperSize.value : this.paperSize,
      total: data.total.present ? data.total.value : this.total,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrintOrder(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('serviceType: $serviceType, ')
          ..write('pages: $pages, ')
          ..write('copies: $copies, ')
          ..write('paperSize: $paperSize, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerName,
    customerPhone,
    serviceType,
    pages,
    copies,
    paperSize,
    total,
    status,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrintOrder &&
          other.id == this.id &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.serviceType == this.serviceType &&
          other.pages == this.pages &&
          other.copies == this.copies &&
          other.paperSize == this.paperSize &&
          other.total == this.total &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class PrintOrdersCompanion extends UpdateCompanion<PrintOrder> {
  final Value<int> id;
  final Value<String> customerName;
  final Value<String?> customerPhone;
  final Value<String> serviceType;
  final Value<int> pages;
  final Value<int> copies;
  final Value<String> paperSize;
  final Value<int> total;
  final Value<String> status;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const PrintOrdersCompanion({
    this.id = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.pages = const Value.absent(),
    this.copies = const Value.absent(),
    this.paperSize = const Value.absent(),
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PrintOrdersCompanion.insert({
    this.id = const Value.absent(),
    required String customerName,
    this.customerPhone = const Value.absent(),
    required String serviceType,
    this.pages = const Value.absent(),
    this.copies = const Value.absent(),
    this.paperSize = const Value.absent(),
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : customerName = Value(customerName),
       serviceType = Value(serviceType);
  static Insertable<PrintOrder> custom({
    Expression<int>? id,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<String>? serviceType,
    Expression<int>? pages,
    Expression<int>? copies,
    Expression<String>? paperSize,
    Expression<int>? total,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (serviceType != null) 'service_type': serviceType,
      if (pages != null) 'pages': pages,
      if (copies != null) 'copies': copies,
      if (paperSize != null) 'paper_size': paperSize,
      if (total != null) 'total': total,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PrintOrdersCompanion copyWith({
    Value<int>? id,
    Value<String>? customerName,
    Value<String?>? customerPhone,
    Value<String>? serviceType,
    Value<int>? pages,
    Value<int>? copies,
    Value<String>? paperSize,
    Value<int>? total,
    Value<String>? status,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return PrintOrdersCompanion(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      serviceType: serviceType ?? this.serviceType,
      pages: pages ?? this.pages,
      copies: copies ?? this.copies,
      paperSize: paperSize ?? this.paperSize,
      total: total ?? this.total,
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
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (serviceType.present) {
      map['service_type'] = Variable<String>(serviceType.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (copies.present) {
      map['copies'] = Variable<int>(copies.value);
    }
    if (paperSize.present) {
      map['paper_size'] = Variable<String>(paperSize.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
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
    return (StringBuffer('PrintOrdersCompanion(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('serviceType: $serviceType, ')
          ..write('pages: $pages, ')
          ..write('copies: $copies, ')
          ..write('paperSize: $paperSize, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OpenTabsTable extends OpenTabs with TableInfo<$OpenTabsTable, OpenTab> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpenTabsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tableIdMeta = const VerificationMeta(
    'tableId',
  );
  @override
  late final GeneratedColumn<int> tableId = GeneratedColumn<int>(
    'table_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderTypeMeta = const VerificationMeta(
    'orderType',
  );
  @override
  late final GeneratedColumn<String> orderType = GeneratedColumn<String>(
    'order_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Dine In'),
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<int> discount = GeneratedColumn<int>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Open'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tableId,
    orderType,
    itemsJson,
    total,
    discount,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'open_tabs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpenTab> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_id')) {
      context.handle(
        _tableIdMeta,
        tableId.isAcceptableOrUnknown(data['table_id']!, _tableIdMeta),
      );
    }
    if (data.containsKey('order_type')) {
      context.handle(
        _orderTypeMeta,
        orderType.isAcceptableOrUnknown(data['order_type']!, _orderTypeMeta),
      );
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OpenTab map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpenTab(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tableId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}table_id'],
      ),
      orderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_type'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OpenTabsTable createAlias(String alias) {
    return $OpenTabsTable(attachedDatabase, alias);
  }
}

class OpenTab extends DataClass implements Insertable<OpenTab> {
  final int id;
  final int? tableId;
  final String orderType;
  final String itemsJson;
  final int total;
  final int discount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OpenTab({
    required this.id,
    this.tableId,
    required this.orderType,
    required this.itemsJson,
    required this.total,
    required this.discount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || tableId != null) {
      map['table_id'] = Variable<int>(tableId);
    }
    map['order_type'] = Variable<String>(orderType);
    map['items_json'] = Variable<String>(itemsJson);
    map['total'] = Variable<int>(total);
    map['discount'] = Variable<int>(discount);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OpenTabsCompanion toCompanion(bool nullToAbsent) {
    return OpenTabsCompanion(
      id: Value(id),
      tableId: tableId == null && nullToAbsent
          ? const Value.absent()
          : Value(tableId),
      orderType: Value(orderType),
      itemsJson: Value(itemsJson),
      total: Value(total),
      discount: Value(discount),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OpenTab.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpenTab(
      id: serializer.fromJson<int>(json['id']),
      tableId: serializer.fromJson<int?>(json['tableId']),
      orderType: serializer.fromJson<String>(json['orderType']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      total: serializer.fromJson<int>(json['total']),
      discount: serializer.fromJson<int>(json['discount']),
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
      'tableId': serializer.toJson<int?>(tableId),
      'orderType': serializer.toJson<String>(orderType),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'total': serializer.toJson<int>(total),
      'discount': serializer.toJson<int>(discount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OpenTab copyWith({
    int? id,
    Value<int?> tableId = const Value.absent(),
    String? orderType,
    String? itemsJson,
    int? total,
    int? discount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OpenTab(
    id: id ?? this.id,
    tableId: tableId.present ? tableId.value : this.tableId,
    orderType: orderType ?? this.orderType,
    itemsJson: itemsJson ?? this.itemsJson,
    total: total ?? this.total,
    discount: discount ?? this.discount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OpenTab copyWithCompanion(OpenTabsCompanion data) {
    return OpenTab(
      id: data.id.present ? data.id.value : this.id,
      tableId: data.tableId.present ? data.tableId.value : this.tableId,
      orderType: data.orderType.present ? data.orderType.value : this.orderType,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      total: data.total.present ? data.total.value : this.total,
      discount: data.discount.present ? data.discount.value : this.discount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpenTab(')
          ..write('id: $id, ')
          ..write('tableId: $tableId, ')
          ..write('orderType: $orderType, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('total: $total, ')
          ..write('discount: $discount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tableId,
    orderType,
    itemsJson,
    total,
    discount,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpenTab &&
          other.id == this.id &&
          other.tableId == this.tableId &&
          other.orderType == this.orderType &&
          other.itemsJson == this.itemsJson &&
          other.total == this.total &&
          other.discount == this.discount &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OpenTabsCompanion extends UpdateCompanion<OpenTab> {
  final Value<int> id;
  final Value<int?> tableId;
  final Value<String> orderType;
  final Value<String> itemsJson;
  final Value<int> total;
  final Value<int> discount;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const OpenTabsCompanion({
    this.id = const Value.absent(),
    this.tableId = const Value.absent(),
    this.orderType = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.total = const Value.absent(),
    this.discount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OpenTabsCompanion.insert({
    this.id = const Value.absent(),
    this.tableId = const Value.absent(),
    this.orderType = const Value.absent(),
    required String itemsJson,
    this.total = const Value.absent(),
    this.discount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : itemsJson = Value(itemsJson);
  static Insertable<OpenTab> custom({
    Expression<int>? id,
    Expression<int>? tableId,
    Expression<String>? orderType,
    Expression<String>? itemsJson,
    Expression<int>? total,
    Expression<int>? discount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableId != null) 'table_id': tableId,
      if (orderType != null) 'order_type': orderType,
      if (itemsJson != null) 'items_json': itemsJson,
      if (total != null) 'total': total,
      if (discount != null) 'discount': discount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OpenTabsCompanion copyWith({
    Value<int>? id,
    Value<int?>? tableId,
    Value<String>? orderType,
    Value<String>? itemsJson,
    Value<int>? total,
    Value<int>? discount,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return OpenTabsCompanion(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      orderType: orderType ?? this.orderType,
      itemsJson: itemsJson ?? this.itemsJson,
      total: total ?? this.total,
      discount: discount ?? this.discount,
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
    if (tableId.present) {
      map['table_id'] = Variable<int>(tableId.value);
    }
    if (orderType.present) {
      map['order_type'] = Variable<String>(orderType.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (discount.present) {
      map['discount'] = Variable<int>(discount.value);
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
    return (StringBuffer('OpenTabsCompanion(')
          ..write('id: $id, ')
          ..write('tableId: $tableId, ')
          ..write('orderType: $orderType, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('total: $total, ')
          ..write('discount: $discount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $StockMovementsTable stockMovements = $StockMovementsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $PromosTable promos = $PromosTable(this);
  late final $EmployeesTable employees = $EmployeesTable(this);
  late final $AttendanceTable attendance = $AttendanceTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $ExpenseCategoriesTable expenseCategories =
      $ExpenseCategoriesTable(this);
  late final $RecurringExpensesTable recurringExpenses =
      $RecurringExpensesTable(this);
  late final $PayrollTable payroll = $PayrollTable(this);
  late final $WasteTable waste = $WasteTable(this);
  late final $LiquidityTable liquidity = $LiquidityTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $BranchesTable branches = $BranchesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ActivationsLocalTable activationsLocal = $ActivationsLocalTable(
    this,
  );
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $CashierSessionsTable cashierSessions = $CashierSessionsTable(
    this,
  );
  late final $OnlineOrdersTable onlineOrders = $OnlineOrdersTable(this);
  late final $CustomerDebtsTable customerDebts = $CustomerDebtsTable(this);
  late final $DebtPaymentsTable debtPayments = $DebtPaymentsTable(this);
  late final $StockCountsTable stockCounts = $StockCountsTable(this);
  late final $StockCountItemsTable stockCountItems = $StockCountItemsTable(
    this,
  );
  late final $ChatSessionsTable chatSessions = $ChatSessionsTable(this);
  late final $DiningTablesTable diningTables = $DiningTablesTable(this);
  late final $LaundryOrdersTable laundryOrders = $LaundryOrdersTable(this);
  late final $ServiceTicketsTable serviceTickets = $ServiceTicketsTable(this);
  late final $AppointmentsTable appointments = $AppointmentsTable(this);
  late final $PrescriptionsTable prescriptions = $PrescriptionsTable(this);
  late final $PrintOrdersTable printOrders = $PrintOrdersTable(this);
  late final $OpenTabsTable openTabs = $OpenTabsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    products,
    stockMovements,
    transactions,
    customers,
    promos,
    employees,
    attendance,
    expenses,
    expenseCategories,
    recurringExpenses,
    payroll,
    waste,
    liquidity,
    suppliers,
    branches,
    settings,
    activationsLocal,
    syncQueue,
    cashierSessions,
    onlineOrders,
    customerDebts,
    debtPayments,
    stockCounts,
    stockCountItems,
    chatSessions,
    diningTables,
    laundryOrders,
    serviceTickets,
    appointments,
    prescriptions,
    printOrders,
    openTabs,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({Value<int> id, required String name});
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({Value<int> id, Value<String> name});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => CategoriesCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  CategoriesCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> sku,
      Value<String?> barcode,
      Value<String> category,
      Value<int> buyPrice,
      required int sellPrice,
      Value<int> stock,
      Value<int> minStock,
      Value<String?> imagePath,
      Value<bool> isOnline,
      Value<DateTime?> expiryDate,
      Value<String?> productType,
      Value<String?> variantsJson,
      Value<String?> wholesaleJson,
      Value<String> priceType,
      Value<DateTime> createdAt,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> sku,
      Value<String?> barcode,
      Value<String> category,
      Value<int> buyPrice,
      Value<int> sellPrice,
      Value<int> stock,
      Value<int> minStock,
      Value<String?> imagePath,
      Value<bool> isOnline,
      Value<DateTime?> expiryDate,
      Value<String?> productType,
      Value<String?> variantsJson,
      Value<String?> wholesaleJson,
      Value<String> priceType,
      Value<DateTime> createdAt,
    });

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get buyPrice => $composableBuilder(
    column: $table.buyPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minStock => $composableBuilder(
    column: $table.minStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productType => $composableBuilder(
    column: $table.productType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantsJson => $composableBuilder(
    column: $table.variantsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wholesaleJson => $composableBuilder(
    column: $table.wholesaleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priceType => $composableBuilder(
    column: $table.priceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get buyPrice => $composableBuilder(
    column: $table.buyPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minStock => $composableBuilder(
    column: $table.minStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productType => $composableBuilder(
    column: $table.productType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantsJson => $composableBuilder(
    column: $table.variantsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wholesaleJson => $composableBuilder(
    column: $table.wholesaleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priceType => $composableBuilder(
    column: $table.priceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get buyPrice =>
      $composableBuilder(column: $table.buyPrice, builder: (column) => column);

  GeneratedColumn<int> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<int> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => column);

  GeneratedColumn<int> get minStock =>
      $composableBuilder(column: $table.minStock, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<bool> get isOnline =>
      $composableBuilder(column: $table.isOnline, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productType => $composableBuilder(
    column: $table.productType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variantsJson => $composableBuilder(
    column: $table.variantsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wholesaleJson => $composableBuilder(
    column: $table.wholesaleJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priceType =>
      $composableBuilder(column: $table.priceType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> buyPrice = const Value.absent(),
                Value<int> sellPrice = const Value.absent(),
                Value<int> stock = const Value.absent(),
                Value<int> minStock = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<String?> productType = const Value.absent(),
                Value<String?> variantsJson = const Value.absent(),
                Value<String?> wholesaleJson = const Value.absent(),
                Value<String> priceType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                name: name,
                sku: sku,
                barcode: barcode,
                category: category,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                stock: stock,
                minStock: minStock,
                imagePath: imagePath,
                isOnline: isOnline,
                expiryDate: expiryDate,
                productType: productType,
                variantsJson: variantsJson,
                wholesaleJson: wholesaleJson,
                priceType: priceType,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> sku = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> buyPrice = const Value.absent(),
                required int sellPrice,
                Value<int> stock = const Value.absent(),
                Value<int> minStock = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<String?> productType = const Value.absent(),
                Value<String?> variantsJson = const Value.absent(),
                Value<String?> wholesaleJson = const Value.absent(),
                Value<String> priceType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                name: name,
                sku: sku,
                barcode: barcode,
                category: category,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                stock: stock,
                minStock: minStock,
                imagePath: imagePath,
                isOnline: isOnline,
                expiryDate: expiryDate,
                productType: productType,
                variantsJson: variantsJson,
                wholesaleJson: wholesaleJson,
                priceType: priceType,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;
typedef $$StockMovementsTableCreateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<int> id,
      required int productId,
      required String type,
      required int qty,
      Value<String?> note,
      Value<DateTime> date,
    });
typedef $$StockMovementsTableUpdateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<int> id,
      Value<int> productId,
      Value<String> type,
      Value<int> qty,
      Value<String?> note,
      Value<DateTime> date,
    });

class $$StockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$StockMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockMovementsTable,
          StockMovement,
          $$StockMovementsTableFilterComposer,
          $$StockMovementsTableOrderingComposer,
          $$StockMovementsTableAnnotationComposer,
          $$StockMovementsTableCreateCompanionBuilder,
          $$StockMovementsTableUpdateCompanionBuilder,
          (
            StockMovement,
            BaseReferences<_$AppDatabase, $StockMovementsTable, StockMovement>,
          ),
          StockMovement,
          PrefetchHooks Function()
        > {
  $$StockMovementsTableTableManager(
    _$AppDatabase db,
    $StockMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => StockMovementsCompanion(
                id: id,
                productId: productId,
                type: type,
                qty: qty,
                note: note,
                date: date,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int productId,
                required String type,
                required int qty,
                Value<String?> note = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => StockMovementsCompanion.insert(
                id: id,
                productId: productId,
                type: type,
                qty: qty,
                note: note,
                date: date,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockMovementsTable,
      StockMovement,
      $$StockMovementsTableFilterComposer,
      $$StockMovementsTableOrderingComposer,
      $$StockMovementsTableAnnotationComposer,
      $$StockMovementsTableCreateCompanionBuilder,
      $$StockMovementsTableUpdateCompanionBuilder,
      (
        StockMovement,
        BaseReferences<_$AppDatabase, $StockMovementsTable, StockMovement>,
      ),
      StockMovement,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required String invoice,
      Value<DateTime> date,
      required String items,
      Value<int> total,
      Value<int> discount,
      Value<String> paymentMethod,
      Value<int?> customerId,
      Value<int?> cashGiven,
      Value<int?> cashReturn,
      Value<String?> cashierName,
      Value<int?> branchId,
      Value<String> status,
      Value<String?> voidReason,
      Value<DateTime?> voidedAt,
      Value<String?> orderType,
      Value<int?> tableId,
      Value<String?> notes,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<String> invoice,
      Value<DateTime> date,
      Value<String> items,
      Value<int> total,
      Value<int> discount,
      Value<String> paymentMethod,
      Value<int?> customerId,
      Value<int?> cashGiven,
      Value<int?> cashReturn,
      Value<String?> cashierName,
      Value<int?> branchId,
      Value<String> status,
      Value<String?> voidReason,
      Value<DateTime?> voidedAt,
      Value<String?> orderType,
      Value<int?> tableId,
      Value<String?> notes,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoice => $composableBuilder(
    column: $table.invoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cashGiven => $composableBuilder(
    column: $table.cashGiven,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cashReturn => $composableBuilder(
    column: $table.cashReturn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashierName => $composableBuilder(
    column: $table.cashierName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tableId => $composableBuilder(
    column: $table.tableId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoice => $composableBuilder(
    column: $table.invoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cashGiven => $composableBuilder(
    column: $table.cashGiven,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cashReturn => $composableBuilder(
    column: $table.cashReturn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashierName => $composableBuilder(
    column: $table.cashierName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tableId => $composableBuilder(
    column: $table.tableId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get invoice =>
      $composableBuilder(column: $table.invoice, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cashGiven =>
      $composableBuilder(column: $table.cashGiven, builder: (column) => column);

  GeneratedColumn<int> get cashReturn => $composableBuilder(
    column: $table.cashReturn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cashierName => $composableBuilder(
    column: $table.cashierName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<String> get orderType =>
      $composableBuilder(column: $table.orderType, builder: (column) => column);

  GeneratedColumn<int> get tableId =>
      $composableBuilder(column: $table.tableId, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            Transaction,
            BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
          ),
          Transaction,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> invoice = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<int?> customerId = const Value.absent(),
                Value<int?> cashGiven = const Value.absent(),
                Value<int?> cashReturn = const Value.absent(),
                Value<String?> cashierName = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<DateTime?> voidedAt = const Value.absent(),
                Value<String?> orderType = const Value.absent(),
                Value<int?> tableId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                invoice: invoice,
                date: date,
                items: items,
                total: total,
                discount: discount,
                paymentMethod: paymentMethod,
                customerId: customerId,
                cashGiven: cashGiven,
                cashReturn: cashReturn,
                cashierName: cashierName,
                branchId: branchId,
                status: status,
                voidReason: voidReason,
                voidedAt: voidedAt,
                orderType: orderType,
                tableId: tableId,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String invoice,
                Value<DateTime> date = const Value.absent(),
                required String items,
                Value<int> total = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<int?> customerId = const Value.absent(),
                Value<int?> cashGiven = const Value.absent(),
                Value<int?> cashReturn = const Value.absent(),
                Value<String?> cashierName = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<DateTime?> voidedAt = const Value.absent(),
                Value<String?> orderType = const Value.absent(),
                Value<int?> tableId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                invoice: invoice,
                date: date,
                items: items,
                total: total,
                discount: discount,
                paymentMethod: paymentMethod,
                customerId: customerId,
                cashGiven: cashGiven,
                cashReturn: cashReturn,
                cashierName: cashierName,
                branchId: branchId,
                status: status,
                voidReason: voidReason,
                voidedAt: voidedAt,
                orderType: orderType,
                tableId: tableId,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        Transaction,
        BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
      ),
      Transaction,
      PrefetchHooks Function()
    >;
typedef $$CustomersTableCreateCompanionBuilder =
    CustomersCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> phone,
      Value<String?> address,
      Value<int> points,
      Value<int> totalSpent,
      Value<String> level,
      Value<DateTime> createdAt,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> address,
      Value<int> points,
      Value<int> totalSpent,
      Value<String> level,
      Value<DateTime> createdAt,
    });

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<int> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
          Customer,
          PrefetchHooks Function()
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<int> totalSpent = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                address: address,
                points: points,
                totalSpent: totalSpent,
                level: level,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<int> totalSpent = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                address: address,
                points: points,
                totalSpent: totalSpent,
                level: level,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
      Customer,
      PrefetchHooks Function()
    >;
typedef $$PromosTableCreateCompanionBuilder =
    PromosCompanion Function({
      Value<int> id,
      required String name,
      required String code,
      required String type,
      required int value,
      Value<int> minBelanja,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<int?> maxUses,
      Value<int> usedCount,
      Value<String> status,
    });
typedef $$PromosTableUpdateCompanionBuilder =
    PromosCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> code,
      Value<String> type,
      Value<int> value,
      Value<int> minBelanja,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<int?> maxUses,
      Value<int> usedCount,
      Value<String> status,
    });

class $$PromosTableFilterComposer
    extends Composer<_$AppDatabase, $PromosTable> {
  $$PromosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minBelanja => $composableBuilder(
    column: $table.minBelanja,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxUses => $composableBuilder(
    column: $table.maxUses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedCount => $composableBuilder(
    column: $table.usedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PromosTableOrderingComposer
    extends Composer<_$AppDatabase, $PromosTable> {
  $$PromosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minBelanja => $composableBuilder(
    column: $table.minBelanja,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxUses => $composableBuilder(
    column: $table.maxUses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedCount => $composableBuilder(
    column: $table.usedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PromosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PromosTable> {
  $$PromosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get minBelanja => $composableBuilder(
    column: $table.minBelanja,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get maxUses =>
      $composableBuilder(column: $table.maxUses, builder: (column) => column);

  GeneratedColumn<int> get usedCount =>
      $composableBuilder(column: $table.usedCount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$PromosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PromosTable,
          Promo,
          $$PromosTableFilterComposer,
          $$PromosTableOrderingComposer,
          $$PromosTableAnnotationComposer,
          $$PromosTableCreateCompanionBuilder,
          $$PromosTableUpdateCompanionBuilder,
          (Promo, BaseReferences<_$AppDatabase, $PromosTable, Promo>),
          Promo,
          PrefetchHooks Function()
        > {
  $$PromosTableTableManager(_$AppDatabase db, $PromosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PromosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PromosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PromosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> minBelanja = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int?> maxUses = const Value.absent(),
                Value<int> usedCount = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => PromosCompanion(
                id: id,
                name: name,
                code: code,
                type: type,
                value: value,
                minBelanja: minBelanja,
                startDate: startDate,
                endDate: endDate,
                maxUses: maxUses,
                usedCount: usedCount,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String code,
                required String type,
                required int value,
                Value<int> minBelanja = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int?> maxUses = const Value.absent(),
                Value<int> usedCount = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => PromosCompanion.insert(
                id: id,
                name: name,
                code: code,
                type: type,
                value: value,
                minBelanja: minBelanja,
                startDate: startDate,
                endDate: endDate,
                maxUses: maxUses,
                usedCount: usedCount,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PromosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PromosTable,
      Promo,
      $$PromosTableFilterComposer,
      $$PromosTableOrderingComposer,
      $$PromosTableAnnotationComposer,
      $$PromosTableCreateCompanionBuilder,
      $$PromosTableUpdateCompanionBuilder,
      (Promo, BaseReferences<_$AppDatabase, $PromosTable, Promo>),
      Promo,
      PrefetchHooks Function()
    >;
typedef $$EmployeesTableCreateCompanionBuilder =
    EmployeesCompanion Function({
      Value<int> id,
      required String name,
      required String pin,
      required String role,
      Value<int?> branchId,
      Value<String?> status,
      Value<String?> phone,
      Value<String?> photoPath,
      Value<int?> baseSalary,
      Value<DateTime?> startDate,
      Value<String?> nfcTag,
      Value<String?> workStart,
      Value<String?> workEnd,
      Value<bool> requiresAttendance,
      Value<bool> requiresCashOpen,
      Value<bool> requiresCashClose,
      Value<DateTime> createdAt,
    });
typedef $$EmployeesTableUpdateCompanionBuilder =
    EmployeesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> pin,
      Value<String> role,
      Value<int?> branchId,
      Value<String?> status,
      Value<String?> phone,
      Value<String?> photoPath,
      Value<int?> baseSalary,
      Value<DateTime?> startDate,
      Value<String?> nfcTag,
      Value<String?> workStart,
      Value<String?> workEnd,
      Value<bool> requiresAttendance,
      Value<bool> requiresCashOpen,
      Value<bool> requiresCashClose,
      Value<DateTime> createdAt,
    });

class $$EmployeesTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pin => $composableBuilder(
    column: $table.pin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseSalary => $composableBuilder(
    column: $table.baseSalary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nfcTag => $composableBuilder(
    column: $table.nfcTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workStart => $composableBuilder(
    column: $table.workStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workEnd => $composableBuilder(
    column: $table.workEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresAttendance => $composableBuilder(
    column: $table.requiresAttendance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresCashOpen => $composableBuilder(
    column: $table.requiresCashOpen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresCashClose => $composableBuilder(
    column: $table.requiresCashClose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmployeesTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pin => $composableBuilder(
    column: $table.pin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseSalary => $composableBuilder(
    column: $table.baseSalary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nfcTag => $composableBuilder(
    column: $table.nfcTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workStart => $composableBuilder(
    column: $table.workStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workEnd => $composableBuilder(
    column: $table.workEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresAttendance => $composableBuilder(
    column: $table.requiresAttendance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresCashOpen => $composableBuilder(
    column: $table.requiresCashOpen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresCashClose => $composableBuilder(
    column: $table.requiresCashClose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pin =>
      $composableBuilder(column: $table.pin, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<int> get baseSalary => $composableBuilder(
    column: $table.baseSalary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get nfcTag =>
      $composableBuilder(column: $table.nfcTag, builder: (column) => column);

  GeneratedColumn<String> get workStart =>
      $composableBuilder(column: $table.workStart, builder: (column) => column);

  GeneratedColumn<String> get workEnd =>
      $composableBuilder(column: $table.workEnd, builder: (column) => column);

  GeneratedColumn<bool> get requiresAttendance => $composableBuilder(
    column: $table.requiresAttendance,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresCashOpen => $composableBuilder(
    column: $table.requiresCashOpen,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresCashClose => $composableBuilder(
    column: $table.requiresCashClose,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EmployeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeesTable,
          Employee,
          $$EmployeesTableFilterComposer,
          $$EmployeesTableOrderingComposer,
          $$EmployeesTableAnnotationComposer,
          $$EmployeesTableCreateCompanionBuilder,
          $$EmployeesTableUpdateCompanionBuilder,
          (Employee, BaseReferences<_$AppDatabase, $EmployeesTable, Employee>),
          Employee,
          PrefetchHooks Function()
        > {
  $$EmployeesTableTableManager(_$AppDatabase db, $EmployeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> pin = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<int?> baseSalary = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<String?> nfcTag = const Value.absent(),
                Value<String?> workStart = const Value.absent(),
                Value<String?> workEnd = const Value.absent(),
                Value<bool> requiresAttendance = const Value.absent(),
                Value<bool> requiresCashOpen = const Value.absent(),
                Value<bool> requiresCashClose = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EmployeesCompanion(
                id: id,
                name: name,
                pin: pin,
                role: role,
                branchId: branchId,
                status: status,
                phone: phone,
                photoPath: photoPath,
                baseSalary: baseSalary,
                startDate: startDate,
                nfcTag: nfcTag,
                workStart: workStart,
                workEnd: workEnd,
                requiresAttendance: requiresAttendance,
                requiresCashOpen: requiresCashOpen,
                requiresCashClose: requiresCashClose,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String pin,
                required String role,
                Value<int?> branchId = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<int?> baseSalary = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<String?> nfcTag = const Value.absent(),
                Value<String?> workStart = const Value.absent(),
                Value<String?> workEnd = const Value.absent(),
                Value<bool> requiresAttendance = const Value.absent(),
                Value<bool> requiresCashOpen = const Value.absent(),
                Value<bool> requiresCashClose = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EmployeesCompanion.insert(
                id: id,
                name: name,
                pin: pin,
                role: role,
                branchId: branchId,
                status: status,
                phone: phone,
                photoPath: photoPath,
                baseSalary: baseSalary,
                startDate: startDate,
                nfcTag: nfcTag,
                workStart: workStart,
                workEnd: workEnd,
                requiresAttendance: requiresAttendance,
                requiresCashOpen: requiresCashOpen,
                requiresCashClose: requiresCashClose,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmployeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeesTable,
      Employee,
      $$EmployeesTableFilterComposer,
      $$EmployeesTableOrderingComposer,
      $$EmployeesTableAnnotationComposer,
      $$EmployeesTableCreateCompanionBuilder,
      $$EmployeesTableUpdateCompanionBuilder,
      (Employee, BaseReferences<_$AppDatabase, $EmployeesTable, Employee>),
      Employee,
      PrefetchHooks Function()
    >;
typedef $$AttendanceTableCreateCompanionBuilder =
    AttendanceCompanion Function({
      Value<int> id,
      required int employeeId,
      Value<DateTime> date,
      Value<String?> checkIn,
      Value<String?> checkOut,
      Value<int?> pettyCash,
      Value<int?> finalCash,
      Value<String?> status,
      Value<int?> expectedCash,
      Value<String?> shiftNotes,
    });
typedef $$AttendanceTableUpdateCompanionBuilder =
    AttendanceCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<DateTime> date,
      Value<String?> checkIn,
      Value<String?> checkOut,
      Value<int?> pettyCash,
      Value<int?> finalCash,
      Value<String?> status,
      Value<int?> expectedCash,
      Value<String?> shiftNotes,
    });

class $$AttendanceTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceTable> {
  $$AttendanceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkIn => $composableBuilder(
    column: $table.checkIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkOut => $composableBuilder(
    column: $table.checkOut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pettyCash => $composableBuilder(
    column: $table.pettyCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalCash => $composableBuilder(
    column: $table.finalCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shiftNotes => $composableBuilder(
    column: $table.shiftNotes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttendanceTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceTable> {
  $$AttendanceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkIn => $composableBuilder(
    column: $table.checkIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkOut => $composableBuilder(
    column: $table.checkOut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pettyCash => $composableBuilder(
    column: $table.pettyCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalCash => $composableBuilder(
    column: $table.finalCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shiftNotes => $composableBuilder(
    column: $table.shiftNotes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttendanceTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceTable> {
  $$AttendanceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get checkIn =>
      $composableBuilder(column: $table.checkIn, builder: (column) => column);

  GeneratedColumn<String> get checkOut =>
      $composableBuilder(column: $table.checkOut, builder: (column) => column);

  GeneratedColumn<int> get pettyCash =>
      $composableBuilder(column: $table.pettyCash, builder: (column) => column);

  GeneratedColumn<int> get finalCash =>
      $composableBuilder(column: $table.finalCash, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get expectedCash => $composableBuilder(
    column: $table.expectedCash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shiftNotes => $composableBuilder(
    column: $table.shiftNotes,
    builder: (column) => column,
  );
}

class $$AttendanceTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceTable,
          AttendanceData,
          $$AttendanceTableFilterComposer,
          $$AttendanceTableOrderingComposer,
          $$AttendanceTableAnnotationComposer,
          $$AttendanceTableCreateCompanionBuilder,
          $$AttendanceTableUpdateCompanionBuilder,
          (
            AttendanceData,
            BaseReferences<_$AppDatabase, $AttendanceTable, AttendanceData>,
          ),
          AttendanceData,
          PrefetchHooks Function()
        > {
  $$AttendanceTableTableManager(_$AppDatabase db, $AttendanceTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> checkIn = const Value.absent(),
                Value<String?> checkOut = const Value.absent(),
                Value<int?> pettyCash = const Value.absent(),
                Value<int?> finalCash = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> expectedCash = const Value.absent(),
                Value<String?> shiftNotes = const Value.absent(),
              }) => AttendanceCompanion(
                id: id,
                employeeId: employeeId,
                date: date,
                checkIn: checkIn,
                checkOut: checkOut,
                pettyCash: pettyCash,
                finalCash: finalCash,
                status: status,
                expectedCash: expectedCash,
                shiftNotes: shiftNotes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                Value<DateTime> date = const Value.absent(),
                Value<String?> checkIn = const Value.absent(),
                Value<String?> checkOut = const Value.absent(),
                Value<int?> pettyCash = const Value.absent(),
                Value<int?> finalCash = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> expectedCash = const Value.absent(),
                Value<String?> shiftNotes = const Value.absent(),
              }) => AttendanceCompanion.insert(
                id: id,
                employeeId: employeeId,
                date: date,
                checkIn: checkIn,
                checkOut: checkOut,
                pettyCash: pettyCash,
                finalCash: finalCash,
                status: status,
                expectedCash: expectedCash,
                shiftNotes: shiftNotes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttendanceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceTable,
      AttendanceData,
      $$AttendanceTableFilterComposer,
      $$AttendanceTableOrderingComposer,
      $$AttendanceTableAnnotationComposer,
      $$AttendanceTableCreateCompanionBuilder,
      $$AttendanceTableUpdateCompanionBuilder,
      (
        AttendanceData,
        BaseReferences<_$AppDatabase, $AttendanceTable, AttendanceData>,
      ),
      AttendanceData,
      PrefetchHooks Function()
    >;
typedef $$ExpensesTableCreateCompanionBuilder =
    ExpensesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      required String category,
      required String description,
      required int amount,
      Value<int?> branchId,
    });
typedef $$ExpensesTableUpdateCompanionBuilder =
    ExpensesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> category,
      Value<String> description,
      Value<int> amount,
      Value<int?> branchId,
    });

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpensesTable,
          Expense,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (Expense, BaseReferences<_$AppDatabase, $ExpensesTable, Expense>),
          Expense,
          PrefetchHooks Function()
        > {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                date: date,
                category: category,
                description: description,
                amount: amount,
                branchId: branchId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                required String category,
                required String description,
                required int amount,
                Value<int?> branchId = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                date: date,
                category: category,
                description: description,
                amount: amount,
                branchId: branchId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpensesTable,
      Expense,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (Expense, BaseReferences<_$AppDatabase, $ExpensesTable, Expense>),
      Expense,
      PrefetchHooks Function()
    >;
typedef $$ExpenseCategoriesTableCreateCompanionBuilder =
    ExpenseCategoriesCompanion Function({Value<int> id, required String name});
typedef $$ExpenseCategoriesTableUpdateCompanionBuilder =
    ExpenseCategoriesCompanion Function({Value<int> id, Value<String> name});

class $$ExpenseCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpenseCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$ExpenseCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpenseCategoriesTable,
          ExpenseCategory,
          $$ExpenseCategoriesTableFilterComposer,
          $$ExpenseCategoriesTableOrderingComposer,
          $$ExpenseCategoriesTableAnnotationComposer,
          $$ExpenseCategoriesTableCreateCompanionBuilder,
          $$ExpenseCategoriesTableUpdateCompanionBuilder,
          (
            ExpenseCategory,
            BaseReferences<
              _$AppDatabase,
              $ExpenseCategoriesTable,
              ExpenseCategory
            >,
          ),
          ExpenseCategory,
          PrefetchHooks Function()
        > {
  $$ExpenseCategoriesTableTableManager(
    _$AppDatabase db,
    $ExpenseCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => ExpenseCategoriesCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  ExpenseCategoriesCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpenseCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpenseCategoriesTable,
      ExpenseCategory,
      $$ExpenseCategoriesTableFilterComposer,
      $$ExpenseCategoriesTableOrderingComposer,
      $$ExpenseCategoriesTableAnnotationComposer,
      $$ExpenseCategoriesTableCreateCompanionBuilder,
      $$ExpenseCategoriesTableUpdateCompanionBuilder,
      (
        ExpenseCategory,
        BaseReferences<_$AppDatabase, $ExpenseCategoriesTable, ExpenseCategory>,
      ),
      ExpenseCategory,
      PrefetchHooks Function()
    >;
typedef $$RecurringExpensesTableCreateCompanionBuilder =
    RecurringExpensesCompanion Function({
      Value<int> id,
      required String category,
      required int amount,
      required String description,
      required String frequency,
      required DateTime nextDate,
      Value<bool> active,
    });
typedef $$RecurringExpensesTableUpdateCompanionBuilder =
    RecurringExpensesCompanion Function({
      Value<int> id,
      Value<String> category,
      Value<int> amount,
      Value<String> description,
      Value<String> frequency,
      Value<DateTime> nextDate,
      Value<bool> active,
    });

class $$RecurringExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringExpensesTable> {
  $$RecurringExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringExpensesTable> {
  $$RecurringExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringExpensesTable> {
  $$RecurringExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<DateTime> get nextDate =>
      $composableBuilder(column: $table.nextDate, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);
}

class $$RecurringExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringExpensesTable,
          RecurringExpense,
          $$RecurringExpensesTableFilterComposer,
          $$RecurringExpensesTableOrderingComposer,
          $$RecurringExpensesTableAnnotationComposer,
          $$RecurringExpensesTableCreateCompanionBuilder,
          $$RecurringExpensesTableUpdateCompanionBuilder,
          (
            RecurringExpense,
            BaseReferences<
              _$AppDatabase,
              $RecurringExpensesTable,
              RecurringExpense
            >,
          ),
          RecurringExpense,
          PrefetchHooks Function()
        > {
  $$RecurringExpensesTableTableManager(
    _$AppDatabase db,
    $RecurringExpensesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringExpensesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<DateTime> nextDate = const Value.absent(),
                Value<bool> active = const Value.absent(),
              }) => RecurringExpensesCompanion(
                id: id,
                category: category,
                amount: amount,
                description: description,
                frequency: frequency,
                nextDate: nextDate,
                active: active,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String category,
                required int amount,
                required String description,
                required String frequency,
                required DateTime nextDate,
                Value<bool> active = const Value.absent(),
              }) => RecurringExpensesCompanion.insert(
                id: id,
                category: category,
                amount: amount,
                description: description,
                frequency: frequency,
                nextDate: nextDate,
                active: active,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringExpensesTable,
      RecurringExpense,
      $$RecurringExpensesTableFilterComposer,
      $$RecurringExpensesTableOrderingComposer,
      $$RecurringExpensesTableAnnotationComposer,
      $$RecurringExpensesTableCreateCompanionBuilder,
      $$RecurringExpensesTableUpdateCompanionBuilder,
      (
        RecurringExpense,
        BaseReferences<
          _$AppDatabase,
          $RecurringExpensesTable,
          RecurringExpense
        >,
      ),
      RecurringExpense,
      PrefetchHooks Function()
    >;
typedef $$PayrollTableCreateCompanionBuilder =
    PayrollCompanion Function({
      Value<int> id,
      required int employeeId,
      required String period,
      required int salary,
      Value<int> bonus,
      Value<int> deduction,
      Value<String?> notes,
      Value<DateTime> date,
      Value<String> status,
    });
typedef $$PayrollTableUpdateCompanionBuilder =
    PayrollCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<String> period,
      Value<int> salary,
      Value<int> bonus,
      Value<int> deduction,
      Value<String?> notes,
      Value<DateTime> date,
      Value<String> status,
    });

class $$PayrollTableFilterComposer
    extends Composer<_$AppDatabase, $PayrollTable> {
  $$PayrollTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get salary => $composableBuilder(
    column: $table.salary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bonus => $composableBuilder(
    column: $table.bonus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deduction => $composableBuilder(
    column: $table.deduction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PayrollTableOrderingComposer
    extends Composer<_$AppDatabase, $PayrollTable> {
  $$PayrollTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get salary => $composableBuilder(
    column: $table.salary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bonus => $composableBuilder(
    column: $table.bonus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deduction => $composableBuilder(
    column: $table.deduction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PayrollTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayrollTable> {
  $$PayrollTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get salary =>
      $composableBuilder(column: $table.salary, builder: (column) => column);

  GeneratedColumn<int> get bonus =>
      $composableBuilder(column: $table.bonus, builder: (column) => column);

  GeneratedColumn<int> get deduction =>
      $composableBuilder(column: $table.deduction, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$PayrollTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayrollTable,
          PayrollData,
          $$PayrollTableFilterComposer,
          $$PayrollTableOrderingComposer,
          $$PayrollTableAnnotationComposer,
          $$PayrollTableCreateCompanionBuilder,
          $$PayrollTableUpdateCompanionBuilder,
          (
            PayrollData,
            BaseReferences<_$AppDatabase, $PayrollTable, PayrollData>,
          ),
          PayrollData,
          PrefetchHooks Function()
        > {
  $$PayrollTableTableManager(_$AppDatabase db, $PayrollTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayrollTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayrollTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayrollTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<String> period = const Value.absent(),
                Value<int> salary = const Value.absent(),
                Value<int> bonus = const Value.absent(),
                Value<int> deduction = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => PayrollCompanion(
                id: id,
                employeeId: employeeId,
                period: period,
                salary: salary,
                bonus: bonus,
                deduction: deduction,
                notes: notes,
                date: date,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required String period,
                required int salary,
                Value<int> bonus = const Value.absent(),
                Value<int> deduction = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => PayrollCompanion.insert(
                id: id,
                employeeId: employeeId,
                period: period,
                salary: salary,
                bonus: bonus,
                deduction: deduction,
                notes: notes,
                date: date,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PayrollTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayrollTable,
      PayrollData,
      $$PayrollTableFilterComposer,
      $$PayrollTableOrderingComposer,
      $$PayrollTableAnnotationComposer,
      $$PayrollTableCreateCompanionBuilder,
      $$PayrollTableUpdateCompanionBuilder,
      (PayrollData, BaseReferences<_$AppDatabase, $PayrollTable, PayrollData>),
      PayrollData,
      PrefetchHooks Function()
    >;
typedef $$WasteTableCreateCompanionBuilder =
    WasteCompanion Function({
      Value<int> id,
      required int productId,
      required int qty,
      Value<String?> reason,
      Value<String> type,
      Value<DateTime> date,
    });
typedef $$WasteTableUpdateCompanionBuilder =
    WasteCompanion Function({
      Value<int> id,
      Value<int> productId,
      Value<int> qty,
      Value<String?> reason,
      Value<String> type,
      Value<DateTime> date,
    });

class $$WasteTableFilterComposer extends Composer<_$AppDatabase, $WasteTable> {
  $$WasteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WasteTableOrderingComposer
    extends Composer<_$AppDatabase, $WasteTable> {
  $$WasteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WasteTableAnnotationComposer
    extends Composer<_$AppDatabase, $WasteTable> {
  $$WasteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$WasteTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WasteTable,
          WasteData,
          $$WasteTableFilterComposer,
          $$WasteTableOrderingComposer,
          $$WasteTableAnnotationComposer,
          $$WasteTableCreateCompanionBuilder,
          $$WasteTableUpdateCompanionBuilder,
          (WasteData, BaseReferences<_$AppDatabase, $WasteTable, WasteData>),
          WasteData,
          PrefetchHooks Function()
        > {
  $$WasteTableTableManager(_$AppDatabase db, $WasteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WasteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WasteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WasteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => WasteCompanion(
                id: id,
                productId: productId,
                qty: qty,
                reason: reason,
                type: type,
                date: date,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int productId,
                required int qty,
                Value<String?> reason = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => WasteCompanion.insert(
                id: id,
                productId: productId,
                qty: qty,
                reason: reason,
                type: type,
                date: date,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WasteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WasteTable,
      WasteData,
      $$WasteTableFilterComposer,
      $$WasteTableOrderingComposer,
      $$WasteTableAnnotationComposer,
      $$WasteTableCreateCompanionBuilder,
      $$WasteTableUpdateCompanionBuilder,
      (WasteData, BaseReferences<_$AppDatabase, $WasteTable, WasteData>),
      WasteData,
      PrefetchHooks Function()
    >;
typedef $$LiquidityTableCreateCompanionBuilder =
    LiquidityCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      required String type,
      required String category,
      required String description,
      required int amount,
      Value<String?> method,
      Value<int?> branchId,
    });
typedef $$LiquidityTableUpdateCompanionBuilder =
    LiquidityCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> type,
      Value<String> category,
      Value<String> description,
      Value<int> amount,
      Value<String?> method,
      Value<int?> branchId,
    });

class $$LiquidityTableFilterComposer
    extends Composer<_$AppDatabase, $LiquidityTable> {
  $$LiquidityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LiquidityTableOrderingComposer
    extends Composer<_$AppDatabase, $LiquidityTable> {
  $$LiquidityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LiquidityTableAnnotationComposer
    extends Composer<_$AppDatabase, $LiquidityTable> {
  $$LiquidityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);
}

class $$LiquidityTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LiquidityTable,
          LiquidityData,
          $$LiquidityTableFilterComposer,
          $$LiquidityTableOrderingComposer,
          $$LiquidityTableAnnotationComposer,
          $$LiquidityTableCreateCompanionBuilder,
          $$LiquidityTableUpdateCompanionBuilder,
          (
            LiquidityData,
            BaseReferences<_$AppDatabase, $LiquidityTable, LiquidityData>,
          ),
          LiquidityData,
          PrefetchHooks Function()
        > {
  $$LiquidityTableTableManager(_$AppDatabase db, $LiquidityTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LiquidityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LiquidityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LiquidityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> method = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
              }) => LiquidityCompanion(
                id: id,
                date: date,
                type: type,
                category: category,
                description: description,
                amount: amount,
                method: method,
                branchId: branchId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                required String type,
                required String category,
                required String description,
                required int amount,
                Value<String?> method = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
              }) => LiquidityCompanion.insert(
                id: id,
                date: date,
                type: type,
                category: category,
                description: description,
                amount: amount,
                method: method,
                branchId: branchId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LiquidityTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LiquidityTable,
      LiquidityData,
      $$LiquidityTableFilterComposer,
      $$LiquidityTableOrderingComposer,
      $$LiquidityTableAnnotationComposer,
      $$LiquidityTableCreateCompanionBuilder,
      $$LiquidityTableUpdateCompanionBuilder,
      (
        LiquidityData,
        BaseReferences<_$AppDatabase, $LiquidityTable, LiquidityData>,
      ),
      LiquidityData,
      PrefetchHooks Function()
    >;
typedef $$SuppliersTableCreateCompanionBuilder =
    SuppliersCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> phone,
      Value<String?> address,
      Value<String?> contactPerson,
      Value<String?> note,
      Value<DateTime> createdAt,
    });
typedef $$SuppliersTableUpdateCompanionBuilder =
    SuppliersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> address,
      Value<String?> contactPerson,
      Value<String?> note,
      Value<DateTime> createdAt,
    });

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuppliersTable,
          Supplier,
          $$SuppliersTableFilterComposer,
          $$SuppliersTableOrderingComposer,
          $$SuppliersTableAnnotationComposer,
          $$SuppliersTableCreateCompanionBuilder,
          $$SuppliersTableUpdateCompanionBuilder,
          (Supplier, BaseReferences<_$AppDatabase, $SuppliersTable, Supplier>),
          Supplier,
          PrefetchHooks Function()
        > {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> contactPerson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SuppliersCompanion(
                id: id,
                name: name,
                phone: phone,
                address: address,
                contactPerson: contactPerson,
                note: note,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> contactPerson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SuppliersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                address: address,
                contactPerson: contactPerson,
                note: note,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuppliersTable,
      Supplier,
      $$SuppliersTableFilterComposer,
      $$SuppliersTableOrderingComposer,
      $$SuppliersTableAnnotationComposer,
      $$SuppliersTableCreateCompanionBuilder,
      $$SuppliersTableUpdateCompanionBuilder,
      (Supplier, BaseReferences<_$AppDatabase, $SuppliersTable, Supplier>),
      Supplier,
      PrefetchHooks Function()
    >;
typedef $$BranchesTableCreateCompanionBuilder =
    BranchesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> address,
      Value<String?> phone,
      Value<String> status,
    });
typedef $$BranchesTableUpdateCompanionBuilder =
    BranchesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> address,
      Value<String?> phone,
      Value<String> status,
    });

class $$BranchesTableFilterComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BranchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BranchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BranchesTable> {
  $$BranchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$BranchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BranchesTable,
          Branche,
          $$BranchesTableFilterComposer,
          $$BranchesTableOrderingComposer,
          $$BranchesTableAnnotationComposer,
          $$BranchesTableCreateCompanionBuilder,
          $$BranchesTableUpdateCompanionBuilder,
          (Branche, BaseReferences<_$AppDatabase, $BranchesTable, Branche>),
          Branche,
          PrefetchHooks Function()
        > {
  $$BranchesTableTableManager(_$AppDatabase db, $BranchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BranchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BranchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BranchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => BranchesCompanion(
                id: id,
                name: name,
                address: address,
                phone: phone,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> address = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => BranchesCompanion.insert(
                id: id,
                name: name,
                address: address,
                phone: phone,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BranchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BranchesTable,
      Branche,
      $$BranchesTableFilterComposer,
      $$BranchesTableOrderingComposer,
      $$BranchesTableAnnotationComposer,
      $$BranchesTableCreateCompanionBuilder,
      $$BranchesTableUpdateCompanionBuilder,
      (Branche, BaseReferences<_$AppDatabase, $BranchesTable, Branche>),
      Branche,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> storeName,
      Value<String?> storeAddress,
      Value<String?> storePhone,
      Value<String?> posPrefix,
      Value<int> trxCounter,
      Value<int> minStockAlert,
      Value<String?> qrisString,
      Value<String?> themeMode,
      Value<int> posGridColumns,
      Value<String?> bankName,
      Value<String?> bankAccount,
      Value<String?> bankHolder,
      Value<String?> receiptFooter,
      Value<String?> storeLogoPath,
      Value<String?> waTemplates,
      Value<int> pointsPerRupiah,
      Value<int> silverThreshold,
      Value<int> goldThreshold,
      Value<int> platinumThreshold,
      Value<String?> qrisImagePath,
      Value<String?> receiptHeader,
      Value<String> receiptPaperSize,
      Value<int> pinLength,
      Value<bool> receiptShowLogo,
      Value<bool> receiptShowCashier,
      Value<bool> receiptShowInvoice,
      Value<bool> receiptShowDate,
      Value<bool> receiptShowBarcode,
      Value<String?> kitchenPrinterAddress,
      Value<bool> kitchenPrinterEnabled,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> storeName,
      Value<String?> storeAddress,
      Value<String?> storePhone,
      Value<String?> posPrefix,
      Value<int> trxCounter,
      Value<int> minStockAlert,
      Value<String?> qrisString,
      Value<String?> themeMode,
      Value<int> posGridColumns,
      Value<String?> bankName,
      Value<String?> bankAccount,
      Value<String?> bankHolder,
      Value<String?> receiptFooter,
      Value<String?> storeLogoPath,
      Value<String?> waTemplates,
      Value<int> pointsPerRupiah,
      Value<int> silverThreshold,
      Value<int> goldThreshold,
      Value<int> platinumThreshold,
      Value<String?> qrisImagePath,
      Value<String?> receiptHeader,
      Value<String> receiptPaperSize,
      Value<int> pinLength,
      Value<bool> receiptShowLogo,
      Value<bool> receiptShowCashier,
      Value<bool> receiptShowInvoice,
      Value<bool> receiptShowDate,
      Value<bool> receiptShowBarcode,
      Value<String?> kitchenPrinterAddress,
      Value<bool> kitchenPrinterEnabled,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeAddress => $composableBuilder(
    column: $table.storeAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storePhone => $composableBuilder(
    column: $table.storePhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posPrefix => $composableBuilder(
    column: $table.posPrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trxCounter => $composableBuilder(
    column: $table.trxCounter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minStockAlert => $composableBuilder(
    column: $table.minStockAlert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrisString => $composableBuilder(
    column: $table.qrisString,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get posGridColumns => $composableBuilder(
    column: $table.posGridColumns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankAccount => $composableBuilder(
    column: $table.bankAccount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankHolder => $composableBuilder(
    column: $table.bankHolder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeLogoPath => $composableBuilder(
    column: $table.storeLogoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waTemplates => $composableBuilder(
    column: $table.waTemplates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsPerRupiah => $composableBuilder(
    column: $table.pointsPerRupiah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get silverThreshold => $composableBuilder(
    column: $table.silverThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goldThreshold => $composableBuilder(
    column: $table.goldThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get platinumThreshold => $composableBuilder(
    column: $table.platinumThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrisImagePath => $composableBuilder(
    column: $table.qrisImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptHeader => $composableBuilder(
    column: $table.receiptHeader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptPaperSize => $composableBuilder(
    column: $table.receiptPaperSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinLength => $composableBuilder(
    column: $table.pinLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptShowLogo => $composableBuilder(
    column: $table.receiptShowLogo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptShowCashier => $composableBuilder(
    column: $table.receiptShowCashier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptShowInvoice => $composableBuilder(
    column: $table.receiptShowInvoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptShowDate => $composableBuilder(
    column: $table.receiptShowDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptShowBarcode => $composableBuilder(
    column: $table.receiptShowBarcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenPrinterAddress => $composableBuilder(
    column: $table.kitchenPrinterAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kitchenPrinterEnabled => $composableBuilder(
    column: $table.kitchenPrinterEnabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeAddress => $composableBuilder(
    column: $table.storeAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storePhone => $composableBuilder(
    column: $table.storePhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posPrefix => $composableBuilder(
    column: $table.posPrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trxCounter => $composableBuilder(
    column: $table.trxCounter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minStockAlert => $composableBuilder(
    column: $table.minStockAlert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrisString => $composableBuilder(
    column: $table.qrisString,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get posGridColumns => $composableBuilder(
    column: $table.posGridColumns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankAccount => $composableBuilder(
    column: $table.bankAccount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankHolder => $composableBuilder(
    column: $table.bankHolder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeLogoPath => $composableBuilder(
    column: $table.storeLogoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waTemplates => $composableBuilder(
    column: $table.waTemplates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsPerRupiah => $composableBuilder(
    column: $table.pointsPerRupiah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get silverThreshold => $composableBuilder(
    column: $table.silverThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goldThreshold => $composableBuilder(
    column: $table.goldThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get platinumThreshold => $composableBuilder(
    column: $table.platinumThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrisImagePath => $composableBuilder(
    column: $table.qrisImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptHeader => $composableBuilder(
    column: $table.receiptHeader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptPaperSize => $composableBuilder(
    column: $table.receiptPaperSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinLength => $composableBuilder(
    column: $table.pinLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptShowLogo => $composableBuilder(
    column: $table.receiptShowLogo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptShowCashier => $composableBuilder(
    column: $table.receiptShowCashier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptShowInvoice => $composableBuilder(
    column: $table.receiptShowInvoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptShowDate => $composableBuilder(
    column: $table.receiptShowDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptShowBarcode => $composableBuilder(
    column: $table.receiptShowBarcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenPrinterAddress => $composableBuilder(
    column: $table.kitchenPrinterAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kitchenPrinterEnabled => $composableBuilder(
    column: $table.kitchenPrinterEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeName =>
      $composableBuilder(column: $table.storeName, builder: (column) => column);

  GeneratedColumn<String> get storeAddress => $composableBuilder(
    column: $table.storeAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storePhone => $composableBuilder(
    column: $table.storePhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get posPrefix =>
      $composableBuilder(column: $table.posPrefix, builder: (column) => column);

  GeneratedColumn<int> get trxCounter => $composableBuilder(
    column: $table.trxCounter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minStockAlert => $composableBuilder(
    column: $table.minStockAlert,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qrisString => $composableBuilder(
    column: $table.qrisString,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<int> get posGridColumns => $composableBuilder(
    column: $table.posGridColumns,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get bankAccount => $composableBuilder(
    column: $table.bankAccount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankHolder => $composableBuilder(
    column: $table.bankHolder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeLogoPath => $composableBuilder(
    column: $table.storeLogoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get waTemplates => $composableBuilder(
    column: $table.waTemplates,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsPerRupiah => $composableBuilder(
    column: $table.pointsPerRupiah,
    builder: (column) => column,
  );

  GeneratedColumn<int> get silverThreshold => $composableBuilder(
    column: $table.silverThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goldThreshold => $composableBuilder(
    column: $table.goldThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<int> get platinumThreshold => $composableBuilder(
    column: $table.platinumThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qrisImagePath => $composableBuilder(
    column: $table.qrisImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptHeader => $composableBuilder(
    column: $table.receiptHeader,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptPaperSize => $composableBuilder(
    column: $table.receiptPaperSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pinLength =>
      $composableBuilder(column: $table.pinLength, builder: (column) => column);

  GeneratedColumn<bool> get receiptShowLogo => $composableBuilder(
    column: $table.receiptShowLogo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get receiptShowCashier => $composableBuilder(
    column: $table.receiptShowCashier,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get receiptShowInvoice => $composableBuilder(
    column: $table.receiptShowInvoice,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get receiptShowDate => $composableBuilder(
    column: $table.receiptShowDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get receiptShowBarcode => $composableBuilder(
    column: $table.receiptShowBarcode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kitchenPrinterAddress => $composableBuilder(
    column: $table.kitchenPrinterAddress,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get kitchenPrinterEnabled => $composableBuilder(
    column: $table.kitchenPrinterEnabled,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> storeName = const Value.absent(),
                Value<String?> storeAddress = const Value.absent(),
                Value<String?> storePhone = const Value.absent(),
                Value<String?> posPrefix = const Value.absent(),
                Value<int> trxCounter = const Value.absent(),
                Value<int> minStockAlert = const Value.absent(),
                Value<String?> qrisString = const Value.absent(),
                Value<String?> themeMode = const Value.absent(),
                Value<int> posGridColumns = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String?> bankAccount = const Value.absent(),
                Value<String?> bankHolder = const Value.absent(),
                Value<String?> receiptFooter = const Value.absent(),
                Value<String?> storeLogoPath = const Value.absent(),
                Value<String?> waTemplates = const Value.absent(),
                Value<int> pointsPerRupiah = const Value.absent(),
                Value<int> silverThreshold = const Value.absent(),
                Value<int> goldThreshold = const Value.absent(),
                Value<int> platinumThreshold = const Value.absent(),
                Value<String?> qrisImagePath = const Value.absent(),
                Value<String?> receiptHeader = const Value.absent(),
                Value<String> receiptPaperSize = const Value.absent(),
                Value<int> pinLength = const Value.absent(),
                Value<bool> receiptShowLogo = const Value.absent(),
                Value<bool> receiptShowCashier = const Value.absent(),
                Value<bool> receiptShowInvoice = const Value.absent(),
                Value<bool> receiptShowDate = const Value.absent(),
                Value<bool> receiptShowBarcode = const Value.absent(),
                Value<String?> kitchenPrinterAddress = const Value.absent(),
                Value<bool> kitchenPrinterEnabled = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                posPrefix: posPrefix,
                trxCounter: trxCounter,
                minStockAlert: minStockAlert,
                qrisString: qrisString,
                themeMode: themeMode,
                posGridColumns: posGridColumns,
                bankName: bankName,
                bankAccount: bankAccount,
                bankHolder: bankHolder,
                receiptFooter: receiptFooter,
                storeLogoPath: storeLogoPath,
                waTemplates: waTemplates,
                pointsPerRupiah: pointsPerRupiah,
                silverThreshold: silverThreshold,
                goldThreshold: goldThreshold,
                platinumThreshold: platinumThreshold,
                qrisImagePath: qrisImagePath,
                receiptHeader: receiptHeader,
                receiptPaperSize: receiptPaperSize,
                pinLength: pinLength,
                receiptShowLogo: receiptShowLogo,
                receiptShowCashier: receiptShowCashier,
                receiptShowInvoice: receiptShowInvoice,
                receiptShowDate: receiptShowDate,
                receiptShowBarcode: receiptShowBarcode,
                kitchenPrinterAddress: kitchenPrinterAddress,
                kitchenPrinterEnabled: kitchenPrinterEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> storeName = const Value.absent(),
                Value<String?> storeAddress = const Value.absent(),
                Value<String?> storePhone = const Value.absent(),
                Value<String?> posPrefix = const Value.absent(),
                Value<int> trxCounter = const Value.absent(),
                Value<int> minStockAlert = const Value.absent(),
                Value<String?> qrisString = const Value.absent(),
                Value<String?> themeMode = const Value.absent(),
                Value<int> posGridColumns = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String?> bankAccount = const Value.absent(),
                Value<String?> bankHolder = const Value.absent(),
                Value<String?> receiptFooter = const Value.absent(),
                Value<String?> storeLogoPath = const Value.absent(),
                Value<String?> waTemplates = const Value.absent(),
                Value<int> pointsPerRupiah = const Value.absent(),
                Value<int> silverThreshold = const Value.absent(),
                Value<int> goldThreshold = const Value.absent(),
                Value<int> platinumThreshold = const Value.absent(),
                Value<String?> qrisImagePath = const Value.absent(),
                Value<String?> receiptHeader = const Value.absent(),
                Value<String> receiptPaperSize = const Value.absent(),
                Value<int> pinLength = const Value.absent(),
                Value<bool> receiptShowLogo = const Value.absent(),
                Value<bool> receiptShowCashier = const Value.absent(),
                Value<bool> receiptShowInvoice = const Value.absent(),
                Value<bool> receiptShowDate = const Value.absent(),
                Value<bool> receiptShowBarcode = const Value.absent(),
                Value<String?> kitchenPrinterAddress = const Value.absent(),
                Value<bool> kitchenPrinterEnabled = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                posPrefix: posPrefix,
                trxCounter: trxCounter,
                minStockAlert: minStockAlert,
                qrisString: qrisString,
                themeMode: themeMode,
                posGridColumns: posGridColumns,
                bankName: bankName,
                bankAccount: bankAccount,
                bankHolder: bankHolder,
                receiptFooter: receiptFooter,
                storeLogoPath: storeLogoPath,
                waTemplates: waTemplates,
                pointsPerRupiah: pointsPerRupiah,
                silverThreshold: silverThreshold,
                goldThreshold: goldThreshold,
                platinumThreshold: platinumThreshold,
                qrisImagePath: qrisImagePath,
                receiptHeader: receiptHeader,
                receiptPaperSize: receiptPaperSize,
                pinLength: pinLength,
                receiptShowLogo: receiptShowLogo,
                receiptShowCashier: receiptShowCashier,
                receiptShowInvoice: receiptShowInvoice,
                receiptShowDate: receiptShowDate,
                receiptShowBarcode: receiptShowBarcode,
                kitchenPrinterAddress: kitchenPrinterAddress,
                kitchenPrinterEnabled: kitchenPrinterEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ActivationsLocalTableCreateCompanionBuilder =
    ActivationsLocalCompanion Function({
      Value<int> id,
      required String key,
      required String deviceId,
      Value<DateTime> activatedAt,
      Value<String> status,
    });
typedef $$ActivationsLocalTableUpdateCompanionBuilder =
    ActivationsLocalCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String> deviceId,
      Value<DateTime> activatedAt,
      Value<String> status,
    });

class $$ActivationsLocalTableFilterComposer
    extends Composer<_$AppDatabase, $ActivationsLocalTable> {
  $$ActivationsLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivationsLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivationsLocalTable> {
  $$ActivationsLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivationsLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivationsLocalTable> {
  $$ActivationsLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$ActivationsLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivationsLocalTable,
          ActivationsLocalData,
          $$ActivationsLocalTableFilterComposer,
          $$ActivationsLocalTableOrderingComposer,
          $$ActivationsLocalTableAnnotationComposer,
          $$ActivationsLocalTableCreateCompanionBuilder,
          $$ActivationsLocalTableUpdateCompanionBuilder,
          (
            ActivationsLocalData,
            BaseReferences<
              _$AppDatabase,
              $ActivationsLocalTable,
              ActivationsLocalData
            >,
          ),
          ActivationsLocalData,
          PrefetchHooks Function()
        > {
  $$ActivationsLocalTableTableManager(
    _$AppDatabase db,
    $ActivationsLocalTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivationsLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivationsLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivationsLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> activatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ActivationsLocalCompanion(
                id: id,
                key: key,
                deviceId: deviceId,
                activatedAt: activatedAt,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                required String deviceId,
                Value<DateTime> activatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ActivationsLocalCompanion.insert(
                id: id,
                key: key,
                deviceId: deviceId,
                activatedAt: activatedAt,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivationsLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivationsLocalTable,
      ActivationsLocalData,
      $$ActivationsLocalTableFilterComposer,
      $$ActivationsLocalTableOrderingComposer,
      $$ActivationsLocalTableAnnotationComposer,
      $$ActivationsLocalTableCreateCompanionBuilder,
      $$ActivationsLocalTableUpdateCompanionBuilder,
      (
        ActivationsLocalData,
        BaseReferences<
          _$AppDatabase,
          $ActivationsLocalTable,
          ActivationsLocalData
        >,
      ),
      ActivationsLocalData,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String taskType,
      required String payload,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> taskType,
      Value<String> payload,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                taskType: taskType,
                payload: payload,
                status: status,
                retryCount: retryCount,
                errorMessage: errorMessage,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String taskType,
                required String payload,
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                taskType: taskType,
                payload: payload,
                status: status,
                retryCount: retryCount,
                errorMessage: errorMessage,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$CashierSessionsTableCreateCompanionBuilder =
    CashierSessionsCompanion Function({
      Value<int> id,
      required int employeeId,
      Value<DateTime> openedAt,
      Value<DateTime?> closedAt,
      Value<int> startingCash,
      Value<int?> branchId,
    });
typedef $$CashierSessionsTableUpdateCompanionBuilder =
    CashierSessionsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<DateTime> openedAt,
      Value<DateTime?> closedAt,
      Value<int> startingCash,
      Value<int?> branchId,
    });

class $$CashierSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $CashierSessionsTable> {
  $$CashierSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingCash => $composableBuilder(
    column: $table.startingCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CashierSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CashierSessionsTable> {
  $$CashierSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingCash => $composableBuilder(
    column: $table.startingCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get branchId => $composableBuilder(
    column: $table.branchId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CashierSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CashierSessionsTable> {
  $$CashierSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get startingCash => $composableBuilder(
    column: $table.startingCash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);
}

class $$CashierSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CashierSessionsTable,
          CashierSession,
          $$CashierSessionsTableFilterComposer,
          $$CashierSessionsTableOrderingComposer,
          $$CashierSessionsTableAnnotationComposer,
          $$CashierSessionsTableCreateCompanionBuilder,
          $$CashierSessionsTableUpdateCompanionBuilder,
          (
            CashierSession,
            BaseReferences<
              _$AppDatabase,
              $CashierSessionsTable,
              CashierSession
            >,
          ),
          CashierSession,
          PrefetchHooks Function()
        > {
  $$CashierSessionsTableTableManager(
    _$AppDatabase db,
    $CashierSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CashierSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CashierSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CashierSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int> startingCash = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
              }) => CashierSessionsCompanion(
                id: id,
                employeeId: employeeId,
                openedAt: openedAt,
                closedAt: closedAt,
                startingCash: startingCash,
                branchId: branchId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                Value<DateTime> openedAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int> startingCash = const Value.absent(),
                Value<int?> branchId = const Value.absent(),
              }) => CashierSessionsCompanion.insert(
                id: id,
                employeeId: employeeId,
                openedAt: openedAt,
                closedAt: closedAt,
                startingCash: startingCash,
                branchId: branchId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CashierSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CashierSessionsTable,
      CashierSession,
      $$CashierSessionsTableFilterComposer,
      $$CashierSessionsTableOrderingComposer,
      $$CashierSessionsTableAnnotationComposer,
      $$CashierSessionsTableCreateCompanionBuilder,
      $$CashierSessionsTableUpdateCompanionBuilder,
      (
        CashierSession,
        BaseReferences<_$AppDatabase, $CashierSessionsTable, CashierSession>,
      ),
      CashierSession,
      PrefetchHooks Function()
    >;
typedef $$OnlineOrdersTableCreateCompanionBuilder =
    OnlineOrdersCompanion Function({
      Value<int> id,
      required String invoice,
      required String customerName,
      required String customerPhone,
      required String items,
      Value<int> subtotal,
      Value<int> discount,
      Value<int> handlingFee,
      required int total,
      Value<String> paymentMethod,
      Value<String?> pickupTime,
      Value<String> branch,
      Value<String?> notes,
      Value<String> status,
      Value<String?> processedBy,
      Value<DateTime> createdAt,
    });
typedef $$OnlineOrdersTableUpdateCompanionBuilder =
    OnlineOrdersCompanion Function({
      Value<int> id,
      Value<String> invoice,
      Value<String> customerName,
      Value<String> customerPhone,
      Value<String> items,
      Value<int> subtotal,
      Value<int> discount,
      Value<int> handlingFee,
      Value<int> total,
      Value<String> paymentMethod,
      Value<String?> pickupTime,
      Value<String> branch,
      Value<String?> notes,
      Value<String> status,
      Value<String?> processedBy,
      Value<DateTime> createdAt,
    });

class $$OnlineOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OnlineOrdersTable> {
  $$OnlineOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoice => $composableBuilder(
    column: $table.invoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get handlingFee => $composableBuilder(
    column: $table.handlingFee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pickupTime => $composableBuilder(
    column: $table.pickupTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processedBy => $composableBuilder(
    column: $table.processedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnlineOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OnlineOrdersTable> {
  $$OnlineOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoice => $composableBuilder(
    column: $table.invoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get handlingFee => $composableBuilder(
    column: $table.handlingFee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pickupTime => $composableBuilder(
    column: $table.pickupTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processedBy => $composableBuilder(
    column: $table.processedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnlineOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnlineOrdersTable> {
  $$OnlineOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get invoice =>
      $composableBuilder(column: $table.invoice, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<int> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<int> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<int> get handlingFee => $composableBuilder(
    column: $table.handlingFee,
    builder: (column) => column,
  );

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pickupTime => $composableBuilder(
    column: $table.pickupTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get processedBy => $composableBuilder(
    column: $table.processedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OnlineOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnlineOrdersTable,
          OnlineOrder,
          $$OnlineOrdersTableFilterComposer,
          $$OnlineOrdersTableOrderingComposer,
          $$OnlineOrdersTableAnnotationComposer,
          $$OnlineOrdersTableCreateCompanionBuilder,
          $$OnlineOrdersTableUpdateCompanionBuilder,
          (
            OnlineOrder,
            BaseReferences<_$AppDatabase, $OnlineOrdersTable, OnlineOrder>,
          ),
          OnlineOrder,
          PrefetchHooks Function()
        > {
  $$OnlineOrdersTableTableManager(_$AppDatabase db, $OnlineOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnlineOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnlineOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnlineOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> invoice = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<String> customerPhone = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<int> subtotal = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<int> handlingFee = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> pickupTime = const Value.absent(),
                Value<String> branch = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> processedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OnlineOrdersCompanion(
                id: id,
                invoice: invoice,
                customerName: customerName,
                customerPhone: customerPhone,
                items: items,
                subtotal: subtotal,
                discount: discount,
                handlingFee: handlingFee,
                total: total,
                paymentMethod: paymentMethod,
                pickupTime: pickupTime,
                branch: branch,
                notes: notes,
                status: status,
                processedBy: processedBy,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String invoice,
                required String customerName,
                required String customerPhone,
                required String items,
                Value<int> subtotal = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<int> handlingFee = const Value.absent(),
                required int total,
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> pickupTime = const Value.absent(),
                Value<String> branch = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> processedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OnlineOrdersCompanion.insert(
                id: id,
                invoice: invoice,
                customerName: customerName,
                customerPhone: customerPhone,
                items: items,
                subtotal: subtotal,
                discount: discount,
                handlingFee: handlingFee,
                total: total,
                paymentMethod: paymentMethod,
                pickupTime: pickupTime,
                branch: branch,
                notes: notes,
                status: status,
                processedBy: processedBy,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnlineOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnlineOrdersTable,
      OnlineOrder,
      $$OnlineOrdersTableFilterComposer,
      $$OnlineOrdersTableOrderingComposer,
      $$OnlineOrdersTableAnnotationComposer,
      $$OnlineOrdersTableCreateCompanionBuilder,
      $$OnlineOrdersTableUpdateCompanionBuilder,
      (
        OnlineOrder,
        BaseReferences<_$AppDatabase, $OnlineOrdersTable, OnlineOrder>,
      ),
      OnlineOrder,
      PrefetchHooks Function()
    >;
typedef $$CustomerDebtsTableCreateCompanionBuilder =
    CustomerDebtsCompanion Function({
      Value<int> id,
      required int customerId,
      required String customerName,
      required int amount,
      required int remainingAmount,
      Value<String?> description,
      Value<DateTime> debtDate,
      Value<DateTime?> dueDate,
      Value<String> status,
    });
typedef $$CustomerDebtsTableUpdateCompanionBuilder =
    CustomerDebtsCompanion Function({
      Value<int> id,
      Value<int> customerId,
      Value<String> customerName,
      Value<int> amount,
      Value<int> remainingAmount,
      Value<String?> description,
      Value<DateTime> debtDate,
      Value<DateTime?> dueDate,
      Value<String> status,
    });

class $$CustomerDebtsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomerDebtsTable> {
  $$CustomerDebtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingAmount => $composableBuilder(
    column: $table.remainingAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get debtDate => $composableBuilder(
    column: $table.debtDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomerDebtsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomerDebtsTable> {
  $$CustomerDebtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingAmount => $composableBuilder(
    column: $table.remainingAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get debtDate => $composableBuilder(
    column: $table.debtDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomerDebtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomerDebtsTable> {
  $$CustomerDebtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get remainingAmount => $composableBuilder(
    column: $table.remainingAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get debtDate =>
      $composableBuilder(column: $table.debtDate, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$CustomerDebtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomerDebtsTable,
          CustomerDebt,
          $$CustomerDebtsTableFilterComposer,
          $$CustomerDebtsTableOrderingComposer,
          $$CustomerDebtsTableAnnotationComposer,
          $$CustomerDebtsTableCreateCompanionBuilder,
          $$CustomerDebtsTableUpdateCompanionBuilder,
          (
            CustomerDebt,
            BaseReferences<_$AppDatabase, $CustomerDebtsTable, CustomerDebt>,
          ),
          CustomerDebt,
          PrefetchHooks Function()
        > {
  $$CustomerDebtsTableTableManager(_$AppDatabase db, $CustomerDebtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomerDebtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomerDebtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomerDebtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> customerId = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> remainingAmount = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> debtDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => CustomerDebtsCompanion(
                id: id,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                remainingAmount: remainingAmount,
                description: description,
                debtDate: debtDate,
                dueDate: dueDate,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int customerId,
                required String customerName,
                required int amount,
                required int remainingAmount,
                Value<String?> description = const Value.absent(),
                Value<DateTime> debtDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => CustomerDebtsCompanion.insert(
                id: id,
                customerId: customerId,
                customerName: customerName,
                amount: amount,
                remainingAmount: remainingAmount,
                description: description,
                debtDate: debtDate,
                dueDate: dueDate,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomerDebtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomerDebtsTable,
      CustomerDebt,
      $$CustomerDebtsTableFilterComposer,
      $$CustomerDebtsTableOrderingComposer,
      $$CustomerDebtsTableAnnotationComposer,
      $$CustomerDebtsTableCreateCompanionBuilder,
      $$CustomerDebtsTableUpdateCompanionBuilder,
      (
        CustomerDebt,
        BaseReferences<_$AppDatabase, $CustomerDebtsTable, CustomerDebt>,
      ),
      CustomerDebt,
      PrefetchHooks Function()
    >;
typedef $$DebtPaymentsTableCreateCompanionBuilder =
    DebtPaymentsCompanion Function({
      Value<int> id,
      required int debtId,
      required int amount,
      Value<String> method,
      Value<String?> notes,
      Value<DateTime> paidAt,
    });
typedef $$DebtPaymentsTableUpdateCompanionBuilder =
    DebtPaymentsCompanion Function({
      Value<int> id,
      Value<int> debtId,
      Value<int> amount,
      Value<String> method,
      Value<String?> notes,
      Value<DateTime> paidAt,
    });

class $$DebtPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get debtId => $composableBuilder(
    column: $table.debtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebtPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get debtId => $composableBuilder(
    column: $table.debtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebtPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get debtId =>
      $composableBuilder(column: $table.debtId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);
}

class $$DebtPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtPaymentsTable,
          DebtPayment,
          $$DebtPaymentsTableFilterComposer,
          $$DebtPaymentsTableOrderingComposer,
          $$DebtPaymentsTableAnnotationComposer,
          $$DebtPaymentsTableCreateCompanionBuilder,
          $$DebtPaymentsTableUpdateCompanionBuilder,
          (
            DebtPayment,
            BaseReferences<_$AppDatabase, $DebtPaymentsTable, DebtPayment>,
          ),
          DebtPayment,
          PrefetchHooks Function()
        > {
  $$DebtPaymentsTableTableManager(_$AppDatabase db, $DebtPaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> debtId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> paidAt = const Value.absent(),
              }) => DebtPaymentsCompanion(
                id: id,
                debtId: debtId,
                amount: amount,
                method: method,
                notes: notes,
                paidAt: paidAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int debtId,
                required int amount,
                Value<String> method = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> paidAt = const Value.absent(),
              }) => DebtPaymentsCompanion.insert(
                id: id,
                debtId: debtId,
                amount: amount,
                method: method,
                notes: notes,
                paidAt: paidAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebtPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtPaymentsTable,
      DebtPayment,
      $$DebtPaymentsTableFilterComposer,
      $$DebtPaymentsTableOrderingComposer,
      $$DebtPaymentsTableAnnotationComposer,
      $$DebtPaymentsTableCreateCompanionBuilder,
      $$DebtPaymentsTableUpdateCompanionBuilder,
      (
        DebtPayment,
        BaseReferences<_$AppDatabase, $DebtPaymentsTable, DebtPayment>,
      ),
      DebtPayment,
      PrefetchHooks Function()
    >;
typedef $$StockCountsTableCreateCompanionBuilder =
    StockCountsCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> totalProducts,
      Value<int> matchCount,
      Value<int> diffCount,
    });
typedef $$StockCountsTableUpdateCompanionBuilder =
    StockCountsCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> totalProducts,
      Value<int> matchCount,
      Value<int> diffCount,
    });

class $$StockCountsTableFilterComposer
    extends Composer<_$AppDatabase, $StockCountsTable> {
  $$StockCountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalProducts => $composableBuilder(
    column: $table.totalProducts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matchCount => $composableBuilder(
    column: $table.matchCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diffCount => $composableBuilder(
    column: $table.diffCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockCountsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockCountsTable> {
  $$StockCountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalProducts => $composableBuilder(
    column: $table.totalProducts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matchCount => $composableBuilder(
    column: $table.matchCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diffCount => $composableBuilder(
    column: $table.diffCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockCountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockCountsTable> {
  $$StockCountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalProducts => $composableBuilder(
    column: $table.totalProducts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get matchCount => $composableBuilder(
    column: $table.matchCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diffCount =>
      $composableBuilder(column: $table.diffCount, builder: (column) => column);
}

class $$StockCountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockCountsTable,
          StockCount,
          $$StockCountsTableFilterComposer,
          $$StockCountsTableOrderingComposer,
          $$StockCountsTableAnnotationComposer,
          $$StockCountsTableCreateCompanionBuilder,
          $$StockCountsTableUpdateCompanionBuilder,
          (
            StockCount,
            BaseReferences<_$AppDatabase, $StockCountsTable, StockCount>,
          ),
          StockCount,
          PrefetchHooks Function()
        > {
  $$StockCountsTableTableManager(_$AppDatabase db, $StockCountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockCountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockCountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockCountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> totalProducts = const Value.absent(),
                Value<int> matchCount = const Value.absent(),
                Value<int> diffCount = const Value.absent(),
              }) => StockCountsCompanion(
                id: id,
                name: name,
                status: status,
                createdAt: createdAt,
                completedAt: completedAt,
                totalProducts: totalProducts,
                matchCount: matchCount,
                diffCount: diffCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> totalProducts = const Value.absent(),
                Value<int> matchCount = const Value.absent(),
                Value<int> diffCount = const Value.absent(),
              }) => StockCountsCompanion.insert(
                id: id,
                name: name,
                status: status,
                createdAt: createdAt,
                completedAt: completedAt,
                totalProducts: totalProducts,
                matchCount: matchCount,
                diffCount: diffCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockCountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockCountsTable,
      StockCount,
      $$StockCountsTableFilterComposer,
      $$StockCountsTableOrderingComposer,
      $$StockCountsTableAnnotationComposer,
      $$StockCountsTableCreateCompanionBuilder,
      $$StockCountsTableUpdateCompanionBuilder,
      (
        StockCount,
        BaseReferences<_$AppDatabase, $StockCountsTable, StockCount>,
      ),
      StockCount,
      PrefetchHooks Function()
    >;
typedef $$StockCountItemsTableCreateCompanionBuilder =
    StockCountItemsCompanion Function({
      Value<int> id,
      required int countSessionId,
      required int productId,
      required String productName,
      required int systemStock,
      Value<int?> physicalStock,
      Value<int> difference,
      Value<int> buyPrice,
      Value<int> sellPrice,
      Value<String?> notes,
    });
typedef $$StockCountItemsTableUpdateCompanionBuilder =
    StockCountItemsCompanion Function({
      Value<int> id,
      Value<int> countSessionId,
      Value<int> productId,
      Value<String> productName,
      Value<int> systemStock,
      Value<int?> physicalStock,
      Value<int> difference,
      Value<int> buyPrice,
      Value<int> sellPrice,
      Value<String?> notes,
    });

class $$StockCountItemsTableFilterComposer
    extends Composer<_$AppDatabase, $StockCountItemsTable> {
  $$StockCountItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countSessionId => $composableBuilder(
    column: $table.countSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get systemStock => $composableBuilder(
    column: $table.systemStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get physicalStock => $composableBuilder(
    column: $table.physicalStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get buyPrice => $composableBuilder(
    column: $table.buyPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockCountItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockCountItemsTable> {
  $$StockCountItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countSessionId => $composableBuilder(
    column: $table.countSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get systemStock => $composableBuilder(
    column: $table.systemStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get physicalStock => $composableBuilder(
    column: $table.physicalStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get buyPrice => $composableBuilder(
    column: $table.buyPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockCountItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockCountItemsTable> {
  $$StockCountItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get countSessionId => $composableBuilder(
    column: $table.countSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get systemStock => $composableBuilder(
    column: $table.systemStock,
    builder: (column) => column,
  );

  GeneratedColumn<int> get physicalStock => $composableBuilder(
    column: $table.physicalStock,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get buyPrice =>
      $composableBuilder(column: $table.buyPrice, builder: (column) => column);

  GeneratedColumn<int> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$StockCountItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockCountItemsTable,
          StockCountItem,
          $$StockCountItemsTableFilterComposer,
          $$StockCountItemsTableOrderingComposer,
          $$StockCountItemsTableAnnotationComposer,
          $$StockCountItemsTableCreateCompanionBuilder,
          $$StockCountItemsTableUpdateCompanionBuilder,
          (
            StockCountItem,
            BaseReferences<
              _$AppDatabase,
              $StockCountItemsTable,
              StockCountItem
            >,
          ),
          StockCountItem,
          PrefetchHooks Function()
        > {
  $$StockCountItemsTableTableManager(
    _$AppDatabase db,
    $StockCountItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockCountItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockCountItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockCountItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> countSessionId = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<int> systemStock = const Value.absent(),
                Value<int?> physicalStock = const Value.absent(),
                Value<int> difference = const Value.absent(),
                Value<int> buyPrice = const Value.absent(),
                Value<int> sellPrice = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => StockCountItemsCompanion(
                id: id,
                countSessionId: countSessionId,
                productId: productId,
                productName: productName,
                systemStock: systemStock,
                physicalStock: physicalStock,
                difference: difference,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int countSessionId,
                required int productId,
                required String productName,
                required int systemStock,
                Value<int?> physicalStock = const Value.absent(),
                Value<int> difference = const Value.absent(),
                Value<int> buyPrice = const Value.absent(),
                Value<int> sellPrice = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => StockCountItemsCompanion.insert(
                id: id,
                countSessionId: countSessionId,
                productId: productId,
                productName: productName,
                systemStock: systemStock,
                physicalStock: physicalStock,
                difference: difference,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockCountItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockCountItemsTable,
      StockCountItem,
      $$StockCountItemsTableFilterComposer,
      $$StockCountItemsTableOrderingComposer,
      $$StockCountItemsTableAnnotationComposer,
      $$StockCountItemsTableCreateCompanionBuilder,
      $$StockCountItemsTableUpdateCompanionBuilder,
      (
        StockCountItem,
        BaseReferences<_$AppDatabase, $StockCountItemsTable, StockCountItem>,
      ),
      StockCountItem,
      PrefetchHooks Function()
    >;
typedef $$ChatSessionsTableCreateCompanionBuilder =
    ChatSessionsCompanion Function({
      Value<int> id,
      required String title,
      required String messagesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ChatSessionsTableUpdateCompanionBuilder =
    ChatSessionsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> messagesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$ChatSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messagesJson => $composableBuilder(
    column: $table.messagesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messagesJson => $composableBuilder(
    column: $table.messagesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get messagesJson => $composableBuilder(
    column: $table.messagesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChatSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatSessionsTable,
          ChatSession,
          $$ChatSessionsTableFilterComposer,
          $$ChatSessionsTableOrderingComposer,
          $$ChatSessionsTableAnnotationComposer,
          $$ChatSessionsTableCreateCompanionBuilder,
          $$ChatSessionsTableUpdateCompanionBuilder,
          (
            ChatSession,
            BaseReferences<_$AppDatabase, $ChatSessionsTable, ChatSession>,
          ),
          ChatSession,
          PrefetchHooks Function()
        > {
  $$ChatSessionsTableTableManager(_$AppDatabase db, $ChatSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> messagesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChatSessionsCompanion(
                id: id,
                title: title,
                messagesJson: messagesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String messagesJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChatSessionsCompanion.insert(
                id: id,
                title: title,
                messagesJson: messagesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatSessionsTable,
      ChatSession,
      $$ChatSessionsTableFilterComposer,
      $$ChatSessionsTableOrderingComposer,
      $$ChatSessionsTableAnnotationComposer,
      $$ChatSessionsTableCreateCompanionBuilder,
      $$ChatSessionsTableUpdateCompanionBuilder,
      (
        ChatSession,
        BaseReferences<_$AppDatabase, $ChatSessionsTable, ChatSession>,
      ),
      ChatSession,
      PrefetchHooks Function()
    >;
typedef $$DiningTablesTableCreateCompanionBuilder =
    DiningTablesCompanion Function({
      Value<int> id,
      required String name,
      Value<int> capacity,
      Value<String> status,
      Value<DateTime> createdAt,
    });
typedef $$DiningTablesTableUpdateCompanionBuilder =
    DiningTablesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> capacity,
      Value<String> status,
      Value<DateTime> createdAt,
    });

class $$DiningTablesTableFilterComposer
    extends Composer<_$AppDatabase, $DiningTablesTable> {
  $$DiningTablesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiningTablesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiningTablesTable> {
  $$DiningTablesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiningTablesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiningTablesTable> {
  $$DiningTablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get capacity =>
      $composableBuilder(column: $table.capacity, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DiningTablesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiningTablesTable,
          DiningTable,
          $$DiningTablesTableFilterComposer,
          $$DiningTablesTableOrderingComposer,
          $$DiningTablesTableAnnotationComposer,
          $$DiningTablesTableCreateCompanionBuilder,
          $$DiningTablesTableUpdateCompanionBuilder,
          (
            DiningTable,
            BaseReferences<_$AppDatabase, $DiningTablesTable, DiningTable>,
          ),
          DiningTable,
          PrefetchHooks Function()
        > {
  $$DiningTablesTableTableManager(_$AppDatabase db, $DiningTablesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiningTablesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiningTablesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiningTablesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> capacity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DiningTablesCompanion(
                id: id,
                name: name,
                capacity: capacity,
                status: status,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> capacity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DiningTablesCompanion.insert(
                id: id,
                name: name,
                capacity: capacity,
                status: status,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiningTablesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiningTablesTable,
      DiningTable,
      $$DiningTablesTableFilterComposer,
      $$DiningTablesTableOrderingComposer,
      $$DiningTablesTableAnnotationComposer,
      $$DiningTablesTableCreateCompanionBuilder,
      $$DiningTablesTableUpdateCompanionBuilder,
      (
        DiningTable,
        BaseReferences<_$AppDatabase, $DiningTablesTable, DiningTable>,
      ),
      DiningTable,
      PrefetchHooks Function()
    >;
typedef $$LaundryOrdersTableCreateCompanionBuilder =
    LaundryOrdersCompanion Function({
      Value<int> id,
      required String customerName,
      Value<String?> customerPhone,
      required String itemsJson,
      Value<int> total,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime?> estimatedReady,
      Value<DateTime> createdAt,
    });
typedef $$LaundryOrdersTableUpdateCompanionBuilder =
    LaundryOrdersCompanion Function({
      Value<int> id,
      Value<String> customerName,
      Value<String?> customerPhone,
      Value<String> itemsJson,
      Value<int> total,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime?> estimatedReady,
      Value<DateTime> createdAt,
    });

class $$LaundryOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $LaundryOrdersTable> {
  $$LaundryOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get estimatedReady => $composableBuilder(
    column: $table.estimatedReady,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LaundryOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $LaundryOrdersTable> {
  $$LaundryOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get estimatedReady => $composableBuilder(
    column: $table.estimatedReady,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LaundryOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LaundryOrdersTable> {
  $$LaundryOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get estimatedReady => $composableBuilder(
    column: $table.estimatedReady,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LaundryOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LaundryOrdersTable,
          LaundryOrder,
          $$LaundryOrdersTableFilterComposer,
          $$LaundryOrdersTableOrderingComposer,
          $$LaundryOrdersTableAnnotationComposer,
          $$LaundryOrdersTableCreateCompanionBuilder,
          $$LaundryOrdersTableUpdateCompanionBuilder,
          (
            LaundryOrder,
            BaseReferences<_$AppDatabase, $LaundryOrdersTable, LaundryOrder>,
          ),
          LaundryOrder,
          PrefetchHooks Function()
        > {
  $$LaundryOrdersTableTableManager(_$AppDatabase db, $LaundryOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LaundryOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LaundryOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LaundryOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> estimatedReady = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LaundryOrdersCompanion(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                itemsJson: itemsJson,
                total: total,
                status: status,
                notes: notes,
                estimatedReady: estimatedReady,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String customerName,
                Value<String?> customerPhone = const Value.absent(),
                required String itemsJson,
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> estimatedReady = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LaundryOrdersCompanion.insert(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                itemsJson: itemsJson,
                total: total,
                status: status,
                notes: notes,
                estimatedReady: estimatedReady,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LaundryOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LaundryOrdersTable,
      LaundryOrder,
      $$LaundryOrdersTableFilterComposer,
      $$LaundryOrdersTableOrderingComposer,
      $$LaundryOrdersTableAnnotationComposer,
      $$LaundryOrdersTableCreateCompanionBuilder,
      $$LaundryOrdersTableUpdateCompanionBuilder,
      (
        LaundryOrder,
        BaseReferences<_$AppDatabase, $LaundryOrdersTable, LaundryOrder>,
      ),
      LaundryOrder,
      PrefetchHooks Function()
    >;
typedef $$ServiceTicketsTableCreateCompanionBuilder =
    ServiceTicketsCompanion Function({
      Value<int> id,
      required String customerName,
      Value<String?> customerPhone,
      required String deviceName,
      required String issue,
      Value<int> estimatedCost,
      Value<int> finalCost,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<String?> plateNumber,
      Value<String?> vehicleBrand,
      Value<int?> vehicleYear,
      Value<String?> technician,
      Value<int> sparepartCost,
      Value<int> serviceCost,
      Value<int?> queueNumber,
    });
typedef $$ServiceTicketsTableUpdateCompanionBuilder =
    ServiceTicketsCompanion Function({
      Value<int> id,
      Value<String> customerName,
      Value<String?> customerPhone,
      Value<String> deviceName,
      Value<String> issue,
      Value<int> estimatedCost,
      Value<int> finalCost,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<String?> plateNumber,
      Value<String?> vehicleBrand,
      Value<int?> vehicleYear,
      Value<String?> technician,
      Value<int> sparepartCost,
      Value<int> serviceCost,
      Value<int?> queueNumber,
    });

class $$ServiceTicketsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceTicketsTable> {
  $$ServiceTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issue => $composableBuilder(
    column: $table.issue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedCost => $composableBuilder(
    column: $table.estimatedCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalCost => $composableBuilder(
    column: $table.finalCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plateNumber => $composableBuilder(
    column: $table.plateNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleBrand => $composableBuilder(
    column: $table.vehicleBrand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vehicleYear => $composableBuilder(
    column: $table.vehicleYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get technician => $composableBuilder(
    column: $table.technician,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sparepartCost => $composableBuilder(
    column: $table.sparepartCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serviceCost => $composableBuilder(
    column: $table.serviceCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get queueNumber => $composableBuilder(
    column: $table.queueNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServiceTicketsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceTicketsTable> {
  $$ServiceTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issue => $composableBuilder(
    column: $table.issue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedCost => $composableBuilder(
    column: $table.estimatedCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalCost => $composableBuilder(
    column: $table.finalCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plateNumber => $composableBuilder(
    column: $table.plateNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleBrand => $composableBuilder(
    column: $table.vehicleBrand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vehicleYear => $composableBuilder(
    column: $table.vehicleYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get technician => $composableBuilder(
    column: $table.technician,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sparepartCost => $composableBuilder(
    column: $table.sparepartCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serviceCost => $composableBuilder(
    column: $table.serviceCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get queueNumber => $composableBuilder(
    column: $table.queueNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServiceTicketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceTicketsTable> {
  $$ServiceTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => column);

  GeneratedColumn<int> get estimatedCost => $composableBuilder(
    column: $table.estimatedCost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get finalCost =>
      $composableBuilder(column: $table.finalCost, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get plateNumber => $composableBuilder(
    column: $table.plateNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehicleBrand => $composableBuilder(
    column: $table.vehicleBrand,
    builder: (column) => column,
  );

  GeneratedColumn<int> get vehicleYear => $composableBuilder(
    column: $table.vehicleYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get technician => $composableBuilder(
    column: $table.technician,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sparepartCost => $composableBuilder(
    column: $table.sparepartCost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serviceCost => $composableBuilder(
    column: $table.serviceCost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get queueNumber => $composableBuilder(
    column: $table.queueNumber,
    builder: (column) => column,
  );
}

class $$ServiceTicketsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceTicketsTable,
          ServiceTicket,
          $$ServiceTicketsTableFilterComposer,
          $$ServiceTicketsTableOrderingComposer,
          $$ServiceTicketsTableAnnotationComposer,
          $$ServiceTicketsTableCreateCompanionBuilder,
          $$ServiceTicketsTableUpdateCompanionBuilder,
          (
            ServiceTicket,
            BaseReferences<_$AppDatabase, $ServiceTicketsTable, ServiceTicket>,
          ),
          ServiceTicket,
          PrefetchHooks Function()
        > {
  $$ServiceTicketsTableTableManager(
    _$AppDatabase db,
    $ServiceTicketsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceTicketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceTicketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
                Value<String> issue = const Value.absent(),
                Value<int> estimatedCost = const Value.absent(),
                Value<int> finalCost = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> plateNumber = const Value.absent(),
                Value<String?> vehicleBrand = const Value.absent(),
                Value<int?> vehicleYear = const Value.absent(),
                Value<String?> technician = const Value.absent(),
                Value<int> sparepartCost = const Value.absent(),
                Value<int> serviceCost = const Value.absent(),
                Value<int?> queueNumber = const Value.absent(),
              }) => ServiceTicketsCompanion(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                deviceName: deviceName,
                issue: issue,
                estimatedCost: estimatedCost,
                finalCost: finalCost,
                status: status,
                notes: notes,
                createdAt: createdAt,
                plateNumber: plateNumber,
                vehicleBrand: vehicleBrand,
                vehicleYear: vehicleYear,
                technician: technician,
                sparepartCost: sparepartCost,
                serviceCost: serviceCost,
                queueNumber: queueNumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String customerName,
                Value<String?> customerPhone = const Value.absent(),
                required String deviceName,
                required String issue,
                Value<int> estimatedCost = const Value.absent(),
                Value<int> finalCost = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> plateNumber = const Value.absent(),
                Value<String?> vehicleBrand = const Value.absent(),
                Value<int?> vehicleYear = const Value.absent(),
                Value<String?> technician = const Value.absent(),
                Value<int> sparepartCost = const Value.absent(),
                Value<int> serviceCost = const Value.absent(),
                Value<int?> queueNumber = const Value.absent(),
              }) => ServiceTicketsCompanion.insert(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                deviceName: deviceName,
                issue: issue,
                estimatedCost: estimatedCost,
                finalCost: finalCost,
                status: status,
                notes: notes,
                createdAt: createdAt,
                plateNumber: plateNumber,
                vehicleBrand: vehicleBrand,
                vehicleYear: vehicleYear,
                technician: technician,
                sparepartCost: sparepartCost,
                serviceCost: serviceCost,
                queueNumber: queueNumber,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServiceTicketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceTicketsTable,
      ServiceTicket,
      $$ServiceTicketsTableFilterComposer,
      $$ServiceTicketsTableOrderingComposer,
      $$ServiceTicketsTableAnnotationComposer,
      $$ServiceTicketsTableCreateCompanionBuilder,
      $$ServiceTicketsTableUpdateCompanionBuilder,
      (
        ServiceTicket,
        BaseReferences<_$AppDatabase, $ServiceTicketsTable, ServiceTicket>,
      ),
      ServiceTicket,
      PrefetchHooks Function()
    >;
typedef $$AppointmentsTableCreateCompanionBuilder =
    AppointmentsCompanion Function({
      Value<int> id,
      required String customerName,
      Value<String?> customerPhone,
      required String service,
      Value<String?> stylist,
      required DateTime date,
      required String timeSlot,
      Value<String> status,
      Value<String?> notes,
      Value<int?> estimatedDuration,
      Value<int?> counterId,
      Value<DateTime> createdAt,
    });
typedef $$AppointmentsTableUpdateCompanionBuilder =
    AppointmentsCompanion Function({
      Value<int> id,
      Value<String> customerName,
      Value<String?> customerPhone,
      Value<String> service,
      Value<String?> stylist,
      Value<DateTime> date,
      Value<String> timeSlot,
      Value<String> status,
      Value<String?> notes,
      Value<int?> estimatedDuration,
      Value<int?> counterId,
      Value<DateTime> createdAt,
    });

class $$AppointmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AppointmentsTable> {
  $$AppointmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get service => $composableBuilder(
    column: $table.service,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stylist => $composableBuilder(
    column: $table.stylist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeSlot => $composableBuilder(
    column: $table.timeSlot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedDuration => $composableBuilder(
    column: $table.estimatedDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get counterId => $composableBuilder(
    column: $table.counterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppointmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppointmentsTable> {
  $$AppointmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get service => $composableBuilder(
    column: $table.service,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stylist => $composableBuilder(
    column: $table.stylist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeSlot => $composableBuilder(
    column: $table.timeSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedDuration => $composableBuilder(
    column: $table.estimatedDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get counterId => $composableBuilder(
    column: $table.counterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppointmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppointmentsTable> {
  $$AppointmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get service =>
      $composableBuilder(column: $table.service, builder: (column) => column);

  GeneratedColumn<String> get stylist =>
      $composableBuilder(column: $table.stylist, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get timeSlot =>
      $composableBuilder(column: $table.timeSlot, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get estimatedDuration => $composableBuilder(
    column: $table.estimatedDuration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get counterId =>
      $composableBuilder(column: $table.counterId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AppointmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppointmentsTable,
          Appointment,
          $$AppointmentsTableFilterComposer,
          $$AppointmentsTableOrderingComposer,
          $$AppointmentsTableAnnotationComposer,
          $$AppointmentsTableCreateCompanionBuilder,
          $$AppointmentsTableUpdateCompanionBuilder,
          (
            Appointment,
            BaseReferences<_$AppDatabase, $AppointmentsTable, Appointment>,
          ),
          Appointment,
          PrefetchHooks Function()
        > {
  $$AppointmentsTableTableManager(_$AppDatabase db, $AppointmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppointmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppointmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppointmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<String> service = const Value.absent(),
                Value<String?> stylist = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> timeSlot = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> estimatedDuration = const Value.absent(),
                Value<int?> counterId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AppointmentsCompanion(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                service: service,
                stylist: stylist,
                date: date,
                timeSlot: timeSlot,
                status: status,
                notes: notes,
                estimatedDuration: estimatedDuration,
                counterId: counterId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String customerName,
                Value<String?> customerPhone = const Value.absent(),
                required String service,
                Value<String?> stylist = const Value.absent(),
                required DateTime date,
                required String timeSlot,
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> estimatedDuration = const Value.absent(),
                Value<int?> counterId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AppointmentsCompanion.insert(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                service: service,
                stylist: stylist,
                date: date,
                timeSlot: timeSlot,
                status: status,
                notes: notes,
                estimatedDuration: estimatedDuration,
                counterId: counterId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppointmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppointmentsTable,
      Appointment,
      $$AppointmentsTableFilterComposer,
      $$AppointmentsTableOrderingComposer,
      $$AppointmentsTableAnnotationComposer,
      $$AppointmentsTableCreateCompanionBuilder,
      $$AppointmentsTableUpdateCompanionBuilder,
      (
        Appointment,
        BaseReferences<_$AppDatabase, $AppointmentsTable, Appointment>,
      ),
      Appointment,
      PrefetchHooks Function()
    >;
typedef $$PrescriptionsTableCreateCompanionBuilder =
    PrescriptionsCompanion Function({
      Value<int> id,
      required String patientName,
      Value<String?> doctorName,
      required String itemsJson,
      Value<String?> dosage,
      Value<int> total,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$PrescriptionsTableUpdateCompanionBuilder =
    PrescriptionsCompanion Function({
      Value<int> id,
      Value<String> patientName,
      Value<String?> doctorName,
      Value<String> itemsJson,
      Value<String?> dosage,
      Value<int> total,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$PrescriptionsTableFilterComposer
    extends Composer<_$AppDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doctorName => $composableBuilder(
    column: $table.doctorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dosage => $composableBuilder(
    column: $table.dosage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrescriptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doctorName => $composableBuilder(
    column: $table.doctorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dosage => $composableBuilder(
    column: $table.dosage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrescriptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrescriptionsTable> {
  $$PrescriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get doctorName => $composableBuilder(
    column: $table.doctorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<String> get dosage =>
      $composableBuilder(column: $table.dosage, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PrescriptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrescriptionsTable,
          Prescription,
          $$PrescriptionsTableFilterComposer,
          $$PrescriptionsTableOrderingComposer,
          $$PrescriptionsTableAnnotationComposer,
          $$PrescriptionsTableCreateCompanionBuilder,
          $$PrescriptionsTableUpdateCompanionBuilder,
          (
            Prescription,
            BaseReferences<_$AppDatabase, $PrescriptionsTable, Prescription>,
          ),
          Prescription,
          PrefetchHooks Function()
        > {
  $$PrescriptionsTableTableManager(_$AppDatabase db, $PrescriptionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrescriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrescriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrescriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> patientName = const Value.absent(),
                Value<String?> doctorName = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<String?> dosage = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PrescriptionsCompanion(
                id: id,
                patientName: patientName,
                doctorName: doctorName,
                itemsJson: itemsJson,
                dosage: dosage,
                total: total,
                status: status,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String patientName,
                Value<String?> doctorName = const Value.absent(),
                required String itemsJson,
                Value<String?> dosage = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PrescriptionsCompanion.insert(
                id: id,
                patientName: patientName,
                doctorName: doctorName,
                itemsJson: itemsJson,
                dosage: dosage,
                total: total,
                status: status,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrescriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrescriptionsTable,
      Prescription,
      $$PrescriptionsTableFilterComposer,
      $$PrescriptionsTableOrderingComposer,
      $$PrescriptionsTableAnnotationComposer,
      $$PrescriptionsTableCreateCompanionBuilder,
      $$PrescriptionsTableUpdateCompanionBuilder,
      (
        Prescription,
        BaseReferences<_$AppDatabase, $PrescriptionsTable, Prescription>,
      ),
      Prescription,
      PrefetchHooks Function()
    >;
typedef $$PrintOrdersTableCreateCompanionBuilder =
    PrintOrdersCompanion Function({
      Value<int> id,
      required String customerName,
      Value<String?> customerPhone,
      required String serviceType,
      Value<int> pages,
      Value<int> copies,
      Value<String> paperSize,
      Value<int> total,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$PrintOrdersTableUpdateCompanionBuilder =
    PrintOrdersCompanion Function({
      Value<int> id,
      Value<String> customerName,
      Value<String?> customerPhone,
      Value<String> serviceType,
      Value<int> pages,
      Value<int> copies,
      Value<String> paperSize,
      Value<int> total,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$PrintOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PrintOrdersTable> {
  $$PrintOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get copies => $composableBuilder(
    column: $table.copies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paperSize => $composableBuilder(
    column: $table.paperSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrintOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PrintOrdersTable> {
  $$PrintOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get copies => $composableBuilder(
    column: $table.copies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paperSize => $composableBuilder(
    column: $table.paperSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrintOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrintOrdersTable> {
  $$PrintOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<int> get copies =>
      $composableBuilder(column: $table.copies, builder: (column) => column);

  GeneratedColumn<String> get paperSize =>
      $composableBuilder(column: $table.paperSize, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PrintOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrintOrdersTable,
          PrintOrder,
          $$PrintOrdersTableFilterComposer,
          $$PrintOrdersTableOrderingComposer,
          $$PrintOrdersTableAnnotationComposer,
          $$PrintOrdersTableCreateCompanionBuilder,
          $$PrintOrdersTableUpdateCompanionBuilder,
          (
            PrintOrder,
            BaseReferences<_$AppDatabase, $PrintOrdersTable, PrintOrder>,
          ),
          PrintOrder,
          PrefetchHooks Function()
        > {
  $$PrintOrdersTableTableManager(_$AppDatabase db, $PrintOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrintOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrintOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrintOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<String> serviceType = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<int> copies = const Value.absent(),
                Value<String> paperSize = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PrintOrdersCompanion(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                serviceType: serviceType,
                pages: pages,
                copies: copies,
                paperSize: paperSize,
                total: total,
                status: status,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String customerName,
                Value<String?> customerPhone = const Value.absent(),
                required String serviceType,
                Value<int> pages = const Value.absent(),
                Value<int> copies = const Value.absent(),
                Value<String> paperSize = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PrintOrdersCompanion.insert(
                id: id,
                customerName: customerName,
                customerPhone: customerPhone,
                serviceType: serviceType,
                pages: pages,
                copies: copies,
                paperSize: paperSize,
                total: total,
                status: status,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrintOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrintOrdersTable,
      PrintOrder,
      $$PrintOrdersTableFilterComposer,
      $$PrintOrdersTableOrderingComposer,
      $$PrintOrdersTableAnnotationComposer,
      $$PrintOrdersTableCreateCompanionBuilder,
      $$PrintOrdersTableUpdateCompanionBuilder,
      (
        PrintOrder,
        BaseReferences<_$AppDatabase, $PrintOrdersTable, PrintOrder>,
      ),
      PrintOrder,
      PrefetchHooks Function()
    >;
typedef $$OpenTabsTableCreateCompanionBuilder =
    OpenTabsCompanion Function({
      Value<int> id,
      Value<int?> tableId,
      Value<String> orderType,
      required String itemsJson,
      Value<int> total,
      Value<int> discount,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$OpenTabsTableUpdateCompanionBuilder =
    OpenTabsCompanion Function({
      Value<int> id,
      Value<int?> tableId,
      Value<String> orderType,
      Value<String> itemsJson,
      Value<int> total,
      Value<int> discount,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$OpenTabsTableFilterComposer
    extends Composer<_$AppDatabase, $OpenTabsTable> {
  $$OpenTabsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tableId => $composableBuilder(
    column: $table.tableId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OpenTabsTableOrderingComposer
    extends Composer<_$AppDatabase, $OpenTabsTable> {
  $$OpenTabsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tableId => $composableBuilder(
    column: $table.tableId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OpenTabsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpenTabsTable> {
  $$OpenTabsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tableId =>
      $composableBuilder(column: $table.tableId, builder: (column) => column);

  GeneratedColumn<String> get orderType =>
      $composableBuilder(column: $table.orderType, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OpenTabsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpenTabsTable,
          OpenTab,
          $$OpenTabsTableFilterComposer,
          $$OpenTabsTableOrderingComposer,
          $$OpenTabsTableAnnotationComposer,
          $$OpenTabsTableCreateCompanionBuilder,
          $$OpenTabsTableUpdateCompanionBuilder,
          (OpenTab, BaseReferences<_$AppDatabase, $OpenTabsTable, OpenTab>),
          OpenTab,
          PrefetchHooks Function()
        > {
  $$OpenTabsTableTableManager(_$AppDatabase db, $OpenTabsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpenTabsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpenTabsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpenTabsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> tableId = const Value.absent(),
                Value<String> orderType = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OpenTabsCompanion(
                id: id,
                tableId: tableId,
                orderType: orderType,
                itemsJson: itemsJson,
                total: total,
                discount: discount,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> tableId = const Value.absent(),
                Value<String> orderType = const Value.absent(),
                required String itemsJson,
                Value<int> total = const Value.absent(),
                Value<int> discount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OpenTabsCompanion.insert(
                id: id,
                tableId: tableId,
                orderType: orderType,
                itemsJson: itemsJson,
                total: total,
                discount: discount,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OpenTabsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpenTabsTable,
      OpenTab,
      $$OpenTabsTableFilterComposer,
      $$OpenTabsTableOrderingComposer,
      $$OpenTabsTableAnnotationComposer,
      $$OpenTabsTableCreateCompanionBuilder,
      $$OpenTabsTableUpdateCompanionBuilder,
      (OpenTab, BaseReferences<_$AppDatabase, $OpenTabsTable, OpenTab>),
      OpenTab,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(_db, _db.stockMovements);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$PromosTableTableManager get promos =>
      $$PromosTableTableManager(_db, _db.promos);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db, _db.employees);
  $$AttendanceTableTableManager get attendance =>
      $$AttendanceTableTableManager(_db, _db.attendance);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$ExpenseCategoriesTableTableManager get expenseCategories =>
      $$ExpenseCategoriesTableTableManager(_db, _db.expenseCategories);
  $$RecurringExpensesTableTableManager get recurringExpenses =>
      $$RecurringExpensesTableTableManager(_db, _db.recurringExpenses);
  $$PayrollTableTableManager get payroll =>
      $$PayrollTableTableManager(_db, _db.payroll);
  $$WasteTableTableManager get waste =>
      $$WasteTableTableManager(_db, _db.waste);
  $$LiquidityTableTableManager get liquidity =>
      $$LiquidityTableTableManager(_db, _db.liquidity);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$BranchesTableTableManager get branches =>
      $$BranchesTableTableManager(_db, _db.branches);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ActivationsLocalTableTableManager get activationsLocal =>
      $$ActivationsLocalTableTableManager(_db, _db.activationsLocal);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$CashierSessionsTableTableManager get cashierSessions =>
      $$CashierSessionsTableTableManager(_db, _db.cashierSessions);
  $$OnlineOrdersTableTableManager get onlineOrders =>
      $$OnlineOrdersTableTableManager(_db, _db.onlineOrders);
  $$CustomerDebtsTableTableManager get customerDebts =>
      $$CustomerDebtsTableTableManager(_db, _db.customerDebts);
  $$DebtPaymentsTableTableManager get debtPayments =>
      $$DebtPaymentsTableTableManager(_db, _db.debtPayments);
  $$StockCountsTableTableManager get stockCounts =>
      $$StockCountsTableTableManager(_db, _db.stockCounts);
  $$StockCountItemsTableTableManager get stockCountItems =>
      $$StockCountItemsTableTableManager(_db, _db.stockCountItems);
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db, _db.chatSessions);
  $$DiningTablesTableTableManager get diningTables =>
      $$DiningTablesTableTableManager(_db, _db.diningTables);
  $$LaundryOrdersTableTableManager get laundryOrders =>
      $$LaundryOrdersTableTableManager(_db, _db.laundryOrders);
  $$ServiceTicketsTableTableManager get serviceTickets =>
      $$ServiceTicketsTableTableManager(_db, _db.serviceTickets);
  $$AppointmentsTableTableManager get appointments =>
      $$AppointmentsTableTableManager(_db, _db.appointments);
  $$PrescriptionsTableTableManager get prescriptions =>
      $$PrescriptionsTableTableManager(_db, _db.prescriptions);
  $$PrintOrdersTableTableManager get printOrders =>
      $$PrintOrdersTableTableManager(_db, _db.printOrders);
  $$OpenTabsTableTableManager get openTabs =>
      $$OpenTabsTableTableManager(_db, _db.openTabs);
}
