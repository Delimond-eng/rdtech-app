import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:checkpoint_app/constants/styles.dart';
import 'package:checkpoint_app/global/controllers.dart';
import 'package:checkpoint_app/global/store.dart';
import 'package:checkpoint_app/kernel/services/http_manager.dart';
import 'package:checkpoint_app/modals/recognition_face_modal.dart';
import 'package:checkpoint_app/pages/mobile_qr_scanner_011.dart';
import 'package:checkpoint_app/themes/app_theme.dart';
import 'package:checkpoint_app/widgets/svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../kernel/models/user.dart';
import '../modals/supervisor_form_modal.dart';
import '../widgets/submit_button.dart' show SubmitButton;
import '../widgets/user_status.dart';

class SupervisorAgent extends StatefulWidget {
  const SupervisorAgent({super.key});

  @override
  State<SupervisorAgent> createState() => _SupervisorAgentState();
}

class _SupervisorAgentState extends State<SupervisorAgent> {
  final TextEditingController commentController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkColor,
        title: const Text(
          "SUPERVISION AGENTS",
          style: TextStyle(
            fontSize: 30.0,
            fontWeight: FontWeight.w900,
            color: whiteColor,
            fontFamily: 'Staatliches',
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          const UserStatus(name: "Gaston delimond").marginAll(8.0),
        ],
      ),
      floatingActionButton: Obx(
        () => authController.pendingSupervision.value != null
            ? FloatingActionButton(
                backgroundColor: darkGreyColor,
                child: const Svg(
                  path: "qrcode.svg",
                  color: primaryColor,
                ),
                onPressed: () {},
              )
            : const SizedBox.shrink(),
      ),
      body: Obx(
        () => authController.stationAgents.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Aucun agent disponible, veuillez scanner à nouveau le QR code du site !",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.0,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Container(
                      height: 60.0,
                      width: 60.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60.0),
                        gradient: LinearGradient(
                          colors: [
                            primaryMaterialColor.shade700,
                            primaryMaterialColor.shade300,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(60.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(60.0),
                          onTap: () {
                            Get.back();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MobileQrScannerPage011(),
                              ),
                            );
                          },
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.chevron_down,
                              color: Colors.white,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          const Text(
                            "Vous devez sélectionner un agent à superviser !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: darkGreyColor,
                            ),
                          ).paddingBottom(15.0),
                          ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              var data = authController.stationAgents[index];
                              return SupervisorAgentCard(
                                data: data,
                                isActive:
                                    authController.pendingSupervision.value !=
                                        null,
                              );
                            },
                            separatorBuilder: (__, _) =>
                                const SizedBox(height: 8),
                            itemCount: authController.stationAgents.length,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: commentController,
                            decoration: const InputDecoration(
                              hintText: "Commentaire général...(facultatif)",
                              hintStyle: TextStyle(fontSize: 12.0),
                              labelStyle: TextStyle(fontSize: 12.0),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (authController.pendingSupervision.value !=
                              null) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: 55.0,
                                child: SubmitButton(
                                  label: "Clôturer la ronde",
                                  color: Colors.green,
                                  loading: tagsController.isLoading.value,
                                  onPressed: () async {
                                    showRecognitionModal(context,
                                        key: "supervize-out", onValidate: () {
                                      closeSupervision();
                                    });
                                  },
                                ),
                              ),
                            )
                          ] else ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: 55.0,
                                child: SubmitButton(
                                  label: "Commencer une ronde",
                                  color: primaryMaterialColor,
                                  loading: tagsController.isLoading.value,
                                  onPressed: () async {
                                    showRecognitionModal(
                                      context,
                                      key: "supervize-in",
                                      onValidate: supervizeStart,
                                    );
                                  },
                                ),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> supervizeStart() async {
    var manager = HttpManager();
    tagsController.isLoading.value = true;
    manager.startSupervison().then((value) async {
      tagsController.isLoading.value = false;
      if (value is String) {
        EasyLoading.showError(value);
      } else {
        authController.refreshSupervision();
        EasyLoading.showSuccess(
          "Bienvenue, vous avez commencer une nouvelle ronde de supervision !",
        );
      }
    });
  }

  Future<void> closeSupervision() async {
    int supervisionId = authController.pendingSupervision.value!.id!;
    File? photoFin = File(tagsController.face.value!.path);

    //final url = Uri.parse('http://192.168.200.9:8000/api/supervision.close');
    final url = Uri.parse('https://mamba.salama-drc.com/api/supervision.close');
    const apiKey = "16jA/0l6TBmFoPk64MnrmLzVp2MRL2Do0yD5N6K4e54=";

    var agents = authController.supervisedDatas;

    tagsController.isLoading.value = true;

    var request = http.MultipartRequest('POST', url)
      ..headers.addAll({
        'Accept': 'application/json',
        'X-API-KEY': apiKey,
      })
      ..fields['comment'] = commentController.text
      ..fields['supervision_id'] = supervisionId.toString();

    // --- Photo de clôture principale
    if (photoFin.existsSync()) {
      request.files
          .add(await http.MultipartFile.fromPath('photo', photoFin.path));
    }

    // --- Données agents
    for (int i = 0; i < agents.length; i++) {
      final agent = agents[i];

      if (agent['photo'] == null) {
        EasyLoading.showInfo(
            "Impossible de clôturer : chaque agent supervisé doit avoir une photo. !");
        tagsController.isLoading.value = false;
        return;
      }
      request.fields['agents[$i][agent_id]'] = agent['agent_id'].toString();

      // Commentaire
      if (agent['comment'] != null) {
        request.fields['agents[$i][comment]'] = agent['comment'].toString();
      }

      // Photo agent
      if (agent['photo'] != null && agent['photo'] is File) {
        final file = agent['photo'] as File;
        if (file.existsSync()) {
          request.files.add(await http.MultipartFile.fromPath(
              'agents[$i][photo]', file.path));
        }
      }

      // Notes de l’agent
      final notes = (agent['notes'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      for (int j = 0; j < notes.length; j++) {
        final note = notes[j];
        request.fields['agents[$i][notes][$j][control_element_id]'] =
            note['control_element_id'].toString();
        request.fields['agents[$i][notes][$j][note]'] = note['note'].toString();

        if (note['comment'] != null) {
          request.fields['agents[$i][notes][$j][comment]'] =
              note['comment'].toString();
        }
      }
    }

    try {
      var response = await request.send();
      final res = await http.Response.fromStream(response);
      tagsController.isLoading.value = false;

      print(res.body);

      if (res.statusCode == 200) {
        var result = jsonDecode(res.body);

        if (result.containsKey("errors")) {
          EasyLoading.showInfo(result["errors"]);
          return;
        } else {
          EasyLoading.showSuccess(result["message"]);
          localStorage.remove("supervision");
          authController.refreshSupervision();
          return;
        }
      } else {
        EasyLoading.showInfo("Échec de traitement de la requête !");
      }
    } catch (e) {
      tagsController.isLoading.value = false;
      if (kDebugMode) print("Erreur lors de la clôture de supervision: $e");
      EasyLoading.showError("Erreur lors de la clôture de supervision $e");
    }
  }
}

class SupervisorAgentCard extends StatelessWidget {
  final User data;
  final bool isActive;
  const SupervisorAgentCard({
    super.key,
    required this.data,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: isActive ? Colors.white : Colors.grey.shade300,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: isActive
              ? () async {
                  authController.selectedAgentId.value = data.id!;
                  /* var elements = await HttpManager().getSupervisionElements();
                  authController.supervisorElements.value = elements; */
                  startSupervisionForAgent(data.id!);
                  showSupervisorFormModal(context);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(40.0),
                        child: data.photo != null
                            ? CachedNetworkImage(
                                height: 40.0,
                                width: 40.0,
                                fit: BoxFit.cover,
                                imageUrl: data.photo!
                                    .replaceAll("127.0.0.1", "192.168.64.247"),
                                placeholder: (context, url) => Image.asset(
                                  "assets/images/profil-2.png",
                                  height: 40.0,
                                  width: 40.0,
                                ),
                                errorWidget: (context, url, error) =>
                                    Image.asset(
                                  "assets/images/profil-2.png",
                                  height: 40.0,
                                  width: 40.0,
                                ),
                              )
                            : Image.asset(
                                "assets/images/profil-2.png",
                                height: 40.0,
                                width: 40.0,
                              ),
                      ).paddingRight(8.0),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.fullname!.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: "Staatliches",
                                fontSize: 18.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              data.matricule!,
                            ),
                          ],
                        ),
                      ),
                      Obx(
                        () => Container(
                          height: 30.0,
                          width: 30.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                          child: authController.supervisedAgent
                                  .contains(data.id)
                              ? Container(
                                  margin: const EdgeInsets.all(2.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30.0),
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryMaterialColor,
                                        primaryMaterialColor.shade200,
                                      ],
                                    ),
                                  ),
                                  child: const Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        size: 14.0,
                                        color: whiteColor,
                                      )
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void startSupervisionForAgent(int agentId) {
    var exists = authController.supervisedDatas
        .any((item) => item['agent_id'] == agentId);
    if (!exists) {
      authController.supervisedDatas.add(
        {
          'agent_id': agentId,
          'comment': '',
          'photo': null,
          'notes': [],
        },
      );
    }
  }
}
