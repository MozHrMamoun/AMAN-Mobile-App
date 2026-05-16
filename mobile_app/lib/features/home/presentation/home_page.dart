import 'package:flutter/material.dart';

import '../../../owner_home_page.dart';
import '../../../seeker_home_page.dart';

class HomePageByRole {
  const HomePageByRole._();

  static Widget fromRole(String role) {
    return role.toLowerCase() == 'owner'
        ? const OwnerHomePage()
        : const SeekerHomePage();
  }
}
