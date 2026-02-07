import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
// Ensure this import matches your file structure exactly
import '../../providers/family_provider.dart';

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  // We keep track of loading state locally for the dialog
  bool _isSending = false;

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final labelController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: !_isSending, // Prevent closing while sending
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Family Member'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('An invitation will be sent to their email.'),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Enter family member\'s email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isSending,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    hintText: 'e.g., Mom, Child',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  enabled: !_isSending,
                ),
              ],
            ),
            actions: [
              if (!_isSending)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ElevatedButton(
                onPressed: _isSending
                    ? null
                    : () async {
                  final email = emailController.text.trim();
                  final label = labelController.text.trim();

                  if (email.isEmpty || label.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  // 1. Show Loading in Dialog
                  setState(() => _isSending = true);

                  // 2. Send Request via Provider
                  await ref
                      .read(familyControllerProvider.notifier)
                      .sendRequest(email, label);

                  // 3. Check Result
                  // We check the provider state to see if it failed
                  final state = ref.read(familyControllerProvider);

                  if (context.mounted) {
                    // Stop Loading
                    setState(() => _isSending = false);
                    Navigator.pop(context); // Close Dialog

                    if (state.hasError) {
                      // SHOW THE REAL ERROR (e.g. "Cannot link to yourself")
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.error
                                .toString()
                                .replaceAll('Exception:', '')
                                .trim(),
                          ),
                          backgroundColor: AppColors.error,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      // SHOW SUCCESS
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Request sent successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                },
                child: _isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Send Invite'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family & Dependents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
      // Add RefreshIndicator so users can check for new requests
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyMembersProvider);
          ref.invalidate(incomingRequestsProvider);
          // Wait for providers to refresh
          await Future.wait([
            ref.refresh(familyMembersProvider.future),
            ref.refresh(incomingRequestsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Needed for RefreshIndicator
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Pending Requests Section ---
              requestsAsync.when(
                data: (requests) {
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'You have ${requests.length} pending request(s)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Pending Requests', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...requests.map((req) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.person_outline, color: AppColors.primary),
                          ),
                          title: Text(req.requester.fullName),
                          subtitle: Text('Wants to link as: ${req.label}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: AppColors.success, size: 32),
                                onPressed: () => ref
                                    .read(familyControllerProvider.notifier)
                                    .respondToRequest(req.linkId, true),
                                tooltip: 'Accept',
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: AppColors.error, size: 32),
                                onPressed: () => ref
                                    .read(familyControllerProvider.notifier)
                                    .respondToRequest(req.linkId, false),
                                tooltip: 'Reject',
                              ),
                            ],
                          ),
                        ),
                      )),
                      const Divider(height: 32),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('Error loading requests: $e', style: const TextStyle(color: Colors.red)),
                ),
              ),

              // --- Active Members Section ---
              const Text('Synced Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              const Text(
                'Switch to these profiles from the main screen.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.family_restroom, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'No family members linked yet.\nTap "Add Member" to invite someone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: CircleAvatar(
                          backgroundImage: member.profile.avatarUrl != null
                              ? NetworkImage(member.profile.avatarUrl!)
                              : null,
                          child: member.profile.avatarUrl == null
                              ? Text(member.profile.fullName[0].toUpperCase())
                              : null,
                        ),
                        title: Text(member.profile.fullName),
                        subtitle: Text(member.label),
                        trailing: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                        onTap: () {
                          // Navigate to Profile Screen to switch
                          // Or call switch directly here if desired
                          ref.read(familyControllerProvider.notifier).switchAccount(member.profile.id);
                          Navigator.pop(context); // Go back to profile
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}