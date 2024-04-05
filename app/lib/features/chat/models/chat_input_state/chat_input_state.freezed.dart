// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_input_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$ChatInputState {
  SelectedMessageState get selectedMessageState =>
      throw _privateConstructorUsedError;
  bool get allowEdit => throw _privateConstructorUsedError;
  bool get sendBtnVisible => throw _privateConstructorUsedError;
  bool get emojiPickerVisible => throw _privateConstructorUsedError;
  types.Message? get selectedMessage => throw _privateConstructorUsedError;
  Map<String, String> get mentionReplacements =>
      throw _privateConstructorUsedError;
  bool get editBtnVisible => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChatInputStateCopyWith<ChatInputState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatInputStateCopyWith<$Res> {
  factory $ChatInputStateCopyWith(
          ChatInputState value, $Res Function(ChatInputState) then) =
      _$ChatInputStateCopyWithImpl<$Res, ChatInputState>;
  @useResult
  $Res call(
      {SelectedMessageState selectedMessageState,
      bool allowEdit,
      bool sendBtnVisible,
      bool emojiPickerVisible,
      types.Message? selectedMessage,
      Map<String, String> mentionReplacements,
      bool editBtnVisible});
}

/// @nodoc
class _$ChatInputStateCopyWithImpl<$Res, $Val extends ChatInputState>
    implements $ChatInputStateCopyWith<$Res> {
  _$ChatInputStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedMessageState = null,
    Object? allowEdit = null,
    Object? sendBtnVisible = null,
    Object? emojiPickerVisible = null,
    Object? selectedMessage = freezed,
    Object? mentionReplacements = null,
    Object? editBtnVisible = null,
  }) {
    return _then(_value.copyWith(
      selectedMessageState: null == selectedMessageState
          ? _value.selectedMessageState
          : selectedMessageState // ignore: cast_nullable_to_non_nullable
              as SelectedMessageState,
      allowEdit: null == allowEdit
          ? _value.allowEdit
          : allowEdit // ignore: cast_nullable_to_non_nullable
              as bool,
      sendBtnVisible: null == sendBtnVisible
          ? _value.sendBtnVisible
          : sendBtnVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      emojiPickerVisible: null == emojiPickerVisible
          ? _value.emojiPickerVisible
          : emojiPickerVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedMessage: freezed == selectedMessage
          ? _value.selectedMessage
          : selectedMessage // ignore: cast_nullable_to_non_nullable
              as types.Message?,
      mentionReplacements: null == mentionReplacements
          ? _value.mentionReplacements
          : mentionReplacements // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      editBtnVisible: null == editBtnVisible
          ? _value.editBtnVisible
          : editBtnVisible // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatInputStateImplCopyWith<$Res>
    implements $ChatInputStateCopyWith<$Res> {
  factory _$$ChatInputStateImplCopyWith(_$ChatInputStateImpl value,
          $Res Function(_$ChatInputStateImpl) then) =
      __$$ChatInputStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SelectedMessageState selectedMessageState,
      bool allowEdit,
      bool sendBtnVisible,
      bool emojiPickerVisible,
      types.Message? selectedMessage,
      Map<String, String> mentionReplacements,
      bool editBtnVisible});
}

/// @nodoc
class __$$ChatInputStateImplCopyWithImpl<$Res>
    extends _$ChatInputStateCopyWithImpl<$Res, _$ChatInputStateImpl>
    implements _$$ChatInputStateImplCopyWith<$Res> {
  __$$ChatInputStateImplCopyWithImpl(
      _$ChatInputStateImpl _value, $Res Function(_$ChatInputStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedMessageState = null,
    Object? allowEdit = null,
    Object? sendBtnVisible = null,
    Object? emojiPickerVisible = null,
    Object? selectedMessage = freezed,
    Object? mentionReplacements = null,
    Object? editBtnVisible = null,
  }) {
    return _then(_$ChatInputStateImpl(
      selectedMessageState: null == selectedMessageState
          ? _value.selectedMessageState
          : selectedMessageState // ignore: cast_nullable_to_non_nullable
              as SelectedMessageState,
      allowEdit: null == allowEdit
          ? _value.allowEdit
          : allowEdit // ignore: cast_nullable_to_non_nullable
              as bool,
      sendBtnVisible: null == sendBtnVisible
          ? _value.sendBtnVisible
          : sendBtnVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      emojiPickerVisible: null == emojiPickerVisible
          ? _value.emojiPickerVisible
          : emojiPickerVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedMessage: freezed == selectedMessage
          ? _value.selectedMessage
          : selectedMessage // ignore: cast_nullable_to_non_nullable
              as types.Message?,
      mentionReplacements: null == mentionReplacements
          ? _value._mentionReplacements
          : mentionReplacements // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      editBtnVisible: null == editBtnVisible
          ? _value.editBtnVisible
          : editBtnVisible // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ChatInputStateImpl implements _ChatInputState {
  const _$ChatInputStateImpl(
      {this.selectedMessageState = SelectedMessageState.none,
      this.allowEdit = true,
      this.sendBtnVisible = false,
      this.emojiPickerVisible = false,
      this.selectedMessage = null,
      final Map<String, String> mentionReplacements = const {},
      this.editBtnVisible = false})
      : _mentionReplacements = mentionReplacements;

  @override
  @JsonKey()
  final SelectedMessageState selectedMessageState;
  @override
  @JsonKey()
  final bool allowEdit;
  @override
  @JsonKey()
  final bool sendBtnVisible;
  @override
  @JsonKey()
  final bool emojiPickerVisible;
  @override
  @JsonKey()
  final types.Message? selectedMessage;
  final Map<String, String> _mentionReplacements;
  @override
  @JsonKey()
  Map<String, String> get mentionReplacements {
    if (_mentionReplacements is EqualUnmodifiableMapView)
      return _mentionReplacements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_mentionReplacements);
  }

  @override
  @JsonKey()
  final bool editBtnVisible;

  @override
  String toString() {
    return 'ChatInputState(selectedMessageState: $selectedMessageState, allowEdit: $allowEdit, sendBtnVisible: $sendBtnVisible, emojiPickerVisible: $emojiPickerVisible, selectedMessage: $selectedMessage, mentionReplacements: $mentionReplacements, editBtnVisible: $editBtnVisible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatInputStateImpl &&
            (identical(other.selectedMessageState, selectedMessageState) ||
                other.selectedMessageState == selectedMessageState) &&
            (identical(other.allowEdit, allowEdit) ||
                other.allowEdit == allowEdit) &&
            (identical(other.sendBtnVisible, sendBtnVisible) ||
                other.sendBtnVisible == sendBtnVisible) &&
            (identical(other.emojiPickerVisible, emojiPickerVisible) ||
                other.emojiPickerVisible == emojiPickerVisible) &&
            (identical(other.selectedMessage, selectedMessage) ||
                other.selectedMessage == selectedMessage) &&
            const DeepCollectionEquality()
                .equals(other._mentionReplacements, _mentionReplacements) &&
            (identical(other.editBtnVisible, editBtnVisible) ||
                other.editBtnVisible == editBtnVisible));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedMessageState,
      allowEdit,
      sendBtnVisible,
      emojiPickerVisible,
      selectedMessage,
      const DeepCollectionEquality().hash(_mentionReplacements),
      editBtnVisible);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatInputStateImplCopyWith<_$ChatInputStateImpl> get copyWith =>
      __$$ChatInputStateImplCopyWithImpl<_$ChatInputStateImpl>(
          this, _$identity);
}

abstract class _ChatInputState implements ChatInputState {
  const factory _ChatInputState(
      {final SelectedMessageState selectedMessageState,
      final bool allowEdit,
      final bool sendBtnVisible,
      final bool emojiPickerVisible,
      final types.Message? selectedMessage,
      final Map<String, String> mentionReplacements,
      final bool editBtnVisible}) = _$ChatInputStateImpl;

  @override
  SelectedMessageState get selectedMessageState;
  @override
  bool get allowEdit;
  @override
  bool get sendBtnVisible;
  @override
  bool get emojiPickerVisible;
  @override
  types.Message? get selectedMessage;
  @override
  Map<String, String> get mentionReplacements;
  @override
  bool get editBtnVisible;
  @override
  @JsonKey(ignore: true)
  _$$ChatInputStateImplCopyWith<_$ChatInputStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
