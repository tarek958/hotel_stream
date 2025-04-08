import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/channel_model.dart';

class FullscreenChannelList extends StatelessWidget {
  final List<Channel> channels;
  final int selectedIndex;
  final Function(Channel) onChannelSelected;
  final ScrollController scrollController;
  final bool isVisible;
  final Channel? currentChannel;

  const FullscreenChannelList({
    super.key,
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
    required this.scrollController,
    required this.isVisible,
    required this.currentChannel,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'Building FullscreenChannelList with ${channels.length} channels, selected: $selectedIndex');

    if (!isVisible) return const SizedBox.shrink();

    // Center the currently playing channel when the list is first displayed
    if (currentChannel != null && scrollController.hasClients) {
      final currentIndex =
          channels.indexWhere((channel) => channel.id == currentChannel!.id);
      if (currentIndex != -1) {
        final itemHeight = 80.0;
        final viewportHeight = scrollController.position.viewportDimension;
        final targetOffset = (currentIndex * itemHeight) -
            (viewportHeight / 2) +
            (itemHeight / 2);
        final clampedOffset =
            targetOffset.clamp(0.0, scrollController.position.maxScrollExtent);

        scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            final isSelected = index == selectedIndex;
            final isPlaying =
                currentChannel != null && channel.id == currentChannel!.id;
            print(
                'Building channel item: ${channel.name}, isSelected: $isSelected, isPlaying: $isPlaying');

            if (isSelected && scrollController.hasClients) {
              final itemHeight = 80.0;
              final viewportHeight =
                  scrollController.position.viewportDimension;
              final targetOffset = (index * itemHeight) -
                  (viewportHeight / 2) +
                  (itemHeight / 2);
              final clampedOffset = targetOffset.clamp(
                  0.0, scrollController.position.maxScrollExtent);

              scrollController.animateTo(
                clampedOffset,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: isPlaying
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.accent.withOpacity(0.3),
                        ],
                      )
                    : null,
                color: isPlaying ? null : AppColors.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.1),
                  width: isSelected ? 2 : 1,
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
                    color: isPlaying ? AppColors.primary : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isPlaying
                    ? const Icon(Icons.play_arrow, color: AppColors.accent)
                    : null,
                onTap: () {
                  print('Channel tapped: ${channel.name}');
                  onChannelSelected(channel);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
