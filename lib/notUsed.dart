// List<ZoomOutTurnAngle> calculateTurnAngleZoomOut(
//   List<LatLng> polypoints,
// ) {
//   List<ZoomOutTurnAngle> allCircles = [];

//   for (int i = 0; i < polypoints.length - 2; i++) {
//     double initialBearing = calculateBearing(
//         polypoints[i].latitude,
//         polypoints[i].longitude,
//         polypoints[i + 1].latitude,
//         polypoints[i + 1].longitude);
//     double finalBearing = calculateBearing(
//         polypoints[i + 1].latitude,
//         polypoints[i + 1].longitude,
//         polypoints[i + 2].latitude,
//         polypoints[i + 2].longitude);

//     double turnAngle = finalBearing - initialBearing;

//     if (turnAngle < 0) {
//       turnAngle = turnAngle.abs();
//       if (turnAngle > 180) {
//         turnAngle -= 360;
//         if (turnAngle < 0) {
//           turnAngle = turnAngle.abs();
//         }
//       }
//     } else if (turnAngle > 180) {
//       turnAngle -= 360;
//       if (turnAngle < 0) {
//         turnAngle = turnAngle.abs();
//       }
//     }
//     if (turnAngle > 40) {
//       allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "red"));
//     } else if (turnAngle < 40 && turnAngle > 20) {
//       allCircles.add(ZoomOutTurnAngle(1, polypoints[i + 1], "orange"));
//     } else {}
//   }
//   List<ZoomOutTurnAngle> returnCircles = checkForDistanceInCircles();

//   return returnCircles;
// }

// Future<void> loadLatlngToCurves(
//     List<LatLng> polylineCoordinates, List<double> curves) async {
//   curveWithLatlng.clear();

//   for (int i = 0; i < curves.length; i++) {
//     curveWithLatlng.add(curveAndLatlng(curves[i], polylineCoordinates[i + 1]));
//   }
// }


