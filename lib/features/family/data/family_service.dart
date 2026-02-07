import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_profile.dart';

class FamilyService {
  FamilyService._();
  static final instance = FamilyService._();
  final _supabase = Supabase.instance.client;

  /// Send a connection request by email (Privacy safe)
  Future<void> sendFamilyRequest(String email, String label) async {
    print('[FamilyService] Sending request to: $email');

    try {
      final response = await _supabase.rpc('send_family_request', params: {
        'target_email': email.trim(),
        'relation_label': label.trim(),
      });

      print('[FamilyService] RPC Response: $response');

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to send request');
      }
    } catch (e) {
      print('[FamilyService] Error sending request: $e');
      rethrow;
    }
  }

  /// Get list of active family members (Accepted links)
  Future<List<FamilyMember>> getActiveFamilyMembers() async {
    try {
      final response = await _supabase
          .from('family_account_links')
          .select('*, target:profiles!target_user_id(*)')
          .eq('requester_id', _supabase.auth.currentUser!.id)
          .eq('status', 'accepted');

      final List<dynamic> data = response as List<dynamic>;

      // Filter out entries where the target profile is missing (null)
      // This prevents the "Null is not a subtype of Map" crash
      return data
          .where((item) => item['target'] != null)
          .map((e) => FamilyMember.fromJson(e))
          .toList();

    } catch (e) {
      print('[FamilyService] Error fetching members: $e');
      return [];
    }
  }

  /// Get pending incoming requests (Where I am the target)
  Future<List<FamilyRequest>> getIncomingRequests() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      print('[FamilyService] Fetching requests for target_user_id: $userId');

      final response = await _supabase
          .from('family_account_links')
          .select('*, requester:profiles!requester_id(*)')
          .eq('target_user_id', userId)
          .eq('status', 'pending');

      final List<dynamic> data = response as List<dynamic>;
      print('[FamilyService] Raw response count: ${data.length}');

      // CRITICAL FIX: Filter out requests where 'requester' is null.
      // This happens if the user who sent the request has a broken/missing profile.
      final validRequests = data.where((item) {
        if (item['requester'] == null) {
          print('[FamilyService] Warning: Found request ${item['id']} with MISSING requester profile. Ignoring.');
          return false;
        }
        return true;
      }).toList();

      print('[FamilyService] Valid requests after filtering: ${validRequests.length}');

      return validRequests.map((e) => FamilyRequest.fromJson(e)).toList();
    } catch (e) {
      print('[FamilyService] Error fetching requests: $e');
      return []; // Return empty list to prevent UI crash
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

  /// Revoke access (Unlink)
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
      linkId: json['id'],
      // We already filtered for nulls in the service, so this is safe now
      profile: UserProfile.fromJson(json['target']),
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
      // We already filtered for nulls in the service, so this is safe now
      requester: UserProfile.fromJson(json['requester']),
      label: json['label'] ?? 'Family',
    );
  }
}