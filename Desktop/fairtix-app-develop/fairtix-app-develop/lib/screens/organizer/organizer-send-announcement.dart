import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'organizer-scaffold.dart';

class OrganizerSendAnnouncementScreen extends StatefulWidget {
  const OrganizerSendAnnouncementScreen({super.key});

  @override
  State<OrganizerSendAnnouncementScreen> createState() =>
      _OrganizerSendAnnouncementScreenState();
}

class _OrganizerSendAnnouncementScreenState
    extends State<OrganizerSendAnnouncementScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  static const int _maxLength = 500;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendAnnouncement() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Announcement Sent'),
        content: const Text(
          'Your announcement has been sent to all ticket holders via '
          'in-app, email, and push notification.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _messageController.text.length;

    return OrganizerScaffold(
      pageTitle: 'Send Announcement',
      activeItem: OrganizerNavItem.dashboard,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.primaryPurple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This will be sent to users who have purchased '
                        'tickets from you, via in-app, email, and push '
                        'notification.',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('New Announcement', style: AppTextStyles.h3),
                    const SizedBox(height: 20),
                    const Text('SUBJECT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGray,
                          letterSpacing: 0.6,
                        )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subjectController,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'e.g. Important update for ticket holders',
                        hintStyle: AppTextStyles.bodyGray,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.primaryPurple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('MESSAGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGray,
                          letterSpacing: 0.6,
                        )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      maxLength: _maxLength,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Write your announcement here...',
                        hintStyle: AppTextStyles.bodyGray,
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.primaryPurple),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$charCount / $_maxLength',
                          style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_alt_outlined,
                                size: 18, color: AppColors.textGray),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: AppTextStyles.bodyGray,
                                children: const [
                                  TextSpan(text: 'Sending to: '),
                                  TextSpan(
                                    text: 'all ticket holders',
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _sendAnnouncement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Send Announcement'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Drafts are coming soon.'),
                        ),
                      );
                    },
                    child: const Text('Drafts',
                        style: TextStyle(
                            color: AppColors.textGray,
                            decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(width: 24),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Scheduled announcements are coming soon.'),
                        ),
                      );
                    },
                    child: const Text('Scheduled Announcements',
                        style: TextStyle(
                            color: AppColors.textGray,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}