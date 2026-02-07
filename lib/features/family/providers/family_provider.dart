import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/models/user_profile.dart';
import '../data/family_service.dart';

// --- State Providers ---

final activeProfileIdProvider = StateProvider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.id;
});

final activeContextProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final activeId = ref.watch(activeProfileIdProvider);
  final authUser = ref.watch(authStateProvider).valueOrNull;

  if (activeId == null || authUser == null) return null;

  if (activeId == authUser.id) {
    return ref.watch(currentProfileProvider).valueOrNull;
  }

  try {
    final data = await SupabaseService.instance.client
        .from('profiles')
        .select()
        .eq('id', activeId)
        .single();
    return UserProfile.fromJson(data);
  } catch (e) {
    return null;
  }
});

// --- Family Data Providers ---

final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  return await FamilyService.instance.getActiveFamilyMembers();
});

final incomingRequestsProvider = StreamProvider<List<FamilyRequest>>((ref) async* {
  yield await FamilyService.instance.getIncomingRequests();
});

// NEW: Provider for outgoing requests (Sent by me, pending)
final outgoingRequestsProvider = StreamProvider<List<FamilyMember>>((ref) async* {
  yield await FamilyService.instance.getOutgoingRequests();
});

// --- Controller ---

class FamilyController extends StateNotifier<AsyncValue<void>> {
  FamilyController(this.ref) : super(const AsyncValue.data(null));
  final Ref ref;

  Future<void> sendRequest(String email, String label) async {
    state = const AsyncValue.loading();
    try {
      await FamilyService.instance.sendFamilyRequest(email, label);
      // REFRESH outgoing requests immediately so the UI updates
      ref.invalidate(outgoingRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> respondToRequest(String linkId, bool accept) async {
    try {
      await FamilyService.instance.updateRequestStatus(linkId, accept);
      ref.invalidate(incomingRequestsProvider);
      if (accept) ref.invalidate(familyMembersProvider);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> cancelRequest(String linkId) async {
    try {
      await FamilyService.instance.revokeAccess(linkId);
      ref.invalidate(outgoingRequestsProvider);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> switchAccount(String? targetUserId) async {
    final currentUserId = ref.read(authStateProvider).valueOrNull?.id;
    ref.read(activeProfileIdProvider.notifier).state = targetUserId ?? currentUserId;
  }
}

final familyControllerProvider = StateNotifierProvider<FamilyController, AsyncValue<void>>((ref) {
  return FamilyController(ref);
});