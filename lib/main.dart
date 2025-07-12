import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(const RedactifyApp());
}

class RedactifyApp extends StatelessWidget {
  const RedactifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Redactify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.security,
                          size: 60,
                          color: Color(0xFF667eea),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Redactify',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Secure Document Processing',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with TickerProviderStateMixin {
  PlatformFile? selectedFile;
  bool isAgreementChecked = false;
  bool isUploading = false;
  double uploadProgress = 0.0;
  
  late AnimationController _cardAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _cardAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _cardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutBack,
    ));

    _buttonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));

    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png'],
        withData: true,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          selectedFile = result.files.first;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    }
  }
  

Future<void> _uploadFile() async {
  if (selectedFile == null || selectedFile!.bytes == null) {
    _showErrorSnackBar('Selected file is invalid or empty.');
    return;
  }

  setState(() {
    isUploading = true;
    uploadProgress = 0.0;
  });

  try {
    final dio = Dio();
    
    // Create form data
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        selectedFile!.bytes!,
        filename: selectedFile!.name,
      ),
    });

    // Upload with progress tracking
    final response = await dio.post(
      'https://f0bf004257d9.ngrok-free.app/upload.php', // Replace with your actual API endpoint
      data: formData,
      onSendProgress: (sent, total) {
        setState(() {
          uploadProgress = sent / total;
        });
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => RedactActivity(
            fileId: data['file_id'],
            originalFileName: data['original_name'],
            redactedUrl: data['redacted_url'],
            processingTime: data['processing_time'],
            piiFound: data['pii_found'],
            fileSize: data['file_size'],
            expiresAt: data['expires_at'],
            originalFile: selectedFile!,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } else {
      final message = response.data['message'] ?? 'Upload failed';
      _showErrorSnackBar(message);
    }
  } catch (e) {
    _showErrorSnackBar('Upload error: $e');
  } finally {
    setState(() {
      isUploading = false;
      uploadProgress = 0.0;
    });
  }
}

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFf093fb),
              Color(0xFFf5576c),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Redactify',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Secure your documents with advanced PII redaction',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _cardAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _cardAnimation.value,
                        child: Opacity(
                          opacity: _cardAnimation.value,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upload Document',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select a PDF, image, or text file to redact sensitive information',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF718096),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  _buildFileSelector(),
                                  const SizedBox(height: 20),
                                  if (selectedFile != null) _buildFilePreview(),
                                  const Spacer(),
                                  _buildAgreementCheckbox(),
                                  const SizedBox(height: 20),
                                  _buildRedactButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildFileSelector() {
  return AnimationLimiter(
    child: Column(
      children: AnimationConfiguration.toStaggeredList(
        duration: const Duration(milliseconds: 600),
        childAnimationBuilder: (widget) => SlideAnimation(
          horizontalOffset: 30.0,
          child: FadeInAnimation(child: widget),
        ),
        children: [
          GestureDetector(
            onTap: _selectFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: selectedFile != null ? 200 : 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedFile != null ? Colors.green : const Color(0xFFE2E8F0),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
                color: selectedFile != null ? Colors.green.withOpacity(0.1) : const Color(0xFFF7FAFC),
                boxShadow: selectedFile != null ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ] : null,
              ),
              child: selectedFile != null ? _buildFilePreviewInSelector() : _buildEmptySelector(),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptySelector() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 40,
                color: Color.lerp(Colors.grey[300], const Color(0xFF718096), value),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Shimmer.fromColors(
          baseColor: const Color(0xFF718096),
          highlightColor: const Color(0xFFE2E8F0),
          child: Text(
            'Tap to select file',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PDF, Images, or Text files',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF718096),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFilePreviewInSelector() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getFileColor(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _getFileColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _getFileIcon(),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFile!.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D3748),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  selectedFile = null;
                });
              },
              icon: const Icon(Icons.close, color: Color(0xFF718096)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _buildFilePreviewContent(),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFilePreviewContent() {
  if (selectedFile == null) return const SizedBox();

  final extension = selectedFile!.extension?.toLowerCase();
  
  switch (extension) {
    case 'pdf':
      return _buildPDFPreview();
    case 'jpg':
    case 'jpeg':
    case 'png':
      return _buildImagePreview();
    case 'txt':
      return _buildTextPreview();
    default:
      return _buildGenericPreview();
  }
}

Widget _buildPDFPreview() {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        colors: [Colors.red[50]!, Colors.red[100]!],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 40, color: Colors.red[600]),
          const SizedBox(height: 8),
          Text(
            'PDF Document',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.red[700],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildImagePreview() {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: selectedFile!.bytes != null
          ? Image.memory(
              selectedFile!.bytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Container(
              color: Colors.blue[50],
              child: Center(
                child: Icon(Icons.image, size: 40, color: Colors.blue[600]),
              ),
            ),
    ),
  );
}

Widget _buildTextPreview() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.green[50],
    ),
    child: selectedFile!.bytes != null
        ? SingleChildScrollView(
            child: Text(
              String.fromCharCodes(selectedFile!.bytes!.take(200)) + '...',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.green[700],
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : Center(
            child: Icon(Icons.description, size: 40, color: Colors.green[600]),
          ),
  );
}

Widget _buildGenericPreview() {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey[50],
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 40, color: Colors.grey[600]),
          const SizedBox(height: 8),
          Text(
            'Document',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFilePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getFileColor(),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedFile!.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2D3748),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedFile = null;
              });
            },
            icon: const Icon(Icons.close, color: Color(0xFF718096)),
          ),
        ],
      ),
    );
  }

  Color _getFileColor() {
    if (selectedFile == null) return Colors.grey;
    
    final extension = selectedFile!.extension?.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.blue;
      case 'txt':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getFileIcon() {
    if (selectedFile == null) return Icons.description;
    
    final extension = selectedFile!.extension?.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'txt':
        return Icons.description;
      default:
        return Icons.description;
    }
  }

  Widget _buildAgreementCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: isAgreementChecked,
          onChanged: (value) {
            setState(() {
              isAgreementChecked = value ?? false;
            });
          },
          activeColor: const Color(0xFF667eea),
        ),
        Expanded(
          child: Text(
            'I agree to the terms and conditions for document processing',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF718096),
            ),
          ),
        ),
      ],
    );
  }

Widget _buildRedactButton() {
  final isEnabled = selectedFile != null && isAgreementChecked && !isUploading;
  
  return AnimatedBuilder(
    animation: _buttonAnimation,
    builder: (context, child) {
      return Transform.scale(
        scale: _buttonAnimation.value,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isEnabled
                ? const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  )
                : null,
            color: isEnabled ? null : const Color(0xFFE2E8F0),
            boxShadow: isEnabled ? [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ] : null,
          ),
          child: ElevatedButton(
            onPressed: isEnabled ? () {
              _buttonAnimationController.forward().then((_) {
                _buttonAnimationController.reverse();
              });
              _uploadFile();
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isUploading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Processing... ${(uploadProgress * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Redact Document',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isEnabled ? Colors.white : const Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
}

class RedactActivity extends StatefulWidget {
  final String fileId;
  final String originalFileName;
  final String redactedUrl;
  final double processingTime;
  final int piiFound;
  final int fileSize;
  final String expiresAt;
  final PlatformFile originalFile;

  const RedactActivity({
    super.key,
    required this.fileId,
    required this.originalFileName,
    required this.redactedUrl,
    required this.processingTime,
    required this.piiFound,
    required this.fileSize,
    required this.expiresAt,
    required this.originalFile,
  });

  @override
  State<RedactActivity> createState() => _RedactActivityState();
}

class _RedactActivityState extends State<RedactActivity>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool isDownloading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

Future<void> _downloadFile(String url) async {
  setState(() {
    isDownloading = true;
  });

  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download started successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download failed: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } finally {
    setState(() {
      isDownloading = false;
    });
  }
}

void _showReport() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Processing Report',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportItem('File ID', widget.fileId),
          _buildReportItem('Original Name', widget.originalFileName),
          _buildReportItem('Processing Time', '${widget.processingTime.toStringAsFixed(2)}s'),
          _buildReportItem('PII Items Found', '${widget.piiFound}'),
          _buildReportItem('File Size', '${(widget.fileSize / 1024).toStringAsFixed(1)} KB'),
          _buildReportItem('Expires At', widget.expiresAt),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    ),
  );
}

Widget _buildReportItem(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF718096),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF2D3748),
            ),
          ),
        ),
      ],
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        'Document Processed',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios),
      ),
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFf093fb),
            Color(0xFFf5576c),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value * 50),
              child: Opacity(
                opacity: 1 - _slideAnimation.value,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Success Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: const Icon(
                                    Icons.check_circle,
                                    size: 80,
                                    color: Colors.green,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Document Processed Successfully',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Found ${widget.piiFound} PII items in ${widget.processingTime.toStringAsFixed(1)}s',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.green[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'File Size',
                              '${(widget.fileSize / 1024).toStringAsFixed(1)} KB',
                              Icons.file_present,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'PII Found',
                              '${widget.piiFound}',
                              Icons.security,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Download Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Download Options',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDownloadOption(
                              'Redacted Document',
                              'Download the processed document with PII removed',
                              Icons.download,
                              Colors.green,
                              () => _downloadFile(widget.redactedUrl),
                            ),
                            const SizedBox(height: 12),
                            _buildDownloadOption(
                              'Processing Report',
                              'View detailed report of redacted items',
                              Icons.analytics,
                              Colors.blue,
                              () => _showReport(),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Expiry Notice
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Files will be automatically deleted at ${widget.expiresAt}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        )
      ),
    ),
  );
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF718096),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDownloadOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: color, size: 16),
        ],
      ),
    ),
  );
}

}