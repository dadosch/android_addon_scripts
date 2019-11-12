#!/bin/bash

##########################################################################################################
#
##########################################################################################################
#~ <HID-Voice und VoLTE unterschiede Leeco/14/16 nach gohan>
        #~ /media/lta-user/Backup/android/DeviceSpecific/android_device_leeco_s2/overlay/frameworks/base/core/res/res/values/config.xml
	#~ /media/lta-user/Backup/android/DeviceSpecific/android_device_leeco_s2/audio/audio_platform_info.xml
	#~ /media/lta-user/Backup/android/DeviceSpecific/android_device_leeco_s2/audio/mixer_paths_qrd_skun_cajon.xml
	#~ /media/lta-user/Backup/android/DeviceSpecific/android_device_leeco_s2/system.prop
	#~ gohan
	#~ /media/lta-user/Backup/android/DeviceSpecific/android_device_bq_gohan/audio/mixer_paths_qrd_skun.xml
#~ <HID-Voice und VoLTE unterschiede Leeco/14/16 nach gohan>


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic pop


##########################################################################################################
# Definitionen
##########################################################################################################

#d=$(date +%Y-%m-%d-%H-%M)
buildDate=$(date +%Y%m%d)

#RootPfad=/media/lta-user/Backup
RootPfad=~
CertPfad=~
limitCpu=false
clearBuild=false
target=gohan
kernel=msm8976

##########################################################################################################

##########################################################################################################
##########################################################################################################
##########################################################################################################
##########################################################################################################
# Functionen
##########################################################################################################

##########################################################################################################
# FunktionsName getTarget
# details               Auswahl des zu bauenden Bq Targets
##########################################################################################################
function getTarget {
    auswahl=$(dialog --stdout --clear --radiolist "choose target:" 10 40 3 1 "gohan" on 2 "tenshi" off)
    if [ $auswahl -eq "2" ] 
    then
        target=tenshi
        kernel=msm8937
        privApp=false
        paramPatch=false
    fi
}

##########################################################################################################
# FunktionsName limitUsedCpu
# details               weitere Apps
##########################################################################################################
function limitUsedCpu {
    dialog --stdout --clear --yesno "limit cpu number of cores used?" 10 40
    if [ $? = 0 ]
    then
        limitCpu=true
    fi
}

##########################################################################################################
# FunktionsName cleanBuild
# details               weitere Apps
##########################################################################################################
function cleanBuild {
    dialog --stdout --clear --yesno "delete build folder beforehand?" 10 40
    if [ $? = 0 ] 
    then
        clearBuild=true
    fi
}

##########################################################################################################
# FunktionsName showFeature
# details               zeigtdie Zusammenfassung
##########################################################################################################
function showFeature {
    
    msgBuild="nicht geloescht"
    if [ $clearBuild = true ]
    then
        msgBuild="geloescht"
    fi
    
    msgCpu="unbegrenzt"
    if [ $limitCpu = true ]
    then
        msgCpu="begrenzt"
    fi

    #~ xmessage -buttons "Passt":0,"Abbruch":1 -default "Abbruch" -nearmouse "Target: $target$msgPrivApp$msgParamPatch. Prozessorzahl $msgCpu, Buildverzeichnis $msgBuild"
    dialog --stdout --clear --title "Target: $target. Prozessorzahl $msgCpu, Buildverzeichnis $msgBuild" --yesno "Continue?" 10 40
    if [ $? = 1 ] 
    then
        exit
    fi
}

##########################################################################################################
# FunktionsName Exit
# details               Beenden
##########################################################################################################
function quit {
    echo - $1 & "  schlug fehl"
    exit
}

##########################################################################################################
# FunktionsName  securityPatchDate
# details               der PatchStand auf der Platte
##########################################################################################################
function securityPatchDate {
    #grep "PLATFORM_SECURITY_PATCH := " ./build/core/version_defaults.mk 
    LOCAL=$(grep -Eoi "PLATFORM_SECURITY_PATCH := .*" ./build/core/version_defaults.mk | sed  s@'PLATFORM_SECURITY_PATCH := '@''@)
    echo -  Security Patch Level lokal vom  : $LOCAL
    echo
}

##########################################################################################################
# FunktionsName  newPatchesAvailable
# details               gibts einen neueren PatchStand
##########################################################################################################
function newPatchesAvailable {
    LOCAL=$(grep -Eoi "PLATFORM_SECURITY_PATCH := .*" ./build/core/version_defaults.mk | sed  s@'PLATFORM_SECURITY_PATCH := '@''@)
    REMOTE=$(curl -sS https://github.com/LineageOS/android_build/blob/cm-14.1/core/version_defaults.mk | grep -Eoi 'PLATFORM_SECURITY_PATCH</span> := [0-9]{4}-[0-9]{2}-[0-9]{2}' | sed  s@'PLATFORM_SECURITY_PATCH</span> := '@''@)

    dialog --stdout --title "Security Patches" --msgbox "Security Patch Level lokal vom: $LOCAL \
    \n\nSecurity Patch Level remote vom: $REMOTE" 10 40

    
    # wenn laenge = 0 keine verbindung zum server
    if [ ${#REMOTE} = 0 ]
    then
        dialog --stdout --msgbox "Keine Verbindung zum Server" 10 40
        exit
    fi    
    if [ ${#LOCAL} = 0 ] 
    then
        dialog --stdout --msgbox "Kein Repo gefunden, starte sync" 10 40
        return
    fi    

    if [ $LOCAL = $REMOTE ]; then
        dialog --stdout --clear --title  "no new patches available" --yesno "Build anyway?" 10 40
        if [ $? = 1 ] 
        then
            dialog --stdout --msgbox "Beenden" 10 40
            exit
        fi
    else
        dialog --stdout --clear --title "new patches available"  --yesno "Build?"  10 40
        if [ $? = 1 ]
        then
            dialog --stdout --msgbox "Beenden" 10 40
            exit
        fi
    fi
}

##########################################################################################################
# FunktionsName prepCache
# details               Cache loeschen und vorbereiten
##########################################################################################################
function prepCache {
    echo "+++++++++++++++++++++++++++++++++++ Cleanup Cache  ++++++++++++++++++++++++++++++++++++++++++++++"
    echo
    ccache -C 
    
    if [ $clearBuild = true ] && [ -d "$RootPfad/android/lineage14.1/out" ]
    then
        echo - out geloescht
        rm -r $RootPfad/android/lineage14.1/out
    fi
    
    echo
    echo "+++++++++++++++++++++++++++++++++++ Cleanup Cache  beendet ++++++++++++++++++++++++++++++++++++++"
    # Cache Einstellungen
    export USE_CCACHE=1
    #ccache -M 75G
    #export CCACHE_COMPRESS=1
    export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G"
    echo
}

##########################################################################################################
# FunktionsName restorePatches
# details               die geaenderten Scripte wiederherstellen
##########################################################################################################
function restorePatches {
    echo
    
    echo - Anzahl Prozessoren
    # Die Buildumgebung wieder zurueck
    replaceWith="mk_timer schedtool -B -n 10 -e ionice -n 7 make -C \$T -j\$(grep \"\^processor\" /proc/cpuinfo | wc -l) \"\$@\""
    searchString="mk_timer schedtool -B -n 10 -e ionice -n 7 make -C \$T -j4 \"\$@\""
    sed -i -e "s:${searchString}:${replaceWith}:g" $RootPfad/android/lineage14.1/vendor/cm/build/envsetup.sh
    #auslesen
    #grep -Eoi "mk_timer schedtool -B -n 10 -e ionice .*" $RootPfad/android/lineage14.1/vendor/cm/build/envsetup.sh 
}

##########################################################################################################
# Functionen
##########################################################################################################
##########################################################################################################
##########################################################################################################
##########################################################################################################

##########################################################################################################
# Wechsel ins Buildverzeichnis
##########################################################################################################
echo "+++++++++++++++++++++++++++++++++++ In das Buildverzeichnis +++++++++++++++++++++++++++++++++++++++++"
echo
cd $RootPfad/android/lineage14.1
pwd
echo
# gibts neue security patches
newPatchesAvailable
# fuer welches Target bauen wir
getTarget
# Prozessoren begrenzen
limitUsedCpu
# BuildOrdner loeschen
cleanBuild
#Zusammenfassung
showFeature

##########################################################################################################
# Repo init und sync
##########################################################################################################
echo "+++++++++++++++++++++++++++++++++++ Init Repo  ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
repo init -u https://github.com/LineageOS/android.git -b cm-14.1
echo
if [ $? -ne 0 ] 
then
    quit "repo Init"
fi

echo "+++++++++++++++++++++++++++++++++++ Sync Repo  ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo
echo  - sync
repo sync
if [ $? -ne 0 ] 
then
    quit "repo sync"
fi
echo

##########################################################################################################
# Android Security Patch Level auslesen
##########################################################################################################
securityPatchDate

##########################################################################################################
# Target bauen
##########################################################################################################
while : ; do

    echo "+++++++++++++++++++++++++++++++++++ Den Code fuer $target   +++++++++++++++++++++++++++++++++++++++++"
    echo
    source build/envsetup.sh
    #syncht den Code fuer gohan oder tenshi
    breakfast $target
    echo
    if [ $? -ne 0 ] 
    then
        quit "breakfast $target"
    fi

    ##########################################################################################################
    # Cache
    ##########################################################################################################
    prepCache

    ##########################################################################################################
    # Build auf x Cpu Cores begrenzen
    ########################################################################################################## 
    if [ $limitCpu = true ]
    then
        searchString="mk_timer schedtool -B -n 10 -e ionice -n 7 make -C \$T -j\$(grep \"\^processor\" /proc/cpuinfo | wc -l) \"\$@\""
        replaceWith="mk_timer schedtool -B -n 10 -e ionice -n 7 make -C \$T -j4 \"\$@\""
        #replaceWith="mk_timer schedtool -B -n 10 -e ionice -n 7 make -C \$T -j1 \"\$@\""
        sed -i -e "s:${searchString}:${replaceWith}:g" $RootPfad/android/lineage14.1/vendor/cm/build/envsetup.sh
    fi

    ##########################################################################################################
    # meine git Repos synchen    
    ##########################################################################################################
    #~ echo - device/bq/$target synchen
    #~ rm -rf device/bq/gohan
    #~ git clone https://github.com/moosburger/android_device_bq_$target.git device/bq/$target
    #~ git config --get remote.origin.url

    #~ echo - external/ant-wireless synchen
    #~ rm -rf external/ant-wireless
    #~ git clone https://github.com/moosburger/android_external_ant-wireless.git external/ant-wireless
    #~ git config --get remote.origin.url

    #Backup aktuellen Pfad
    lstPath=$PWD   
    
    if [ $target = gohan  ]
    then
        echo - device/bq/$target synchen
        cd $RootPfad/android/packages/android_device_bq_$target
        git config --get remote.origin.url
        git branch | grep \* | cut -d ' ' -f2
        git pull    
        
        echo - kernel/bq/msm8976 synchen
        cd $RootPfad/android/packages/android_kernel_bq_msm8976
        git config --get remote.origin.url
        git branch | grep \* | cut -d ' ' -f2
        git pull    
    fi

    echo - external/ant-wireless synchen
    cd $RootPfad/android/packages/android_external_ant-wireless
    git config --get remote.origin.url
    git branch | grep \* | cut -d ' ' -f2
    git pull    

    echo - vendor/bq/$target synchen
    cd $RootPfad/android/lineage14.1/vendor/bq/$target        
    git config --get remote.origin.url
    git branch | grep \* | cut -d ' ' -f2
    git pull 
    
    echo - die modifizierten Dateien, die in das LOS kopiert werden
    cd $RootPfad/android/packages/modifizierte
    git config --get remote.origin.url
    git branch | grep \* | cut -d ' ' -f2
    git pull
    
    #zurueck in den Pfad
    cd $lstPath       

    ##########################################################################################################
    # Files austauschen, patchen, hinzufuegen
    ##########################################################################################################
    echo "+++++++++++++++++++++++++++++++++++ Dateien austauschen, patchen, hinzufuegen   +++++++++++++++++++++++++++++++"
    echo
    
    if [ $target = gohan  ]
    then
        echo - Ant+   
        cp $RootPfad/android/packages/modifizierte/airplane_defaults.xml ./frameworks/base/packages/SettingsProvider/res/values/defaults.xml       
        
        echo - device/bq/$target kopieren
        rm -rf device/bq/gohan
        cp -r $RootPfad/android/packages/android_device_bq_gohan/ ./device/bq/gohan/
        rm -rf device/bq/gohan/.git      
        
        echo - kernel/bq/msm8976 kopieren
        rm -rf kernel/bq/msm8976
        cp -r $RootPfad/android/packages/android_kernel_bq_msm8976/ ./kernel/bq/msm8976/
        rm -rf kernel/bq/msm8976/.git     
    fi    
    
    if [ $target = tenshi  ]
    then  
        echo  - gps.conf im Ordner austauschen
        cp $RootPfad/android/packages/modifizierte/gps.conf ./device/bq/msm8937-common/gps/etc/gps.conf
        cp $RootPfad/android/packages/modifizierte/msm8937.dtsi ./device/bq/msm8937-common/msm8937.dtsi    
    fi
       
#    echo - BqKamera Hack
#    rm -rf frameworks/base/core/java/android/hardware/camera2/impl/CameraMetadataNative.java
#    cp $RootPfad/android/packages/modifizierte/CameraMetadataNative.java ./frameworks/base/core/java/android/hardware/camera2/impl/CameraMetadataNative.java
        
    echo - external/ant-wireless kopieren
    rm -rf external/ant-wireless
    cp -r $RootPfad/android/packages/android_external_ant-wireless/ ./external/ant-wireless/
    rm -rf external/ant-wireless/.git

    echo - die Lautstaerke Aenderungen und die VPN Uebersetzungen
    cp $RootPfad/android/packages/modifizierte/cm_strings.xml ./packages/apps/Settings/res/values-de/cm_strings.xml    
    cp $RootPfad/android/packages/modifizierte/default_volume_tables.xml ./frameworks/av/services/audiopolicy/config/default_volume_tables.xml
    
    echo "+++++++++++++++++++++++++++++++++++ Dateien austauschen, patchen, hinzufuegen  beendet ++++++++++++++++++++++++"
    echo
#exit    
    ##########################################################################################################
    # Build
    ##########################################################################################################
    echo "+++++++++++++++++++++++++++++++++++ Starte unsignierten Build  fuer $target ++++++++++++++++++++++++++++++++++++++"
    echo
    croot
    brunch $target
    if [ $? -ne 0 ] 
    then
        echo - brunch $target schlug fehl
        break
    fi
    echo "+++++++++++++++++++++++++++++++++++ Ende unsignierter Build  ++++++++++++++++++++++++++++++++++++++++"
    echo
    echo "+++++++++++++++++++++++++++++++++++ Starte signierten Build  fuer $target ++++++++++++++++++++++++++++"
    echo
    mka target-files-package otatools
    if [ $? -ne 0 ] 
    then
        echo - otatools $target schlug fehl
        break
    fi
    echo
    echo "+++++++++++++++++++++++++++++++++++ APK +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo
    croot
    ./build/tools/releasetools/sign_target_files_apks -o -d $CertPfad/.android-certs $OUT/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip $RootPfad/signed-target_files.zip 
    if [ $? -ne 0 ]
    then
        echo - $target APK signieren schlug fehl
        break
    fi
    echo
    echo "+++++++++++++++++++++++++++++++++++ OTA +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo
    ./build/tools/releasetools/ota_from_target_files -k $CertPfad/.android-certs/releasekey --block --backup=true $RootPfad/$target-files-signed.zip $RootPfad/$target-ota-update.zip
    if [ $? -ne 0 ]
    then
        echo - $target OTA signieren schlug fehl
        break
    fi
    echo
    echo "+++++++++++++++++++++++++++++++++++ Ende signierter Build  ++++++++++++++++++++++++++++++++++++++++++"
    echo
    
break
done

##########################################################################################################
# Android Security Patch Level auslesen
##########################################################################################################
securityPatchDate

if [ -f $RootPfad/$target-files-signed.zip ]
then
    rm $RootPfad/$target-files-signed.zip
fi

# Kopieren und umbenennen
if [ -f $RootPfad/$target-ota-update.zip ]
then
    echo "verschiebe $RootPfad/$target-ota-update.zip ==> $RootPfad/lineage-14.1-$buildDate-UNOFFICIAL-$target-signed.zip"
    mv $RootPfad/$target-ota-update.zip $RootPfad/lineage-14.1-$buildDate-UNOFFICIAL-$target-signed.zip
fi

if [ -f $OUT/lineage-14.1-*-UNOFFICIAL-$target.zip ]
then
    echo "verschiebe $OUT/lineage-14.1-*-UNOFFICIAL-$target.zip ==> $RootPfad/lineage-14.1-*-UNOFFICIAL-$target.zip"
    mv $OUT/lineage-14.1-*-UNOFFICIAL-$target.zip $RootPfad
    echo "verschiebe $OUT/lineage-14.1-*-UNOFFICIAL-$target.zip.md5sum ==> $RootPfad/lineage-14.1-*-UNOFFICIAL-$target.zip.md5sum"
    mv $OUT/lineage-14.1-*-UNOFFICIAL-$target.zip.md5sum $RootPfad
fi

restorePatches
    
##########################################################################################################

