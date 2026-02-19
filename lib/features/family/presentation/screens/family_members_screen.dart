import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/family_provider.dart';

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  bool _isSending = false;

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final labelController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: !_isSending,
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

                  setState(() => _isSending = true);

                  await ref
                      .read(familyControllerProvider.notifier)
                      .sendRequest(email, label);

                  final state = ref.read(familyControllerProvider);

                  if (context.mounted) {
                    setState(() => _isSending = false);
                    Navigator.pop(context);

                    if (state.hasError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.error.toString().replaceAll('Exception:', '').trim(),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } else {
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
    final outgoingAsync = ref.watch(outgoingRequestsProvider); // Watch outgoing requests

    return Scaffold(
      appBar: AppBar(title: const Text('Family & Dependents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyMembersProvider);
          ref.invalidate(incomingRequestsProvider);
          ref.invalidate(outgoingRequestsProvider);
          await Future.wait([
            ref.refresh(familyMembersProvider.future),
            ref.refresh(incomingRequestsProvider.future),
            ref.refresh(outgoingRequestsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Incoming Requests (Needs Action) ---
              requestsAsync.when(
                data: (requests) {
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You have ${requests.length} incoming request(s)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...requests.map((req) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(req.requester.fullName[0].toUpperCase()),
                          ),
                          title: Text(req.requester.fullName),
                          subtitle: Text('Wants to link as: ${req.label}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: AppColors.success),
                                onPressed: () => ref.read(familyControllerProvider.notifier).respondToRequest(req.linkId, true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: AppColors.error),
                                onPressed: () => ref.read(familyControllerProvider.notifier).respondToRequest(req.linkId, false),
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
                error: (e, _) => const SizedBox.shrink(),
              ),

              // --- 2. Outgoing Requests (Pending Status) ---
              outgoingAsync.when(
                data: (requests) {
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sent Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...requests.map((req) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(Icons.hourglass_empty, color: Colors.grey),
                          ),
                          title: Text(req.profile.fullName),
                          subtitle: Text('Invitation sent to ${req.profile.email}'),
                          trailing: Chip(
                            label: const Text('Pending'),
                            backgroundColor: Colors.orange.shade50,
                            labelStyle: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                          ),
                          onLongPress: () {
                            // Optional: Allow cancelling request on long press
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Cancel Request?'),
                                content: Text('Do you want to cancel the invitation to ${req.profile.fullName}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                                  TextButton(
                                      onPressed: () {
                                        ref.read(familyControllerProvider.notifier).cancelRequest(req.linkId);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Yes, Cancel')
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )),
                      const Divider(height: 32),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // --- 3. Active Members ---
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
                          ref.read(familyControllerProvider.notifier).switchAccount(member.profile.id);
                          Navigator.pop(context);
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