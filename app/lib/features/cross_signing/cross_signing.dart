import 'dart:async';
import 'dart:io';

import 'package:acter/common/themes/app_theme.dart';
import 'package:acter/router/router.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sprintf/sprintf.dart';

import 'package:logging/logging.dart';

final _log = Logger('a3::cross_signing');

class VerificationProcess {
  bool verifiyingThisDevice;
  String stage;

  VerificationProcess({
    required this.verifiyingThisDevice,
    required this.stage,
  });
}

class CrossSigning {
  Client client;
  bool acceptingRequest = false;
  bool waitForMatch = false;
  late StreamSubscription<VerificationEvent>? _verificationPoller;
  final Map<String, VerificationProcess> _processMap = {};
  bool _mounted = true;
  bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  CrossSigning({required this.client}) {
    _installVerificationEvent();
  }

  void dispose() {
    _mounted = false;
    _verificationPoller?.cancel();
  }

  void _installVerificationEvent() {
    _verificationPoller = client.verificationEventRx()?.listen((event) {
      String eventType = event.eventType();
      _log.info('$eventType - flow_id: ${event.flowId()}');
      switch (eventType) {
        case 'm.key.verification.request':
          _onKeyVerificationRequest(event);
          break;
        case 'm.key.verification.ready':
          _onKeyVerificationReady(event, false);
          break;
        case 'm.key.verification.start':
          _onKeyVerificationStart(event);
          break;
        case 'm.key.verification.cancel':
          _onKeyVerificationCancel(event);
          break;
        case 'm.key.verification.accept':
          _onKeyVerificationAccept(event);
          break;
        case 'm.key.verification.key':
        case 'SasState::KeysExchanged':
          _onKeyVerificationKey(event);
          break;
        case 'm.key.verification.mac':
          _onKeyVerificationMac(event);
          break;
        case 'm.key.verification.done':
          _onKeyVerificationDone(event);
          break;
      }
    });
  }

  void _onKeyVerificationRequest(VerificationEvent event) {
    String flowId = event.flowId();
    if (_processMap.containsKey(flowId)) {
      return;
    }
    // this case is bob side
    _processMap[flowId] = VerificationProcess(
      verifiyingThisDevice: true, // this device is requested for verification
      stage: 'm.key.verification.request',
    );
    acceptingRequest = false;
    showModalBottomSheet(
      context: rootNavKey.currentContext!,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildOnRequest(context, event, flowId),
      ),
      isDismissible: false,
    );
  }

  Widget _buildOnRequest(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: isDesktop ? 2 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: isDesktop
                      ? const Icon(Atlas.laptop)
                      : const Icon(Atlas.phone),
                ),
                Text(
                  AppLocalizations.of(context)!.sasIncomingReqNotifTitle,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      rootNavKey.currentContext?.pop();
                      // cancel verification request from other device
                      await event.cancelVerificationRequest();
                    },
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: Text(
            sprintf(
              AppLocalizations.of(context)!.sasIncomingReqNotifContent,
              [event.sender()],
            ),
          ),
        ),
        const Spacer(flex: 1),
        const Flexible(
          flex: 3,
          child: Icon(Atlas.lock_keyhole),
        ),
        const Spacer(flex: 1),
        Flexible(
          flex: 1,
          child: _buildBodyOnRequest(context, event),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildBodyOnRequest(BuildContext context, VerificationEvent event) {
    if (acceptingRequest) {
      return const CircularProgressIndicator();
    }
    return ElevatedButton(
      child: Text(AppLocalizations.of(context)!.acceptRequest),
      onPressed: () async {
        if (_mounted) {
          acceptingRequest = true;
        }
        rootNavKey.currentContext?.pop();
        // accept verification request from other device
        await event.acceptVerificationRequest();
        // go to onReady status
        Future.delayed(const Duration(milliseconds: 500), () {
          _onKeyVerificationReady(event, true);
        });
      },
    );
  }

  void _onKeyVerificationReady(VerificationEvent event, bool manual) {
    String flowId = event.flowId();
    if (manual) {
      _processMap[flowId]!.stage = 'm.key.verification.ready';
    } else {
      // this device is alice side
      _processMap[flowId] = VerificationProcess(
        verifiyingThisDevice: false, // other device is ready for verification
        stage: 'm.key.verification.ready',
      );
    }
    showModalBottomSheet(
      context: rootNavKey.currentContext!,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildOnReady(context, event, flowId),
      ),
      isDismissible: false,
    );
  }

  Widget _buildOnReady(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: isDesktop
                      ? const Icon(Atlas.laptop)
                      : const Icon(Atlas.phone),
                ),
                const SizedBox(width: 5),
                Text(
                  _processMap[flowId]!.verifiyingThisDevice
                      ? AppLocalizations.of(context)!.verifyThisSession
                      : AppLocalizations.of(context)!.verifySession,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      rootNavKey.currentContext?.pop();
                      await event.cancelVerificationRequest();
                    },
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Text(
              AppLocalizations.of(context)!.verificationScanSelfNotice,
            ),
          ),
        ),
        const Flexible(
          flex: 2,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: TextButton(
            onPressed: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Atlas.camera),
                ),
                Text(
                  AppLocalizations.of(context)!.verificationScanWithThisDevice,
                ),
              ],
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: Wrap(
            children: [
              ListTile(
                title: Text(
                  AppLocalizations.of(context)!.verificationScanEmojiTitle,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!
                      .verificationScanSelfEmojiSubtitle,
                ),
                trailing: const Icon(Icons.keyboard_arrow_right_outlined),
                onTap: () async {
                  // start sas verification from this device
                  await event.startSasVerification();
                  // go to onStart status
                  _onKeyVerificationStart(event);
                },
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  void _onKeyVerificationStart(VerificationEvent event) {
    if (rootNavKey.currentContext?.canPop() == true) {
      rootNavKey.currentContext?.pop();
    }
    String flowId = event.flowId();
    if (_processMap[flowId]?.stage != 'm.key.verification.request' &&
        _processMap[flowId]?.stage != 'm.key.verification.ready') {
      return;
    }
    _processMap[flowId]?.stage = 'm.key.verification.start';
    showModalBottomSheet(
      context: rootNavKey.currentContext!,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildOnStart(context, event, flowId),
      ),
      isDismissible: false,
    );
    // accept the sas verification that other device started
    Future.delayed(const Duration(milliseconds: 500), () async {
      await event.acceptSasVerification();
    });
  }

  Widget _buildOnStart(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: 1,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                child: isDesktop
                    ? const Icon(Atlas.laptop)
                    : const Icon(Atlas.phone),
              ),
              const SizedBox(width: 5),
              Text(
                _processMap[flowId]?.verifiyingThisDevice == true
                    ? AppLocalizations.of(context)!.verifyThisSession
                    : AppLocalizations.of(context)!.verifySession,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await event.cancelSasVerification();
                  },
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Flexible(
          flex: 3,
          child: Center(
            child: SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: Center(
            child: Text(AppLocalizations.of(context)!.pleaseWait),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  void _onKeyVerificationCancel(VerificationEvent event) {
    if (rootNavKey.currentContext?.canPop() == true) {
      rootNavKey.currentContext?.pop();
    }
    String flowId = event.flowId();
    _processMap[flowId]?.stage = 'm.key.verification.cancel';
    showModalBottomSheet(
      context: rootNavKey.currentContext!,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildOnCancel(context, event, flowId),
      ),
    );
  }

  String _getCancelledMsg(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    VerificationProcess? process = _processMap[flowId];
    if (process == null) {
      return 'No messages';
    }
    // [ref] https://spec.matrix.org/unstable/client-server-api/#mkeyverificationcancel
    final reason = event.getContent('reason');
    if (reason != null) {
      return reason;
    }
    return AppLocalizations.of(context)!.verificationConclusionCompromised;
  }

  Widget _buildOnCancel(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: isDesktop ? 2 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: isDesktop
                      ? const Icon(Atlas.laptop)
                      : const Icon(Atlas.phone),
                ),
                const SizedBox(width: 5),
                Text(
                  _processMap[flowId]?.verifiyingThisDevice == true
                      ? AppLocalizations.of(context)!.verifyThisSession
                      : AppLocalizations.of(context)!.verifySession,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        const Spacer(flex: 1),
        const Flexible(
          flex: 3,
          child: Icon(Atlas.lock_keyhole),
        ),
        Flexible(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_getCancelledMsg(context, event, flowId)),
          ),
        ),
        const Spacer(flex: 1),
        Flexible(
          flex: 1,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.40,
            child: ElevatedButton(
              child: Text(AppLocalizations.of(context)!.sasGotIt),
              onPressed: () {
                rootNavKey.currentContext?.pop();
                // finish verification
                _processMap.remove(flowId);
              },
            ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  void _onKeyVerificationAccept(VerificationEvent event) {
    if (rootNavKey.currentContext?.canPop() == true) {
      rootNavKey.currentContext?.pop();
    }
    String flowId = event.flowId();
    _processMap[flowId]?.stage = 'm.key.verification.accept';
    showModalBottomSheet(
      context: rootNavKey.currentContext!,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildOnAccept(context, event, flowId),
      ),
      isDismissible: false,
    );
  }

  Widget _buildOnAccept(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: isDesktop ? 2 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: isDesktop
                      ? const Icon(Atlas.laptop)
                      : const Icon(Atlas.phone),
                ),
                const SizedBox(width: 5),
                Text(
                  _processMap[flowId]?.verifiyingThisDevice == true
                      ? AppLocalizations.of(context)!.verifyThisSession
                      : AppLocalizations.of(context)!.verifySession,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        const Spacer(flex: 1),
        const Flexible(
          flex: 3,
          child: Center(
            child: SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        const Spacer(flex: 1),
        Flexible(
          flex: 2,
          child: Text(
            sprintf(
              AppLocalizations.of(context)!.verificationRequestWaitingFor,
              [event.sender()],
            ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  void _onKeyVerificationKey(VerificationEvent event) {
    if (rootNavKey.currentContext?.canPop() == true) {
      rootNavKey.currentContext?.pop();
    }
    String flowId = event.flowId();
    _processMap[flowId]?.stage = 'm.key.verification.key';
    event.getEmojis().then((emojis) {
      showModalBottomSheet(
        context: rootNavKey.currentContext!,
        builder: (BuildContext context) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: _buildOnKey(context, event, flowId, emojis),
        ),
        isDismissible: false,
      );
    });
  }

  Widget _buildOnKey(
    BuildContext context,
    VerificationEvent event,
    String flowId,
    FfiListVerificationEmoji emojis,
  ) {
    List<int> codes = emojis.map((e) => e.symbol()).toList();
    List<String> descriptions = emojis.map((e) => e.description()).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          flex: isDesktop ? 1 : 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: isDesktop
                      ? const Icon(Atlas.laptop)
                      : const Icon(Atlas.phone),
                ),
                const SizedBox(width: 5),
                Text(
                  _processMap[flowId]?.verifiyingThisDevice == true
                      ? AppLocalizations.of(context)!.verifyThisSession
                      : AppLocalizations.of(context)!.verifySession,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await event.cancelVerificationRequest();
                    },
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: isDesktop ? 1 : 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              AppLocalizations.of(context)!.verificationEmojiNotice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const Spacer(flex: 1),
        Expanded(
          flex: isDesktop ? 2 : 7,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Theme.of(context).colorScheme.neutral2,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: GridView.count(
                  crossAxisCount: isDesktop ? 7 : 4,
                  children: List.generate(emojis.length, (index) {
                    return GridTile(
                      child: Column(
                        children: <Widget>[
                          Text(
                            String.fromCharCode(codes[index]),
                            style: const TextStyle(fontSize: 32),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            descriptions[index],
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        const Spacer(flex: 1),
        Expanded(
          flex: isDesktop ? 1 : 2,
          child: _buildBodyOnKey(context, event),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildBodyOnKey(BuildContext context, VerificationEvent event) {
    if (waitForMatch) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            sprintf(
              AppLocalizations.of(context)!.verificationRequestWaitingFor,
              [event.sender()],
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          child: Text(AppLocalizations.of(context)!.verificationSasDoNotMatch),
          onPressed: () async {
            rootNavKey.currentContext?.pop();
            // mismatch sas verification
            await event.mismatchSasVerification();
          },
        ),
        const SizedBox(width: 15),
        ElevatedButton(
          child: Text(AppLocalizations.of(context)!.verificationSasMatch),
          onPressed: () async {
            if (_mounted) {
              waitForMatch = true;
            }
            rootNavKey.currentContext?.pop();
            // confirm sas verification
            await event.confirmSasVerification();
            // close dialog
            if (_mounted) {
              waitForMatch = false;
            }
          },
        ),
      ],
    );
  }

  void _onKeyVerificationMac(VerificationEvent event) {
    String flowId = event.flowId();
    _processMap[flowId]?.stage = 'm.key.verification.mac';
    Future.delayed(const Duration(milliseconds: 500), () async {
      await event.reviewVerificationMac();
    });
  }

  void _onKeyVerificationDone(VerificationEvent event) {
    if (rootNavKey.currentContext?.canPop() == true) {
      rootNavKey.currentContext?.pop();
    }
    String flowId = event.flowId();
    _processMap[flowId]?.stage = 'm.key.verification.done';
    showModalBottomSheet(
      context: rootNavKey.currentContext!,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildOnDone(context, event, flowId),
      ),
      isDismissible: false,
    );
  }

  String _getDoneMsg(BuildContext context, String flowId) {
    VerificationProcess? process = _processMap[flowId];
    if (process == null) {
      return 'No messages';
    }
    if (process.verifiyingThisDevice) {
      return AppLocalizations.of(context)!.verificationConclusionOkSelfNotice;
    }
    return AppLocalizations.of(context)!.verificationConclusionOkDone;
  }

  Widget _buildOnDone(
    BuildContext context,
    VerificationEvent event,
    String flowId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: isDesktop ? 2 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: isDesktop
                      ? const Icon(Atlas.laptop)
                      : const Icon(Atlas.phone),
                ),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context)!.sasVerified),
              ],
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              _getDoneMsg(context, flowId),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const Flexible(
          flex: 2,
          child: Center(
            child: Icon(Atlas.lock_keyhole),
          ),
        ),
        Flexible(
          flex: 1,
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.40,
              child: ElevatedButton(
                child: Text(AppLocalizations.of(context)!.sasGotIt),
                onPressed: () {
                  rootNavKey.currentContext?.pop();
                  // finish verification
                  _processMap.remove(flowId);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
