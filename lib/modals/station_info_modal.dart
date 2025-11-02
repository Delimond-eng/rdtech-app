import 'package:checkpoint_app/constants/styles.dart';
import 'package:checkpoint_app/global/controllers.dart';
import 'package:checkpoint_app/themes/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../kernel/services/http_manager.dart';
import 'utils.dart';

Future<void> showStationInfoModal(context, {VoidCallback? onFinished}) async {
  showCustomModal(
    context,
    onClosed: () {
      //tagsController.isScanningModalOpen.value = false;
    },
    title: "STATION IDENTIFICATION",
    child: Padding(
      padding: const EdgeInsets.all(10.0),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/tango.png").paddingBottom(10.0),
            Text(
              tagsController.scannedSite.value.name!.toUpperCase(),
              style: TextStyle(
                fontFamily: "Staatliches",
                fontSize: 22.0,
                color: primaryMaterialColor.shade900,
                fontWeight: FontWeight.w900,
              ),
            ).paddingBottom(5.0),
            Text(
              tagsController.scannedSite.value.code!.toUpperCase(),
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ).paddingBottom(10.0),
            Container(
              height: 60.0,
              width: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60.0),
                gradient: LinearGradient(
                  colors: [
                    primaryMaterialColor.shade700,
                    primaryMaterialColor.shade300,
                  ], // orange dégradé
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
                    var site = tagsController.scannedSite.value;
                    tagsController.isLoading.value = true;
                    HttpManager().getStationAgents(site.id).then((agents) {
                      tagsController.isLoading.value = false;
                      authController.stationAgents.value = agents;
                      Get.back();
                      onFinished!.call();
                    });
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tagsController.isLoading.value) ...[
                        const SizedBox(
                          height: 30.0,
                          width: 30.0,
                          child: CircularProgressIndicator(
                              color: whiteColor, strokeWidth: 2.0),
                        )
                      ] else ...[
                        const Icon(
                          CupertinoIcons.arrow_right,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
