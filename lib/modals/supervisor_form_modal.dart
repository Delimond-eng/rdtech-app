import 'dart:io';

import 'package:checkpoint_app/constants/styles.dart';
import 'package:checkpoint_app/global/controllers.dart';
import 'package:checkpoint_app/kernel/models/supervision_element.dart';
import 'package:checkpoint_app/modals/photo_capture_modal.dart';
import 'package:checkpoint_app/themes/app_theme.dart';
import 'package:checkpoint_app/widgets/svg.dart';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../widgets/submit_button.dart';
import 'utils.dart';

Future<void> showSupervisorFormModal(context) async {
  File? photo;
  int agentId = authController.selectedAgentId.value;
  var existingData = authController.supervisedDatas
      .firstWhereOrNull((item) => item['agent_id'] == agentId);

  // Si l'agent existe déjà, on récupère ses données
  if (existingData != null) {
    photo = existingData['photo'];
  }

  showCustomModal(
    context,
    onClosed: () {
      var index = authController.supervisedDatas
          .indexWhere((e) => e['agent_id'] == agentId);
      var notes = authController.supervisedDatas[index]['notes'] as List;
      bool allChecked = authController.supervisorElements
          .every((e) => notes.any((n) => n['control_element_id'] == e.id));
      if (allChecked && !authController.supervisedAgent.contains(agentId)) {
        authController.supervisedAgent.add(agentId);
      }
    },
    title: "Elémenent à superviser",
    child: Padding(
      padding: const EdgeInsets.all(10.0),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StatefulBuilder(
              builder: (context, setter) => Container(
                height: 150.0,
                width: 150.0,
                decoration: BoxDecoration(
                  image: photo != null
                      ? DecorationImage(
                          image: FileImage(photo!),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(150.0),
                  color: darkGreyColor,
                  border: Border.all(
                    color: primaryMaterialColor,
                    width: 0.5,
                  ),
                ),
                child: Material(
                  borderRadius: BorderRadius.circular(150.0),
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(150.0),
                    onTap: () {
                      showPhotoCaptureModal(context, onValidate: (file) {
                        setter(() => photo = file);
                        authController.updateAgentPhoto(agentId, file);
                      });
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Svg(
                          path: "photo-edit.svg",
                          color: primaryMaterialColor,
                          size: 30.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Text(
              "Veuillez completer les éléments de la supervision !",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w500,
              ),
            ).paddingTop(5.0),
            const SizedBox(
              height: 10.0,
            ),
            // === LISTE DES ÉLÉMENTS ===
            ...authController.supervisorElements.map((e) {
              // Récupérer la note existante pour cet élément si elle existe
              var existingNote = existingData?['notes']?.firstWhere(
                (n) => n['control_element_id'] == e.id,
                orElse: () => null,
              );

              return ElementCard(
                data: e,
                initialNote: existingNote?['note'],
                onNoteSelected: (noteLabel) {
                  // Supprime l'ancienne note pour cet élément
                  existingData?['notes']
                      ?.removeWhere((n) => n['control_element_id'] == e.id);
                  // Ajoute la nouvelle note
                  existingData?['notes']?.add({
                    'control_element_id': e.id,
                    'note': noteLabel,
                    'comment': '',
                  });
                },
              ).paddingBottom(4);
            }).toList(),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                hintText: "Commentaire...(facultatif)",
                border: OutlineInputBorder(),
                hintStyle: TextStyle(fontSize: 12.0),
                labelStyle: TextStyle(fontSize: 12.0),
                isDense: true,
              ),
              onChanged: (val) {
                var index = authController.supervisedDatas
                    .indexWhere((e) => e['agent_id'] == agentId);
                if (index != -1) {
                  authController.supervisedDatas[index]['comment'] = val;
                  authController.supervisedDatas.refresh();
                }
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 55.0,
              child: SubmitButton(
                label: "Valider",
                color: Colors.indigo,
                loading: false,
                onPressed: () async {
                  var index = authController.supervisedDatas
                      .indexWhere((e) => e['agent_id'] == agentId);
                  var notes =
                      authController.supervisedDatas[index]['notes'] as List;
                  bool allChecked = authController.supervisorElements.every(
                      (e) => notes.any((n) => n['control_element_id'] == e.id));
                  if (allChecked &&
                      !authController.supervisedAgent.contains(agentId)) {
                    authController.supervisedAgent.add(agentId);
                    EasyLoading.showSuccess("Supervision effectuée !");
                  }
                  Get.back();
                },
              ),
            )
          ],
        ),
      ),
    ),
  );
}

class ElementCard extends StatefulWidget {
  final SupElement data;
  final String? initialNote;
  final Function(String) onNoteSelected;

  const ElementCard({
    super.key,
    required this.data,
    this.initialNote,
    required this.onNoteSelected,
  });

  @override
  State<ElementCard> createState() => _ElementCardState();
}

class _ElementCardState extends State<ElementCard> {
  late List<Map<String, dynamic>> notes;

  @override
  void initState() {
    super.initState();
    notes = [
      {"label": "B", "isActive": widget.initialNote == "B"},
      {"label": "P", "isActive": widget.initialNote == "P"},
      {"label": "M", "isActive": widget.initialNote == "M"},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: scaffoldColor,
        border: Border.all(
          color: const Color.fromARGB(255, 216, 224, 246),
          width: 2.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.data.libelle,
                    style: const TextStyle(
                      color: darkGreyColor,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ).paddingBottom(4.0),
                  Text(
                    widget.data.description,
                    style:
                        TextStyle(color: Colors.grey.shade800, fontSize: 8.0),
                  ),
                ],
              ),
            ),
            Row(
              children: notes.map((task) {
                return Row(
                  children: [
                    TaskCheck(
                      label: task["label"],
                      isActive: task["isActive"],
                      onActived: () {
                        setState(() {
                          for (var n in notes) {
                            n["isActive"] = false;
                          }
                          task["isActive"] = true;
                        });
                        widget.onNoteSelected(task["label"]);
                      },
                    ),
                    const SizedBox(width: 5.0),
                  ],
                );
              }).toList(),
            ).paddingLeft(5.0),
          ],
        ),
      ),
    );
  }
}

class TaskCheck extends StatelessWidget {
  final String? label;
  final bool isActive;
  final VoidCallback onActived;
  const TaskCheck({
    super.key,
    this.label,
    this.isActive = false,
    required this.onActived,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Material(
        borderRadius: BorderRadius.circular(5.0),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5.0),
          onTap: onActived,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label!,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  fontSize: 10.0,
                ),
              ).paddingBottom(3.0),
              if (isActive) ...[
                AnimatedContainer(
                  height: 30.0,
                  width: 30.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    gradient: LinearGradient(
                      colors: [color, color.shade400],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  duration: const Duration(milliseconds: 100),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 10.0,
                        color: whiteColor,
                      )
                    ],
                  ),
                ),
              ] else ...[
                AnimatedContainer(
                  height: 30.0,
                  width: 30.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    border: Border.all(
                      color: color,
                    ),
                  ),
                  duration: const Duration(milliseconds: 100),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  MaterialColor get color {
    if (label == "B") {
      return Colors.green;
    } else if (label == "P") {
      return Colors.amber;
    } else {
      return Colors.deepOrange;
    }
  }
}
