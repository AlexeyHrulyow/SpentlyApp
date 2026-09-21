// lib/models/category_icons.dart

import 'package:flutter/material.dart';

/// Каталог иконок для категорий.
/// Ключ ('restaurant', 'home_work', ...) хранится в БД в categories.icon_code.
///
/// ⚠️ Все Icons.xxx перечислены здесь ЛИТЕРАЛЬНО — этого требует
/// tree-shaking шрифта MaterialIcons в release-сборке. Если строить IconData
/// из «сырого» codePoint в рантайме, глиф может отсутствовать в собранном
/// шрифте и вместо иконки будет пустой квадратик.
const Map<String, IconData> kCategoryIcons = {
  // Общее
  'label':              Icons.label_outline,
  'category':           Icons.category,
  'star':               Icons.star,
  'favorite':           Icons.favorite,
  // Дом / быт
  'home':               Icons.home,
  'home_work':          Icons.home_work,
  'cleaning':           Icons.cleaning_services,
  'build':              Icons.build,
  // Еда
  'restaurant':         Icons.restaurant,
  'fastfood':           Icons.fastfood,
  'cookie':             Icons.cookie,
  'local_cafe':         Icons.local_cafe,
  'local_bar':          Icons.local_bar,
  'shopping_cart':      Icons.shopping_cart,
  'shopping_bag':       Icons.shopping_bag,
  // Транспорт
  'directions_bus':     Icons.directions_bus,
  'directions_car':     Icons.directions_car,
  'train':              Icons.train,
  'pedal_bike':         Icons.pedal_bike,
  'flight':             Icons.flight,
  'local_gas_station':  Icons.local_gas_station,
  // Здоровье / спорт
  'medical_services':   Icons.medical_services,
  'fitness_center':     Icons.fitness_center,
  'self_improvement':   Icons.self_improvement,
  'spa':                Icons.spa,
  // Образование / работа
  'school':             Icons.school,
  'menu_book':          Icons.menu_book,
  'work':               Icons.work,
  'laptop':             Icons.laptop,
  // Развлечения
  'movie':              Icons.movie,
  'sports_esports':     Icons.sports_esports,
  'sports_soccer':      Icons.sports_soccer,
  'music_note':         Icons.music_note,
  'photo_camera':       Icons.photo_camera,
  // Техника
  'phone_android':      Icons.phone_android,
  'devices':            Icons.devices,
  // Одежда
  'checkroom':          Icons.checkroom,
  // Прочее
  'card_giftcard':      Icons.card_giftcard,
  'pets':               Icons.pets,
  'child_care':         Icons.child_care,
  'attach_money':       Icons.attach_money,
  'savings':            Icons.savings,
  'brush':              Icons.brush,
  'hotel':              Icons.hotel,
};

const IconData kDefaultCategoryIcon = Icons.label_outline;

/// name → IconData. Если код неизвестен — дефолтная иконка.
IconData iconForCode(String? code) {
  if (code == null) return kDefaultCategoryIcon;
  return kCategoryIcons[code] ?? kDefaultCategoryIcon;
}