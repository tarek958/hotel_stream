import 'package:flutter/material.dart';
import '../models/channel_model.dart';
import '../models/channel_response.dart';
import '../services/channel_service.dart';
import '../utils/connectivity_util.dart';

class HotelProvider with ChangeNotifier {
  final ChannelService _channelService = ChannelService();
  List<Channel> _channels = [];
  List<Bouquet> _categories = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;
  String _hotelName = '';

  List<Channel> get channels => _channels;
  List<Bouquet> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;
  String get hotelName => _hotelName;

  Future<void> loadHotelInfo(String hotelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // For now, we'll just set a default hotel name
      // TODO: Implement actual hotel info fetching
      _hotelName = 'Hotel Stream';
      _error = null;
    } catch (e) {
      _error = 'Failed to load hotel info: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChannelsAndCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _channelService.getChannelsAndCategories();
      
      _channels = response.channels;
      _categories = response.categories;
      _isOffline = response.isOffline;
      _error = null;
    } catch (e) {
      if (e.toString().contains('offline_no_cache')) {
        _error = 'offline_no_cache';
        _isOffline = true;
      } else if (e.toString().contains('server_error')) {
        _error = 'server_error';
        _isOffline = true;
        // Don't clear channels and categories here, keep showing the existing data
      } else {
        _error = 'Failed to load channels and categories: $e';
      }
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    if (await ConnectivityUtil.isConnected()) {
      await _channelService.clearLocalData();
      await loadChannelsAndCategories();
    } else {
      _error = 'offline_no_connection';
      notifyListeners();
    }
  }

  Channel? getChannelById(String id) {
    try {
      return _channels.firstWhere((channel) => channel.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Channel> getChannelsByCategory(String categoryId) {
    if (categoryId == 'all') {
      return _channels;
    }
    return _channels.where((channel) => channel.categ == categoryId).toList();
  }
}