import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class Passenger {
  final String name;
  final double duration;
  final String earliestPickup;
  final String latestPickup;
  final String pickupAddress;
  final Point pickupLatLng;
  final String dropoffAddress;
  final Point dropoffLatLng;

  Passenger({
    required this.name,
    required this.duration,
    required this.earliestPickup,
    required this.latestPickup,
    required this.pickupAddress,
    required this.pickupLatLng,
    required this.dropoffAddress,
    required this.dropoffLatLng,
  });
}

// Demo data
final List<Passenger> passengerList = [
  Passenger(
    name: "KIMBERLY M FINEMAN",
    duration: 7.2,
    earliestPickup: "05:46",
    latestPickup: "06:14",
    pickupAddress: "833 S Ellipse Way, Denver, CO",
    pickupLatLng: Point(coordinates: Position(-104.9782, 39.7009)),
    dropoffAddress: "2822 E Colfax Ave, Denver, CO",
    dropoffLatLng: Point(coordinates: Position(-104.9549, 39.7401)),
  ),
  Passenger(
    name: "KIMBERLY M FINEMAN",
    duration: 5.57,
    earliestPickup: "06:45",
    latestPickup: "07:15",
    pickupAddress: "2822 E Colfax Ave, Denver, CO",
    pickupLatLng: Point(coordinates: Position(-104.9549, 39.7401)),
    dropoffAddress: "777 Bannock St, Denver, CO",
    dropoffLatLng: Point(coordinates: Position(-104.9915, 39.7300)),
  ),
  Passenger(
    name: "MELISSA C SELSTAD",
    duration: 25.55,
    earliestPickup: "06:54",
    latestPickup: "07:22",
    pickupAddress: "17519 E Temple Dr, Aurora, CO",
    pickupLatLng: Point(coordinates: Position(-104.7866, 39.6415)),
    dropoffAddress: "10240 Park Meadows Dr, Lone Tree, CO",
    dropoffLatLng: Point(coordinates: Position(-104.8726, 39.5516)),
  ),
  Passenger(
    name: "KATHERINE G SANDERS",
    duration: 12.83,
    earliestPickup: "07:11",
    latestPickup: "07:39",
    pickupAddress: "4473 S Hannibal Way, Aurora, CO",
    pickupLatLng: Point(coordinates: Position(-104.7926, 39.6346)),
    dropoffAddress: "1444 S Potomac St, Aurora, CO",
    dropoffLatLng: Point(coordinates: Position(-104.8308, 39.6901)),
  ),
  Passenger(
    name: "AIYANA J BEATTY",
    duration: 17.85,
    earliestPickup: "07:50",
    latestPickup: "08:20",
    pickupAddress: "18995 E Colorado Dr, Aurora, CO",
    pickupLatLng: Point(coordinates: Position(-104.7727, 39.6876)),
    dropoffAddress: "1635 Aurora Ct, Aurora, CO",
    dropoffLatLng: Point(coordinates: Position(-104.8373, 39.7427)),
  ),
  Passenger(
    name: "ROBERT W JULIAN",
    duration: 41.43,
    earliestPickup: "08:12",
    latestPickup: "08:40",
    pickupAddress: "19402 E Hamilton Pl, Aurora, CO",
    pickupLatLng: Point(coordinates: Position(-104.7571, 39.6245)),
    dropoffAddress: "8015 W Alameda Ave, Lakewood, CO",
    dropoffLatLng: Point(coordinates: Position(-105.0866, 39.7119)),
  ),
  Passenger(
    name: "MEIHWAY LIU",
    duration: 25.73,
    earliestPickup: "08:23",
    latestPickup: "08:51",
    pickupAddress: "4460 S Pitkin St, Aurora, CO",
    pickupLatLng: Point(coordinates: Position(-104.7792, 39.6344)),
    dropoffAddress: "55 Madison St, Denver, CO",
    dropoffLatLng: Point(coordinates: Position(-104.9467, 39.7174)),
  ),
  Passenger(
    name: "SONA ALIFOVA",
    duration: 10.32,
    earliestPickup: "08:43",
    latestPickup: "09:11",
    pickupAddress: "11558 E Adriatic Pl, Aurora, CO",
    pickupLatLng: Point(coordinates: Position(-104.8510, 39.6971)),
    dropoffAddress: "13710 E Rice Pl, Aurora, CO",
    dropoffLatLng: Point(coordinates: Position(-104.8289, 39.6706)),
  ),
  Passenger(
    name: "REBECCA CAUDILL",
    duration: 21.72,
    earliestPickup: "09:00",
    latestPickup: "09:30",
    pickupAddress: "509 Scott Blvd, Castle Rock, CO",
    pickupLatLng: Point(coordinates: Position(-104.8567, 39.3772)),
    dropoffAddress: "8500 Park Meadows Dr, Lone Tree, CO",
    dropoffLatLng: Point(coordinates: Position(-104.8788, 39.5648)),
  ),
  Passenger(
    name: "SEAN D ALBERTS",
    duration: 24.73,
    earliestPickup: "09:00",
    latestPickup: "09:30",
    pickupAddress: "8871 E Florida Ave, Denver, CO",
    pickupLatLng: Point(coordinates: Position(-104.8848, 39.6894)),
    dropoffAddress: "5554 S Prince St, Littleton, CO",
    dropoffLatLng: Point(coordinates: Position(-105.0147, 39.6162)),
  ),
];