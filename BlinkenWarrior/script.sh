#! /bin/sh

# ------------------------------------------------------------
# cvsstat: /Users/ilja/source/IOWarrior/BlinkenWarrior
# ------------------------------------------------------------

cd /Users/ilja/source/IOWarrior/BlinkenWarrior

# ------------------------------------------------------------
# 6 dir(s) unknown to cvs
# ------------------------------------------------------------

( cd English.lproj && \
  cvs add \
      \
      MainMenu.nib \
      MyDocument.nib \
)

( cd . && \
  cvs add \
      \
      BlinkenLights Movies \
      BlinkenWarrior.pbproj \
      English.lproj \
      Pictures \
)
# ------------------------------------------------------------
# 39 file(s) unknown to cvs
# ------------------------------------------------------------

( cd . && \
  cvs add \
      \
      AppIcon.icns \
      BlinkenWarrior.m \
      BlinkenWarriorAppDelegate.h \
      BlinkenWarriorAppDelegate.m \
      InfoPlist.plc \
      MyDocument.h \
      MyDocument.m \
      Util.c \
      Util.h \
      main.m \
      script.sh \
)

( cd English.lproj && \
  cvs add \
      \
      Credits.rtf \
      InfoPlist.strings \
      locversion.plist \
)

( cd BlinkenLights Movies && \
  cvs add \
      \
      3D_cube.blm \
      Scrolltext.blm \
      klo.blm \
      kriechi_die_schlange.blm \
      life.blm \
      rakete.blm \
      wasserhahn.blm \
)

( cd English.lproj/MyDocument.nib && \
  cvs add \
      \
      classes.nib \
      info.nib \
      objects.nib \
)

( cd English.lproj/MainMenu.nib && \
  cvs add \
      \
      classes.nib \
      info.nib \
      objects.nib \
)

( cd BlinkenWarrior.pbproj && \
  cvs add \
      \
      project.pbxproj \
)

( cd Pictures && \
  cvs add \
      \
      NewBitMask32.tiff \
      NewBitMask48.tiff \
      NewBitmap16.tiff \
      NewIcon \
      NewIcon16.tiff \
      NewIcon32.tiff \
      NewIcon48.tiff \
      NewIconAlpha.tiff \
)

cvs commit -m "modifications automated by cvsstat" \
    \
    BlinkenLights Movies/3D_cube.blm \
    BlinkenLights Movies/Scrolltext.blm \
    BlinkenLights Movies/klo.blm \
    BlinkenLights Movies/kriechi_die_schlange.blm \
    BlinkenLights Movies/life.blm \
    BlinkenLights Movies/rakete.blm \
    BlinkenLights Movies/wasserhahn.blm \
    BlinkenWarrior.pbproj/ilja.pbxuser \
    BlinkenWarrior.pbproj/project.pbxproj \
    BlinkenWarrior.pbproj/ralfmenssen.pbxuser \
    English.lproj/.DS_Store \
    English.lproj/Credits.rtf \
    English.lproj/InfoPlist.strings \
    English.lproj/locversion.plist \
    English.lproj/MainMenu.nib/classes.nib \
    English.lproj/MainMenu.nib/info.nib \
    English.lproj/MainMenu.nib/objects.nib \
    English.lproj/MyDocument.nib/classes.nib \
    English.lproj/MyDocument.nib/info.nib \
    English.lproj/MyDocument.nib/objects.nib \
    Pictures/NewBitMask32.tiff \
    Pictures/NewBitMask48.tiff \
    Pictures/NewBitmap16.tiff \
    Pictures/NewIcon \
    Pictures/NewIcon16.tiff \
    Pictures/NewIcon32.tiff \
    Pictures/NewIcon48.tiff \
    Pictures/NewIconAlpha.tiff \
    AppIcon.icns \
    BlinkenWarrior.m \
    BlinkenWarriorAppDelegate.h \
    BlinkenWarriorAppDelegate.m \
    InfoPlist.plc \
    MyDocument.h \
    MyDocument.m \
    Util.c \
    Util.h \
    main.m \
    script.sh


