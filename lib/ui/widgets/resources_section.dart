// lib/features/home/presentation/widgets/resources_section.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/firestore_providers.dart';
import '../../core/providers/user_session.dart';

class ResourcesSection extends ConsumerStatefulWidget {
  final String eventId;
  const ResourcesSection({Key? key, required this.eventId}) : super(key: key);

  @override
  ConsumerState<ResourcesSection> createState() => _ResourcesSectionState();
}

class _ResourcesSectionState extends ConsumerState<ResourcesSection> {
  late final CollectionReference _resourcesRef;

  @override
  void initState() {
    super.initState();
    final db = ref.read(firestoreProvider);

    _resourcesRef = db
        .collection('events')
        .doc(widget.eventId)
        .collection('resources');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final isAdmin = session.isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resurser',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (isAdmin)
                ElevatedButton.icon(
                  onPressed: _uploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Ladda upp'),
                ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream:
              _resourcesRef.orderBy('uploadedAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Fel vid hämtning: \${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Inga dokument uppladdade'));
            }
            final resources =
                docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return {
                    'url': data['url'] as String,
                    'type': data['type'] as String,
                    'name': data['name'] as String,
                    'docId': d.id,
                  };
                }).toList();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: resources.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = resources[index];
                final name = item['name']!;
                final url = item['url']!;
                final type = item['type']!;
                final docId = item['docId']!;
                final isImage = type == 'image';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      isImage
                          ? Image.network(
                            url,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          )
                          : const Icon(Icons.picture_as_pdf, size: 40),
                  title: Text(name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ResourceViewerPage(
                              resources: resources,
                              initialIndex: index,
                            ),
                      ),
                    );
                  },
                  trailing:
                      isAdmin
                          ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              switch (value) {
                                case 'share':
                                  _shareResource(url);
                                  break;
                                case 'delete':
                                  _confirmDelete(docId, url);
                                  break;
                              }
                            },
                            itemBuilder:
                                (ctx) => [
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Text('Dela dokument'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Radera dokument'),
                                  ),
                                ],
                          )
                          : null,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _uploadFile() async {
    // Kontrollera att vi inte har fler än 5 filer
    final snapshot = await _resourcesRef.get();
    if (snapshot.docs.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max 5 filer per event är tillåtna.')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    // Kontrollera filstorlek (max 1MB)
    final maxBytes = 1024 * 1024;
    if (picked.size > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filen får vara max 1 MB.')),
        );
      }
      return;
    }

    final file = File(picked.path!);
    final fileName = picked.name;
    final storagePath = 'events/${widget.eventId}/resources/$fileName';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Vänta medan filen laddas'),
              ],
            ),
          ),
    );

    try {
      final snapshotUpload = await storageRef.putFile(file);
      final downloadUrl = await snapshotUpload.ref.getDownloadURL();

      await _resourcesRef.add({
        'name': fileName,
        'url': downloadUrl,
        'storagePath': storagePath,
        'type': fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image',
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Uppladdning klar: $fileName')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fel vid uppladdning: \$e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _shareResource(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _confirmDelete(String docId, String url) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Radera dokument'),
            content: const Text(
              'Är du säker på att du vill radera dokumentet?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _deleteResource(docId, url);
                },
                child: const Text(
                  'Radera',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteResource(String docId, String url) async {
    try {
      // Radera från Storage
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
      // Radera Firestore-dokument
      await _resourcesRef.doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dokument raderat')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fel vid radering: \$e')));
      }
    }
  }
}

class ResourceViewerPage extends StatefulWidget {
  final List<Map<String, String>> resources;
  final int initialIndex;

  const ResourceViewerPage({
    Key? key,
    required this.resources,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ResourceViewerPage> createState() => _ResourceViewerPageState();
}

class _ResourceViewerPageState extends State<ResourceViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final resources = widget.resources;
    return Scaffold(
      appBar: AppBar(title: Text(resources[_currentIndex]['name']!)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: resources.length,
            itemBuilder: (context, index) {
              final item = resources[index];
              final url = item['url']!;
              final isPdf = item['type'] == 'pdf';
              if (isPdf) {
                return FutureBuilder<String>(
                  future: _loadPdf(url),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Fel vid laddning av PDF: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    } else if (snap.hasData) {
                      return PDFView(
                        filePath: snap.data!,
                        swipeHorizontal: false,
                        autoSpacing: true,
                        pageSnap: true,
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                );
              } else {
                return Center(
                  child: InteractiveViewer(child: Image.network(url)),
                );
              }
            },
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height * 0.5 - 24,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed:
                      () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      ),
                ),
              ),
            ),
          if (_currentIndex < resources.length - 1)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.5 - 24,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed:
                      () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<String> _loadPdf(String url) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${url.hashCode}.pdf';
    final file = File(path);
    if (!await file.exists()) {
      final bytes = await http.readBytes(Uri.parse(url));
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }
}
