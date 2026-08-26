import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum CropAspectRatio {
  square('1:1 Square', 1.0, Icons.crop_square_rounded),
  free('Freeform', null, Icons.crop_free_rounded),
  circle('Circle (Round)', 1.0, Icons.circle_outlined),
  standard('4:3', 4.0 / 3.0, Icons.crop_landscape_rounded),
  wide('16:9', 16.0 / 9.0, Icons.crop_16_9_rounded),
  original('Original', 0.0, Icons.image_outlined);

  final String label;
  final double? ratio;
  final IconData icon;
  const CropAspectRatio(this.label, this.ratio, this.icon);
}

enum LogoBgColor {
  white('White', Color(0xFFFFFFFF)),
  dark('Dark', Color(0xFF0F172A)),
  transparent('Clear', Colors.transparent);

  final String label;
  final Color color;
  const LogoBgColor(this.label, this.color);
}

class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    this.title = 'Crop & Resize Logo',
  });

  /// Helper to pick an image from source and directly launch full-page crop screen
  static Future<Uint8List?> pickAndCrop(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
    String title = 'Crop & Resize Logo',
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (!context.mounted) return null;

    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (ctx) => ImageCropDialog(imageBytes: bytes, title: title),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  ui.Image? _decodedImage;
  bool _isLoading = true;
  bool _isProcessingCrop = false;

  CropAspectRatio _selectedRatio = CropAspectRatio.free;
  LogoBgColor _selectedBg = LogoBgColor.white;
  bool _autoSquarePad = true; // Automatically pad with chosen BG to create perfect 1:1 square output
  int _rotationQuarterTurns = 0; // 0, 1, 2, 3 (0°, 90°, 180°, 270°)
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // Normalized crop rectangle: values between 0.0 and 1.0 representing fraction of the displayed image rect
  Rect _normCropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);

  // Active dragging handle
  _DragHandle? _activeHandle;
  Offset? _lastPanPosition;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _decodedImage = frame.image;
        _isLoading = false;
      });
      _initCropRect();
    } catch (e) {
      debugPrint('[ImageCropDialog] Error decoding image: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e'), backgroundColor: Colors.redAccent),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _initCropRect() {
    if (_decodedImage == null) return;
    final imgW = _decodedImage!.width.toDouble();
    final imgH = _decodedImage!.height.toDouble();

    // Default: generous 88% crop centered
    _applyAspectRatio(CropAspectRatio.free, imgW, imgH);
  }

  void _applyAspectRatio(CropAspectRatio ratioType, [double? imgW, double? imgH]) {
    final w = imgW ?? (_decodedImage?.width.toDouble() ?? 100);
    final h = imgH ?? (_decodedImage?.height.toDouble() ?? 100);

    final isRotated90 = _rotationQuarterTurns % 2 != 0;
    final effectiveW = isRotated90 ? h : w;
    final effectiveH = isRotated90 ? w : h;

    double? targetRatio = ratioType.ratio;
    if (ratioType == CropAspectRatio.original) {
      targetRatio = effectiveW / effectiveH;
    }

    if (targetRatio == null) {
      // Freeform
      setState(() {
        _selectedRatio = ratioType;
        _normCropRect = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
      });
      return;
    }

    // Fit aspect-ratio rectangle inside (0,0, 1,1)
    double rectW, rectH;
    final imageAspect = effectiveW / effectiveH;
    if (targetRatio > imageAspect) {
      rectW = 0.90;
      rectH = rectW * (effectiveW / effectiveH) / targetRatio;
      if (rectH > 0.90) {
        rectH = 0.90;
        rectW = rectH * targetRatio / (effectiveW / effectiveH);
      }
    } else {
      rectH = 0.90;
      rectW = rectH * targetRatio / (effectiveW / effectiveH);
      if (rectW > 0.90) {
        rectW = 0.90;
        rectH = rectW * (effectiveW / effectiveH) / targetRatio;
      }
    }

    rectW = rectW.clamp(0.1, 0.96);
    rectH = rectH.clamp(0.1, 0.96);
    final left = (1.0 - rectW) / 2.0;
    final top = (1.0 - rectH) / 2.0;

    setState(() {
      _selectedRatio = ratioType;
      _normCropRect = Rect.fromLTWH(left, top, rectW, rectH);
    });
  }

  void _rotateClockwise() {
    HapticFeedback.lightImpact();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
    _applyAspectRatio(_selectedRatio);
  }

  void _rotateCounterClockwise() {
    HapticFeedback.lightImpact();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 3) % 4;
    });
    _applyAspectRatio(_selectedRatio);
  }

  void _toggleFlipHorizontal() {
    HapticFeedback.lightImpact();
    setState(() {
      _flipHorizontal = !_flipHorizontal;
    });
  }

  void _toggleFlipVertical() {
    HapticFeedback.lightImpact();
    setState(() {
      _flipVertical = !_flipVertical;
    });
  }

  void _resetCrop() {
    HapticFeedback.mediumImpact();
    setState(() {
      _rotationQuarterTurns = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _selectedRatio = CropAspectRatio.free;
      _selectedBg = LogoBgColor.white;
      _autoSquarePad = true;
    });
    _applyAspectRatio(CropAspectRatio.free);
  }

  /// Perform high-resolution GPU crop with auto 1:1 square canvas background fill
  Future<void> _performCrop() async {
    if (_decodedImage == null || _isProcessingCrop) return;

    setState(() => _isProcessingCrop = true);
    HapticFeedback.mediumImpact();

    try {
      final origW = _decodedImage!.width.toDouble();
      final origH = _decodedImage!.height.toDouble();

      final isRotated90 = _rotationQuarterTurns % 2 != 0;
      final rotW = isRotated90 ? origH : origW;
      final rotH = isRotated90 ? origW : origH;

      // 1. Create transformed base image (rotation + flips)
      final transformedRecorder = ui.PictureRecorder();
      final transformedCanvas = Canvas(transformedRecorder, Rect.fromLTWH(0, 0, rotW, rotH));

      transformedCanvas.save();
      transformedCanvas.translate(rotW / 2, rotH / 2);
      transformedCanvas.rotate(_rotationQuarterTurns * math.pi / 2);
      transformedCanvas.scale(_flipHorizontal ? -1.0 : 1.0, _flipVertical ? -1.0 : 1.0);
      transformedCanvas.drawImage(
        _decodedImage!,
        Offset(-origW / 2, -origH / 2),
        Paint()..filterQuality = FilterQuality.high,
      );
      transformedCanvas.restore();

      final transformedPicture = transformedRecorder.endRecording();
      final transformedImage = await transformedPicture.toImage(rotW.toInt(), rotH.toInt());

      // 2. Compute cropped region in source pixels
      final cropX = (_normCropRect.left * rotW).clamp(0.0, rotW);
      final cropY = (_normCropRect.top * rotH).clamp(0.0, rotH);
      final cropW = (_normCropRect.width * rotW).clamp(1.0, rotW - cropX);
      final cropH = (_normCropRect.height * rotH).clamp(1.0, rotH - cropY);

      final srcRect = Rect.fromLTWH(cropX, cropY, cropW, cropH);

      // 3. Final Output Dimensions & Canvas Layout
      const outputCanvasSize = 600.0; // Perfect standard logo size
      double outW, outH;
      Rect dstRect;

      if (_autoSquarePad) {
        // Output is a perfect 1:1 Square (outputCanvasSize x outputCanvasSize)
        outW = outputCanvasSize;
        outH = outputCanvasSize;

        // Fit cropped region inside square canvas with a clean 4% inner padding
        final innerBoxSize = outputCanvasSize * 0.94;
        final scale = math.min(innerBoxSize / cropW, innerBoxSize / cropH);
        final scaledW = cropW * scale;
        final scaledH = cropH * scale;

        final dstLeft = (outputCanvasSize - scaledW) / 2.0;
        final dstTop = (outputCanvasSize - scaledH) / 2.0;
        dstRect = Rect.fromLTWH(dstLeft, dstTop, scaledW, scaledH);
      } else {
        // Direct cropped aspect ratio
        final maxDim = outputCanvasSize;
        if (cropW >= cropH) {
          outW = maxDim;
          outH = (cropH / cropW) * maxDim;
        } else {
          outH = maxDim;
          outW = (cropW / cropH) * maxDim;
        }
        dstRect = Rect.fromLTWH(0, 0, outW, outH);
      }

      final finalRecorder = ui.PictureRecorder();
      final finalCanvas = Canvas(finalRecorder, Rect.fromLTWH(0, 0, outW, outH));

      // 4. Fill Background (White / Dark / Transparent)
      if (_selectedBg.color != Colors.transparent) {
        final bgPaint = Paint()
          ..color = _selectedBg.color
          ..style = PaintingStyle.fill;
        finalCanvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), bgPaint);
      }

      // 5. Circle clipping if circle preset chosen
      if (_selectedRatio == CropAspectRatio.circle) {
        final clipPath = Path()..addOval(dstRect);
        finalCanvas.save();
        finalCanvas.clipPath(clipPath);
      }

      // 6. Draw cropped image into destination rect
      finalCanvas.drawImageRect(
        transformedImage,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      if (_selectedRatio == CropAspectRatio.circle) {
        finalCanvas.restore();
      }

      final finalPicture = finalRecorder.endRecording();
      final finalImage = await finalPicture.toImage(outW.toInt(), outH.toInt());

      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode cropped image to PNG');

      final croppedBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(croppedBytes);
      }
    } catch (e) {
      debugPrint('[ImageCropDialog] Crop error: $e');
      if (mounted) {
        setState(() => _isProcessingCrop = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping image: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Studio dark photo-editor canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Cancel',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const Text(
              'Resize, rotate & auto-pad for 1:1 logo',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _resetCrop,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Reset All',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isProcessingCrop ? null : _performCrop,
              icon: _isProcessingCrop
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
              label: Text(
                _isProcessingCrop ? 'Saving...' : 'Done',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Main Viewport ──────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _buildCropViewport(),
            ),

            // ─── Bottom Studio Control Deck ─────────────────────────────────
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCropViewport() {
    if (_decodedImage == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;

        final origW = _decodedImage!.width.toDouble();
        final origH = _decodedImage!.height.toDouble();
        final isRotated90 = _rotationQuarterTurns % 2 != 0;
        final imgW = isRotated90 ? origH : origW;
        final imgH = isRotated90 ? origW : origH;

        final padding = 24.0;
        final availW = math.max(10.0, viewW - padding * 2);
        final availH = math.max(10.0, viewH - padding * 2);

        final imageAspect = imgW / imgH;
        final availAspect = availW / availH;

        double renderW, renderH;
        if (imageAspect > availAspect) {
          renderW = availW;
          renderH = renderW / imageAspect;
        } else {
          renderH = availH;
          renderW = renderH * imageAspect;
        }

        final renderLeft = (viewW - renderW) / 2.0;
        final renderTop = (viewH - renderH) / 2.0;
        final imageDisplayRect = Rect.fromLTWH(renderLeft, renderTop, renderW, renderH);

        final screenCropRect = Rect.fromLTWH(
          renderLeft + _normCropRect.left * renderW,
          renderTop + _normCropRect.top * renderH,
          _normCropRect.width * renderW,
          _normCropRect.height * renderH,
        );

        return GestureDetector(
          onPanStart: (details) {
            final pos = details.localPosition;
            _lastPanPosition = pos;
            _activeHandle = _determineHandle(pos, screenCropRect);
          },
          onPanUpdate: (details) {
            if (_lastPanPosition == null || _activeHandle == null) return;
            final delta = details.localPosition - _lastPanPosition!;
            _lastPanPosition = details.localPosition;

            _updateCropRectWithDelta(
              delta: delta,
              handle: _activeHandle!,
              imageRect: imageDisplayRect,
              currentScreenRect: screenCropRect,
            );
          },
          onPanEnd: (_) {
            _activeHandle = null;
            _lastPanPosition = null;
          },
          child: Container(
            width: viewW,
            height: viewH,
            color: const Color(0xFF060A12),
            child: Stack(
              children: [
                // Render Transformed Base Image
                Positioned.fromRect(
                  rect: imageDisplayRect,
                  child: ClipRect(
                    child: Transform.rotate(
                      angle: _rotationQuarterTurns * math.pi / 2,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          _flipHorizontal ? -1.0 : 1.0,
                          _flipVertical ? -1.0 : 1.0,
                          1.0,
                        ),
                        child: RawImage(
                          image: _decodedImage,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),

                // Dark Vignette & Rule-of-Thirds Grid CustomPainter
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      cropRect: screenCropRect,
                      imageRect: imageDisplayRect,
                      isCircle: _selectedRatio == CropAspectRatio.circle,
                      primaryColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ),

                // Corner & Edge Drag Handles
                _buildHandles(screenCropRect),

                // Live Info Floating Tag
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _autoSquarePad ? Icons.auto_awesome_rounded : Icons.crop_rounded,
                            size: 13,
                            color: const Color(0xFF60A5FA),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _autoSquarePad
                                ? 'Auto 1:1 Square Output (${_selectedBg.label} BG)'
                                : 'Exact Crop (${_selectedRatio.label})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _DragHandle _determineHandle(Offset pos, Rect cropRect) {
    const handleHitRadius = 26.0;

    if ((pos - cropRect.topLeft).distance <= handleHitRadius) return _DragHandle.topLeft;
    if ((pos - cropRect.topRight).distance <= handleHitRadius) return _DragHandle.topRight;
    if ((pos - cropRect.bottomLeft).distance <= handleHitRadius) return _DragHandle.bottomLeft;
    if ((pos - cropRect.bottomRight).distance <= handleHitRadius) return _DragHandle.bottomRight;

    if ((pos.dy - cropRect.top).abs() <= handleHitRadius && pos.dx >= cropRect.left && pos.dx <= cropRect.right) {
      return _DragHandle.top;
    }
    if ((pos.dy - cropRect.bottom).abs() <= handleHitRadius && pos.dx >= cropRect.left && pos.dx <= cropRect.right) {
      return _DragHandle.bottom;
    }
    if ((pos.dx - cropRect.left).abs() <= handleHitRadius && pos.dy >= cropRect.top && pos.dy <= cropRect.bottom) {
      return _DragHandle.left;
    }
    if ((pos.dx - cropRect.right).abs() <= handleHitRadius && pos.dy >= cropRect.top && pos.dy <= cropRect.bottom) {
      return _DragHandle.right;
    }

    if (cropRect.contains(pos)) return _DragHandle.inside;

    return _DragHandle.none;
  }

  void _updateCropRectWithDelta({
    required Offset delta,
    required _DragHandle handle,
    required Rect imageRect,
    required Rect currentScreenRect,
  }) {
    if (handle == _DragHandle.none) return;

    final imgW = imageRect.width;
    final imgH = imageRect.height;
    if (imgW <= 0 || imgH <= 0) return;

    final normDx = delta.dx / imgW;
    final normDy = delta.dy / imgH;

    double newLeft = _normCropRect.left;
    double newTop = _normCropRect.top;
    double newRight = _normCropRect.right;
    double newBottom = _normCropRect.bottom;

    const minSize = 0.08;

    if (handle == _DragHandle.inside) {
      final w = _normCropRect.width;
      final h = _normCropRect.height;
      newLeft = (_normCropRect.left + normDx).clamp(0.0, 1.0 - w);
      newTop = (_normCropRect.top + normDy).clamp(0.0, 1.0 - h);
      newRight = newLeft + w;
      newBottom = newTop + h;
    } else {
      if (handle == _DragHandle.topLeft || handle == _DragHandle.left || handle == _DragHandle.bottomLeft) {
        newLeft = (newLeft + normDx).clamp(0.0, newRight - minSize);
      }
      if (handle == _DragHandle.topRight || handle == _DragHandle.right || handle == _DragHandle.bottomRight) {
        newRight = (newRight + normDx).clamp(newLeft + minSize, 1.0);
      }
      if (handle == _DragHandle.topLeft || handle == _DragHandle.top || handle == _DragHandle.topRight) {
        newTop = (newTop + normDy).clamp(0.0, newBottom - minSize);
      }
      if (handle == _DragHandle.bottomLeft || handle == _DragHandle.bottom || handle == _DragHandle.bottomRight) {
        newBottom = (newBottom + normDy).clamp(newTop + minSize, 1.0);
      }

      final fixedRatio = _selectedRatio.ratio;
      if (fixedRatio != null && fixedRatio > 0) {
        final pixelAspectFactor = imgW / imgH;
        final targetNormRatio = fixedRatio / pixelAspectFactor;

        double curNormW = newRight - newLeft;
        double curNormH = newBottom - newTop;

        if (handle == _DragHandle.topLeft || handle == _DragHandle.topRight ||
            handle == _DragHandle.bottomLeft || handle == _DragHandle.bottomRight) {
          curNormH = curNormW / targetNormRatio;
          if (newTop + curNormH > 1.0) {
            curNormH = 1.0 - newTop;
            curNormW = curNormH * targetNormRatio;
          }
          if (handle == _DragHandle.bottomRight) {
            newRight = newLeft + curNormW;
            newBottom = newTop + curNormH;
          } else if (handle == _DragHandle.bottomLeft) {
            newLeft = newRight - curNormW;
            newBottom = newTop + curNormH;
          } else if (handle == _DragHandle.topRight) {
            newRight = newLeft + curNormW;
            newTop = newBottom - curNormH;
          } else if (handle == _DragHandle.topLeft) {
            newLeft = newRight - curNormW;
            newTop = newBottom - curNormH;
          }
        }
      }
    }

    setState(() {
      _normCropRect = Rect.fromLTRB(
        newLeft.clamp(0.0, 1.0),
        newTop.clamp(0.0, 1.0),
        newRight.clamp(0.0, 1.0),
        newBottom.clamp(0.0, 1.0),
      );
    });
  }

  Widget _buildHandles(Rect cropRect) {
    const cornerSize = 18.0;
    return Stack(
      children: [
        // Corners
        Positioned(
          left: cropRect.left - cornerSize / 2,
          top: cropRect.top - cornerSize / 2,
          child: _buildHandleCircle(),
        ),
        Positioned(
          left: cropRect.right - cornerSize / 2,
          top: cropRect.top - cornerSize / 2,
          child: _buildHandleCircle(),
        ),
        Positioned(
          left: cropRect.left - cornerSize / 2,
          top: cropRect.bottom - cornerSize / 2,
          child: _buildHandleCircle(),
        ),
        Positioned(
          left: cropRect.right - cornerSize / 2,
          top: cropRect.bottom - cornerSize / 2,
          child: _buildHandleCircle(),
        ),
      ],
    );
  }

  Widget _buildHandleCircle() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2563EB), width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 1. Aspect Ratio Pills ─────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: CropAspectRatio.values.map((ratio) {
                final isSelected = _selectedRatio == ratio;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _applyAspectRatio(ratio);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ratio.icon,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ratio.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // ─── 2. Auto 1:1 Square & Background Fill Options ──────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155), width: 0.8),
            ),
            child: Row(
              children: [
                // 1:1 Auto Square Checkbox/Toggle
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _autoSquarePad = !_autoSquarePad);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _autoSquarePad ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: _autoSquarePad ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1:1 Square Pad',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          Text(
                            'Fits logo slot',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Background Color Options
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: LogoBgColor.values.map((bg) {
                    final isSelected = _selectedBg == bg;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedBg = bg;
                            _autoSquarePad = true; // Selecting a color enables square padding
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: bg.color == Colors.transparent ? Colors.grey : bg.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white38, width: 0.8),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                bg.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ─── 3. Transformation Tools Row ───────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildToolBtn(
                  icon: Icons.rotate_90_degrees_ccw_rounded,
                  label: '-90°',
                  onTap: _rotateCounterClockwise,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToolBtn(
                  icon: Icons.rotate_90_degrees_cw_rounded,
                  label: '+90°',
                  onTap: _rotateClockwise,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToolBtn(
                  icon: Icons.flip_rounded,
                  label: 'Flip H',
                  onTap: _toggleFlipHorizontal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToolBtn(
                  icon: Icons.swap_vert_rounded,
                  label: 'Flip V',
                  onTap: _toggleFlipVertical,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── 4. Full Width Apply Button (Zero Overflow) ───────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isProcessingCrop ? null : _performCrop,
              icon: _isProcessingCrop
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: Text(
                _isProcessingCrop ? 'Processing & Saving Logo...' : 'Apply & Use Logo',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: const Color(0xFFE2E8F0)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE2E8F0)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DragHandle {
  none,
  inside,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageRect;
  final bool isCircle;
  final Color primaryColor;

  _CropOverlayPainter({
    required this.cropRect,
    required this.imageRect,
    required this.isCircle,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw darkened vignette mask
    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropPath = Path();
    if (isCircle) {
      cropPath.addOval(cropRect);
    } else {
      cropPath.addRect(cropRect);
    }

    final diffPath = Path.combine(PathOperation.difference, backgroundPath, cropPath);
    canvas.drawPath(diffPath, maskPaint);

    // 2. Draw Crop Box Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    if (isCircle) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRect(cropRect, borderPaint);
    }

    // 3. Draw Rule-of-Thirds Grid Lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final w = cropRect.width;
    final h = cropRect.height;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + w / 3, cropRect.top),
      Offset(cropRect.left + w / 3, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + 2 * w / 3, cropRect.top),
      Offset(cropRect.left + 2 * w / 3, cropRect.bottom),
      gridPaint,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + h / 3),
      Offset(cropRect.right, cropRect.top + h / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + 2 * h / 3),
      Offset(cropRect.right, cropRect.top + 2 * h / 3),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.isCircle != isCircle;
  }
}
