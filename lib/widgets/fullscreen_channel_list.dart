import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/channel_model.dart';

class FullscreenChannelList extends StatelessWidget {
  final List<Channel> channels;
  final int selectedIndex;
  final Function(Channel) onChannelSelected;
  final ScrollController scrollController;
  final bool isVisible;

  const FullscreenChannelList({
    super.key,
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
    required this.scrollController,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'Building FullscreenChannelList with ${channels.length} channels, selected: $selectedIndex');

    if (!isVisible) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tv,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Channels',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Channel List
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                final isSelected = index == selectedIndex;
                print(
                    'Building channel item: ${channel.name}, isSelected: $isSelected');

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Image.network(
                      channel.logo,
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.tv, color: AppColors.primary),
                        );
                      },
                    ),
                    title: Text(
                      channel.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      print('Channel tapped: ${channel.name}');
                      onChannelSelected(channel);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
