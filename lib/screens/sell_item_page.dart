import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/listing_draft.dart';
import '../services/gemini_vision_service.dart';

class SellItemPage extends StatefulWidget {
  const SellItemPage({super.key});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  // ตัวแปรเก็บรูปภาพที่เลือก
  File? _imageFile;

  // Prompt ที่ส่งไปให้ Gemini
  static const String _prompt = '''
วิเคราะห์สินค้าในรูปภาพนี้ แล้วตอบกลับเป็น JSON ตามโครงสร้างที่กำหนดให้เท่านั้น อย่าพิมพ์ข้อความอื่นนอกจาก JSON
''';

  // 3 สถานะของการวิเคราะห์ AI
  bool _isAnalyzing = false;
  bool _hasDraft = false;  // true เมื่อ AI วิเคราะห์สำเร็จและฟอร์มพร้อมแสดง
  String? _errorMessage;

  // TextEditingController สำหรับ 3 ช่อง — ผู้ใช้แก้ไขได้ก่อนยืนยัน
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // เลือกรูปภาพจาก Gallery
  Future<void> _pickImage() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return;

    setState(() {
      _imageFile = File(result.path);
      // รีเซ็ตผลลัพธ์เก่าเมื่อเลือกรูปใหม่
      _hasDraft = false;
      _errorMessage = null;
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
    });
  }

  // เรียก GeminiVisionService แล้วนำผลลัพธ์ไปใส่ใน TextEditingController
  Future<void> _analyzeWithAI() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _hasDraft = false;
      _errorMessage = null;
    });

    try {
      print('=== SENDING PROMPT TO AI ===');
      print(_prompt);

      final resultMap = await GeminiVisionService().analyzeProductImage(
        _imageFile!,
        _prompt,
      );
      final draft = ListingDraft.fromJson(resultMap);

      // ✅ นำค่าจาก AI ใส่ใน Controller เพื่อให้แก้ไขได้ก่อนยืนยัน
      _titleController.text = draft.title;
      _categoryController.text = draft.category;
      _descriptionController.text = draft.description;

      setState(() {
        _hasDraft = true;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  // ยืนยันร่างประกาศ
  void _confirmListing() {
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || category.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')),
      );
      return;
    }

    // เก็บค่าลงตัวแปรไว้ (จำลองการบันทึก)
    final finalDraft = ListingDraft(
      title: title,
      category: category,
      description: description,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('บันทึกร่างประกาศ "${finalDraft.title}" เรียบร้อยแล้ว'),
        backgroundColor: Colors.green,
      ),
    );

    // ล้างฟอร์มกลับสู่สถานะว่างเปล่า
    setState(() {
      _imageFile = null;
      _hasDraft = false;
      _errorMessage = null;
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงประกาศขาย'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── พื้นที่แสดงรูปภาพ ───
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  height: 250,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('ยังไม่ได้เลือกรูปภาพ',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ─── ปุ่มเลือกรูปภาพ ───
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('เลือกรูปภาพสินค้า'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // ─── ปุ่ม AI ───
            ElevatedButton.icon(
              onPressed: (_imageFile == null || _isAnalyzing) ? null : _analyzeWithAI,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ให้ AI ช่วยแนะนำ'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 20),

            // ─── สถานะ: กำลังวิเคราะห์ ───
            if (_isAnalyzing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'AI กำลังวิเคราะห์ภาพสินค้า...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),

            // ─── สถานะ: ผิดพลาด ───
            if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── สถานะ: สำเร็จ — ฟอร์มที่แก้ไขได้ (Human-in-the-loop) ───
            if (_hasDraft) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.deepPurple, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI แนะนำข้อมูลด้านล่าง — แก้ไขได้ก่อนยืนยัน',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.deepPurple),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ช่อง: ชื่อประกาศ
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อประกาศ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 60,
              ),
              const SizedBox(height: 12),

              // ช่อง: หมวดหมู่
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'หมวดหมู่',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),

              // ช่อง: คำบรรยาย
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'คำบรรยายสินค้า',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // ปุ่มยืนยันการประกาศ
              ElevatedButton.icon(
                onPressed: _confirmListing,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('ยืนยันลงประกาศ'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
