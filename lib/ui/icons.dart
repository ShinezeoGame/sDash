import 'package:flutter/material.dart';

import '../models/home.dart';

IconData roomIcon(RoomKind kind) => switch (kind) {
      RoomKind.living => Icons.weekend_rounded,
      RoomKind.kitchen => Icons.kitchen_rounded,
      RoomKind.bedroom => Icons.king_bed_rounded,
      RoomKind.office => Icons.desk_rounded,
      RoomKind.bathroom => Icons.bathtub_rounded,
      RoomKind.entrance => Icons.door_front_door_rounded,
      RoomKind.outdoor => Icons.yard_rounded,
      RoomKind.generic => Icons.home_rounded,
    };

IconData sceneIcon(SceneKind kind) => switch (kind) {
      SceneKind.cosy => Icons.local_fire_department_rounded,
      SceneKind.movie => Icons.movie_rounded,
      SceneKind.night => Icons.nights_stay_rounded,
      SceneKind.morning => Icons.wb_twilight_rounded,
      SceneKind.away => Icons.logout_rounded,
      SceneKind.generic => Icons.auto_awesome_rounded,
    };

IconData switchIcon(SwitchKind kind) => switch (kind) {
      SwitchKind.tv => Icons.tv_rounded,
      SwitchKind.coffee => Icons.coffee_maker_rounded,
      SwitchKind.speaker => Icons.speaker_rounded,
      SwitchKind.fan => Icons.air_rounded,
      SwitchKind.plug => Icons.power_rounded,
      SwitchKind.generic => Icons.toggle_on_rounded,
    };

IconData weatherIcon(WeatherKind kind) => switch (kind) {
      WeatherKind.sunny => Icons.wb_sunny_rounded,
      WeatherKind.partlyCloudy => Icons.wb_cloudy_rounded,
      WeatherKind.cloudy => Icons.cloud_rounded,
      WeatherKind.rainy => Icons.water_drop_rounded,
      WeatherKind.snowy => Icons.ac_unit_rounded,
      WeatherKind.stormy => Icons.thunderstorm_rounded,
      WeatherKind.foggy => Icons.foggy,
      WeatherKind.night => Icons.nightlight_round,
      WeatherKind.unknown => Icons.thermostat_rounded,
    };

IconData climateModeIcon(ClimateMode mode) => switch (mode) {
      ClimateMode.comfort => Icons.local_fire_department_rounded,
      ClimateMode.eco => Icons.eco_rounded,
      ClimateMode.away => Icons.ac_unit_rounded,
      ClimateMode.off => Icons.power_settings_new_rounded,
    };
