import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cc_app/pages/login.dart';
import 'package:cc_app/pages/create_group.dart';
import 'package:cc_app/controllers/user.dart';

int _selectedIndex = 1;

void _setSelectedIndex(int index) {
  _selectedIndex = index;
}

void showBottomOptions(BuildContext context, int index) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color.fromARGB(255, 60, 60, 67),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index == 1) ...[
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text(
                'Log out',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Provider.of(context, listen: false).logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.close, color: Colors.white),
            title: const Text('Close', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}
