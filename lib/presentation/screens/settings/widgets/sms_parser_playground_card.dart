// [TEMP DIAGNOSTIC]
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/sms_automation/models/parsed_sms_dto.dart';
import '../../../../core/sms_automation/sms_parser_engine.dart';
import '../../../../core/sms_automation/strategies/sms_parser_strategy.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Temporary diagnostic widget allowing manual testing of raw SMS strings
/// against the SMS parsing pipeline without physical incoming SMS.
// [TEMP DIAGNOSTIC]
class SmsParserPlaygroundCard extends StatefulWidget {
  final bool initiallyExpanded;

  const SmsParserPlaygroundCard({
    super.key,
    this.initiallyExpanded = false,
  });

  @override
  State<SmsParserPlaygroundCard> createState() =>
      _SmsParserPlaygroundCardState();
}

class _SmsParserPlaygroundCardState extends State<SmsParserPlaygroundCard> {
  static const List<String> _senderPresets = [
    'VF-Cash',
    'InstaPay',
    'BM',
    'NBE',
    'CIB',
    'OrangeCash',
    'WE',
  ];

  late bool _isExpanded;
  final TextEditingController _senderController =
      TextEditingController(text: 'VF-Cash');
  final TextEditingController _bodyController = TextEditingController();

  String _selectedPreset = 'VF-Cash';
  bool _tested = false;
  ParsedSmsDto? _result;
  SmsRejectionInfo? _rejectionInfo;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onPresetSelected(String preset) {
    setState(() {
      _selectedPreset = preset;
      _senderController.text = preset;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      setState(() {
        _bodyController.text = text;
      });
    }
  }

  void _testParse() {
    final sender = _senderController.text.trim();
    final body = _bodyController.text.trim();

    if (sender.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم المرسل ونص الرسالة أولاً'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final engine = SmsParserEngine();
    final parsed = engine.parse(sender, body);

    setState(() {
      _tested = true;
      _result = parsed;
      _rejectionInfo = engine.lastRejection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: _buildHeader(),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              _buildPresetChips(),
              const SizedBox(height: 12),
              _buildSenderInput(),
              const SizedBox(height: 12),
              _buildBodyInput(),
              const SizedBox(height: 12),
              _buildActionButton(),
              if (_tested) ...[
                const SizedBox(height: 14),
                _buildResultCard(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.science_outlined,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'مختبر فحص الرسائل (SMS Parser Playground)',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'DIAGNOSTIC',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: AppColors.textSecondary(context),
        ),
      ],
    );
  }

  Widget _buildPresetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _senderPresets.map((preset) {
        final isSelected = _selectedPreset == preset &&
            _senderController.text.trim() == preset;
        return FilterChip(
          label: Text(preset),
          selected: isSelected,
          onSelected: (_) => _onPresetSelected(preset),
          selectedColor: AppColors.primary.withAlpha(40),
          checkmarkColor: AppColors.primary,
          labelStyle: AppTextStyles.bodySmall.copyWith(
            color:
                isSelected ? AppColors.primary : AppColors.textPrimary(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color:
                  isSelected ? AppColors.primary : AppColors.divider(context),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSenderInput() {
    return TextField(
      controller: _senderController,
      decoration: InputDecoration(
        labelText: 'اسم المرسل (Sender)',
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary(context),
        ),
        prefixIcon: const Icon(Icons.send_outlined, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.divider(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.divider(context)),
        ),
      ),
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textPrimary(context),
      ),
      onChanged: (val) {
        if (_selectedPreset != val) {
          setState(() {
            _selectedPreset = '';
          });
        }
      },
    );
  }

  Widget _buildBodyInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _bodyController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'نص الرسالة (SMS Body)',
            hintText: 'ألصق نص الرسالة النصية هنا للفحص...',
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.hint(context),
            ),
            labelStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary(context),
            ),
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.divider(context)),
            ),
          ),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.paste_rounded, size: 16),
              label: const Text('لصق من الحافظة (Paste)'),
              onPressed: _pasteFromClipboard,
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('مسح النص'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary(context),
              ),
              onPressed: () {
                _bodyController.clear();
                setState(() {
                  _tested = false;
                  _result = null;
                  _rejectionInfo = null;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('اختبار الرسالة (Test Parse)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _testParse,
      ),
    );
  }

  Widget _buildResultCard() {
    if (_result != null) {
      final res = _result!;
      final isDebit = res.type == TransactionType.debit;
      final typeLabel = isDebit ? 'سحب (Debit)' : 'إيداع (Credit)';
      final typeColor = isDebit ? AppColors.send : AppColors.receive;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(20),
          border: Border.all(color: AppColors.success.withAlpha(120)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'تم التعرف بنجاح (Parsed Successfully)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildResultRow(
              label: 'نوع العملية:',
              value: typeLabel,
              valueColor: typeColor,
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              label: 'المبلغ:',
              value: 'EGP ${res.amount}',
              valueColor: AppColors.textPrimary(context),
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              label: 'رقم الطرف الآخر:',
              value: '\u200E${res.counterpartyNumber}\u200E',
              valueColor: AppColors.textPrimary(context),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              label: 'المشغل:',
              value: res.serviceProvider,
              valueColor: AppColors.textPrimary(context),
            ),
          ],
        ),
      );
    } else {
      final reason = _rejectionInfo?.reason ?? 'PARSING_FAILED';
      final step = _rejectionInfo?.failureStep ?? 'NO_MATCHING_STRATEGY';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          border: Border.all(color: AppColors.error.withAlpha(120)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'فشل التحليل (Parsing Failed)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildResultRow(
              label: 'سبب الرفض:',
              value: reason,
              valueColor: AppColors.error,
            ),
            const SizedBox(height: 6),
            _buildResultRow(
              label: 'خطوة التوقف:',
              value: step,
              valueColor: AppColors.textSecondary(context),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildResultRow({
    required String label,
    required String value,
    required Color valueColor,
    TextDirection? textDirection,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: textDirection,
            style: AppTextStyles.bodySmall.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
