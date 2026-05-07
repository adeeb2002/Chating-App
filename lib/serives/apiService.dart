import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:provider/model/massege.dart';

final dataApi = ChangeNotifierProvider<GetDataFromApi>(
  (ref) => GetDataFromApi(),
);

class GetDataFromApi extends ChangeNotifier {
  List<Massege> post = [];
  GetDataFromApi() {
    getData();
  }

  void getData() async {
    final response = await http.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      for (var i = 0; i < data.length; i++) {
        post.add(Massege.fromMap(data[i]));
      }
      print(post.length.toString());
      notifyListeners();
    }
  }
}
