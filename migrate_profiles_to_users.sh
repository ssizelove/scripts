#!/usr/bin/env bash
set -euo pipefail

# Run from your project root (contains pubspec.yaml)
if [[ ! -f "pubspec.yaml" ]]; then
  echo "❌ Run this from your Flutter project root (pubspec.yaml not found)."
  exit 1
fi

mkdir -p lib/_attic

# 1) Overwrite app_providers.dart with a users-centric version
cat > lib/app_providers.dart <<'EOF'
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Collection names
const kUsersCol = 'users';
const kHouseholdsCol = 'households';

/// User model (stored in Firestore at users/{uid})
@immutable
class Profile {
  final String uid;
  final String email;
  final String displayName;
  final String avatar;
  final String? householdID;
  final DateTime? createdAt;

  const Profile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.avatar,
    required this.householdID,
    required this.createdAt,
  });

  factory Profile.fromMap(String id, Map<String, dynamic> map) {
    return Profile(
      uid: id,
      email: (map['email'] ?? '') as String,
      displayName: (map['displayName'] ?? 'You') as String,
      avatar: (map['avatar'] ?? 'assets/avatars/avatar_01.png') as String,
      householdID: map['householdID'] as String?,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Firebase Auth stream
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Current UID
final uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// Current user's Firestore doc at users/{uid}
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) {
    return Stream<Profile?>.value(null);
  }
  return FirebaseFirestore.instance
      .collection(kUsersCol)
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Profile.fromMap(d.id, d.data()!) : null);
});

/// Resolve a household name from its ID
Stream<String?> householdNameStream(String? householdID) {
  if (householdID == null || householdID.isEmpty) {
    return Stream<String?>.value(null);
  }
  final docRef =
      FirebaseFirestore.instance.collection(kHouseholdsCol).doc(householdID);
  return docRef.snapshots().map((d) => d.data()?['name'] as String?);
}
EOF

# 2) Overwrite services/profile_service.dart to write users/{uid}
mkdir -p lib/services
cat > lib/services/profile_service.dart <<'EOF'
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_providers.dart'; // for kUsersCol

Future<void> createProfileForCurrentUser({
  required String uid,
  required String email,
  String displayName = 'You',
  String avatar = 'assets/avatars/avatar_01.png',
}) async {
  final db = FirebaseFirestore.instance;
  final doc = db.collection(kUsersCol).doc(uid);
  await doc.set({
    'ownerUID': uid,
    'email': email,
    'displayName': displayName,
    'avatar': avatar,
    'householdID': null,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
EOF

# 3) Optional: park any old profile-related files
for f in \
  lib/pages/profile_picker.dart \
  lib/pages/profile_editor.dart \
  lib/profile_* \
  lib/pages/profiles_* \
  lib/_attic/profile_* \
; do
  if [[ -f "$f" ]]; then
    echo "🗄️  moving $f -> lib/_attic/"
    mv "$f" "lib/_attic/$(basename "$f")"
  fi
done

# 4) Safety scan for leftovers
echo "🔎 Searching for lingering 'profiles' references..."
grep -RIn --exclude-dir=build --exclude-dir=.dart_tool --exclude-dir=ios --exclude-dir=android \
  -E '\bprofiles\b|kProfilesCol' lib || true

echo "📦 flutter pub get"
fvm flutter pub get || flutter pub get

echo "✅ Done. Rebuild recommended:"
echo "    fvm flutter clean && fvm flutter run -d \"iPhone 16 Plus\""
