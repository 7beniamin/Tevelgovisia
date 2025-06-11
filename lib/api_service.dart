import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class ApiService {
  final String baseUrl = 'http://192.168.43.17:8000'; // Replace with your actual API URL

  Future<Map<String, dynamic>> sendImageForVerification(
      XFile imageFile,
      bool isPedestrianMode
      ) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl ${isPedestrianMode ? '/detect_faces/' : '/verify-vehicle/'}'),
      );

      // Add image file - let the http package handle the content type automatically
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));

      // Send request
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Bad request');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No Internet connection');
    } on FormatException {
      throw Exception('Invalid server response');
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }
}