import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pdf_progress_dialog.dart';

class PdfDisplayOptionsSheet extends StatefulWidget {
  final String defaultFileName;
  final bool initialShowItemDetails;
  final bool initialShowDescription;
  final bool initialShowPaymentStatus;
  final bool initialShowPaymentInfo;
  final Future<void> Function({
    required String fileName,
    required bool showItemDetails,
    required bool showDescription,
    required bool showPaymentStatus,
    required bool showPaymentInfo,
  }) onApply;

  const PdfDisplayOptionsSheet({
    super.key,
    required this.defaultFileName,
    this.initialShowItemDetails = true,
    this.initialShowDescription = false,
    this.initialShowPaymentStatus = false,
    this.initialShowPaymentInfo = true,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String defaultFileName,
    bool initialShowItemDetails = true,
    bool initialShowDescription = false,
    bool initialShowPaymentStatus = false,
    bool initialShowPaymentInfo = true,
    required Future<void> Function({
      required String fileName,
      required bool showItemDetails,
      required bool showDescription,
      required bool showPaymentStatus,
      required bool showPaymentInfo,
    }) onApply,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PdfDisplayOptionsSheet(
        defaultFileName: defaultFileName,
        initialShowItemDetails: initialShowItemDetails,
        initialShowDescription: initialShowDescription,
        initialShowPaymentStatus: initialShowPaymentStatus,
        initialShowPaymentInfo: initialShowPaymentInfo,
        onApply: onApply,
      ),
    );
  }

  @override
  State<PdfDisplayOptionsSheet> createState() => _PdfDisplayOptionsSheetState();
}

class _PdfDisplayOptionsSheetState extends State<PdfDisplayOptionsSheet> {
  late TextEditingController _fileNameController;
  late bool _showItemDetails;
  late bool _showDescription;
  late bool _showPaymentStatus;
  late bool _showPaymentInfo;
  bool _editingName = false;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(text: widget.defaultFileName);
    _showItemDetails = widget.initialShowItemDetails;
    _showDescription = widget.initialShowDescription;
    _showPaymentStatus = widget.initialShowPaymentStatus;
    _showPaymentInfo = widget.initialShowPaymentInfo;
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'What to display on PDF?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Filename Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _editingName
                            ? TextField(
                                controller: _fileNameController,
                                autofocus: true,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => setState(() => _editingName = false),
                              )
                            : Text(
                                _fileNameController.text.trim().isNotEmpty
                                    ? _fileNameController.text.trim()
                                    : widget.defaultFileName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _editingName = !_editingName),
                        child: Text(
                          _editingName ? 'Done' : 'Edit Name',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Checklist Items
                _DisplayOptionRow(
                  label: 'Item Details',
                  value: _showItemDetails,
                  onChanged: (v) => setState(() => _showItemDetails = v),
                ),
                _DisplayOptionRow(
                  label: 'Description',
                  value: _showDescription,
                  onChanged: (v) => setState(() => _showDescription = v),
                ),
                _DisplayOptionRow(
                  label: 'Payment status',
                  value: _showPaymentStatus,
                  onChanged: (v) => setState(() => _showPaymentStatus = v),
                ),
                _DisplayOptionRow(
                  label: 'Payment Information',
                  value: _showPaymentInfo,
                  onChanged: (v) => setState(() => _showPaymentInfo = v),
                ),

                const SizedBox(height: 20),

                // Action Buttons (Cancel / Apply)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isApplying
                            ? null
                            : () async {
                                setState(() => _isApplying = true);
                                final name = _fileNameController.text.trim().isNotEmpty
                                    ? _fileNameController.text.trim()
                                    : widget.defaultFileName;
                                Navigator.pop(context);
                                
                                // Show loading progress overlay on screen
                                PdfProgressDialog.show(context, message: 'Preparing Statement PDF...');
                                try {
                                  await widget.onApply(
                                    fileName: name,
                                    showItemDetails: _showItemDetails,
                                    showDescription: _showDescription,
                                    showPaymentStatus: _showPaymentStatus,
                                    showPaymentInfo: _showPaymentInfo,
                                  );
                                } finally {
                                  PdfProgressDialog.hide();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isApplying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Apply',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisplayOptionRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DisplayOptionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
