import 'package:acter/common/widgets/acter_icon_picker/acter_icon_widget.dart';
import 'package:acter/common/widgets/acter_icon_picker/model/acter_icons.dart';
import 'package:acter/common/widgets/acter_icon_picker/model/color_data.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter/material.dart';

class CategoryHeaderView extends StatelessWidget {
  final Category category;

  const CategoryHeaderView({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return _buildCategoryHeader();
  }

  Widget _buildCategoryHeader() {
    final display = category.display();
    return Row(
      children: [
        ActerIconWidget(
          iconSize: 24,
          color: convertColor(
            display?.color(),
            iconPickerColors[0],
          ),
          icon: ActerIcon.iconForCategories(display?.iconStr()),
        ),
        const SizedBox(width: 6),
        Text(category.title()),
      ],
    );
  }
}
