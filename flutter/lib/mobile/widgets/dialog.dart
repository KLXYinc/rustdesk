import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/common/widgets/toolbar.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void _showSuccess() {
  showToast(translate("Successful"));
}

void setTemporaryPasswordLengthDialog(
    OverlayDialogManager dialogManager) async {
  List<String> lengths = ['6', '8', '10'];
  String length = await bind.mainGetOption(key: "temporary-password-length");
  var index = lengths.indexOf(length);
  if (index < 0) index = 0;
  length = lengths[index];
  dialogManager.show((setState, close, context) {
    setLength(newValue) {
      final oldValue = length;
      if (oldValue == newValue) return;
      setState(() {
        length = newValue;
      });
      bind.mainSetOption(key: "temporary-password-length", value: newValue);
      bind.mainUpdateTemporaryPassword();
      Future.delayed(Duration(milliseconds: 200), () {
        close();
        _showSuccess();
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Set one-time password length")),
      content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: lengths
              .map(
                (value) => Row(
                  children: [
                    Text(value),
                    Radio(
                        value: value, groupValue: length, onChanged: setLength),
                  ],
                ),
              )
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showServerSettings(OverlayDialogManager dialogManager,
    void Function(VoidCallback) upSetState) async {
  List<ServerProfile> profiles = [];
  try {
    String profilesStr = await bind.mainGetOption(key: 'server-profiles');
    if (profilesStr.isNotEmpty) {
      List<dynamic> jsonList = jsonDecode(profilesStr);
      profiles = jsonList.map((e) => ServerProfile.fromJson(e)).toList();
    }
  } catch (e) {
    print("Failed to decode server-profiles: $e");
  }

  // To support legacy, if profiles is empty, let's load legacy custom-rendezvous-server and make it the first profile if exists.
  if (profiles.isEmpty) {
    try {
      Map<String, dynamic> options = jsonDecode(await bind.mainGetOptions());
      final sc = ServerConfig.fromOptions(options);
      if (sc.idServer.isNotEmpty) {
        profiles.add(ServerProfile(
          friendlyName: 'Default',
          enabled: true,
          idServer: sc.idServer,
          relayServer: sc.relayServer,
          apiServer: sc.apiServer,
          key: sc.key,
        ));
      }
    } catch(e) {}
  }

  dialogManager.show((setState, close, context) {
    Future<void> saveProfiles() async {
      final jsonStr = jsonEncode(profiles.map((e) => e.toJson()).toList());
      await bind.mainSetOption(key: 'server-profiles', value: jsonStr);
      upSetState.call(() {});
    }

    void editProfile(int index) {
      ServerProfile? p = index >= 0 ? profiles[index] : null;
      showServerProfileEditor(p, dialogManager, (ServerProfile newP) {
        setState(() {
          if (index >= 0) {
            profiles[index] = newP;
          } else {
            profiles.add(newP);
          }
        });
        saveProfiles();
      });
    }

    return CustomAlertDialog(
      title: Text(translate('Server Profiles')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: profiles.isEmpty 
          ? Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(translate("No profiles found.")),
            ))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: profiles.asMap().entries.map((entry) {
                final index = entry.key;
                final p = entry.value;
                return ListTile(
                  title: Text(p.friendlyName.isNotEmpty ? p.friendlyName : p.idServer),
                  subtitle: Text(p.idServer),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: p.enabled,
                        onChanged: (v) {
                          setState(() { p.enabled = v; });
                          saveProfiles();
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => editProfile(index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() { profiles.removeAt(index); });
                          saveProfiles();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
      ),
      actions: [
        dialogButton('Add', onPressed: () => editProfile(-1)),
        dialogButton('Close', onPressed: () => close(), isOutline: true),
      ],
    );
  });
}

void showServerSettingsWithValue(
    ServerConfig sc, OverlayDialogManager dialogManager, void Function(VoidCallback)? setState) {
  // Backwards compatibility for scan_page.dart that calls this directly with ServerConfig
  showServerProfileEditor(
    ServerProfile(
      idServer: sc.idServer,
      relayServer: sc.relayServer,
      apiServer: sc.apiServer,
      key: sc.key,
      friendlyName: sc.idServer,
    ),
    dialogManager,
    (ServerProfile newP) async {
      await bind.mainSetOption(key: 'custom-rendezvous-server', value: newP.idServer);
      await bind.mainSetOption(key: 'relay-server', value: newP.relayServer);
      await bind.mainSetOption(key: 'api-server', value: newP.apiServer);
      await bind.mainSetOption(key: 'key', value: newP.key);
      
      // Also inject to server-profiles to align with new logic
      try {
        String profilesStr = await bind.mainGetOption(key: 'server-profiles');
        List<dynamic> jsonList = profilesStr.isNotEmpty ? jsonDecode(profilesStr) : [];
        List<ServerProfile> profiles = jsonList.map((e) => ServerProfile.fromJson(e)).toList();
        
        int idx = profiles.indexWhere((p) => p.idServer == newP.idServer);
        if (idx >= 0) profiles[idx] = newP;
        else profiles.add(newP);
        
        await bind.mainSetOption(key: 'server-profiles', value: jsonEncode(profiles.map((e) => e.toJson()).toList()));
      } catch (e) {}

      setState?.call(() {});
    }
  );
}

void showServerProfileEditor(
    ServerProfile? profile,
    OverlayDialogManager dialogManager,
    void Function(ServerProfile) onSave) async {
  final nameCtrl = TextEditingController(text: profile?.friendlyName ?? '');
  final idCtrl = TextEditingController(text: profile?.idServer ?? '');
  final relayCtrl = TextEditingController(text: profile?.relayServer ?? '');
  final apiCtrl = TextEditingController(text: profile?.apiServer ?? '');
  final keyCtrl = TextEditingController(text: profile?.key ?? '');

  RxString idServerMsg = ''.obs;
  RxString relayServerMsg = ''.obs;
  RxString apiServerMsg = ''.obs;

  final controllers = [idCtrl, relayCtrl, apiCtrl, keyCtrl];
  final errMsgs = [
    idServerMsg,
    relayServerMsg,
    apiServerMsg,
  ];

  dialogManager.show((setState, close, context) {
    Future<bool> submit() async {
      if (idCtrl.text.trim().isEmpty) return false;
      onSave(ServerProfile(
        friendlyName: nameCtrl.text.trim(),
        enabled: profile?.enabled ?? true,
        idServer: idCtrl.text.trim(),
        relayServer: relayCtrl.text.trim(),
        apiServer: apiCtrl.text.trim(),
        key: keyCtrl.text.trim(),
      ));
      return true;
    }

    Widget buildField(
        String label, TextEditingController controller, String errorMsg,
        {String? Function(String?)? validator, bool autofocus = false, int? maxLines = 1}) {
      if (isDesktop || isWeb) {
        return Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label),
            ),
            SizedBox(width: 8),
            Expanded(
              child: serverSettingsTextFormField(
                label: label,
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  errorText: errorMsg.isEmpty ? null : errorMsg,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                validator: validator,
                autofocus: autofocus,
              ).workaroundFreezeLinuxMint(),
            ),
          ],
        );
      }

      return serverSettingsTextFormField(
        label: label,
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorMsg.isEmpty ? null : errorMsg,
        ),
        validator: validator,
      ).workaroundFreezeLinuxMint();
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(translate(profile == null ? 'Add Server Profile' : 'Edit Server Profile'))),
          ...ServerConfigImportExportWidgets(controllers, errMsgs),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Form(
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildField(translate('Friendly Name'), nameCtrl, ''),
                  SizedBox(height: 8),
                  buildField(translate('ID Server'), idCtrl, idServerMsg.value,
                      autofocus: true),
                  SizedBox(height: 8),
                  if (!isIOS && !isWeb) ...[
                    buildField(translate('Relay Server'), relayCtrl,
                        relayServerMsg.value, maxLines: null),
                    SizedBox(height: 8),
                  ],
                  buildField(
                    translate('API Server'),
                    apiCtrl,
                    apiServerMsg.value,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (!(v.startsWith('http://') ||
                            v.startsWith("https://"))) {
                          return translate("invalid_http");
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  buildField('Key', keyCtrl, ''),
                ],
              )),
        ),
      ),
      actions: [
        dialogButton('Cancel', onPressed: () {
          close();
        }, isOutline: true),
        dialogButton(
          'OK',
          onPressed: () async {
            if (await submit()) {
              close();
              showToast(translate('Successful'));
            } else {
              showToast(translate('Failed'));
            }
          },
        ),
      ],
    );
  });
}

TextFormField serverSettingsTextFormField({
  required String label,
  required TextEditingController controller,
  required String errorMsg,
  String? Function(String?)? validator,
  bool autofocus = false,
  bool showLabelText = true,
  EdgeInsetsGeometry? contentPadding,
}) {
  return TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: showLabelText ? label : null,
      errorText: errorMsg.isEmpty ? null : errorMsg,
      contentPadding: contentPadding,
    ),
    validator: validator,
    autofocus: autofocus,
    keyboardType: TextInputType.visiblePassword,
    textCapitalization: TextCapitalization.none,
    autocorrect: false,
    enableSuggestions: false,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    enableIMEPersonalizedLearning: false,
    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
  );
}

void setPrivacyModeDialog(
  OverlayDialogManager dialogManager,
  List<TToggleMenu> privacyModeList,
  RxString privacyModeState,
) async {
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('Privacy mode')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: privacyModeList
              .map((value) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: value.child,
                    value: value.value,
                    onChanged: value.onChanged,
                  ))
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}
