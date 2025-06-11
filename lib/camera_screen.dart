import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

            //******************************************************************** Parameters
  bool _isSendButtonDisabled = false;
  bool _isTakeButtonDisabled = false;

  CameraController? _cameraController; //Camera harware ko control karta hy
  List<CameraDescription>? _cameras; //ek list hai jo device ke available cameras ka data rakhti hai
  bool _isCameraInitialized = false;// check krny ky liyh camera initialize hua ya nahi
  bool _isCameraPreviewOpen = false;// sirf camera live dakhna chal kiya raha hy no recording
  bool _isCameraLive = false; // camera live hy ya nahi

  bool _hasCapturedImage = false; // image campure ki hy ya nahi
  XFile? _capturedImage;//XFile ek class hai jo captured ya selected file ko represent karti hai

  bool _isUploading = false;//picture upload hui hy ya nahi ilhal false hy
  bool _showLoadingSpinner = false; // gool daira loading ky liyh use hota hy
  Map<String, dynamic>? _resultData;// ik dictionary hy jha pr API response ko store karte ho ya JSON data ko parse karte ho
  String? _resultText;

  bool _isPedestrianMode = false;// pedestrain mode filhal false e hy
  String? _apiErrorMessage; // api sae koi b error msg ay ga usky liyh
                        //******************************************************** parameters



  Widget _buildPedestrianResult() {
    final status = _resultData?["status"] ?? "Unknown";
    final timestamp = _resultData?["timestamp"]?.toString().substring(0, 19) ?? "";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.person, size: 40, color: Color(0xFF00FF88)),
        const SizedBox(height: 10),
        Text(
          'Pedestrian Verification',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status.contains("Authorized") ? "✅ Authorized" : "❌ Unauthorized",
          style: TextStyle(
            color: status.contains("Authorized") ? Colors.green : Colors.red,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Timestamp: $timestamp',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }


  Widget _buildVehicleResult() {
    final status = _resultData?["status"] ?? "Unknown";
    final isAuthorized = status.toLowerCase().contains("authorized");

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.directions_car, size: 40, color: Color(0xFF00FF88)),
        const SizedBox(height: 10),
        Text(
          'Vehicle Verification',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isAuthorized ? "✅ Authorized" : "❌ Unauthorized",
          style: TextStyle(
            color: isAuthorized ? Colors.green : Colors.red,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    if (_capturedImage != null) {
      File(_capturedImage!.path).delete(); // Convert to File first
    }
    super.dispose();
  }
//yha sae lekr
  // yeh function camera ko initiliaze krta hy sirf
  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackBar('Camera permission is required');
      return;
    }

    _cameras = await availableCameras();
    if (_cameras!.isEmpty) {
      _showSnackBar('No cameras found on device');
      return;
    }

    // ✅ Prefer the back camera explicitly
    final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high, // You can change to medium if needed for low-end devices
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _showSnackBar('Error initializing camera: $e');
    }
  }


  void _openCameraPreview() async {
    //user ko rukne ka kehna jab tak pehla process khatam nahi hota
    if (_isUploading) {
      _showSnackBar('Please wait for the result first');
      return;
    }
//app crash se bacha raha hai agar permission na mile
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackBar('Camera permission is required');
      return;
    }
//agar phone mein hardware hi nahi hai, user ko inform karo
    if (_cameraController == null) {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        _showSnackBar('No cameras found on device');
        return;
      }

      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      } catch (e) {
        debugPrint('Error initializing camera: $e');
        _showSnackBar('Error initializing camera: $e');
        return;
      }
    }

    setState(() {
      _isCameraPreviewOpen = true;
      _isCameraLive = true;
      _hasCapturedImage = false;
      _capturedImage = null;
      _resultText = null;
    });
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      final image = await _cameraController!.takePicture();

      // Purani image ko delete karna zaruri nahi — wo pehle hi _retakePicture mein delete ho chuki hoti hai

      setState(() {
        _capturedImage = image;       // Yehi final image samjhi jayegi
        _hasCapturedImage = true;
        _isCameraLive = false;        // Preview band
      });

      // Optional: yahan se image ko agay processing ke liye bhej sakte ho
      // _processImage(image);  <- agar koi API ya processing ka method hai

    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showSnackBar('Error capturing image: $e');
    }
  }


  void _retakePicture() async {
    if (!_isCameraInitialized) {
      _showSnackBar('Camera not ready');
      return;
    }

    // Purani image file delete karo agar koi hai
    if (_capturedImage != null) {
      final file = File(_capturedImage!.path);
      if (await file.exists()) {
        await file.delete(); // Blur ya unwanted image zaya kar di
      }
    }

    setState(() {
      _capturedImage = null;
      _hasCapturedImage = false;
      _isCameraLive = true; // Preview chalu karo
    });
  }



  void _handleSendPressed() async {
    // Close camera preview immediately
    if (_isCameraPreviewOpen) {
      await _cameraController?.dispose();
      _cameraController = null;
      setState(() {
        _isCameraPreviewOpen = false;
        _isCameraLive = false;
        _isCameraInitialized = false;
      });
    }

    setState(() {
      _isSendButtonDisabled = true;
    });

    await _onNextClicked(); // Call API

    await Future.delayed(const Duration(seconds: 1)); // Optional delay for smooth UI

    setState(() {
      _isSendButtonDisabled = false;
    });
  }


  void _handleTakePressed() async {
    setState(() {
      _isTakeButtonDisabled = true;
    });

    if (_isCameraLive) {
      await _takePicture();
    } else {
      _retakePicture();
    }

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isTakeButtonDisabled = false;
    });
  }

  Future<void> _onNextClicked() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) _showSnackBar('No internet connection');
        return;
      }
    } catch (e) {
      debugPrint('Connectivity check error: $e');
    }

    if (_capturedImage == null) {
      _showSnackBar('Please take a picture first');
      return;
    }

    setState(() {
      _isUploading = true;
      _showLoadingSpinner = true;
      _resultData = null;
      _resultText = null;
      _apiErrorMessage = null; // Reset error state
    });

    try {
      final apiService = ApiService();
      final response = await apiService.sendImageForVerification(
        _capturedImage!,
        _isPedestrianMode,
      );

      setState(() {
        _resultData = response;
        _apiErrorMessage = null;

        if (_isPedestrianMode) {
          _resultText = 'Status: ${response['status']}\n'
              'Timestamp: ${response['timestamp']}';
        } else {
          _resultText = 'Status: ${response['status']}\n'
              'License: ${response['license_plate']}\n'
              'Make: ${response['car_make']}\n'
              'Model: ${response['car_model']}\n'
              'Timestamp: ${response['timestamp']}';
        }
      });
    } catch (e) {
      final errorMsg = e is SocketException
          ? 'Network error'
          : e is TimeoutException
          ? 'Request timeout'
          : 'Server error';
      debugPrint('API call failed: $e');
      setState(() {
        _resultText = null;
        _apiErrorMessage = errorMsg;
      });
    } finally {
      setState(() {
        _isUploading = false;
        _showLoadingSpinner = false;
        // Don't clear _capturedImage here anymore
        // Let result show first
      });
    }
  }


  Future<void> _pickImageFromGallery() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) _showSnackBar('No internet connection');
        return;
      }
    } catch (e) {
      debugPrint('Connectivity check error: $e');
    }

    if (_isUploading) {
      _showSnackBar('Please wait for the result first');
      return;
    }

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      _showSnackBar('Gallery permission is required');
      return;
    }

    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _capturedImage = image;
          _hasCapturedImage = true;
          _isCameraPreviewOpen = false;
          _resultData = null;
          _resultText = null;
          _apiErrorMessage = null; // Reset error state
          _showLoadingSpinner = true;
          _isUploading = true;
        });

        try {
          final apiService = ApiService();
          final response = await apiService.sendImageForVerification(
            image,
            _isPedestrianMode,
          );

          setState(() {
            _resultData = response;
            _apiErrorMessage = null;

            if (_isPedestrianMode) {
              _resultText = 'Status: ${response['status']}\n'
                  'Timestamp: ${response['timestamp']}';
            } else {
              _resultText = 'Status: ${response['status']}\n'
                  'License: ${response['license_plate']}\n'
                  'Make: ${response['car_make']}\n'
                  'Model: ${response['car_model']}\n'
                  'Timestamp: ${response['timestamp']}';
            }
          });
        } catch (e) {
          final errorMsg = e is SocketException
              ? 'Network error'
              : e is TimeoutException
              ? 'Request timeout'
              : 'Server error';
          debugPrint('Gallery upload failed: $e');
          setState(() {
            _resultText = null;
            _apiErrorMessage = errorMsg;
          });
        } finally {
          setState(() {
            _showLoadingSpinner = false;
            _isUploading = false;
            _capturedImage = null;
            _hasCapturedImage = false;
          });
        }

        await _initializeCamera();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showSnackBar('Error picking image: $e');
    }
  }

//yha tak
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isCameraPreviewOpen) {
          await _cameraController?.dispose();
          _cameraController = null;
          setState(() {
            _isCameraPreviewOpen = false;
            _isCameraLive = false;
            _isCameraInitialized = false;
            _capturedImage = null;
            _hasCapturedImage = false;
          });
          return false;
        }
        return true;
      },
        child: Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Tevelgo Visia',
              style: GoogleFonts.rubik(
                fontSize: 30,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return OrientationBuilder(
                builder: (context, orientation) {
                  return Stack(
                    children: [
                      if (_isCameraPreviewOpen)
                        Positioned.fill(
                          child: Column(
                            children: [
                              Expanded(
                                child: _isCameraLive
                                    ? (_isCameraInitialized && _cameraController != null
                                    ? CameraPreview(_cameraController!)
                                    : const Center(
                                  child: Text(
                                    'Loading camera...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ))
                                    : _hasCapturedImage && _capturedImage != null
                                    ? Container(
                                  color: const Color(0xFF1E1E1E),
                                  margin: const EdgeInsets.all(20),
                                  child: Image.file(
                                    File(_capturedImage!.path),
                                    fit: BoxFit.contain,
                                  ),
                                )
                                    : const Center(
                                  child: Text(
                                    'No picture taken',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              Container(
                                color: const Color(0xFF1E1E1E),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: (_hasCapturedImage && !_isSendButtonDisabled) ? _handleSendPressed : null,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('Send'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.greenAccent.shade400,
                                        disabledBackgroundColor: Colors.grey,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isTakeButtonDisabled ? null : _handleTakePressed,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Capture'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00FF88),
                                        disabledBackgroundColor: Colors.grey,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: IntrinsicHeight(
                              child: Column(
                                children: [
                                  const SizedBox(height: 60),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '   Welcome',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 30,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.5),
                                            offset: const Offset(2, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Mode:',
                                          style: TextStyle(color: Colors.white, fontSize: 16),
                                        ),
                                        Row(
                                          children: [
                                            const Text('Vehicle', style: TextStyle(color: Colors.white)),
                                            Switch(
                                              value: _isPedestrianMode,
                                              onChanged: (value) {
                                                setState(() {
                                                  _isPedestrianMode = value;
                                                  _resultData = null;
                                                  _resultText = null;
                                                  _apiErrorMessage = null;
                                                });
                                              },
                                              activeColor: const Color(0xFF00FF88),
                                            ),
                                            const Text('Pedestrian', style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    height: isWide ? 220 : 180,
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: _showLoadingSpinner
                                          ? const CircularProgressIndicator(color: Color(0xFF00FF88))
                                          : (_apiErrorMessage != null
                                          ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                                          const SizedBox(height: 10),
                                          Text(
                                            _apiErrorMessage!,
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      )
                                          : (_resultData != null
                                          ? SingleChildScrollView(
                                        padding: const EdgeInsets.all(12.0),
                                        child: _isPedestrianMode
                                            ? _buildPedestrianResult()
                                            : _buildVehicleResult(),
                                      )
                                          : const SizedBox.shrink())),
                                    ),
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: FloatingActionButton.extended(
                                            heroTag: 'gallery_btn',
                                            onPressed: _pickImageFromGallery,
                                            backgroundColor: const Color(0xFF1E1E1E),
                                            icon: const Icon(Icons.photo_library, color: Color(0xFF00FF88)),
                                            label: const Text('Gallery', style: TextStyle(color: Color(0xFF00FF88))),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: FloatingActionButton.extended(
                                            heroTag: 'capture_btn',
                                            onPressed: _openCameraPreview,
                                            backgroundColor: const Color(0xFF00FF88),
                                            icon: Icon(
                                              _isPedestrianMode ? Icons.directions_walk : Icons.directions_car,
                                              color: Colors.black,
                                              size: 30,
                                            ),
                                            label: Text(
                                              _isPedestrianMode ? 'Scan Person' : 'Scan Vehicle',
                                              style: const TextStyle(color: Colors.black),
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
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),


    );
  }
}
