import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../models/link_request.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import 'profile_match_screen.dart';

class FindProfileScreen extends StatefulWidget {
  final String currentUserUid;
  final String currentPhone;

  const FindProfileScreen({
    super.key,
    required this.currentUserUid,
    required this.currentPhone,
  });

  @override
  State<FindProfileScreen> createState() => _FindProfileScreenState();
}

class _FindProfileScreenState extends State<FindProfileScreen> {
  final _searchController = TextEditingController();
  final _codeController = TextEditingController();
  final _firestoreService = FirestoreService();
  String _query = '';
  bool _isLookingUpCode = false;
  String? _codeError;

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<List<Member>> _searchMembers() async {
    final q = _query.trim();
    if (q.isEmpty) {
      return const [];
    }

    final snapshot = await _firestoreService.searchUnclaimedByName(q);
    return snapshot.docs.map(Member.fromDoc).toList();
  }

  void _goToMatch(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileMatchScreen(
          member: member,
          currentUserUid: widget.currentUserUid,
          currentPhone: widget.currentPhone,
        ),
      ),
    );
  }

  Future<void> _lookupByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLookingUpCode = true;
      _codeError = null;
    });

    final doc = await _firestoreService.findUnclaimedMemberByCode(code);

    if (!mounted) return;
    setState(() => _isLookingUpCode = false);

    if (doc == null) {
      setState(() => _codeError = AppStrings.idNotFound);
      return;
    }

    _goToMatch(Member.fromDoc(doc));
  }

  @override
  Widget build(BuildContext context) {
    // Once a request is in, showing the search UI again is misleading — the
    // user has no idea anything happened and can fire off duplicate
    // requests, each of which becomes another card for the admin to review.
    return GradientScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchMyPendingLinkRequest(widget.currentUserUid),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isNotEmpty) {
            return _PendingRequestView(request: LinkRequest.fromDoc(docs.first));
          }
          return _buildSearchView(context);
        },
      ),
    );
  }

  Widget _buildSearchView(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleService.isEnglish ? 'Find my profile' : 'আমার প্রোফাইল খুঁজুন',
              style: AppTextStyles.h1,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              LocaleService.isEnglish
                  ? 'If the admin gave you a Member ID, enter it below for the fastest match.'
                  : 'অ্যাডমিন যদি আপনাকে সদস্য আইডি দিয়ে থাকেন, দ্রুত মেলাতে নিচে সেটি লিখুন।',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.lg),

            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.connectWithId, style: AppTextStyles.h3),
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTextStyles.bodyLarge.copyWith(letterSpacing: 1.5),
                          decoration: InputDecoration(
                            hintText: AppStrings.enterMemberId,
                            prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primary),
                          ),
                          onSubmitted: (_) => _lookupByCode(),
                        ),
                      ),
                    ],
                  ),
                  if (_codeError != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Text(_codeError!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger)),
                  ],
                  const SizedBox(height: AppDimensions.md),
                  GradientButton(
                    label: AppStrings.connect,
                    isLoading: _isLookingUpCode,
                    onPressed: _lookupByCode,
                    icon: Icons.link_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.lg),
            Center(
              child: Text(
                AppStrings.orSearchByName,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: LocaleService.isEnglish ? 'Enter name or school' : 'নাম বা বিদ্যালয় লিখুন',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Expanded(
              child: FutureBuilder<List<Member>>(
                future: _searchMembers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    final isEmptyQuery = _query.trim().isEmpty;
                    return Center(
                      child: Text(
                        LocaleService.isEnglish
                            ? (isEmptyQuery ? 'Type a name/school to search' : 'No profile found')
                            : (isEmptyQuery ? 'খুঁজতে নাম/বিদ্যালয় লিখুন' : 'কোনো প্রোফাইল পাওয়া যায়নি'),
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  final members = snapshot.data!;
                  return ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return PremiumCard(
                        onTap: () => _goToMatch(member),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                member.name.isNotEmpty ? member.name[0] : '?',
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(member.name, style: AppTextStyles.h3),
                                  if (member.nameEnglish.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      member.nameEnglish,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    member.schoolName,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
    );
  }
}

/// Shown instead of the search UI while an admin review is outstanding.
/// Also the only place a user in this state can sign out — without it they
/// are stuck on the linking screen with no route back to the login page,
/// since this screen sits outside the shell that normally carries the
/// drawer/logout.
class _PendingRequestView extends StatelessWidget {
  final LinkRequest request;

  const _PendingRequestView({required this.request});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumCard(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 32),
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  LocaleService.isEnglish ? 'Waiting for approval' : 'অনুমোদনের অপেক্ষায়',
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  LocaleService.isEnglish
                      ? 'Your request has been sent to the admin. Once approved, your profile and payment history will appear here automatically.'
                      : 'আপনার অনুরোধ অ্যাডমিনের কাছে পাঠানো হয়েছে। অনুমোদনের পর আপনার প্রোফাইল ও পেমেন্ট তথ্য এখানে স্বয়ংক্রিয়ভাবে দেখা যাবে।',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          TextButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              AppSnackbar.success(
                LocaleService.isEnglish ? 'Logged out' : 'লগ আউট হয়েছে',
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(AppStrings.logout),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
