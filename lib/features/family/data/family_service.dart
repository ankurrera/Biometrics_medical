import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_profile.dart';

class FamilyService {
  FamilyService._();
  static final instance = FamilyService._();
  final _supabase = Supabase.instance.client;

  /// Send a connection request by email
  Future<void> sendFamilyRequest(String email, String label) async {
    try {
      final response = await _supabase.rpc('send_family_request', params: {
        'target_email': email.trim(),
        'relation_label': label.trim(),
      });

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to send request');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get list of active family members (Bidirectional)
  /// Returns the *other* person in the link.
  Future<List<FamilyMember>> getActiveFamilyMembers() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Fetch links where I am Requester OR Target, and status is accepted
      final response = await _supabase
          .from('family_account_links')
          .select('*, requester:profiles!requester_id(*), target:profiles!target_user_id(*)')
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,target_user_id.eq.$userId');

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        // Determine relationship direction to show the OTHER person
        final isMeRequester = item['requester_id'] == userId;
        final otherProfileMap = isMeRequester ? item['target'] : item['requester'];

        if (otherProfileMap == null) return null;

        return FamilyMember(
          linkId: item['id'],
          profile: UserProfile.fromJson(otherProfileMap),
          label: item['label'] ?? 'Family',
        );
      }).whereType<FamilyMember>().toList();

    } catch (e) {
      return [];
    }
  }

  /// Get pending incoming requests (Where I am the target)
  Future<List<FamilyRequest>> getIncomingRequests() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('family_account_links')
          .select('*, requester:profiles!requester_id(*)')
          .eq('target_user_id', userId)
          .eq('status', 'pending');

      final List<dynamic> data = response as List<dynamic>;

      return data
          .where((item) => item['requester'] != null)
          .map((e) => FamilyRequest.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get pending outgoing requests (Where I am the requester)
  /// NEW: Added this method to show "Sent Requests"
  Future<List<FamilyMember>> getOutgoingRequests() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('family_account_links')
          .select('*, target:profiles!target_user_id(*)')
          .eq('requester_id', userId)
          .eq('status', 'pending');

      final List<dynamic> data = response as List<dynamic>;

      // Map to FamilyMember, where profile is the Target
      return data
          .where((item) => item['target'] != null)
          .map((item) => FamilyMember(
        linkId: item['id'],
        profile: UserProfile.fromJson(item['target']),
        label: item['label'] ?? 'Family',
      ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Accept or Reject a request
  Future<void> updateRequestStatus(String linkId, bool accept) async {
    final status = accept ? 'accepted' : 'rejected';
    await _supabase
        .from('family_account_links')
        .update({'status': status})
        .eq('id', linkId);
  }

  /// Revoke/Cancel access
  Future<void> revokeAccess(String linkId) async {
    await _supabase
        .from('family_account_links')
        .update({'status': 'revoked'})
        .eq('id', linkId);
  }
}

// --- Data Models ---

class FamilyMember {
  final String linkId;
  final UserProfile profile;
  final String label;

  FamilyMember({required this.linkId, required this.profile, required this.label});

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      linkId: json['linkId'] ?? json['id'],
      profile: UserProfile.fromJson(json['profile'] ?? json['target'] ?? json['requester']),
      label: json['label'] ?? 'Family',
    );
  }
}

class FamilyRequest {
  final String linkId;
  final UserProfile requester;
  final String label;

  FamilyRequest({required this.linkId, required this.requester, required this.label});

  factory FamilyRequest.fromJson(Map<String, dynamic> json) {
    return FamilyRequest(
      linkId: json['id'],
      requester: UserProfile.fromJson(json['requester']),
      label: json['label'] ?? 'Family',
    );
  }
}