import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/api/server.dart';
import '../../../data/model/response/branch_model.dart';
import '../../../data/model/response/category_model.dart';
import '../../../data/model/response/item_model.dart';
import '../../../data/model/response/order_mode.dart';
import '../../../data/repository/branch_repo.dart';
import '../../../data/repository/category_repo.dart';
import '../../../data/repository/featured_item_repo.dart';
import '../../../data/repository/item_repo.dart';
import '../../../data/repository/my_order_repo.dart';
import '../../../data/repository/popular_item_repo.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  static Server server = Server();
  List<OrdersData> activeOrderData = <OrdersData>[];
  List<CategoryData> categoryDataList = <CategoryData>[];
  List<ItemData> itemDataList = <ItemData>[];
  List<ItemData> popularItemDataList = <ItemData>[];
  List<ItemData> featuredItemDataList = <ItemData>[];
  List<BranchData> branchDataList = <BranchData>[];

  String? selectedBranch;
  int? selectedbranchId;

  bool loader = false;
  bool menuLoader = false;
  bool featuredLoader = false;
  bool offerLoader = false;
  bool popularLoader = false;
  bool activeOrderLoader = false;
  int selectedBranchIndex = 0;

  @override
  void onInit() {
    final box = GetStorage();
    getCategoryList();
    getBranchList();
    getPopularItemDataList();
    getFeaturedItemDataList();
    getItemDataList();
    if (box.read('isLogedIn') == true && box.read('isLogedIn') != null) {
      getActiveOrderList();
    }
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    determinePositionAndUpdateBranch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      determinePositionAndUpdateBranch();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  setIndexOfBranch() {
    selectedBranchIndex =
        branchDataList.indexWhere((e) => e.name == selectedBranch);

    selectedbranchId = branchDataList[selectedBranchIndex]
        .id!; //new add for issue in place order page
  }

  setSelectedBranchIndex(int index) {
    selectedBranchIndex = index;
    update();
  }

  getCategoryList() async {
    menuLoader = true;
    update();
    var categoryData = await CategoryRepo.getCategory();
    if (categoryData != null) {
      categoryDataList = categoryData.data!;
      menuLoader = false;
      update();
    } else {
      menuLoader = false;
      update();
    }
  }

  getBranchList() async {
    var branchData = await BranchRepo.getBranch();
    if (branchData.data != null) {
      branchDataList = branchData.data!;
      setInitialBranch();
      update();
    }
  }

  setInitialBranch() {
    if (selectedBranch == null) {
      selectedBranch = branchDataList[0].name;
      selectedbranchId = branchDataList[0].id!;
    }
  }

  getItemDataList() async {
    var itemData = await ItemRepo.getItem();
    if (itemData != null) {
      itemDataList = itemData.data!;
      update();
    } else {
      update();
    }
  }

  getPopularItemDataList() async {
    popularLoader = true;
    update();
    var popularItemData = await PopularItemRepo.getPopularItem();
    if (popularItemData != null) {
      popularItemDataList = popularItemData.data!;
      popularLoader = false;
      update();
    } else {
      update();
    }
  }

  getFeaturedItemDataList() async {
    featuredLoader = true;
    update();
    var featuredItemData = await FeaturedItemRepo.getFeaturedItem();
    if (featuredItemData != null) {
      featuredItemDataList = featuredItemData.data!;
      update();
      featuredLoader = false;
      update();
    } else {
      update();
    }
  }

  getActiveOrderList() async {
    var activeOrder = await MyOrderRepo.getActiveOrder();
    if (activeOrder != null) {
      activeOrderData = activeOrder.data!;
      update();
    } else {}
  }

  determinePositionAndUpdateBranch() async {
    Position? currentPosition = await _determinePosition();
    if (currentPosition != null) {
      _setNearestBranch(currentPosition);
    } else {
      setSelectedBranchToDefault();
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  void _setNearestBranch(Position currentPosition) {
    double minDistance = double.infinity;
    BranchData? nearestBranch;

    for (var branch in branchDataList) {
      double distance = _calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        double.parse(branch.latitude!),
        double.parse(branch.longitude!),
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestBranch = branch;
      }
    }

    if (nearestBranch != null) {
      selectedBranch = nearestBranch.name;
      selectedbranchId = nearestBranch.id;
      selectedBranchIndex = branchDataList.indexOf(nearestBranch);

      print(
          "User's Current Location: Latitude: ${currentPosition.latitude}, Longitude: ${currentPosition.longitude}");
      print(
          "Nearest Branch:${nearestBranch.name}, Location: Latitude: ${nearestBranch.latitude}, Longitude: ${nearestBranch.longitude}");

      update();
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void setSelectedBranchToDefault() {
    if (branchDataList.isNotEmpty) {
      selectedBranch = branchDataList[0].name;
      selectedbranchId = branchDataList[0].id;
      selectedBranchIndex = 0;
      update();
    } else {
      print("Branch data list is empty");
    }
  }
}
