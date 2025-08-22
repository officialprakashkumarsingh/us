import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/prompt_enhancer_service.dart';
import '../../../shared/widgets/prompt_enhancer.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController? controller;
  final Function(String, {bool useWebSearch}) onSendMessage;
  final Function(String)? onGenerateImage;
  final Function(String)? onGenerateDiagram;
  final Function(String)? onGeneratePresentation;
  final Function(String)? onGenerateChart;
  final Function(String)? onGenerateFlashcards;
  final Function(String)? onGenerateQuiz;
  final Function(String, String)? onVisionAnalysis;
  final VoidCallback? onStopStreaming;
  final VoidCallback? onTemplateRequest;
  final String selectedModel;
  final bool isLoading;
  final bool enabled;

  const ChatInput({
    super.key,
    this.controller,
    required this.onSendMessage,
    this.onGenerateImage,
    this.onGenerateDiagram,
    this.onGeneratePresentation,
    this.onGenerateChart,
    this.onGenerateFlashcards,
    this.onGenerateQuiz,
    this.onVisionAnalysis,
    this.onStopStreaming,
    this.onTemplateRequest,
    this.selectedModel = '',
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;
  bool _shouldDisposeController = false;
  bool _showEnhancerSuggestion = false;
  bool _webSearchEnabled = false;
  bool _imageGenerationMode = false;
  bool _diagramGenerationMode = false;
  bool _presentationGenerationMode = false;
  bool _chartGenerationMode = false;
  bool _flashcardGenerationMode = false;
  bool _quizGenerationMode = false;
  String? _pendingImageData;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _shouldDisposeController = true;
    }
    _controller.addListener(_updateSendButton);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_shouldDisposeController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _updateSendButton() {
    final canSend = _controller.text.trim().isNotEmpty && 
                   widget.enabled && 
                   !widget.isLoading;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  void _startEnhancerTimer() {
    _typingTimer?.cancel();
    
    if (widget.selectedModel.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _focusNode.hasFocus) {
          final text = _controller.text.trim();
          if (text.isNotEmpty && PromptEnhancerService.shouldSuggestEnhancement(text)) {
            setState(() {
              _showEnhancerSuggestion = true;
            });
          }
        }
      });
    }
  }

  void _onInputTapped() {
    setState(() {
      _showEnhancerSuggestion = false;
    });
    _startEnhancerTimer();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _startEnhancerTimer();
    } else {
      _typingTimer?.cancel();
      setState(() {
        _showEnhancerSuggestion = false;
      });
    }
  }

  void _handleSend() {
    if (!_canSend) return;
    
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    _updateSendButton();
    
    // Check if there's pending image data for vision analysis
    if (_pendingImageData != null && widget.onVisionAnalysis != null) {
      widget.onVisionAnalysis!(message, _pendingImageData!);
      _pendingImageData = null; // Clear after use
    } else {
      widget.onSendMessage(message, useWebSearch: _webSearchEnabled);
    }
    
    HapticFeedback.lightImpact();
  }

  void _handleStop() {
    if (widget.onStopStreaming != null) {
      widget.onStopStreaming!();
      HapticFeedback.mediumImpact();
    }
  }

  void _showPromptEnhancer() {
    final originalPrompt = _controller.text.trim();
    if (originalPrompt.isEmpty) return;

    setState(() {
      _showEnhancerSuggestion = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: PromptEnhancer(
          originalPrompt: originalPrompt,
          selectedModel: widget.selectedModel,
          onEnhanced: (enhancedPrompt) {
            _controller.text = enhancedPrompt;
            Navigator.pop(context);
            HapticFeedback.lightImpact();
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input area - completely transparent
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: SafeArea(
            child: Row(
              children: [
                // Extensions button with close option
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      onPressed: _showExtensionsSheet,
                      icon: Icon(
                        Icons.extension_outlined,
                        color: _isAnyExtensionActive() 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        size: 24,
                      ),
                      tooltip: 'Extensions',
                    ),
                    if (_isAnyExtensionActive())
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _clearAllExtensions,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 10,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Text input - no background
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onTap: _onInputTapped,
                    decoration: InputDecoration(
                      hintText: widget.enabled 
                          ? (_pendingImageData != null
                              ? '📸 Ask something about the uploaded image...'
                              : _imageGenerationMode 
                                  ? 'Describe the image you want to generate...'
                                  : _diagramGenerationMode
                                      ? 'Describe the diagram you want to create...'
                                      : _presentationGenerationMode
                                          ? 'Describe the presentation topic...'
                                          : _chartGenerationMode
                                              ? 'Describe the chart or graph you want...'
                                              : _flashcardGenerationMode
                                                  ? 'What topic for flashcards?'
                                                  : _quizGenerationMode
                                                      ? 'What topic for the quiz?'
                                                      : 'Type your message...') 
                          : 'Select a model to start chatting',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Send/Stop button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubic,
                  child: Material(
                    color: widget.isLoading
                        ? Colors.red
                        : (_canSend 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: widget.isLoading ? _handleStop : (_canSend ? (_imageGenerationMode ? _handleImageGenerationDirect : (_diagramGenerationMode ? _handleDiagramGenerationDirect : (_presentationGenerationMode ? _handlePresentationGenerationDirect : (_chartGenerationMode ? _handleChartGenerationDirect : (_flashcardGenerationMode ? _handleFlashcardGenerationDirect : (_quizGenerationMode ? _handleQuizGenerationDirect : _handleSend)))))) : null),
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            _getButtonIcon(),
                            color: _getButtonIconColor(context),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleImageGeneration() {
    // This method is no longer used as popup is removed
  }

  void _handleImageGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateImage != null) {
      widget.onGenerateImage!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleDiagramGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateDiagram != null) {
      widget.onGenerateDiagram!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handlePresentationGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGeneratePresentation != null) {
      widget.onGeneratePresentation!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleChartGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateChart != null) {
      widget.onGenerateChart!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleFlashcardGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateFlashcards != null) {
      widget.onGenerateFlashcards!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _handleQuizGenerationDirect() {
    final prompt = _controller.text.trim();
    if (prompt.isNotEmpty && widget.onGenerateQuiz != null) {
      widget.onGenerateQuiz!(prompt);
      _controller.clear();
      // Keep mode active - user must manually turn it off
      _updateSendButton();
      HapticFeedback.lightImpact();
    }
  }

  void _showExtensionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExtensionsBottomSheet(
        webSearchEnabled: _webSearchEnabled,
        imageGenerationMode: _imageGenerationMode,
        diagramGenerationMode: _diagramGenerationMode,
        presentationGenerationMode: _presentationGenerationMode,
        chartGenerationMode: _chartGenerationMode,
        flashcardGenerationMode: _flashcardGenerationMode,
        quizGenerationMode: _quizGenerationMode,
        onImageUpload: () async {
          Navigator.pop(context);
          await _handleImageUpload();
        },
        onWebSearchToggle: (enabled) {
          setState(() {
            _webSearchEnabled = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onImageModeToggle: (enabled) {
          setState(() {
            _imageGenerationMode = enabled;
            if (enabled) {
              _webSearchEnabled = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onEnhancePrompt: () {
          Navigator.pop(context);
          _showPromptEnhancer();
        },
        onDiagramToggle: (enabled) {
          setState(() {
            _diagramGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _webSearchEnabled = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onPresentationToggle: (enabled) {
          setState(() {
            _presentationGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _webSearchEnabled = false;
              _diagramGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onChartToggle: (enabled) {
          setState(() {
            _chartGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _webSearchEnabled = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _flashcardGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onFlashcardToggle: (enabled) {
          setState(() {
            _flashcardGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _webSearchEnabled = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _quizGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
        onQuizToggle: (enabled) {
          setState(() {
            _quizGenerationMode = enabled;
            if (enabled) {
              _imageGenerationMode = false;
              _webSearchEnabled = false;
              _diagramGenerationMode = false;
              _presentationGenerationMode = false;
              _chartGenerationMode = false;
              _flashcardGenerationMode = false;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }



  Future<void> _handleImageUpload() async {
    try {
      // Show image source selection
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _ImageSourceSelector(),
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image != null) {
          // Convert image to base64
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64Image';

          // Show success message and prompt user to type in input
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📸 Image uploaded! Type your question in the input area and send.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );

          // Store the image data temporarily for the next message
          _pendingImageData = dataUrl;
          _focusNode.requestFocus();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  bool _isAnyExtensionActive() {
    return _imageGenerationMode || 
           _diagramGenerationMode || 
           _presentationGenerationMode || 
           _chartGenerationMode || 
           _flashcardGenerationMode || 
           _quizGenerationMode ||
           _webSearchEnabled;
  }
  
  void _clearAllExtensions() {
    setState(() {
      _imageGenerationMode = false;
      _diagramGenerationMode = false;
      _presentationGenerationMode = false;
      _chartGenerationMode = false;
      _flashcardGenerationMode = false;
      _quizGenerationMode = false;
      _webSearchEnabled = false;
    });
    _updateSendButton();
  }

  IconData _getButtonIcon() {
    if (widget.isLoading) {
      return Icons.stop_rounded;
    }
    if (_imageGenerationMode) {
      return Icons.auto_awesome_outlined;
    }
    if (_diagramGenerationMode) {
      return Icons.account_tree_outlined;
    }
    if (_presentationGenerationMode) {
      return Icons.slideshow_outlined;
    }
    if (_chartGenerationMode) {
      return Icons.bar_chart_outlined;
    }
    if (_flashcardGenerationMode) {
      return Icons.style_outlined;
    }
    if (_quizGenerationMode) {
      return Icons.quiz_outlined;
    }
    return Icons.arrow_upward_rounded;
  }

  Color _getButtonIconColor(BuildContext context) {
    if (widget.isLoading) {
      return Colors.white;
    }
    if (_canSend) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
  }
}

class _ExtensionsBottomSheet extends StatelessWidget {
  final bool webSearchEnabled;
  final bool imageGenerationMode;
  final bool diagramGenerationMode;
  final bool presentationGenerationMode;
  final bool chartGenerationMode;
  final bool flashcardGenerationMode;
  final bool quizGenerationMode;
  final VoidCallback onImageUpload;
  final Function(bool) onWebSearchToggle;
  final Function(bool) onImageModeToggle;
  final Function(bool) onDiagramToggle;
  final Function(bool) onPresentationToggle;
  final Function(bool) onChartToggle;
  final Function(bool) onFlashcardToggle;
  final Function(bool) onQuizToggle;
  final VoidCallback onEnhancePrompt;

  const _ExtensionsBottomSheet({
    required this.webSearchEnabled,
    required this.imageGenerationMode,
    this.diagramGenerationMode = false,
    this.presentationGenerationMode = false,
    this.chartGenerationMode = false,
    this.flashcardGenerationMode = false,
    this.quizGenerationMode = false,
    required this.onImageUpload,
    required this.onWebSearchToggle,
    required this.onImageModeToggle,
    required this.onDiagramToggle,
    required this.onPresentationToggle,
    required this.onChartToggle,
    required this.onFlashcardToggle,
    required this.onQuizToggle,
    required this.onEnhancePrompt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Options in grid layout
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // First row
                Row(
                  children: [
                    Expanded(
                      child: _CompactExtensionTile(
                        icon: Icons.photo_camera_outlined,
                        title: 'Analyze',
                        onTap: onImageUpload,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactExtensionTile(
                        icon: Icons.auto_fix_high,
                        title: 'Enhance',
                        onTap: onEnhancePrompt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.search_outlined,
                        title: 'Search',
                        subtitle: '',
                        isToggled: webSearchEnabled,
                        onTap: () => onWebSearchToggle(!webSearchEnabled),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Second row - Generation modes
                Row(
                  children: [
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Image',
                        subtitle: '',
                        isToggled: imageGenerationMode,
                        onTap: () => onImageModeToggle(!imageGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.account_tree_outlined,
                        title: 'Diagram',
                        subtitle: '',
                        isToggled: diagramGenerationMode,
                        onTap: () => onDiagramToggle(!diagramGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.bar_chart_outlined,
                        title: 'Chart',
                        subtitle: '',
                        isToggled: chartGenerationMode,
                        onTap: () => onChartToggle(!chartGenerationMode),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Third row - Presentation, Flashcards, Quiz
                Row(
                  children: [
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.slideshow_outlined,
                        title: 'Presentation',
                        subtitle: '',
                        isToggled: presentationGenerationMode,
                        onTap: () => onPresentationToggle(!presentationGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.style_outlined,
                        title: 'Flashcards',
                        subtitle: '',
                        isToggled: flashcardGenerationMode,
                        onTap: () => onFlashcardToggle(!flashcardGenerationMode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtensionTile(
                        icon: Icons.quiz_outlined,
                        title: 'Quiz',
                        subtitle: '',
                        isToggled: quizGenerationMode,
                        onTap: () => onQuizToggle(!quizGenerationMode),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isToggled;
  final double iconSize;
  final bool compact;
  final VoidCallback onTap;

  const _ExtensionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isToggled = false,
    this.iconSize = 20,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isToggled 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isToggled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 24,
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToggled ? FontWeight.w600 : FontWeight.w500,
                    color: isToggled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactExtensionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _CompactExtensionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSourceSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Camera option
                _ExtensionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Capture image with camera',
                  iconSize: 20,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                
                const SizedBox(height: 12),
                
                // Gallery option
                _ExtensionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select image from your photos',
                  iconSize: 20,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

