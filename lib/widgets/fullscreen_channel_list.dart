import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/channel_model.dart';

class FullscreenChannelList extends StatefulWidget {
  final List<Channel> channels;
  final int selectedIndex;
  final Function(Channel) onChannelSelected;
  final ScrollController scrollController;
  final bool isVisible;
  final Channel? currentChannel;

  const FullscreenChannelList({
    Key? key,
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
    required this.scrollController,
    required this.isVisible,
    required this.currentChannel,
  }) : super(key: key);

  @override
  State<FullscreenChannelList> createState() => _FullscreenChannelListState();
}

class _FullscreenChannelListState extends State<FullscreenChannelList> {
  // Constant for channel item height including padding
  static const double ITEM_HEIGHT = 82.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerSelectedChannel(context);
    });
  }

  @override
  void didUpdateWidget(FullscreenChannelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Center the channel when selected index changes or visibility changes
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        (!oldWidget.isVisible && widget.isVisible)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerSelectedChannel(context);
      });
    }
  }

  void _centerSelectedChannel(BuildContext context) {
    if (!widget.scrollController.hasClients || widget.selectedIndex < 0) {
      print('CENTERLOG: ScrollController has no clients or invalid index');
      return;
    }

    try {
      // Get viewport height
      final viewportHeight = widget.scrollController.position.viewportDimension;
      print('CENTERLOG: ListView height: $viewportHeight');

      // Calculate position of the selected item
      final itemPosition = widget.selectedIndex * ITEM_HEIGHT;
      print('CENTERLOG: Item position: $itemPosition');

      // Calculate target offset to center the item
      final targetOffset =
          itemPosition - (viewportHeight / 2) + (ITEM_HEIGHT / 2);
      print('CENTERLOG: Target offset: $targetOffset');

      // Get maximum scroll extent and current offset for debugging
      final maxScrollExtent = widget.scrollController.position.maxScrollExtent;
      final currentOffset = widget.scrollController.position.pixels;
      print(
          'CENTERLOG: Max scroll extent: $maxScrollExtent, Current offset: $currentOffset');

      // Clamp the offset to valid range
      final clampedOffset = targetOffset.clamp(0.0, maxScrollExtent);

      // Use jumpTo for immediate positioning without animation
      widget.scrollController.jumpTo(clampedOffset);
      print(
          'CENTERLOG: JUMPED to offset $clampedOffset for channel ${widget.selectedIndex}');
    } catch (e) {
      print('CENTERLOG: Error during centering: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building FullscreenChannelList with ${widget.channels.length} channels, selected: ${widget.selectedIndex}');

    if (!widget.isVisible) return const SizedBox.shrink();

    // Center the currently playing channel when the list is first displayed
    if (widget.currentChannel != null && widget.scrollController.hasClients) {
      final currentIndex = widget.channels
          .indexWhere((channel) => channel.id == widget.currentChannel!.id);
      if (currentIndex != -1) {
        final itemHeight = 80.0;
        final viewportHeight =
            widget.scrollController.position.viewportDimension;
        final targetOffset = (currentIndex * itemHeight) -
            (viewportHeight / 2) +
            (itemHeight / 2);
        final clampedOffset = targetOffset.clamp(
            0.0, widget.scrollController.position.maxScrollExtent);

        widget.scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Column(
        children: [
          // Header with title
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Channels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Channel list
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: widget.channels.length,
              itemExtent: ITEM_HEIGHT, // Fixed height for precise calculations
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                final isSelected = index == widget.selectedIndex;
                final isPlaying = widget.currentChannel != null &&
                    channel.id == widget.currentChannel!.id;
                print(
                    'Building channel item: ${channel.name}, isSelected: $isSelected, isPlaying: $isPlaying');

                if (isSelected && widget.scrollController.hasClients) {
                  final itemHeight = 80.0;
                  final viewportHeight =
                      widget.scrollController.position.viewportDimension;
                  final targetOffset = (index * itemHeight) -
                      (viewportHeight / 2) +
                      (itemHeight / 2);
                  final clampedOffset = targetOffset.clamp(
                      0.0, widget.scrollController.position.maxScrollExtent);

                  widget.scrollController.animateTo(
                    clampedOffset,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: isPlaying
                        ? LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.3),
                              AppColors.accent.withOpacity(0.3),
                            ],
                          )
                        : null,
                    color:
                        isPlaying ? null : AppColors.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: false,
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
                      widget.onChannelSelected(channel);
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
