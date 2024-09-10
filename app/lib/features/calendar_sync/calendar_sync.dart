import 'dart:io';

import 'package:acter/common/themes/colors/color_scheme.dart';
import 'package:acter/common/utils/utils.dart';
import 'package:acter/features/calendar_sync/providers/events_to_sync_provider.dart';
import 'package:acter/features/settings/providers/settings_providers.dart';
import 'package:acter/router/router.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:extension_nullable/extension_nullable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('a3::calendar_sync');

final bool isSupportedPlatform = Platform.isAndroid || Platform.isIOS;
typedef IdMapping = (String acterId, String localId);

class CalendarSyncFailed extends Error {}

const rejectionKey = 'rejected_calendar_sync';
const calendarSyncKey = 'calendar_sync_id';
const calendarSyncIdsKey = 'calendar_sync_ids';

// internal state

// ignore: unnecessary_late
late DeviceCalendarPlugin deviceCalendar = DeviceCalendarPlugin();
ProviderSubscription<AsyncValue<List<EventAndRsvp>>>? _subscription;

Future<bool> _isEnabled() async {
  try {
    return (await rootNavKey.currentContext!
        .read(asyncIsActiveProvider(LabsFeature.deviceCalendarSync).future));
  } catch (e, s) {
    _log.severe('Reading current context failed', e, s);
    return false;
  }
}

T? _logError<T>(Result<T> result, String msg, {bool doThrow = false}) {
  if (result.hasErrors) {
    for (final err in result.errors) {
      _log.severe('$msg ${err.errorCode}: ${err.errorMessage}');
    }
    if (doThrow) {
      throw CalendarSyncFailed();
    }
  }
  if (doThrow && result.data == null) {
    throw CalendarSyncFailed();
  }
  return result.data;
}

Future<void> initCalendarSync({bool ignoreRejection = false}) async {
  if (!await _isEnabled()) {
    _log.warning('Calendar Sync disabled');
    return;
  }
  if (!isSupportedPlatform) {
    _log.warning('Calendar Sync not available on this device');
    return;
  }
  final SharedPreferences preferences = await sharedPrefs();

  final hasPermission = await deviceCalendar.hasPermissions();

  if (hasPermission.data == false) {
    if (!ignoreRejection && (preferences.getBool(rejectionKey) ?? false)) {
      _log.warning('user previously rejected calendar sync. quitting');
      return;
    }
    final requesting = await deviceCalendar.requestPermissions();
    if (requesting.data == false) {
      await preferences.setBool(rejectionKey, true);
      _log.warning('user rejected calendar sync. quitting');
      return;
    }
  }
  // FOR DEBUGGING CLEAR Acter CALENDARS VIA:
  // await clearActerCalendars();

  final calendarId = await _getOrCreateCalendar();
  // clear if it existed before
  _subscription?.close();
  // start listening
  _subscription =
      ProviderScope.containerOf(rootNavKey.currentContext!, listen: true)
          .listen(
    eventsToSyncProvider,
    (prev, next) async {
      if (!next.hasValue) {
        _log.info('ignoring state change without value');
        return;
      }
      // FIXME: we probably want to debounce this ...
      await _refreshCalendar(calendarId, next.valueOrNull ?? []);
    },
    fireImmediately: true,
  );
}

Future<void> _refreshCalendar(
  String calendarId,
  List<EventAndRsvp> events,
) async {
  final preferences = await sharedPrefs();
  final Map<String, String> currentLinks = {};
  // reading the existing  linking
  for (final s in (preferences.getStringList(calendarSyncIdsKey) ?? [])) {
    final parts = s.split('=');
    currentLinks[parts.first] = parts.sublist(1).join('=');
  }

  List<Event> foundEvents = [];
  if (currentLinks.isNotEmpty) {
    final foundEventsResult = await deviceCalendar.retrieveEvents(
      calendarId,
      RetrieveEventsParams(eventIds: currentLinks.values.toList()),
    );
    foundEvents = List.of(
      _logError(foundEventsResult, 'Failed to load calendar events') ?? [],
    );
  }

  Map<String, String> newLinks = {};
  List<String> foundEventIds = [];
  for (final eventAndRsvp in events) {
    final calEvent = eventAndRsvp.event;
    final rsvp = eventAndRsvp.rsvp;
    final calEventId = calEvent.eventId().toString();
    var localEvent = currentLinks[calEventId].map((p0) {
      final ret = foundEvents.where((e) => e.eventId == p0).firstOrNull;
      if (ret != null) foundEventIds.add(p0);
      return ret;
    });
    localEvent ??= Event(calendarId);

    localEvent = await _updateEventDetails(calEvent, rsvp, localEvent);
    final localRequest = await deviceCalendar.createOrUpdateEvent(localEvent);
    if (localRequest == null) {
      _log.severe('Updating $calEventId failed. No response. skipping');
      continue;
    }
    final resultData = _logError(localRequest, 'Updating $calEventId failed');
    if (resultData != null) {
      newLinks[calEventId] = resultData;
    } else {
      _log.warning('Updating $calEventId failed. no new id given');
      final evtId = localEvent.eventId;
      if (evtId != null) {
        // assuming that all went fine...
        // maybe this is usual?
        newLinks[calEventId] = evtId;
      }
    }
  }
  final newMapping =
      newLinks.entries.map((m) => '${m.key}=${m.value}').toList();
  _log.info('Storing new mapping: $newMapping');
  // set our new mapping
  await preferences.setStringList(calendarSyncIdsKey, newMapping);

  // time to clean up events that we aren’t tracking anymore
  final uselessEvents = foundEvents
      .where((e) => e.eventId != null && !foundEventIds.contains(e.eventId));
  for (final toDelete in uselessEvents) {
    _log.info('Deleting event ${toDelete.eventId}');
    _logError(
      await deviceCalendar.deleteEvent(calendarId, toDelete.eventId),
      'Deleting local event $toDelete failed',
    );
  }
}

Future<Event> _updateEventDetails(
  CalendarEvent acterEvent,
  RsvpStatusTag? rsvp,
  Event localEvent,
) async {
  localEvent.title = acterEvent.title();
  localEvent.description = acterEvent.description()?.body();
  localEvent.reminders = [Reminder(minutes: 10)];
  localEvent.start = TZDateTime.from(
    toDartDatetime(acterEvent.utcStart()),
    UTC,
  );
  localEvent.end = TZDateTime.from(
    toDartDatetime(acterEvent.utcEnd()),
    UTC,
  );
  localEvent.status = switch (rsvp) {
    RsvpStatusTag.Yes => EventStatus.Confirmed,
    RsvpStatusTag.Maybe => EventStatus.Tentative,
    _ => EventStatus.None
  };
  return localEvent;
}

Future<List<String>> _findActerCalendars() async {
  // confirm this key exists.
  final calendars = _logError(
    await deviceCalendar.retrieveCalendars(),
    'Failed to load calendars',
  );
  if (calendars == null) {
    return [];
  }
  if (Platform.isAndroid) {
    return calendars
        .where(
      (c) =>
          c.accountType == 'LOCAL' &&
          c.accountName == 'Acter' &&
          c.name == 'Acter',
    )
        .map((c) {
      _log.info('Scheduling to delete ${c.id} (${c.accountType})');
      return c.id!;
    }).toList();
  }
  return calendars
      .where((c) => c.accountType == 'Local' && c.name == 'Acter')
      .map((c) {
    _log.info('Scheduling to delete ${c.id} (${c.accountType})');
    return c.id!;
  }).toList();
}

Future<void> clearActerCalendars() async {
  final calendars = await _findActerCalendars();
  if (calendars.isNotEmpty) {
    _log.info('Deleting acter named calendars', calendars);
    await _deleteCalendars(calendars);
  }
}

Future<void> _deleteCalendars(List<String> toDelete) async {
  for (final calendarId in toDelete) {
    _logError(
      await deviceCalendar.deleteCalendar(calendarId),
      'Deleting of $calendarId failed',
    );
  }
}

Future<String> _getOrCreateCalendar() async {
  final preferences = await sharedPrefs();
  final storedKey = preferences.getString(calendarSyncKey);
  // confirm this key exists.
  final calendars = _logError(
    await deviceCalendar.retrieveCalendars(),
    'Failed to load calendars',
  );
  if (storedKey != null) {
    _log.info('Previous key found $storedKey');
    if (calendars != null) {
      for (final calendar in calendars) {
        if (calendar.id == storedKey) {
          _log.info('Existing calendar found $storedKey');
          return storedKey;
        }
      }
    }
  }

  // find old and remove them
  await clearActerCalendars();

  _log.info('No previous calendar found, creating a new one');

  // fallback: calendar not found or not yet created. Create one
  final newCalendarId = _logError(
    await deviceCalendar.createCalendar(
      'Acter',
      calendarColor: brandColor,
      localAccountName: 'Acter',
    ),
    'Failed to create new calendar',
    doThrow: true,
  )!;
  await preferences.setString(calendarSyncKey, newCalendarId);
  return newCalendarId;
}