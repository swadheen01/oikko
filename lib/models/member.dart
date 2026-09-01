import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String name; // Bengali name (primary)
  final String nameEnglish; // English name (shown smaller, below Bengali name)
  final String photoUrl;
  final String designation;
  final String schoolName;
  final String bloodGroup;
  final String qualification;
  final String phone;
  final String email;
  /// Association index/registration number.
  final String indexNumber;
  /// Stored as ISO `yyyy-MM-dd`; shown formatted on the profile.
  final String joiningDate;
  final String mpoDate;
  final String role;
  final String status;
  final String? authUid;
  final bool isClaimed;
  /// True for a freshly created Google sign-in that hasn't filled in the
  /// rest of its profile yet — AuthWrapper routes it to the setup screen
  /// until it's cleared (on first profile save).
  final bool needsProfileSetup;
  final DateTime? createdAt;
  /// When this member last opened the Notices / Polls tabs. Anything created
  /// after these times counts as "new" and drives the red badge on those tabs
  /// (see HomeShell). Null for a member who has never opened the tab.
  final DateTime? lastSeenNoticeAt;
  final DateTime? lastSeenPollAt;
  /// Short, human-shareable ID (derived from the Firestore doc ID — see
  /// `FirestoreService.createMemberByAdmin`) that a member can hand a
  /// teacher so they can request to link their login to this record,
  /// instead of searching by name (see `FindProfileScreen`).
  final String memberCode;

  const Member({
    required this.id,
    required this.name,
    this.nameEnglish = '',
    this.photoUrl = '',
    this.designation = '',
    this.schoolName = '',
    this.bloodGroup = '',
    this.qualification = '',
    this.phone = '',
    this.email = '',
    this.indexNumber = '',
    this.joiningDate = '',
    this.mpoDate = '',
    this.role = 'member',
    this.status = 'pending',
    this.authUid,
    this.isClaimed = false,
    this.needsProfileSetup = false,
    this.createdAt,
    this.lastSeenNoticeAt,
    this.lastSeenPollAt,
    this.memberCode = '',
  });

  bool get isAdmin => role == 'admin';
  bool get isApproved => status == 'approved';

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final englishName =
        data['nameEnglish'] ?? data['name_en'] ?? data['nameEn'] ?? '';

    return Member(
      id: doc.id,
      name: data['name'] ?? '',
      nameEnglish: englishName,
      photoUrl: data['photoUrl'] ?? '',
      designation: data['designation'] ?? '',
      schoolName: data['schoolName'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      qualification: data['qualification'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      indexNumber: data['indexNumber'] ?? '',
      joiningDate: data['joiningDate'] ?? '',
      mpoDate: data['mpoDate'] ?? '',
      role: data['role'] ?? 'member',
      status: data['status'] ?? 'pending',
      authUid: data['authUid'],
      isClaimed: data['isClaimed'] ?? false,
      needsProfileSetup: data['needsProfileSetup'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSeenNoticeAt: (data['lastSeenNoticeAt'] as Timestamp?)?.toDate(),
      lastSeenPollAt: (data['lastSeenPollAt'] as Timestamp?)?.toDate(),
      memberCode: data['memberCode'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameEnglish': nameEnglish,
      'name_en': nameEnglish,
      'photoUrl': photoUrl,
      'designation': designation,
      'schoolName': schoolName,
      'bloodGroup': bloodGroup,
      'qualification': qualification,
      'phone': phone,
      'email': email,
      'indexNumber': indexNumber,
      'joiningDate': joiningDate,
      'mpoDate': mpoDate,
      'role': role,
      'status': status,
      'authUid': authUid,
      'isClaimed': isClaimed,
      'memberCode': memberCode,
    };
  }
}
