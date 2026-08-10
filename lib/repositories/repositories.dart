// lib/repositories/repositories.dart
//
// Barrel export for the repository layer. The app is on-device first: import
// this and use the *OnDevice* implementations. To enable a backend, implement
// the corresponding seam (see each file) and swap the constructor in main().
export 'auth_repository.dart';
export 'scan_repository.dart';
export 'leads_repository.dart';
