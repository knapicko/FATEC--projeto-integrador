import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 10,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = (_controller.value * 2) - 1;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [
                    (position - 0.35).clamp(0.0, 1.0),
                    position.clamp(0.0, 1.0),
                    (position + 0.35).clamp(0.0, 1.0),
                  ],
                  colors: const [
                    Color(0xFFE8EDF3),
                    Color(0xFFF8FAFC),
                    Color(0xFFE8EDF3),
                  ],
                ),
                color: const Color(0xFFE8EDF3),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonContent extends StatelessWidget {
  const SkeletonContent({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.itemCount = 4,
    this.itemHeight = 92,
  });

  final EdgeInsets padding;
  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 56, height: 56, borderRadius: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: itemHeight * 0.22),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: index.isEven ? double.infinity : 150,
                  height: itemHeight * 0.16,
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: index.isEven ? 190 : double.infinity,
                  height: itemHeight * 0.16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonPage extends StatelessWidget {
  const SkeletonPage({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 24),
    this.layout = SkeletonLayout.list,
  });

  final int itemCount;
  final EdgeInsets padding;
  final SkeletonLayout layout;

  @override
  Widget build(BuildContext context) {
    switch (layout) {
      case SkeletonLayout.cards:
        return SkeletonCardList(itemCount: itemCount, padding: padding);
      case SkeletonLayout.grid:
        return SkeletonGrid(itemCount: itemCount, padding: padding);
      case SkeletonLayout.form:
        return SkeletonForm(padding: padding);
      case SkeletonLayout.profile:
        return SkeletonProfile(padding: padding);
      case SkeletonLayout.calendar:
        return SkeletonCalendar(padding: padding);
      case SkeletonLayout.messages:
        return SkeletonMessages(padding: padding);
      case SkeletonLayout.request:
        return SkeletonRequest(padding: padding);
      case SkeletonLayout.list:
        return SkeletonContent(itemCount: itemCount, padding: padding);
    }
  }
}

enum SkeletonLayout {
  list,
  cards,
  grid,
  form,
  profile,
  calendar,
  messages,
  request,
}

class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => Container(
        height: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 84, height: 84, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(
                    width: index.isEven ? double.infinity : 150,
                    height: 17,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 112, height: 13, borderRadius: 4),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 74, height: 24, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SkeletonBox(height: double.infinity, borderRadius: 10),
            ),
            const SizedBox(height: 10),
            SkeletonBox(
              width: index.isEven ? double.infinity : 100,
              height: 16,
              borderRadius: 4,
            ),
            const SizedBox(height: 7),
            const SkeletonBox(width: 72, height: 13, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

class SkeletonForm extends StatelessWidget {
  const SkeletonForm({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 24),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        const SkeletonBox(width: 190, height: 22, borderRadius: 5),
        const SizedBox(height: 22),
        ...List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 110, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                SkeletonBox(height: index == 3 ? 94 : 50, borderRadius: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SkeletonBox(height: 48, borderRadius: 12),
      ],
    );
  }
}

class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 24),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        const Center(
          child: SkeletonBox(width: 104, height: 104, borderRadius: 52),
        ),
        const SizedBox(height: 14),
        const Center(
          child: SkeletonBox(width: 180, height: 20, borderRadius: 4),
        ),
        const SizedBox(height: 8),
        const Center(
          child: SkeletonBox(width: 120, height: 14, borderRadius: 4),
        ),
        const SizedBox(height: 24),
        const SkeletonBox(height: 82, borderRadius: 14),
        const SizedBox(height: 14),
        const SkeletonBox(height: 120, borderRadius: 14),
        const SizedBox(height: 14),
        const SkeletonBox(height: 82, borderRadius: 14),
      ],
    );
  }
}

class SkeletonCalendar extends StatelessWidget {
  const SkeletonCalendar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        const SkeletonBox(height: 52, borderRadius: 12),
        const SizedBox(height: 16),
        const SkeletonBox(height: 270, borderRadius: 14),
        const SizedBox(height: 18),
        const SkeletonBox(width: 170, height: 20, borderRadius: 4),
        const SizedBox(height: 12),
        const SkeletonBox(height: 62, borderRadius: 12),
        const SizedBox(height: 12),
        const SkeletonBox(height: 62, borderRadius: 12),
      ],
    );
  }
}

class SkeletonMessages extends StatelessWidget {
  const SkeletonMessages({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 50, height: 50, borderRadius: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: index.isEven ? 160 : 110,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                const SkeletonBox(height: 14, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 38, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

class SkeletonRequest extends StatelessWidget {
  const SkeletonRequest({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 24),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        const SkeletonBox(height: 54, borderRadius: 12),
        const SizedBox(height: 16),
        const SkeletonBox(height: 90, borderRadius: 14),
        const SizedBox(height: 16),
        const SkeletonBox(width: 180, height: 20, borderRadius: 4),
        const SizedBox(height: 10),
        const SkeletonBox(height: 130, borderRadius: 14),
        const SizedBox(height: 16),
        const SkeletonBox(height: 90, borderRadius: 14),
        const SizedBox(height: 16),
        const SkeletonBox(height: 48, borderRadius: 12),
      ],
    );
  }
}

class SkeletonProfileCard extends StatelessWidget {
  const SkeletonProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 72, height: 72, borderRadius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonBox(height: 17, borderRadius: 4),
                SizedBox(height: 9),
                SkeletonBox(width: 132, height: 13, borderRadius: 4),
                SizedBox(height: 9),
                SkeletonBox(width: 88, height: 24, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonAgenda extends StatelessWidget {
  const SkeletonAgenda({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 72, borderRadius: 12),
        SizedBox(height: 16),
        SkeletonBox(height: 160, borderRadius: 14),
      ],
    );
  }
}

class SkeletonServiceDetail extends StatelessWidget {
  const SkeletonServiceDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF0FB3FF),
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top,
            left: 12,
            right: 16,
            bottom: 12,
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 24, height: 24, borderRadius: 12),
              SizedBox(width: 14),
              Expanded(child: SkeletonBox(height: 19, borderRadius: 5)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SkeletonBox(height: 250, borderRadius: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        SkeletonBox(width: 128, height: 34, borderRadius: 6),
                        Spacer(),
                        SkeletonBox(width: 64, height: 24, borderRadius: 6),
                        SizedBox(width: 8),
                        SkeletonBox(width: 74, height: 24, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        SkeletonBox(width: 150, height: 16, borderRadius: 4),
                        SizedBox(width: 8),
                        SkeletonBox(width: 52, height: 24, borderRadius: 6),
                        SizedBox(width: 6),
                        SkeletonBox(width: 64, height: 24, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 58,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: SkeletonBox(height: 18, borderRadius: 4),
                          ),
                          SizedBox(width: 12),
                          SkeletonBox(width: 22, height: 22, borderRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SkeletonBox(width: 164, height: 20, borderRadius: 4),
                    const SizedBox(height: 10),
                    Container(
                      height: 88,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          SkeletonBox(width: 52, height: 52, borderRadius: 12),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(height: 16, borderRadius: 4),
                                SizedBox(height: 8),
                                SkeletonBox(
                                  width: 130,
                                  height: 12,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 74,
                            height: 32,
                            child: SkeletonBox(height: 32, borderRadius: 8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SkeletonBox(width: 156, height: 20, borderRadius: 4),
                    const SizedBox(height: 10),
                    const SkeletonBox(height: 14, borderRadius: 4),
                    const SizedBox(height: 7),
                    const SkeletonBox(width: 270, height: 14, borderRadius: 4),
                    const SizedBox(height: 22),
                    const SkeletonBox(width: 172, height: 20, borderRadius: 4),
                    const SizedBox(height: 10),
                    const SkeletonBox(height: 72, borderRadius: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SkeletonServiceSheet extends StatelessWidget {
  const SkeletonServiceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.94,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 28, height: 28, borderRadius: 14),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 21, borderRadius: 5)),
              SizedBox(
                width: 28,
                height: 28,
                child: SkeletonBox(height: 28, borderRadius: 14),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SkeletonBox(height: 46, borderRadius: 10),
          const SizedBox(height: 18),
          const SkeletonBox(width: 152, height: 18, borderRadius: 4),
          const SizedBox(height: 10),
          const SkeletonBox(height: 52, borderRadius: 10),
          const SizedBox(height: 18),
          const SkeletonBox(width: 132, height: 18, borderRadius: 4),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 72, borderRadius: 10)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 72, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 18),
          const SkeletonBox(width: 160, height: 18, borderRadius: 4),
          const SizedBox(height: 10),
          const SkeletonBox(height: 112, borderRadius: 12),
          const Spacer(),
          const SkeletonBox(height: 48, borderRadius: 12),
        ],
      ),
    );
  }
}
