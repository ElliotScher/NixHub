{ appimageTools, fetchurl, lib }:

# Open CASCADE CAD Assistant - freeware STEP/IGES/glTF/STL/OBJ viewer.
# Not in nixpkgs; upstream only ships a Linux AppImage, and 1.6.0 (2021) is
# still the latest release, so this wraps it with appimageTools.
let
  pname = "cad-assistant";
  version = "1.6.0";

  src = fetchurl {
    url = "https://www.opencascade.com/sites/default/files/private/occt/applications/cad_assistant_${version}_2021-10-05_lin64.appimage";
    hash = "sha256-Bt2NgQ1dWtcxLxUtLcr/jZMReW7dM6pkMUy+x06AzlQ=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Upstream's .desktop calls `CADAssistant`; point it at the wrapper instead.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/cad_assistant.desktop $out/share/applications/cad-assistant.desktop
    substituteInPlace $out/share/applications/cad-assistant.desktop \
      --replace-fail 'Exec=CADAssistant' 'Exec=${pname}'
    install -Dm444 ${appimageContents}/cadassistant.png $out/share/pixmaps/cadassistant.png
  '';

  meta = {
    description = "Open CASCADE viewer and converter for 3D CAD models";
    homepage = "https://www.opencascade.com/products/cad-assistant/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
