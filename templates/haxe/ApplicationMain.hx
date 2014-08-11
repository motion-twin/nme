// Might have waxe without NME
#if nme
import nme.Assets;
#elseif waxe
import wx.Assets;
#end

#if cpp
::foreach ndlls::::importStatic::::end::
#end



#if iosview
@:buildXml("
<files id='__lib__'>
  <file name='FrameworkInterface.mm'>
  </file>
</files>
")
#end

class ApplicationMain
{

   #if waxe
   static public var frame : wx.Frame;
   static public var autoShowFrame : Bool = true;
   #if nme
   static public var nmeStage : wx.NMEStage;
   #end
   #end
   
   public static function main()
   {
      #if cpp
      ::if MEGATRACE::
      untyped __global__.__hxcpp_execution_trace(2);
      ::end::
      #end

      #if flash

      nme.AssetData.create();

      #elseif nme
      nme.Lib.setPackage("::APP_COMPANY::", "::APP_FILE::", "::APP_PACKAGE::", "::APP_VERSION::");

      nme.AssetData.create();

      ::if (sslCaCert != "")::
      nme.net.URLLoader.initialize(nme.installer.Assets.getResourceName("::sslCaCert::"));
      ::end::

      ::if (WIN_ORIENTATION == "portrait")::
      nme.display.Stage.setFixedOrientation( nme.display.Stage.OrientationPortraitAny );
      ::elseif (WIN_ORIENTATION == "landscape")::
      nme.display.Stage.setFixedOrientation( nme.display.Stage.OrientationLandscapeAny );
      ::else::
      nme.display.Stage.setFixedOrientation( nme.display.Stage.OrientationAny );
      ::end::
      
      #end
   

   
      #if flash
      flash.Lib.current.stage.align = flash.display.StageAlign.TOP_LEFT;
      flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;

      var load = function() ApplicationBoot.createInstance();

      ::if (PRELOADER_NAME!=null)::
         new ::PRELOADER_NAME::(::WIN_WIDTH::, ::WIN_HEIGHT::, ::WIN_BACKGROUND::, load);
      ::else::
         load();
      ::end::


      #elseif waxe

      #if nme
      nme.display.ManagedStage.initSdlAudio();
      #end

      if (ApplicationBoot.canCallMain())
         ApplicationBoot.createInstance();
      else
      {
         wx.App.boot(function()
         {
            var size = { width: ::WIN_WIDTH::, height: ::WIN_HEIGHT:: };
            ::if (APP_FRAME != null)::
               frame = wx.::APP_FRAME::.create(null, null, "::APP_TITLE::", null, size);
            ::else::
               frame = wx.Frame.create(null, null, "::APP_TITLE::", null, size);
            ::end::


            #if nme
            wx.NMEStage.create(frame, null, null, { width: ::WIN_WIDTH::, height: ::WIN_HEIGHT:: });
            #end

            ApplicationBoot.createInstance();

            if (autoShowFrame)
            {
               wx.App.setTopWindow(frame);
               frame.shown = true;
            }
         });
      }
      #else
      nme.Lib.create(function() { 
            nme.Lib.current.stage.align = nme.display.StageAlign.TOP_LEFT;
            nme.Lib.current.stage.scaleMode = nme.display.StageScaleMode.NO_SCALE;
            nme.Lib.current.loaderInfo = nme.display.LoaderInfo.create (null);
            ApplicationBoot.createInstance();
         },
         ::WIN_WIDTH::, ::WIN_HEIGHT::, 
         ::WIN_FPS::, 
         ::WIN_BACKGROUND::,
         (::WIN_HARDWARE:: ? nme.Lib.HARDWARE : 0) |
         nme.Lib.ALLOW_SHADERS | nme.Lib.REQUIRE_SHADERS |
         (::WIN_DEPTH_BUFFER:: ? nme.Lib.DEPTH_BUFFER : 0) |
         (::WIN_STENCIL_BUFFER:: ? nme.Lib.STENCIL_BUFFER : 0) |
         (::WIN_RESIZABLE:: ? nme.Lib.RESIZABLE : 0) |
         (::WIN_BORDERLESS:: ? nme.Lib.BORDERLESS : 0) |
         (::WIN_VSYNC:: ? nme.Lib.VSYNC : 0) |
         (::WIN_FULLSCREEN:: ? nme.Lib.FULLSCREEN : 0) |
         (::WIN_ANTIALIASING:: == 4 ? nme.Lib.HW_AA_HIRES : 0) |
         (::WIN_ANTIALIASING:: == 2 ? nme.Lib.HW_AA : 0),
         "::APP_TITLE::"
         ::if (WIN_ICON!=null)::
         , getAsset("::WIN_ICON::")
         ::end::
      );
      #end
      
   }

   @:keep function keepMe() { Reflect.callMethod(null,null,null); }

   public static function setAndroidViewHaxeObject(inObj:Dynamic)
   {
      #if androidview
      try
      {
         var setHaxeObject = nme.JNI.createStaticMethod("::CLASS_PACKAGE::.::CLASS_NAME::Base",
              "setHaxeCallbackObject", "(Lorg/haxe/nme/HaxeObject;)V", true, true );
         if (setHaxeObject!=null)
            setHaxeObject([inObj]);
      }
      catch(e:Dynamic) {  }
      #end
   }

   public static function getAsset(inName:String) : Dynamic
   {
      var i = Assets.info.get(inName);
      if (i==null)
         throw "Asset does not exist: " + inName;
      var cached = i.getCache();
      if (cached!=null)
         return cached;
      switch(i.type)
      {
         case BINARY, TEXT: return Assets.getBytes(inName);
         case FONT: return Assets.getFont(inName);
         case IMAGE: return Assets.getBitmapData(inName);
         case MUSIC, SOUND: return Assets.getSound(inName);
      }

      throw "Unknown asset type: " + i.type;
      return null;
   }
   
   
   #if neko
   public static function __init__ () {
      
      untyped $loader.path = $array ("@executable_path/", $loader.path);
      
   }
   #end
   
   
}

