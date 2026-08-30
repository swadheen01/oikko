import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import 'committee_edit_screen.dart';

/// One elected office bearer of the branch committee. Backed by a Firestore
/// doc (slot `docId`) so admins can edit it; falls back to the bundled
/// default when no doc/override exists yet.
class CommitteeMember {
  final String docId; // fixed slot: c0..c4
  final String nameBn;
  final String nameEn;
  final String designationBn;
  final String designationEn;
  final String assetImage; // bundled fallback photo
  final String photoUrl; // admin-uploaded override ('' = use asset)

  const CommitteeMember({
    required this.docId,
    required this.nameBn,
    required this.nameEn,
    required this.designationBn,
    required this.designationEn,
    required this.assetImage,
    this.photoUrl = '',
  });

  // Fall back to the Bengali value when the English one is blank (most of the
  // imported members only have a Bengali name/designation until an admin adds
  // the English).
  String get name =>
      (LocaleService.isEnglish && nameEn.isNotEmpty) ? nameEn : nameBn;
  String get designation => (LocaleService.isEnglish && designationEn.isNotEmpty)
      ? designationEn
      : designationBn;

  bool get hasPhoto => photoUrl.isNotEmpty || assetImage.isNotEmpty;

  /// Only valid when [hasPhoto] is true; the tile shows an initial avatar
  /// otherwise.
  ImageProvider get image =>
      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : AssetImage(assetImage) as ImageProvider;

  /// Applies a Firestore doc's values on top of the built-in default,
  /// keeping the default for any field the doc leaves blank.
  CommitteeMember withOverrides(Map<String, dynamic> d) {
    String pick(String key, String fallback) {
      final v = (d[key] as String?)?.trim();
      return (v == null || v.isEmpty) ? fallback : v;
    }

    return CommitteeMember(
      docId: docId,
      nameBn: pick('nameBn', nameBn),
      nameEn: pick('nameEn', nameEn),
      designationBn: pick('designationBn', designationBn),
      designationEn: pick('designationEn', designationEn),
      assetImage: assetImage,
      photoUrl: (d['photoUrl'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nameBn': nameBn,
        'nameEn': nameEn,
        'designationBn': designationBn,
        'designationEn': designationEn,
        'photoUrl': photoUrl,
      };
}

/// The branch line shown under every bearer's designation.
String committeeBranchLine() => LocaleService.isEnglish
    ? 'Bangladesh Teachers Association, Baniyachong Upazila Branch, Habiganj.'
    : 'বাংলাদেশ শিক্ষক সমিতি, বানিয়াচং উপজেলা শাখা, হবিগঞ্জ।';

/// Built-in default committee, in order of office. Overridable per slot via
/// Firestore. The first two are also shown directly on the About page.
const List<CommitteeMember> kCommitteeDefaults = [
  CommitteeMember(
    docId: 'c0',
    nameBn: 'মো: আবু তাহের',
    nameEn: 'Md. Abu Taher',
    designationBn: 'সভাপতি',
    designationEn: 'President',
    assetImage: 'assets/first_cut.png',
  ),
  CommitteeMember(
    docId: 'c1',
    nameBn: 'মোহাম্মদ মোফাজ্জল হোসেন',
    nameEn: 'Mohammad Mofazzal Hossain',
    designationBn: 'সাধারণ সম্পাদক',
    designationEn: 'General Secretary',
    assetImage: 'assets/second_cut.png',
  ),
  CommitteeMember(
    docId: 'c2',
    nameBn: 'মো: জুবায়ের মিয়া',
    nameEn: 'Md. Jubayer Miah',
    designationBn: 'সহ-সাধারণ সম্পাদক',
    designationEn: 'Joint General Secretary',
    assetImage: 'assets/third_cut.png',
  ),
  CommitteeMember(
    docId: 'c3',
    nameBn: 'শাহীনুর মিয়া',
    nameEn: 'Shahinur Miah',
    designationBn: 'সাংগঠনিক সম্পাদক',
    designationEn: 'Organizing Secretary',
    assetImage: 'assets/fourth_cut.png',
  ),
  CommitteeMember(
    docId: 'c4',
    nameBn: 'মো. সিরাজুল ইসলাম',
    nameEn: 'Md. Sirajul Islam',
    designationBn: 'সহ-সাংগঠনিক সম্পাদক',
    designationEn: 'Joint Organizing Secretary',
    assetImage: 'assets/fifth_cut.png',
  ),
];

/// A committee member imported from the 2026 committee list (name +
/// designation only, no photo/edit). Shown below the main office bearers.
class ExtraCommitteeMember {
  final String name;
  final String designation;
  const ExtraCommitteeMember({required this.name, required this.designation});
}

/// The remaining 50 committee members (the full 55-member list minus the five
/// office bearers already shown above). Imported from "New committee 2026.xlsx"
/// (Sheet1); Bijoy/SutonnyMJ names were converted to Unicode.
const List<ExtraCommitteeMember> kExtraCommittee = [
  ExtraCommitteeMember(name: 'মোঃ বদরুল আলম', designation: 'সিনিয়র সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'রানা লাল দাশ', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'বিনয় ভূষণ দাস', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'মোঃ জামাল উদ্দীন', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'মোঃ আহসান হাবিব মানিক', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'হরিপদ বৈষ্ণব', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'মোঃ শফিকুল ইসলাম', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'মোঃ আব্দুস সজীব খান', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'মোহাম্মাদ আবু ছাদেক', designation: 'সহ-সভাপতি'),
  ExtraCommitteeMember(name: 'মোঃ জাহিদুল ইসলাম চৌধুরী', designation: 'সহ-সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ নুরুল ইসলাম', designation: 'সহ-সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ সেলিম তালুকদার', designation: 'সহ-সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ শাব্বির আহমেদ শিবলী', designation: 'সহ-সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ জাকির হোসেন', designation: 'সহ-সম্পাদক'),
  ExtraCommitteeMember(name: 'প্রাণকৃষ্ণ দাশ তালুকদার', designation: 'অর্থ সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ আব্দুল্লাহ মিয়া', designation: 'প্রচার সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ আজহারুল ইসলাম', designation: 'সহ-প্রচার সম্পাদক'),
  ExtraCommitteeMember(name: 'দীপক কুমার দাস', designation: 'শিক্ষা বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ দুলাল মিয়া', designation: 'সহ-শিক্ষা বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ জাহিদুল ইসলাম', designation: 'সাংস্কৃতিক সম্পাদক'),
  ExtraCommitteeMember(name: 'আবু মুসা আনসারী', designation: 'সহ-সাংস্কৃতিক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ হুমায়ূন কবির', designation: 'সমাজকল্যাণ সম্পাদক'),
  ExtraCommitteeMember(name: 'গৌর চাঁদ দাস', designation: 'সহ-সমাজকল্যাণ সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ কবির মিয়া', designation: 'দপ্তর সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ জুন্নুন মিয়া', designation: 'সহ-দপ্তর সম্পাদক'),
  ExtraCommitteeMember(name: 'মাহমুদুর রহমান', designation: 'ধর্ম বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'দীপক কুমার ঘোষ', designation: 'সহ-ধর্ম বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'দীপু রানী সরকার', designation: 'মহিলা বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোছাঃ মিলন বেগম', designation: 'সহ-মহিলা বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ শিবলী আহমেদ', designation: 'ক্রীড়া বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোছাঃ জেসমিন চৌধুরী', designation: 'সহ: ক্রীড়া বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ সাইদুর রহমান চৌধুরী', designation: 'স্কাউট সম্পাদক'),
  ExtraCommitteeMember(name: 'ছাহমিদা বেগম', designation: 'সহ-স্কাউট সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ আলাউদ্দিন মিয়া', designation: 'আইন বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'বেনু রঞ্জন দাস', designation: 'সহ-আইন বিষয়ক সম্পাদক'),
  ExtraCommitteeMember(name: 'ইত্তেফাক হোসেন', designation: 'প্রকাশনা সম্পাদক'),
  ExtraCommitteeMember(name: 'মোঃ ছাইফুজ্জামান', designation: 'সহ-প্রকাশনা সম্পাদক'),
  ExtraCommitteeMember(name: 'অঞ্জন দেব', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ জামাল মিয়া', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ আব্দুল তাজ', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ শফিকুল আলম', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'ফখর উদ্দিন আহমদ', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ আহমেদ ইমতিয়াজ বশির', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ ইছহাক আহমদ', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'অনিল চন্দ্র বিশ্ব শর্মা', designation: 'সম্মানিত সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ তোফাজ্জুল হোসেন', designation: 'সদস্য'),
  ExtraCommitteeMember(name: 'বিনয় ভূষণ বিশ্বাস', designation: 'সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ আবিদুর রহমান', designation: 'সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ পারভেজ মিয়া খন্দকার', designation: 'সদস্য'),
  ExtraCommitteeMember(name: 'মোঃ রবিউল মিয়া', designation: 'সদস্য'),
];

/// Number of photographed office bearers shown above the divider (the rest
/// are the imported members, without photos by default).
const int kOfficeBearerCount = 5;

/// The whole 55-member committee as editable slots: the five photographed
/// office bearers (c0..c4) followed by the 50 imported members (c5..c54,
/// no photo / no English until an admin adds them).
final List<CommitteeMember> kAllCommitteeDefaults = [
  ...kCommitteeDefaults,
  for (var i = 0; i < kExtraCommittee.length; i++)
    CommitteeMember(
      docId: 'c${i + kOfficeBearerCount}',
      nameBn: kExtraCommittee[i].name,
      nameEn: '',
      designationBn: kExtraCommittee[i].designation,
      designationEn: '',
      assetImage: '',
    ),
];

/// Live stream of the committee overrides collection.
Stream<QuerySnapshot<Map<String, dynamic>>> watchCommittee() =>
    FirestoreService().collection(FirestorePaths.committee).snapshots();

/// Merges the defaults with any Firestore overrides, preserving slot order.
List<CommitteeMember> mergeCommittee(QuerySnapshot<Map<String, dynamic>>? snap) {
  final byId = <String, Map<String, dynamic>>{
    for (final doc in snap?.docs ?? const []) doc.id: doc.data(),
  };
  return [
    for (final d in kAllCommitteeDefaults)
      byId.containsKey(d.docId) ? d.withOverrides(byId[d.docId]!) : d,
  ];
}

/// "সম্পূর্ণ তালিকা" — the whole elected committee with photos, reached from
/// the About page. Admins get a per-member edit button.
class CommitteeScreen extends StatelessWidget {
  const CommitteeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                isEn ? 'Full committee' : 'সম্পূর্ণ তালিকা',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 4),
              Text(
                isEn ? 'Executive committee' : 'কার্যনির্বাহী পরিষদ',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.lg),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: watchCommittee(),
                builder: (context, snapshot) {
                  final members = mergeCommittee(snapshot.data);
                  return ValueListenableBuilder<bool>(
                    valueListenable: AdminSession.isAdmin,
                    builder: (context, isAdmin, _) {
                      return Column(
                        children: [
                          for (var i = 0; i < members.length; i++) ...[
                            // Separator between the five photographed office
                            // bearers and the rest of the committee.
                            if (i == kOfficeBearerCount) ...[
                              const _CommitteeDivider(),
                              const SizedBox(height: AppDimensions.md),
                            ],
                            PremiumCard(
                              child: CommitteeMemberTile(
                                serial: i + 1,
                                member: members[i],
                                onEdit: isAdmin
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CommitteeEditScreen(member: members[i]),
                                          ),
                                        )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.sm),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Photo + name + "designation, branch line" — used both on the About page
/// (top two, read-only) and in the full committee list (admin gets [onEdit]).
class CommitteeMemberTile extends StatelessWidget {
  final CommitteeMember member;
  final VoidCallback? onEdit;

  /// Position in the committee (1-based), shown in the avatar when the
  /// member has no photo.
  final int? serial;

  const CommitteeMemberTile({
    super.key,
    required this.member,
    this.onEdit,
    this.serial,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (member.hasPhoto)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowContact,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image(image: member.image, fit: BoxFit.cover),
          )
        else
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              serial != null
                  ? '$serial'
                  : (member.name.isNotEmpty ? member.name.characters.first : '?'),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                member.designation,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                committeeBranchLine(),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded, color: AppColors.primary),
            tooltip: LocaleService.isEnglish ? 'Edit' : 'সম্পাদনা',
          ),
      ],
    );
  }
}

/// The line that separates the five photographed office bearers from the rest
/// of the committee.
class _CommitteeDivider extends StatelessWidget {
  const _CommitteeDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
          child: Text(
            LocaleService.isEnglish ? 'Other members' : 'অন্যান্য সদস্য',
            style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}
