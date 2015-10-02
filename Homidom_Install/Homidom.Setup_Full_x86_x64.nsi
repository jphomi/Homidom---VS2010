; **********************************************************************
; Homidom Install & Update script
; **********************************************************************

; --- d�finition des constantes de base
!define PRODUCT_NAME "HoMIDoM"
!define PRODUCT_VERSION "#PRODUCT_VERSION#"
!define PRODUCT_BUILD "#PRODUCT_BUILD#"
!define PRODUCT_REVISION "#PRODUCT_REVISION#"
!define PRODUCT_RELEASE "RELEASE"
!define PRODUCT_PUBLISHER "HoMIDoM"
!define PRODUCT_WEB_SITE "http://www.homidom.com"
!define PRODUCT_DIR_REGKEY "Software\${PRODUCT_NAME}"
!define PRODUCT_UNINSTALL_REGKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

!define DEFAULT_CFG_IPSOAP "localhost"
!define DEFAULT_CFG_PORTSOAP "7999"
!define DEFAULT_CFG_IDSRV "123456789"

; --- Version du Framework .NET requis et URL de t�l�chargement
!define DOT_MAJOR "4"
!define DOT_MINOR "0"
!define URL_DOTNET "http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe"

; --- Dossier racine contenant les sources (relatif � l'emplacement du script NSIS)
!define ROOT_DIR ".."
; --- Dossier de publication => dossier contenant les binaires
!define PUBLISH_DIR "${ROOT_DIR}\${PRODUCT_RELEASE}"
; --- Dossier de destination du package g�n�r� (relatif � l'emplacement du script NSIS)
!define PACKAGES_DIR "Packages"

; --- D�finition des constantes permettant de mettre � jour les informations de version (VI) de l'executable g�n�r�.
VIProductVersion "${PRODUCT_VERSION}.${PRODUCT_BUILD}.${PRODUCT_REVISION}"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "Comments" "${PRODUCT_WEB_SITE}"
VIAddVersionKey "CompanyName" "${PRODUCT_NAME}"
VIAddVersionKey "LegalCopyright" "Copyright ${PRODUCT_NAME}"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME}"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}.${PRODUCT_BUILD}.${PRODUCT_REVISION}"

; MUI 1.67 compatible ------
!include "MUI2.nsh"
!include "Sections.nsh"
!include "TextFunc.nsh"
!include "LogicLib.nsh"
!include "includes\x64.nsh"
!include "nsDialogs.nsh"
!include "includes\CustomLog.nsh"

; --- inclusion du code de d�tection et de t�l�chargement du Framework .NET
!include "includes\CheckDotNetInstalled.nsh"
!include "includes\Redist.VC2010.nsh"
!include "includes\Redist.VC11.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_NODESC
!define MUI_ICON "${ROOT_DIR}\Images\Logo\icone.ico"
!define MUI_UNICON "${ROOT_DIR}\Images\Logo\icone.ico"

!define TEMP1 $R0 ;Temp variable

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; License page
!define MUI_LICENSEPAGE_CHECKBOX
!insertmacro MUI_PAGE_LICENSE "includes\gpl-3.0.txt"
; Components page
!insertmacro MUI_PAGE_COMPONENTS
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Custom option page
Page custom nsDialogsPage nsDialogsPageLeave
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
;!insertmacro MUI_PAGE_FINISH


;!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!include "includes\localization.fr.nsh"
;!include "includes\localization.en.nsh"

; MUI end ------

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}.${PRODUCT_BUILD} (${PRODUCT_REVISION})"
OutFile "${PACKAGES_DIR}\${PRODUCT_NAME}.Setup.${PRODUCT_VERSION}.${PRODUCT_BUILD}.${PRODUCT_REVISION}_Full_x86_x64.exe"
InstallDir $PROGRAMFILES\HoMIDoM
BrandingText "HoMIDoM Installer v1.2"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir"
ShowInstDetails show
ShowUnInstDetails show

; --- d�finition des variables de la boite de dialogue personalis� 
Var Dialog
var chkInstallAsService_Handle
Var optInstallAsService
var chkStartService_Handle
Var optStartService
var chkStartServiceGUI_Handle
Var optStartServiceGUI
Var chkCreateStartMenuShortcuts_Handle
Var optCreateStartMenuShortcuts
Var txtCfgIpSoap_Handle
Var txtCfgPortSoap_Handle
Var txtCfgIdSrv_Handle

; Request application privileges for Windows Vista
RequestExecutionLevel admin

Var platform

; --- d�finition des variables personalis�es
Var IsHomidomInstalled ;indique si HoMIDom est d�ja install�
Var IsHomidomInstalledAsService ;indique si HoMIServicE est install� en tant que service windows
Var IsHomidomInstalledAsServiceNSSM
;Var IsHomidomServiceRunning ;indique si le service HoMIServicE est d�marr�
;Var IsHomidomAppRunning ;indique si une app Homidom est en cours d'execution (Admin,WPF, )
Var HomidomInstalledVersion ;Num�ro de version Homidom.dll
Var IsPreviousInstallIsDeprecated ;Indique si la pr�cedente installation a �t� faite avec l'ancien installeur (msi)
;Var HomidomServiceVersion ;Indique le type de service install� : 1=> HomidomSvc via NSSM, 2=> HomiService
Var HomiServiceName

Var IsWindowsFirewallEnabled

Var cfg_ipsoap
Var cfg_portsoap
Var cfg_idsrv

!define Unicode2Ansi "!insertmacro Unicode2Ansi"
!macro Unicode2Ansi String outVar
  System::Call 'kernel32::WideCharToMultiByte(i 0, i 0, w "${String}", i -1, t .s, i ${NSIS_MAX_STRLEN}, i 0, i 0) i'
  Pop "${outVar}"
!macroend

; **********************************************************************
; Initialisation - code ex�cut� avant l'affichage de la 1iere fen�tre
; **********************************************************************
Function .onInit

  !insertmacro Log_Init "$EXEDIR\$EXEFILE.log"
  !insertmacro Log_String "================================================================================"
  !insertmacro Log_String " ${PRODUCT_NAME} v${PRODUCT_VERSION}.${PRODUCT_BUILD}.${PRODUCT_REVISION}"
  !insertmacro Log_String "================================================================================"
  
  ; -- Cr�ation du dossier temporaires n�cessaires � l'installeur (%TEMP%\ns*****)
  InitPluginsDir

  ; --- d�ploiement des fichiers n�cessaires � l'installation
  File /oname=$PLUGINSDIR\nssm.exe "tools\nssm-2.16\win32\nssm.exe"
  File /oname=$PLUGINSDIR\hitb.exe "tools\hitb-1.0\win32\hitb.exe"
    
  # --- affichage du Logo "splah"
  File /oname=$PLUGINSDIR\splash.bmp "..\Images\logo\logo.bmp"  
  advsplash::show 2000 600 400 -1 $PLUGINSDIR\splash
  Pop $0

  ; --- s�lection de la langue
  !insertmacro MUI_LANGDLL_DISPLAY

  ; --- V�rification de la version du Framework .NET
  Call CheckDotNetInstalled

  ; --- d�tection de l'OS (32bits/64bits) & pr�-configuration du dossier de destination
  StrCpy $INSTDIR "$programfiles32\${PRODUCT_NAME}"
  
  ${If} ${RunningX64}
    !insertmacro Log_String "Architecture 64-bit detect�e."
    StrCpy $INSTDIR "$programfiles64\${PRODUCT_NAME}"
    SetRegView 64
    StrCpy $platform "x64"
  ${Else}
    !insertmacro Log_String "Architecture 32-bit detect�e."
    SetRegView 32
    StrCpy $platform "x86"
  ${EndIf}

  ; -- V�rification de la pr�sence des runtimes VC++ 2010 (10.0)
  Call CheckVC10Redist
  
  ; -- V�rification de la pr�sence des runtimes VC++ 2012 (11.0)
  Call CheckVC11Redist

  !insertmacro Log_String "Les dossier d'installation par d�faut est '$INSTDIR'."
  
  ; --- Initialisation des variables
  StrCpy $IsHomidomInstalled "0"
  StrCpy $IsPreviousInstallIsDeprecated "0"
  StrCpy $HomiServiceName "HoMIServicE"
  StrCpy $IsWindowsFirewallEnabled "0"

  ; --- Recherche d'une installation faite avec l'ancien installeur
  ;!insertmacro Log_String "Recherche des installation existante en base de registre."
  StrCpy $0 0
  ${Do}
    ; parcours de chaque entr�e 'Uninstall" du registre
    EnumRegKey $1 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" $0
    ${If} $1 != ""
      IntOp $0 $0 + 1
      ; Lecture du "nom du produit"
      ReadRegStr $2 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$1" "DisplayName"
      ${If} $2 == "HoMIDoM"
        ; entr�e trouv�e
        ReadRegDword $3 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$1" "WindowsInstaller"
        !insertmacro Log_String "Une installation existante a �t� trouv�e dans la cl� de registre 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$1'"
        ${If} $3 == 1
          MessageBox MB_ICONEXCLAMATION|MB_OK "Une ancienne installation a �t� d�tect�e. Veuillez effectuer une sauvegarde de vos donn�es, d�sinstaller manuellement l'ancienne version et relancer une nouvelle installation."
          Abort
        ${EndIf}
      ${EndIf}
    ${EndIf}
  ${LoopUntil} $1 == ""

  ; --- D�tection bas�e sur la pr�sence de la DLL principale dans le dossier d'install par d�faut -ou- sp�cifi� en BdR si d�ja install�
  ;!insertmacro Log_String "Recherche d'une installation exitante dans le dossier '$INSTDIR'."
  ${If} ${FileExists} "$INSTDIR\HoMIDom.dll"
    ; --- Installation existante d�tect�e !
    StrCpy $IsHomidomInstalled "1"
    ; --- r�cup�ration de la version install�e => $HomidomInstalledVersion
    ${GetFileVersion} "$INSTDIR\HoMIDom.dll" $HomidomInstalledVersion
    !insertmacro Log_String "Une installation existante a �t� trouv� dans le dossier '$INSTDIR'. Le num�ro de version est '$HomidomInstalledVersion'"
  ${EndIf}

  ;!insertmacro Log_String "Recherche des services HoMIDoM..."
  ; V�rification de l'existance du service V1
  SimpleSC::ExistsService "HoMIDoM"
  Pop $0
  ${If} $0 == "0"
    StrCpy $IsHomidomInstalledAsServiceNSSM "1"
    StrCpy $optInstallAsService "1"
    !insertmacro Log_String "Une version du service HoMIDoM install�e avec NSSM a �t� trouv�e."
  ${EndIf}
  
  ; V�rification de l'existance du service V2
  SimpleSC::ExistsService "$HomiServiceName"
  Pop $0 ; returns an errorcode if the service doesn�t exists (<>0)/service exists (0)
  ${If} $0 == 0
    StrCpy $IsHomidomInstalledAsService "1"
    StrCpy $optInstallAsService "1"
    StrCpy $optStartService "1"
    StrCpy $optStartServiceGUI "1"
    !insertmacro Log_String "Une version du service HoMIDoM install�e avec InstallUtil a �t� trouv�e."
  ${EndIf}


  ; Check if the firewall is enabled
  SimpleFC::IsFirewallEnabled
  Pop $0 ; return error(1)/success(0)
  Pop $1 ; return 1=Enabled/0=Disabled
  ${If} $0 == 0
    StrCpy $IsWindowsFirewallEnabled "$1"
    ${If} $IsWindowsFirewallEnabled == 1
      !insertmacro Log_String "Le pare-feux Windows est activ�."
    ${Else}
      !insertmacro Log_String "Le pare-feux Windows n'est pas activ�."
    ${EndIf}
  ${EndIf}

  Call LoadConfig

  !insertmacro Log_String "IsHomidomInstalled: $IsHomidomInstalled"
  !insertmacro Log_String "HomidomInstalledVersion: $HomidomInstalledVersion"
  !insertmacro Log_String "IsHomidomInstalledAsServiceNSSM: $IsHomidomInstalledAsServiceNSSM"
  !insertmacro Log_String "IsHomidomInstalledAsService: $IsHomidomInstalledAsService"
    
  !insertmacro Log_String "================================================================================"
  !insertmacro Log_String "D�but de l'installation."
    
FunctionEnd

Function LoadConfig

  StrCpy $cfg_ipsoap ${DEFAULT_CFG_IPSOAP}
  StrCpy $cfg_portsoap ${DEFAULT_CFG_PORTSOAP}
  StrCpy $cfg_idsrv ${DEFAULT_CFG_IDSRV}

  ; V�rification de la pr�sence du fichier de configuration
  !insertmacro Log_String "Recherche du fichier de configuration."
  ${If} ${FileExists} "$INSTDIR\Config\HoMIDom.xml"
    nsisXML::create
    nsisXML::load "$INSTDIR\Config\HoMIDom.xml"
    ; r�cup�ration du noeud /homidom/server
    nsisXML::select '/homidom/server'
    ${If} $2 != 0
      nsisXML::getAttribute "ipsoap"
      ${If} $3 != ""
        StrCpy $cfg_ipsoap $3
      ${EndIf}
      nsisXML::getAttribute "portsoap"
      ${If} $3 != ""
        StrCpy $cfg_portsoap $3
      ${EndIf}
      nsisXML::getAttribute "idsrv"
      ${If} $3 != ""
        StrCpy $cfg_idsrv $3
      ${EndIf}
    ${EndIf}
  ${EndIf}

FunctionEnd

Function SaveConfig

  !insertmacro Log_String "Sauvegarde de la configuration."

  nsisXML::create
  nsisXML::load "$INSTDIR\Config\HoMIDom.xml"
  nsisXML::select '/homidom/server'
  ${If} $2 != 0
    nsisXML::setAttribute "ipsoap" $cfg_ipsoap
    nsisXML::setAttribute "portsoap" $cfg_portsoap
    nsisXML::setAttribute "idsrv" $cfg_idsrv
  ${EndIf}
  nsisXML::save "$INSTDIR\Config\HoMIDom.xml"
  
  nsisXML::create
  nsisXML::load "$INSTDIR\Config\HoMIAdmiN.xml"
  nsisXML::select '/ArrayOfClServer/ClServer/Adresse'
  ${If} $2 != 0
    nsisXML::setText "$cfg_ipsoap"
  ${EndIf}
  nsisXML::select '/ArrayOfClServer/ClServer/Port'
  ${If} $2 != 0
    nsisXML::setText "$cfg_portsoap"
  ${EndIf}
  nsisXML::select '/ArrayOfClServer/ClServer/Id'
  ${If} $2 != 0
    nsisXML::setText "$cfg_idsrv"
  ${EndIf}
  nsisXML::save "$INSTDIR\Config\HoMIAdmiN.xml"
  
  
  
FunctionEnd

; **********************************************************************
; Success - code ex�cut� � la fin de l'installation (en cas de success)
; **********************************************************************
Function .onInstSuccess

  !insertmacro Log_String "Installation termin�e avec succ�s."


FunctionEnd

Function un.onInit

  ; -- Cr�ation du dossier temporaires n�cessaires � l'installeur (%TEMP%\ns*****)
  InitPluginsDir

  ; --- d�ploiement des fichiers n�cessaires � l'installation
  File /oname=$PLUGINSDIR\nssm.exe "tools\nssm-2.16\win32\nssm.exe"
  File /oname=$PLUGINSDIR\hitb.exe "tools\hitb-1.0\win32\hitb.exe"

  ${If} ${RunningX64}
    !insertmacro Log_String "Architecture 64-bit detect�e."
    StrCpy $INSTDIR "$programfiles64\${PRODUCT_NAME}"
    SetRegView 64
  ${Else}
    !insertmacro Log_String "Architecture 32-bit detect�e."
    SetRegView 32
  ${EndIf}

  StrCpy $HomiServiceName "HoMIServicE"

FunctionEnd

; --- D�finition des profils (types) d'installation
InstType "Complete"
InstType "Service uniquement"
InstType "Admin uniquement"

Section "" HoMIDoM_STOPSVC
  !insertmacro Log_String "[HoMIDoM_STOPSVC]"
  SectionIn 1 2
  ; --- D�sintallation du service V1 dans tous les cas.
  Call UnInstallHomidomServiceNSSM
  Call KillAllHomidomServices
SectionEnd

Section "" HoMIDoM_FRAMEWORK

  !insertmacro Log_String "[HoMIDoM_FRAMEWORK]"

  ; Fichiers de base : requis par l'ensemble des applications de la solution
  ; Section obligatoire.
  SectionIn RO

  CreateDirectory "$INSTDIR"
  CreateDirectory "$INSTDIR\Bdd"
  CreateDirectory "$INSTDIR\Config"
  CreateDirectory "$INSTDIR\Drivers"
  CreateDirectory "$INSTDIR\Fichiers"
  CreateDirectory "$INSTDIR\Logs"
  CreateDirectory "$INSTDIR\Templates"
  
  SetOutPath "$INSTDIR"
  File "tools\hitb-1.0\win32\hitb.exe"
  File "..\RELEASE\HoMIDom.DLL"
  File "..\RELEASE\NCrontab.dll"
    
  ${If} ${RunningX64}
    File  /x "*.xml" /x "*.pdb" /x "MjpegProcessor.*" "..\Dll_externes\Homidom-64bits\*"
  ${Else}
    File  /x "*.xml" /x "*.pdb" /x "MjpegProcessor.*" "..\Dll_externes\Homidom-32bits\*"
  ${EndIf}

  SetOutPath "$INSTDIR\Templates"
  File /r "..\RELEASE\Templates\*"

SectionEnd

SectionGroup "HoMIDoM Service" HoMIDoM_SERVICE_GRP

   Section "Service" HoMIDoM_SERVICE

    !insertmacro Log_String "[HoMIDoM_SERVICE]"

    SectionIn 1 2

    SetOverwrite on
    SetOutPath "$INSTDIR"
    ;File "..\RELEASE\HoMIDomService.exe"
    File "..\RELEASE\HoMIService.exe"
    File "..\RELEASE\HoMIDomWebAPI.dll"
    
    SetOverwrite off
    ;File "..\RELEASE\HoMIDomService.exe.config"
    File "..\RELEASE\HoMIService.exe.config"

    SetOverwrite off
    SetOutPath "$INSTDIR\Bdd"
    File "..\RELEASE\Bdd\homidom.db"
    File "..\RELEASE\Bdd\medias.db"

    SetOverwrite off
    SetOutPath "$INSTDIR\Config"
    File "..\RELEASE\Config\homidom.xml"

    SetOutPath "$INSTDIR\Drivers"
    File "..\RELEASE\Drivers\Driver_System.dll"
    File "..\RELEASE\Drivers\Driver_Virtuel.dll"
    File "..\RELEASE\Drivers\Driver_Weather.dll"
    ${If} ${RunningX64}
      File  "..\Dll_externes\Homidom-64bits\Drivers\Interop.WUApiLib.dll"
    ${Else}
      File  "..\Dll_externes\Homidom-32bits\Drivers\Interop.WUApiLib.dll"
    ${EndIf}

  SectionEnd
  
   Section "GUI" HoMIDoM_SVCGUI

    !insertmacro Log_String "[HoMIDoM_SVCGUI]"

    SectionIn 1 2

    SetOverwrite on
    SetOutPath "$INSTDIR"
    File "..\RELEASE\HoMIGuI.exe"
    File "..\RELEASE\HoMIGuI.exe.config"

    WriteRegStr HKLM "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\layers" "$INSTDIR\HoMIGuI.exe" "RUNASADMIN"

  SectionEnd
  
  SectionGroup "Drivers" DRIVERS_GRP
    !include "includes\Driver_*.nsh"
  SectionGroupEnd
  
SectionGroupEnd


Section "HoMIDoM Admin" HoMIDoM_ADMIN
  
  !insertmacro Log_String "[HoMIDoM_ADMIN]"
  
  SectionIn 1 3

  SetOverwrite on
  SetOutPath "$INSTDIR"
  File "..\RELEASE\HoMIAdmiN.exe"
  
  SetOverwrite off
  File "..\RELEASE\HoMIAdmiN.exe.Config"
  
  CreateDirectory "$INSTDIR\Images"
  SetOutPath "$INSTDIR\Images"
  File /r "..\RELEASE\Images\*"
  
  SetOverwrite off
  SetOutPath "$INSTDIR\Config"
  File "..\RELEASE\Config\HoMIAdmiN.xml"
  
SectionEnd


Section "" HoMIDoM_SHORTCUTS

  SetOutPath "$INSTDIR"
  CreateDirectory $SMPROGRAMS\${PRODUCT_NAME}
  ; suppression de tous les raccourcis existant
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\*.*"
  
  ; Cr�ation du raccour�i pour HomiAdmin
  ${If} ${SectionIsSelected} ${HoMIDoM_ADMIN}
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\HoMIDoM Administration.lnk" "$INSTDIR\HoMIAdmin.exe"
  ${EndIf}
  
  ; Cr�ation du raccourci vers HomiService mode console
  ${If} ${SectionIsSelected} ${HoMIDoM_SERVICE}
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\HoMIDoM Service (Mode Console).lnk" "$INSTDIR\HoMIService.exe"
  ${EndIf}
  
  ${If} ${SectionIsSelected} ${HoMIDoM_SVCGUI}
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\HoMIDoM Service Agent (GUI).lnk" "$INSTDIR\HoMIGuI.exe"
  ${EndIf}
  
  ${If} $optStartServiceGUI == "1"
    SetOutPath "$INSTDIR"
    ;CreateShortCut "$SMSTARTUP\HoMIDoM Service GUI.lnk" "$INSTDIR\HoMIGuI.exe"
    ${If} ${RunningX64}
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "HoMIGuI" "$INSTDIR\HoMIGuI.exe"
    ${Else}
      ;WriteRegStr HKLM "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run" "HoMIGuI" "$INSTDIR\HoMIGuI.exe"
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "HoMIGuI" "$INSTDIR\HoMIGuI.exe"
    ${EndIf}
  ${EndIf}
  
  WriteINIStr "$SMPROGRAMS\${PRODUCT_NAME}\Visitez le site Web HoMIDoM.URL" "InternetShortcut" "URL" "http://www.homidom.com"
  
SectionEnd

Section "" HoMIDoM_POST

  Call WriteUnInstaller
  Call AddFirewallRules
  Call SaveConfig
  Call InstallHomidomService
  Call StartHomidomService

SectionEnd


; **********************************************************************
; Uninstall Section
; **********************************************************************
Section "Uninstall"

  SetOutPath "$INSTDIR"

  Banner::show /NOUNLOAD "D�sinstallation..."

  ExecCmd::exec /TIMEOUT=5000 '"$PLUGINSDIR\hitb.exe -sps"' "" ; stop-service
  Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
  !insertmacro Log_String "Arret du serveur (hitb -sps) : $0"

  ExecCmd::exec /TIMEOUT=5000 '"$PLUGINSDIR\hitb.exe -ka"' ""  ; kill-all
  Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
  !insertmacro Log_String "Arret du serveur (hitb -ka) : $0"

  ReadRegStr $3 HKLM "${PRODUCT_UNINSTALL_REGKEY}" "ServiceName"

  ; Arret du Service V2
  SimpleSC::ExistsService "$HomiServiceName"
  Pop $0 ; returns an errorcode if the service doesn�t exists (<>0)/service exists (0)
  !insertmacro Log_String "V�rification de l'existance du Service '$HomiServiceName': $3"
  ${If} $0 == 0
    SimpleSC::GetServiceStatus "$HomiServiceName"
    Pop $0 ; returns an errorcode (!=0) otherwise success (0)
    Pop $1 ; return the status of the service (see below)
    !insertmacro Log_String "GetServiceStatus: $0,$1"
    ${If} $1 != 1
      !insertmacro Log_String "Arr�t du Service '$HomiServiceName'"
      ; Stop a service and waits for file release. Be sure to pass the service name, not the display name.
      SimpleSC::StopService "$HomiServiceName" 0 30
      SimpleSC::StopService "$HomiServiceName" 1 30
      Pop $0 ; returns an errorcode (<>0) otherwise success (0)
      !insertmacro Log_String "StopService=$0"
      SimpleSC::GetServiceStatus "$HomiServiceName"
      Pop $0 ; returns an errorcode (!=0) otherwise success (0)
      Pop $1 ; return the status of the service (see below)
      !insertmacro Log_String "GetServiceStatus=$0,$1"
    ${EndIf}
  ${EndIf}

  Banner::destroy
  
  Banner::show /NOUNLOAD "Desinstallation en cours..."
  
    ; desinstallation du service existant V1
    ExecCmd::exec /TIMEOUT=5000 '$PLUGINSDIR\nssm.exe remove HoMIDoM confirm'
    Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
    !insertmacro Log_String "Desintallation du service V1: $0"

    Call un.UnInstallHomidomService
    
  Banner::destroy

  ; Remove registry keys
  DeleteRegKey HKLM "${PRODUCT_UNINSTALL_REGKEY}"

  Delete $INSTDIR\*
  
  ;Delete $INSTDIR\Bdd\*
  ;RMDir "$INSTDIR\Bdd"
  
  ;Delete $INSTDIR\Config\*
  ;RMDir "$INSTDIR\Config"

  ;Delete $INSTDIR\Fichiers\*
  ;RMDir "$INSTDIR\Fichiers"

  Delete $INSTDIR\Images\*
  RMDir "$INSTDIR\Images"
  
  ;Delete $INSTDIR\Logs\*
  ;RMDir "$INSTDIR\Logs"

  ;Delete $INSTDIR\Templates\*
  ;RMDir "$INSTDIR\Templates"

  Delete "$INSTDIR\Drivers\*"
  ;Delete "$INSTDIR\Drivers\ZWave\*"
  ;Delete "$INSTDIR\Drivers\KNX\*"
  RMDir "$INSTDIR\Drivers\ZWave"
  RMDir "$INSTDIR\Drivers\KNX"
  RMDir "$INSTDIR\Drivers"

  Delete "$SMPROGRAMS\${PRODUCT_NAME}\HoMIDoM Administration.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\HoMIDoM Service GUI.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}"
  
  ; Remove files and uninstaller
  Delete $INSTDIR\uninstall.exe

  ; Remove directories used
  RMDir "$INSTDIR"

SectionEnd

; **********************************************************************
; d�-installation du service windows via NSSM
; **********************************************************************
Function UnInstallHomidomServiceNSSM
  ${If} $IsHomidomInstalledAsServiceNSSM == "1"
    Banner::show /NOUNLOAD ""
    ; desinstallation du service existant V1
    ExecCmd::exec /TIMEOUT=5000 '$PLUGINSDIR\nssm.exe remove HoMIDoM confirm'
    Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
    !insertmacro Log_String "Desintallation du service V1: $0"
    Banner::destroy
  ${EndIf}
FunctionEnd

; **********************************************************************
; d�-installation du service windows via InstallUtil
; **********************************************************************
Function un.UnInstallHomidomService
  ${If} $IsHomidomInstalledAsService == "1"
    Banner::show /NOUNLOAD ""
    ; desinstallation du service existant V2
    ExecCmd::exec /TIMEOUT=5000 '"$WINDIR\Microsoft.NET\Framework\v4.0.30319\installUtil.Exe" /u "$INSTDIR\HoMIService.exe"'
    Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
    !insertmacro Log_String "Desintallation du service V2: $0"
    Banner::destroy
  ${EndIf}
FunctionEnd

; **********************************************************************
; installation du service windows via InstallUtil
; **********************************************************************
Function InstallHomidomService

${If} $optInstallAsService == "1"

  Banner::show /NOUNLOAD "Installation du Service"
  !insertmacro Log_String "Installation du service via InstallUtil"

  SetOutpath "$INSTDIR"
  ;File "tools\InstallUtil.exe"
  ; installation du service
  ExecWait '"$WINDIR\Microsoft.NET\Framework\v4.0.30319\installUtil.Exe" "$INSTDIR\HoMIService.exe"'

  ; Arret du Service V2
  SimpleSC::ExistsService "$HomiServiceName"
  Pop $0 ; returns an errorcode if the service doesn�t exists (<>0)/service exists (0)
  
  ${If} $0 == "0"
    !insertmacro Log_String "Installation du Service r�usise."
  ${Else}
    !insertmacro Log_String "Une erreur est survenue durant l'installation du Service: $0"
  ${EndIf}

  Banner::destroy

${EndIf}

FunctionEnd

; **********************************************************************
; installation & d�marrage du service windows
; **********************************************************************
Function StartHomidomService

  Banner::show /NOUNLOAD "D�marrage du service..."
  !insertmacro Log_String "D�marrage du service : $HomiServiceName"

  ; --- D�marrage du serveur (si n�cessaire)
  ${If} $optStartService == "1"
    ${If} $optInstallAsService == "1"
      SimpleSC::SetServiceStartType "$HomiServiceName" "2"
      Pop $0 ; returns an errorcode (<>0) otherwise success (0)
      ; Start a service. Be sure to pass the service name, not the display name.
      SimpleSC::StartService "$HomiServiceName" "" 30
      Pop $0 ; returns an errorcode (<>0) otherwise success (0)

    ${Else}
      SetOutPath "$INSTDIR"
      Exec '"$INSTDIR\HoMIServicE.exe"'
    ${EndIf}
  ${EndIf}

  ${If} $optStartServiceGUI == "1"
      SetOutPath "$INSTDIR"
      Exec '"$INSTDIR\HomiGUI.exe"'

  ${EndIf}

  Banner::destroy

FunctionEnd

Function AddFirewallRules

  ${If} $optInstallAsService == "1"
  

  
  
    ; Check if the port 7999/TCP is enabled/disabled
    ;SimpleFC::IsPortEnabled $cfg_portsoap 6
    
    SimpleFC::IsApplicationAdded "$INSTDIR\HoMIServicE.exe"
    Pop $0 ; return error(1)/success(0)
    Pop $1 ; return 1=Enabled/0=Not enabled
    ${If} $0 == 0
      ${If} $1 == 0
        Banner::show /NOUNLOAD "Configuration du pare-feu..."
        
        ; Add the port xxxxx/TCP to the firewall exception list - All Networks - All IP Version - Enabled
        SimpleFC::AddPort $cfg_portsoap "HoMIDoM Service" 6 0 2 "" 1
        ; Add an application to the firewall exception list - All Networks - All IP Version - Enabled
        SimpleFC::AddApplication "HoMIDoM Service" "$INSTDIR\HoMIServicE.exe" 0 2 "" 1
        Pop $0 ; return error(1)/success(0)
        
        !insertmacro Log_String "Configuration du pare-feu. Ouverture du Port TCP $cfg_portsoap : $0"
        !insertmacro Log_String "Configuration du pare-feu. Ajout de l'application $INSTDIR\HoMIServicE.exe : $0"
        Banner::destroy
        
      ${Else}
        !insertmacro Log_String "Le pare-feu est d�ja configur� correctement."
      ${EndIf}


    ${EndIf}
  ${EndIf}

FunctionEnd

; **********************************************************************
; Arr�t de toutes les application & services HoMIDom
; **********************************************************************
Function KillAllHomidomServices

  !insertmacro Log_String "[KillAllHomidomServices]"

  Banner::show /NOUNLOAD "Arr�t d'HoMIDoM..."
  
  ExecCmd::exec /TIMEOUT=5000 '"$PLUGINSDIR\hitb.exe -sps"' "" ; stop-service
  Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
  !insertmacro Log_String "Arret du serveur (hitb -sps) : $0"
  
  ExecCmd::exec /TIMEOUT=5000 '"$PLUGINSDIR\hitb.exe -ka"' ""  ; kill-all
  Pop $0 ; return value - process exit code or error or STILL_ACTIVE (0x103).
  !insertmacro Log_String "Arret du serveur (hitb -ka) : $0"

  ; Arret du Service V2
  SimpleSC::ExistsService "$HomiServiceName"
  Pop $0 ; returns an errorcode if the service doesn�t exists (<>0)/service exists (0)
  !insertmacro Log_String "V�rification de l'existance du Service: $0"
  ${If} $0 == 0
    SimpleSC::GetServiceStatus "$HomiServiceName"
    Pop $0 ; returns an errorcode (!=0) otherwise success (0)
    Pop $1 ; return the status of the service (see below)
    !insertmacro Log_String "GetServiceStatus: $0,$1"
    ${If} $1 != 1
      !insertmacro Log_String "Arr�t du Service '$HomiServiceName'"
      ; Stop a service and waits for file release. Be sure to pass the service name, not the display name.
      SimpleSC::StopService "$HomiServiceName" 0 30
      SimpleSC::StopService "$HomiServiceName" 1 30
      Pop $0 ; returns an errorcode (<>0) otherwise success (0)
      !insertmacro Log_String "StopService=$0"
      SimpleSC::GetServiceStatus "$R0"
      Pop $0 ; returns an errorcode (!=0) otherwise success (0)
      Pop $1 ; return the status of the service (see below)
      !insertmacro Log_String "GetServiceStatus=$0,$1"
    ${EndIf}
  ${EndIf}
  
  Banner::destroy
  
FunctionEnd

Function nsDialogsPage

!insertmacro MUI_HEADER_TEXT "Options d'installation" "Configurer les options"

  nsDialogs::Create 1018
  Pop $Dialog

  ${If} $Dialog == error
    Abort
  ${EndIf}

  StrCpy $optInstallAsService "1"
  StrCpy $optCreateStartMenuShortcuts "1"
  StrCpy $optStartService "1"
  StrCpy $optStartServiceGUI "1"

  ; CreateStartMenuShortcuts
  ${NSD_CreateCheckbox} 0 0u 100% 10u "Cr�er les raccour�is dans le menu D�marrer"
  Pop $chkCreateStartMenuShortcuts_Handle
  ${If} $optCreateStartMenuShortcuts == ${BST_CHECKED}
    ${NSD_Check} $chkCreateStartMenuShortcuts_Handle
  ${EndIf}

  ${If} ${SectionIsSelected} ${HoMIDoM_SERVICE}

    ${NSD_CreateHLine} 0 15u 100% 0u ""
    ; ---------------------------------------------------------------
    ${NSD_CreateCheckbox} 0 20u 100% 10u "Installer HoMIDoM Service en tant que Service Windows"
    Pop $chkInstallAsService_Handle
    ${If} $optInstallAsService == ${BST_CHECKED}
      ${NSD_Check} $chkInstallAsService_Handle
    ${EndIf}

    ${NSD_CreateCheckbox} 0 35u 100% 10u "Demarrer le Service HoMIDoM � la fin de l'installation"
    Pop $chkStartService_Handle
    ${If} $optStartService == ${BST_CHECKED}
      ${NSD_Check} $chkStartService_Handle
    ${EndIf}
    ; ---------------------------------------------------------------
    ${NSD_CreateHLine} 0 50u 100% 0u ""

    ${NSD_CreateLabel} 10u 55u 50u 10u "IP/Nom d'h�te : "
    ${NSD_CreateText} 75u 55u 30% 10u $cfg_ipsoap
    Pop $txtCfgIpSoap_Handle
    
    ${NSD_CreateLabel} 10u 70u 50u 10u "Port : "
    ${NSD_CreateText} 75u 70u 30% 10u $cfg_portsoap
    Pop $txtCfgPortSoap_Handle
    
    ${NSD_CreateLabel} 10u 85u 50u 10u "ID serveur : "
    ${NSD_CreateText} 75u 85u 30% 10u $cfg_idsrv
    Pop $txtCfgIdSrv_Handle

    ${NSD_CreateCheckbox} 0 110u 100% 10u "Demarrer automatiquement HoMIDoM GUI au d�marrage du PC"
    Pop $chkStartServiceGUI_Handle
    ${If} $optStartServiceGUI == ${BST_CHECKED}
      ${NSD_Check} $chkStartServiceGUI_Handle
    ${EndIf}

  ${EndIf}
  nsDialogs::Show
  
FunctionEnd

Function nsDialogsPageLeave
         ${NSD_GetState} $chkInstallAsService_Handle $optInstallAsService
         ${NSD_GetState} $chkStartService_Handle $optStartService
         ${NSD_GetState} $chkCreateStartMenuShortcuts_Handle $optCreateStartMenuShortcuts
         ${NSD_GetState} $chkStartServiceGUI_Handle $optStartServiceGUI
         
         ${NSD_GetText} $txtCfgIpSoap_Handle $cfg_ipsoap
         !insertmacro Log_String "IPSOAP=$cfg_ipsoap"
         ${NSD_GetText} $txtCfgPortSoap_Handle $cfg_portsoap
         !insertmacro Log_String "PORTSOAP=$cfg_portsoap"
         ${NSD_GetText} $txtCfgIdSrv_Handle $cfg_idsrv
         !insertmacro Log_String "IDSRV=$cfg_idsrv"
         
FunctionEnd

Function WriteUnInstaller

  Banner::show /NOUNLOAD ""

  ; Write the installation path into the registry
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir" "$INSTDIR"

  ; Recuperation de la taille de l'installation
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0

  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "Publisher" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "DisplayIcon" "$INSTDIR\Images\icone.ico"
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "Comments" "HoMIDoM, la solution gratuite et multi-technologie de domotique"
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "DisplayVersion" "${PRODUCT_VERSION}.${PRODUCT_BUILD}.${PRODUCT_REVISION}"
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "${PRODUCT_UNINSTALL_REGKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${PRODUCT_UNINSTALL_REGKEY}" "NoRepair" 1
  WriteRegExpandStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "HelpLink" "http://www.homidom.com"
  WriteRegDWORD HKLM "${PRODUCT_UNINSTALL_REGKEY}" "EstimatedSize" "$0"
  WriteRegStr HKLM "${PRODUCT_UNINSTALL_REGKEY}" "ServiceName" "$HomiServiceName"
  WriteUninstaller "uninstall.exe"
  
  Banner::destroy
  
FunctionEnd
