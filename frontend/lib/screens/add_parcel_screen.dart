import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/errors.dart';

/// 添加快递页：支持手动填写 + 剪贴板/截图智能识别。
/// 识别后回填到表单，由用户确认后再保存（识别确认页能力内联于此）。
class AddParcelScreen extends StatefulWidget {
  const AddParcelScreen({super.key});
  @override
  State<AddParcelScreen> createState() => _AddParcelScreenState();
}

class _AddParcelScreenState extends State<AddParcelScreen> {
  final _api = ApiService();
  final company = TextEditingController();
  final pickupCode = TextEditingController();
  final locker = TextEditingController();
  final location = TextEditingController();
  final recipient = TextEditingController();
  final note = TextEditingController();
  String _source = 'manual';
  bool _saving = false;

  // 通用：把一段文本送后端识别并回填
  Future<void> _recognize(String text, String source) async {
    if (text.trim().isEmpty) return;
    try {
      final ParsedExpress p = await _api.parse(text);
      setState(() {
        if (p.company != null) company.text = p.company!;
        if (p.pickupCode != null) pickupCode.text = p.pickupCode!;
        if (p.locker != null) locker.text = p.locker!;
        if (p.location != null) location.text = p.location!;
        _source = source;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已识别（置信度 ${(p.confidence * 100).toInt()}%），请确认后保存')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('识别失败：${friendlyError(e)}')));
    }
  }

  // 从剪贴板识别
  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    await _recognize(data?.text ?? '', 'clipboard');
  }

  // 从截图 OCR 识别（本地离线 OCR）
  Future<void> _fromImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(picked.path));
      await _recognize(result.text, 'ocr');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('识别失败：${friendlyError(e)}')));
    } finally {
      await recognizer.close();
    }
  }

  Future<void> _save() async {
    if (pickupCode.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取件码必填')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.addParcel({
        'company': company.text.trim(),
        'pickupCode': pickupCode.text.trim(),
        'locker': locker.text.trim(),
        'location': location.text.trim(),
        'recipient': recipient.text.trim(),
        'note': note.text.trim(),
        'source': _source,
        'status': 'pending',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加快递')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 智能识别入口
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _fromClipboard,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('剪贴板识别'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _fromImage,
                  icon: const Icon(Icons.image_search),
                  label: const Text('截图识别'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('确认 / 填写信息', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _field(pickupCode, '取件码', required: true),
          _field(company, '快递公司'),
          _field(locker, '取件柜'),
          _field(location, '取件位置'),
          _field(recipient, '收件人'),
          _field(note, '备注'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
