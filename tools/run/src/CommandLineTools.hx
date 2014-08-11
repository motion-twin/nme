package;

import haxe.io.Path;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
import platforms.Platform;
import nme.system.System;
import nme.net.SharedObject;
import NMEProject;


class CommandLineTools 
{
   public static var nme(default,null):String;

   static var additionalArguments:Array<String>;
   static var command:String;
   static var assumedTest:Bool = false;
   static var debug:Bool;
   static var forceFlag:Bool = false;
   static var staticFlag:Bool = false;
   static var sampleInDir:String = "";
   static var words:Array<String>;
   static var traceEnabled:Null<Bool>;
   static var host = PlatformHelper.hostPlatform;
   static var nmeVersion:String;
   static var binDirOverride:String = "";
   static var store:SharedObject;
   static var storeData:Dynamic;


   static var allTargets = 
          [ "cpp", "neko", "ios", "iphone", "iphoneos", "iosview", "ios-view",
            "androidview", "android-view", "iphonesim", "android", "androidsim",
            "windows", "mac", "linux", "flash" ];
   static var allCommands = 
          [ "help", "setup", "document", "generate", "create", "xcode", "clone", "demo",
             "installer", "copy-if-newer", "tidy", "set", "unset",
            "clean", "update", "build", "run", "rerun", "install", "uninstall", "trace", "test" ];
   static var setNames =  [ "target", "bin", "command" ];
   static var setNamesHelp =  [ "default when no target is specifiec", "alternate location for binary files", "default command to run" ];
   static var quickSetNames =  [ "debug", "verbose" ];


   private static function buildProject(project:NMEProject) 
   {
      if (!loadProject(project))
         return;

      var platform:Platform = null;

      Log.verbose("Using target platform: " + project.target);
      Log.verbose("Using command : " + project.command);
      if (binDirOverride!="")
      {
         project.setBinDir(binDirOverride);
         Log.verbose("Overriding bin directory : " + project.app.binDir);
      }

      switch(project.target) 
      {
         case Platform.ANDROID:
            platform = new platforms.AndroidPlatform(project);

         case Platform.IOSVIEW:
            platform = new platforms.IOSView(project);

         case Platform.ANDROIDVIEW:
            platform = new platforms.AndroidView(project);

         case Platform.IOS:
            platform = new platforms.IOSPlatform(project);

         case Platform.WINDOWS:
            platform = new platforms.WindowsPlatform(project);

         case Platform.MAC:
            platform = new platforms.MacPlatform(project);

         case Platform.LINUX:
            platform = new platforms.LinuxPlatform(project);

         case Platform.FLASH:
            platform = new platforms.FlashPlatform(project);
      }
      if (platform != null) 
      {
         platform.init();

         var command = project.command.toLowerCase();

         if (command == "tidy" || project.targetFlags.exists("tidy") ||
             command == "clean" || project.targetFlags.exists("clean")) 
         {
            Log.verbose("\nRunning command: TIDY");
            platform.tidy();
         }

         if (command == "clean" || project.targetFlags.exists("clean")) 
         {
            Log.verbose("\nRunning command: CLEAN");
            platform.clean();
         }

         if (command == "uninstall" )
         {
            Log.verbose("\nRunning command: UNINSTALL");
            platform.uninstall();
         }

         if (command == "update" || command == "build" || command == "test" || command=="xcode") 
         {
            Log.verbose("\nRunning command: UPDATE");
            platform.updateBuildDir();
            platform.updateOutputDir();
            platform.updateAssets();
            platform.updateLibs();
            platform.updateExtra();
         }

         if (command == "build" || command == "test" || command=="xcode") 
         {
            Log.verbose("\nRunning command: BUILD");
            platform.runHaxe();
            platform.copyBinary();
            if (command!="xcode")
            {
               platform.buildPackage();
               platform.postBuild();
            }
         }

         if (command == "install" || command == "run" || command == "test") 
         {
            Log.verbose("\nRunning command: INSTALL");
            platform.prepareTest();
            platform.install();
         }

         if (command == "run" || command == "rerun" || command == "test") 
         {
            Log.verbose("\nRunning command: RUN");
            platform.run(additionalArguments);
         }

         if (command == "test" || command == "trace") 
         {
            if (traceEnabled==null)
              traceEnabled = project.platformType == Platform.TYPE_MOBILE;
            if (traceEnabled || command == "trace") 
            {
               Log.verbose("\nRunning command: TRACE");
               platform.trace();
            }
         }
         Log.verbose("NME done.");
      }
   }

   static function showSampleHelp(inMode:String)
   {
      if (inMode=="demo")
         Sys.println("nme demo [target] - build given sample [with given target]");
      else
         Sys.println("nme clone [-in local-dir] - clone a project [into given directory]");

      Sys.println('   nme $inMode directory - from given directory');
      Sys.println('   nme $inMode nme-sample - $inMode nme sample');
      Sys.println('   nme $inMode haxelib - list samples in given haxelib');
      Sys.println('   nme $inMode haxelib:directory - sample from given haxelib directory');
      Sys.println('   nme $inMode haxelib:sample-name - named sample from given haxelib');
      Sys.println("");

      showSamples("NME",nme);
      //var joint = Log.mVerbose ? "\n" : ", ";
   }

   static function getSamples(dir:String)
   {
      var result = new Array<Sample>();

      var subDirs = ["/samples", ""];
      for(subDir in subDirs)
      {
         var test = dir + subDir;
         if (FileSystem.exists(test) && FileSystem.isDirectory(test))
         {
            if ( Sample.fromDir(test,result) )
               break;
         }
      }

      return result;
   }

   static function showSamples(name:String, dir:String)
   {
      var samples = getSamples(dir);

      var joint = "\n ";
      Sys.println(name + " samples: " + joint + samples.join(joint) );
   }

   static function findSample(samples:Array<Sample>, name:String, target:String )
   {
      var nameLen = name.length;
      for(sample in samples)
      {
         if (name==sample.name ||
              (nameLen<sample.name.length && nameLen>=sample.short.length &&
                  name==sample.name.substr(0, nameLen) ) )
         {
            doSample(sample.path,target);
            return;
         }
      }
      // Once more, ignoring case...
      var lower = name.toLowerCase();
      for(sample in samples)
      {
         if (lower==sample.name ||
              (nameLen<sample.name.length && nameLen>=sample.short.length &&
                  lower==sample.name.substr(0, nameLen).toLowerCase() ) )
         {
            doSample(sample.path,target);
            return;
         }
      }


      var joint = "\n ";
      Sys.println("Valid samples: " + joint + samples.join(joint) );
      Log.error("Could not find unique sample " + name);
   }


   static function doSample(dir:String,sampleTarget:String)
   {
 

      if (command=="demo")
      {
         if (sampleInDir=="")
         {
            if (binDirOverride!="")
               sampleInDir = binDirOverride;
            else
            {
               var path = new haxe.io.Path(dir);
               sampleInDir = path.file;
            }
         }

         if (!PathHelper.isAbsolute(sampleInDir))
            sampleInDir = PathHelper.normalise(Sys.getCwd()+ "/" + sampleInDir);

         Log.verbose("Building sample " + dir + " in " + sampleInDir); 
         var args = ["run","nme","test","-bin", sampleInDir ];
         if (Log.mVerbose)
            args.push("-v");
         if (debug)
            args.push("-debug");
         if (sampleTarget!="")
         {
            Sys.println("Create demo " + dir + " for target " + sampleTarget);
            args.push(sampleTarget);
         }
         else
         {
            Sys.println("Create demo " + dir + " using default target");
         }
         ProcessHelper.runCommand(dir, "haxelib", args);
      }
      else
      {
         if (sampleInDir=="")
         {
            var path = new haxe.io.Path(dir);
            sampleInDir = path.file;
         }

         Sys.println("Clone " + dir + " in " + sampleInDir); 
         FileHelper.recursiveCopy(dir, sampleInDir);

         var relocation = FileSystem.fullPath(dir);
         try
         {
           File.saveContent(sampleInDir+"/relocation.dir", relocation);
         }
         catch(e:Dynamic)
         {
            Log.error("Could not save relocation.dir:" + e);
         }

         if (sampleTarget!="")
         {
            var args = ["run","nme","test",sampleTarget ];
            if (Log.mVerbose)
               args.push("-v");
            if (debug)
               args.push("-debug");

            Sys.println("Test " + sampleInDir + " using target " + sampleTarget);
            ProcessHelper.runCommand(sampleInDir, "haxelib", args);
         }
      }
   }

   static function processSample(inMode:String)
   {
      var target="";
      if (words.length>1 && isTarget(words[words.length-1]))
         target = words.pop();

      if (words.length==0)
        showSampleHelp(inMode);
      else
      {

        var arg = words[0];

        if (FileSystem.exists(arg) && FileSystem.isDirectory(arg))
        {
           doSample(arg,target);
           return;
        }

        var parts = words.length>1 ? words : words[0].split(":");
        if (parts.length>1)
        {
           var name = Sample.projectOf(parts[0]);
           var path = PathHelper.getHaxelib(new Haxelib(name),true);
           if (path==null)
           {
              Log.error("Could not find haxelib " + name);
           }
           if (parts[1]=="")
              showSamples(name, path );
           else
           {
              var samples = getSamples(path);
              if (samples.length<1)
                 Log.error("Could not find samples in " + path);
              findSample(samples,parts[1],target);
           }
           return;
        }

        // maybe it is an nme sample or a haxelib ...
        var name = Sample.projectOf(words[0]);
        var path = PathHelper.getHaxelib(new Haxelib(name),true);
        if (path!=null)
            showSamples(name,path);
        else
        {
           var samples = getSamples(nme);
           if (samples.length<1)
               Log.error("Could not find nme samples");
           findSample(samples,words[0],target);
        }
     }
   }

   private static function createTemplate() 
   {
      if (words.length > 0) 
      {
         if (words[0] == "project") 
         {
            var id = [ "com", "example", "project" ];

            if (words.length > 1) 
            {
               var name = words[1];
               id = name.split(".");

               if (id.length < 3) 
               {
                  id = [ "com", "example" ].concat(id);
               }
            }

            var company = "Company Name";

            if (words.length > 2) 
            {
               company = words[2];
            }

            var context:Dynamic = { };

            var title = id[id.length - 1];
            title = title.substr(0, 1).toUpperCase() + title.substr(1);

            var packageName = id.join(".").toLowerCase();

            context.title = title;
            context.packageName = packageName;
            context.version = "1.0.0";
            context.company = company;
            context.file = StringTools.replace(title, " ", "");


            /*
            for(define in userDefines.keys()) 
            {
               Reflect.setField(context, define, userDefines.get(define));
            }
            */

            PathHelper.mkdir(title);
            FileHelper.recursiveCopyTemplate([ nme + "/templates/default" ], "project", title, context);

            if (FileSystem.exists(title + "/Project.hxproj")) 
            {
               FileSystem.rename(title + "/Project.hxproj", title + "/" + title + ".hxproj");
            }

         } else if (words[0] == "extension") 
         {
            var title = "Extension";

            if (words.length > 1) 
            {
               title = words[1];
            }

            var file = StringTools.replace(title, " ", "");
            var extension = StringTools.replace(file, "-", "_");
            var className = extension.substr(0, 1).toUpperCase() + extension.substr(1);

            var context:Dynamic = { };
            context.file = file;
            context.extension = extension;
            context.className = className;
            context.extensionLowerCase = extension.toLowerCase();
            context.extensionUpperCase = extension.toUpperCase();

            PathHelper.mkdir(title);
            FileHelper.recursiveCopyTemplate([ nme + "/templates" ], "extension", title, context);

            if (FileSystem.exists(title + "/Extension.hx")) 
            {
               FileSystem.rename(title + "/Extension.hx", title + "/" + className + ".hx");
            }

            if (FileSystem.exists(title + "/project/common/Extension.cpp")) 
            {
               FileSystem.rename(title + "/project/common/Extension.cpp", title + "/project/common/" + file + ".cpp");
            }

            if (FileSystem.exists(title + "/project/include/Extension.h")) 
            {
               FileSystem.rename(title + "/project/include/Extension.h", title + "/project/include/" + file + ".h");
            }
         }
         else
         {
            var sampleName = words[0];

            if (FileSystem.exists(nme + "/samples/" + sampleName)) 
            {
               PathHelper.mkdir(sampleName);
               FileHelper.recursiveCopy(nme + "/samples/" + sampleName, Sys.getCwd() + "/" + sampleName);
            }
            else
            {
               Log.error("Could not find sample project \"" + sampleName + "\"");
            }
         }
      }
      else
      {
         Sys.println("You must specify 'project' or a sample name when using the 'create' command.");
         Sys.println("");
         Sys.println("Usage: ");
         Sys.println("");
         Sys.println(" nme create project \"com.package.name\" \"Company Name\"");
         Sys.println(" nme create extension \"ExtensionName\"");
         Sys.println(" nme create SampleName");
         Sys.println("");
         Sys.println("");
         Sys.println("Available samples:");
         Sys.println("");

         for(name in FileSystem.readDirectory(nme + "/samples")) 
         {
            if (FileSystem.isDirectory(nme + "/samples/" + name)) 
            {
               Sys.println(" - " + name);
            }
         }
      }
   }

   private static function setup():Void 
   {
      if (PlatformHelper.hostPlatform==Platform.WINDOWS)
      {
         var haxePath:String = Sys.getEnv("HAXEPATH");
         if (haxePath==null || haxePath=="")
         {
            var nekoPath = System.exeName;
            var parts = nekoPath.split("\\");
            if (parts.length>3 && parts[parts.length-2]=="neko")
               haxePath = parts.slice(0,parts.length-2).join("\\") + "\\haxe";
            else
               haxePath = "C:\\HaxeToolkit\\haxe\\";
         }

         var target = haxePath + "\\nme.bat";
         var source = nme + "/tools/run/bin/nme.bat";

         if (!forceFlag && FileSystem.exists(target))
         {
            Sys.println("NME appears to be setup already.  Use '-f' to force reinstall");
         }
         else
         {
            try
            {
               File.copy(source,target);
               Sys.println("Wrote " + target);
            }
            catch(e:Dynamic)
            {
              Log.error("Could not write " + target + " :" + e);
            }
         }
      }
      else
      {
         var source = nme + "/tools/run/bin/nme.sh";
         var target = "/usr/bin/nme";

         if (!forceFlag && FileSystem.exists(target))
         {
            Sys.println("NME appears to be setup already.  Use '-f' to force reinstall");
         }
         else
         {
            try
            {
               Sys.command("sudo", ["cp", source, target]);
               Sys.command("sudo", ["chmod", "755", target]);
            } catch (e:Dynamic) { }

            if (!FileSystem.exists(target))
               Log.error("NME setup failed - could not write " + target);
            else
               Sys.println("Wrote " + target);
         }
      }
   }


   private static function document():Void 
   {
   }

   private static function displayHelp():Void 
   {
      displayInfo();

      Sys.println("");
      Sys.println(" Usage : nme help");
      Sys.println(" Usage : nme [setup|clean|update|build|run|test] <project> (target) [options]");
      Sys.println("");
      Sys.println(" Commands : ");
      Sys.println("");
      Sys.println("  help : Show this information");
      Sys.println("  tidy : Remove the target build directory if it exists");
      Sys.println("  clean : Remove the target build directory and cpp obj files");
      Sys.println("  update : Copy assets for the specified project/target");
      Sys.println("  build : Compile and package for the specified project/target");
      Sys.println("  run : Install and run for the specified project/target");
      Sys.println("  test : Update, build and run in one command");
      Sys.println("  clone : Copy an existing sample or project");
      Sys.println("  demo :  Run an existing sample or project");
      Sys.println("  create : Create a new project or extension using templates");
      Sys.println("  setup : Create an alias for nme so you don't need to type 'haxelib run nme...'");
      Sys.println("");
      Sys.println(" Targets : ");
      Sys.println("");
      Sys.println("  cpp         : Create applications, for host system (linux,mac,windows)");
      Sys.println("  android     : Create Google Android applications");
      Sys.println("  ios         : Create Apple iOS applications");
      Sys.println("  androidview : Create library files for inclusion in Google Android applications");
      Sys.println("  iosview     : Create library files for inclusion in Apple iOS applications");
      Sys.println("  flash       : Create SWF applications for Adobe Flash Player");
      Sys.println("  neko        : Create application for rapid testing on host system");
      Sys.println("  iphone      : ios + device debugging");
      Sys.println("  iphonesim   : ios + simulator");
      Sys.println("  androidsim  : android + simulator");
      Sys.println("");
      Sys.println(" Options : ");
      Sys.println("");
      Sys.println("  -D : Specify a define to use when processing other commands");
      Sys.println("  -debug : Use debug configuration instead of release");
      Sys.println("  -megatrace : Add maximum debugging");
      Sys.println("  -verbose : Print additional information(when available)");
      Sys.println("  -f : force setup re-write");
      Sys.println("  -vverbose : very berbose - includes haxe verbose mode");
      Sys.println("  -tidy : remove ouput files");
      Sys.println("  -clean : remove output files and c++ obj file store");
      Sys.println("  -bin directory: put generated binaries in different directory");
      Sys.println("  [mac/linux] -32 -64 : Compile for 32-bit or 64-bit instead of default");
      Sys.println("  [android] -device=serialnumber : specify serial number");
      Sys.println("  [ios] -simulator : Build/test for the device simulator");
      Sys.println("  [ios] -simulator -ipad : Build/test for the iPad Simulator");
      Sys.println("  (run|test) -args a0 a1 ... : Pass remaining arguments to executable");
   }

   private static function displayInfo(showHint:Bool = false, forXcode:Bool = false):Void 
   {
      if (!forXcode) // Does not show up so well in xcode
      {
         Sys.println(" _____________");
         Sys.println("|             |");
         Sys.println("|__  _  __  __|");
         Sys.println("|  \\| \\/  ||__|");
         Sys.println("|\\  \\  \\ /||__|");
         Sys.println("|_|\\_|\\/|_||__|");
         Sys.println("|             |");
         Sys.println("|_____________|");
         Sys.println("");
      }
      Sys.println("NME Command-Line Tools(" + nmeVersion + " @ '" + nme + "')");

      if (showHint) 
      {
         //if (!FileSystem.exits(
         Sys.println("Use \"nme help\" for more commands");
      }
   }

   private static function findProjectFile(path:String):String 
   {
      if (FileSystem.exists(PathHelper.combine(path, "project.nmml"))) 
         return PathHelper.combine(path, "project.nmml");
      else if (FileSystem.exists(PathHelper.combine(path, "build.nmml"))) 
         return PathHelper.combine(path, "build.nmml");
      else if (FileSystem.exists(PathHelper.combine(path, "project.xml"))) 
         return PathHelper.combine(path, "project.xml");
      else if (FileSystem.exists(PathHelper.combine(path, "Project.xml"))) 
         return PathHelper.combine(path, "Project.xml");
      else
      {
         var files = FileSystem.readDirectory(path);
         var projs = [];
         var haxes = [];

         for(file in files) 
         {
            var path = PathHelper.combine(path, file);
            if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
            {
               var ext = Path.extension(file);
               if (ext=="nmml" || ext=="xml")
                  projs.push(path);
               else if (ext=="hx")
                  haxes.push(path);
            }
         }

         if (projs.length==1)
            return projs[0];

         if (projs.length==0 && haxes.length==1)
            return haxes[0];
      }

      return "";
   }

   private static function generate():Void 
   {
   }

   private static function getBuildNumber(project:NMEProject, increment:Bool = true):Void 
   {
      if (project.app.buildNumber == "1") 
      {
         var versionFile = PathHelper.combine(project.app.binDir, ".build");
         var version = 1;

         PathHelper.mkdir(project.app.binDir);

         if (FileSystem.exists(versionFile)) 
         {
            var previousVersion = Std.parseInt(File.getBytes(versionFile).toString());
            if (previousVersion != null) 
            {
               version = previousVersion;
               if (increment) 
                  version ++;
            }
         }

         project.app.buildNumber = Std.string(version);

         try 
         {
            var output = File.write(versionFile, false);
            output.writeString(Std.string(version));
            output.close();

         } catch(e:Dynamic) {}
      }
   }

   public static function getHXCPPConfig(project:NMEProject) : Void
   {
      var environment = Sys.environment();
      var config = "";

      if (environment.exists("HXCPP_CONFIG")) 
      {
         config = environment.get("HXCPP_CONFIG");
      }
      else
      {
         var home = "";

         if (environment.exists("HOME")) 
            home = environment.get("HOME");
         else if (environment.exists("USERPROFILE")) 
            home = environment.get("USERPROFILE");
         else
         {
            Log.warn("HXCPP config might be missing(Environment has no \"HOME\" variable)");

            return null;
         }

         config = home + "/.hxcpp_config.xml";

         if (host == Platform.WINDOWS) 
         {
            config = config.split("/").join("\\");
         }
      }

      if (FileSystem.exists(config)) 
      {
         Log.verbose("Reading HXCPP config: " + config);

         new NMMLParser(project,config);
      }
      else
      {
         Log.warn("", "Could not read HXCPP config: " + config);
      }
   }

   private static function getVersion():String 
   {
      var data = haxe.Json.parse(File.getContent(nme + "/haxelib.json"));
      return data.version;
   }

   #if (neko && haxe_210)
   public static function __init__ () 
   {
      // Fix for library search paths
      var path = PathHelper.getHaxelib(new Haxelib("nme")) + "ndll/";

      switch(PlatformHelper.hostPlatform) 
      {
         case WINDOWS:
            untyped $loader.path = $array(path + "Windows/", $loader.path);

         case MAC:
            untyped $loader.path = $array(path + "Mac/", $loader.path);

         case LINUX:
            var arguments = Sys.args();
            var raspberryPi = false;

            for(argument in arguments) 
               if (argument == "-rpi") raspberryPi = true;

            if (raspberryPi) 
               untyped $loader.path = $array(path + "RPi/", $loader.path);
            else if (PlatformHelper.hostArchitecture == Architecture.X64) 
               untyped $loader.path = $array(path + "Linux64/", $loader.path);
            else
               untyped $loader.path = $array(path + "Linux/", $loader.path);

         default:
      }
   }
   #end

   static function loadProject(project:NMEProject) : Bool
   {
      Log.verbose("Loading project...");

      var projectFile = "";
      var targetName = "";
      var explicitProjectFile = false;

      for(w in 0...words.length)
      {
         var test = words[w].toLowerCase();
         if (isTarget(test))
         {
            targetName = test;
            words.splice(w,1);
            break;
         }
      }

      if (targetName=="")
      {
         if (words.length>1)
            Log.error("No valid target supplied. Try : " + allTargets.join(","));

         if (storeData.target!=null)
         {
            targetName = storeData.target;
            Log.verbose('Using target "$targetName" from settings');
         }
         else
         {
            targetName = "cpp";
            Log.verbose('Using default target "$targetName"');
         }
      }

      if (words.length>0)
      {
         if (FileSystem.exists(words[0])) 
         {
            if (FileSystem.isDirectory(words[0])) 
               projectFile = findProjectFile(words[0]);
            else
            {
               explicitProjectFile = true;
               projectFile = words[0];
            }
         }
      }
      else
         projectFile = findProjectFile(Sys.getCwd());


      if (projectFile == "") 
      {
         if (assumedTest && words.length==0)
            return false;

         Log.error("You must have a \"project.nmml\" file or specify another valid project file when using the '" + command + "' command");
      }
      else
         Log.verbose("Using project file: " + projectFile);

      project.checkRelocation( new Path(projectFile).dir );

      project.haxedefs.set("nme_install_tool", 1);
      project.haxedefs.set("nme_ver", nmeVersion);
      project.haxedefs.set("nme" + nmeVersion.split(".")[0], 1);

      project.setTarget(targetName);

      if (staticFlag && project.optionalStaticLink)
         project.staticLink = true;

      getHXCPPConfig(project);

      if (host == Platform.WINDOWS) 
      {
         if (project.environment.exists("JAVA_HOME")) 
            Sys.putEnv("JAVA_HOME", project.environment.get("JAVA_HOME"));

         if (Sys.getEnv("JAVA_HOME") != null) 
         {
            var javaPath = PathHelper.combine(Sys.getEnv("JAVA_HOME"), "bin");

            if (host == Platform.WINDOWS) 
               Sys.putEnv("PATH", javaPath + ";" + Sys.getEnv("PATH"));
            else
               Sys.putEnv("PATH", javaPath + ":" + Sys.getEnv("PATH"));
         }
      }

      try { Sys.setCwd(Path.directory(projectFile)); } catch(e:Dynamic) {}

      var ext =  Path.extension(projectFile);
      var projFile = Path.withoutDirectory(projectFile);
      if (ext == "nmml" || ext == "xml") 
      {
         new NMMLParser(project,projFile);
      }
      else if (ext=="hx")
      {
         new HxParser(project,projFile);
      }
      else
      {
         var loaded = false;
         if (explicitProjectFile)
         {
            try
            {
               new NMMLParser(project,projFile);
               loaded = true;
            }
            catch(e:Dynamic)
            {
               Log.warn(e);
            }
         }

         if (!loaded)
         {
            Log.error(projectFile + " does not appear be a project file.");
            return false;
         }
      }

      project.localDefines.set("PROJECT_FILE", projFile);
      project.processStdLibs();

      // Better way to do this?
      switch(project.target) 
      {
         case Platform.ANDROID, Platform.IOS,
              Platform.IOSVIEW, Platform.ANDROIDVIEW:

            getBuildNumber(project);

         default:
      }

      project.templatePaths.push( nme + "/templates" );

      return true;
   }

   private static function resolveClass(name:String):Class<Dynamic> 
   {
      if (name.toLowerCase().indexOf("project") > -1) 
      {
         return NMEProject;
      }
      else
      {
         return Type.resolveClass(name);
      }
   }

   public static function isIn(array:Array<String>,inValue:String)
   {
      for(a in array)
         if (a==inValue)
            return true;
      return false;

   }

   public static function isCommand(inCommand:String)
   {
      return isIn(allCommands,inCommand);
   }

   public static function isTarget(inTarget:String)
   {
      return isIn(allTargets,inTarget);
   }


   public static function setValue()
   {
      if (words.length==2 || isIn(setNames,words[0]))
      {
         Reflect.setField(storeData, words[0], words[1]);
         store.flush();
      }
      else if (words.length==1 || isIn(quickSetNames,words[0]))
      {
         Reflect.setField(storeData, words[0], true);
         store.flush();
      }
      else
      {
         Sys.println("Usage : nme set name [value]");
         for(n in 0...setNames.length)
         {
            Sys.println(" " + setNames[n] + " = " + setNamesHelp[n]);
         }
         for(name in quickSetNames)
            Sys.println(' $name');
      }
   }


   public static function unsetValue()
   {
      if (words.length!=1 || !(isIn(setNames,words[0]) || isIn(quickSetNames,words[0])) )
      {
         Sys.println("Usage : nme unset name");
         Sys.println(" name : " + setNames.concat(quickSetNames).join(",") );
      }
      else
      {
         Reflect.deleteField(storeData, words[0]);
         store.flush();
      }
   }



   public static function main():Void 
   {
      var project = new NMEProject( );

      traceEnabled = null;

      additionalArguments = new Array<String>();

      command = "";

      words = new Array<String>();

      store = SharedObject.getLocal("nme-run");
      storeData = store.data;

      if (storeData.verbose!=null)
      {
         Sys.putEnv("HXCPP_VERBOSE","1");
         Log.mVerbose = true;
         Log.verbose("Using verbose option from setting");
      }

      if (storeData.debug!=null)
      {
         project.debug = debug = true;
         Log.verbose("Using debug option from setting");
      }


      // Haxelib bug
      for(hackDir in ["Linux","Linux64", Sys.systemName(), Sys.systemName()+"64" ])
      {
         try
         {
            if (FileSystem.exists("ndll") && !FileSystem.exists("ndll/" + hackDir) )
                FileSystem.createDirectory("ndll/" + hackDir);
         }
         catch(e:Dynamic) { }
      }


      processArguments(project);



      if (Log.mVerbose && command!="") 
      {
         displayInfo(false, command=="xcode");
         Sys.println("");
      }

      switch(command) 
      {
         case "":
            displayInfo(true);

         case "help":
            displayHelp();

         case "set":
            setValue();

         case "unset":
            unsetValue();

         case "setup":
            setup();

         case "document":
            document();

         case "generate":
            generate();

         case "clone":
            processSample("clone");

         case "demo":
            processSample("demo");

         case "create":
            createTemplate();

         case "xcode":
            if (Sys.getEnv("NME_ALREADY_BUILDING")=="BUILDING")
               Sys.println("...already building");
            else
               buildProject(project);

         case "clean", "update", "build", "run", "rerun", "install", "uninstall", "trace", "test", "tidy":

            if (words.length > 2) 
            {
               Log.error("Incorrect number of arguments for command '" + command + "'");
               return;
            }

            buildProject(project);

         case "installer", "copy-if-newer":

            // deprecated?
         default:

            Log.error("'" + command + "' is not a valid command");
      }
   }

   private static function processArguments(project:NMEProject):Void 
   {
      var arguments = Sys.args();

      nme = PathHelper.getHaxelib(new Haxelib("nme"));

      var lastCharacter = nme.substr( -1, 1);
      if (lastCharacter == "/" || lastCharacter == "\\") 
         nme = nme.substr(0, -1);

      nmeVersion = getVersion();

      if (arguments.length > 0) 
      {
         // When the command-line tools are called from haxelib, 
         // the last argument is the project directory and the
         // path to NME is the current working directory 
         var lastArgument = "";
         for(i in 0...arguments.length) 
         {
            lastArgument = arguments.pop();
            if (lastArgument.length > 0) break;
         }

         lastArgument = new Path(lastArgument).toString();
         if (((StringTools.endsWith(lastArgument, "/") && lastArgument != "/") ||
               StringTools.endsWith(lastArgument, "\\")) &&
               !StringTools.endsWith(lastArgument, ":\\")) 
            lastArgument = lastArgument.substr(0, lastArgument.length - 1);

         if (FileSystem.exists(lastArgument) && FileSystem.isDirectory(lastArgument)) 
            Sys.setCwd(lastArgument);
      }

      command = "";

      var argIdx = 0;
      while(argIdx < arguments.length)
      {
         var argument = arguments[argIdx++];

         var equals = argument.indexOf("=");
         if (equals > 0) 
         {
            var argValue = argument.substr(equals + 1);
            // if quotes remain on the argValue we need to strip them off
            // otherwise the compiler really dislikes the result!
            var r = ~/^['"](.*)['"]$/;
            if (r.match(argValue)) 
               argValue = r.matched(1);

            if (argument.substr(0, 2) == "-D") 
               project.haxedefs.set(argument.substr(2, equals - 2), argValue);
            else if (argument.substr(0, equals) == "-device") 
               project.targetFlags.set("device",argValue);
            else if (argument.substr(0, 2) == "--") 
            {
               // this won't work because it assumes there is only ever one of these.
               //projectDefines.set(argument.substr(2, equals - 2), argValue);
               var field = argument.substr(2, equals - 2);

               if (field == "haxedef") 
                  project.haxedefs.set(argValue,"1");
               else if (field == "haxeflag") 
                  project.haxeflags.push(argValue);
               else if (field == "macro") 
                  project.macros.push(StringTools.replace(argument, "macro=", "macro "));
               else if (field == "haxelib") 
               {
                  var name = argValue;
                  var version = "";

                  if (name.indexOf(":") > -1) 
                  {
                     version = name.substr(name.indexOf(":") + 1);
                     name = name.substr(0, name.indexOf(":"));
                  }

                  project.haxelibs.push(new Haxelib(name, version));
               }
               else if (field == "source" || field=="cp" ) 
                  project.classPaths.push(argValue);
               else if (field == "xcodeconfig" ) 
               {
                  if (argValue=="Debug")
                     project.debug = debug = true;
               }
               else
                  project.localDefines.set(field, argValue);
            }
            else
            {
               project.haxedefs.set(argument.substr(0, equals), argValue);
            }
         }
         else if (argument.substr(0, 1) == "-") 
         {
            if (argument.substr(1, 1) == "-") 
            {
               project.haxeflags.push(argument);
               if (argument == "--remap" || argument == "--connect") 
               {
                  project.haxeflags.push(argument);
                  project.haxeflags.push(arguments[argIdx++]);
               }
            }
            else if (argument == "-bin") 
               binDirOverride = arguments[argIdx++];

            else if (argument.substr(0, 4) == "-arm") 
            {
               var name = argument.substr(1).toUpperCase();
               var value = Type.createEnum(Architecture, name);

               if (value != null) 
                  project.architectures.push(value);
            }
            else if (argument == "-64") 
               project.architectures.push(Architecture.X64);

            else if (argument == "-in") 
               sampleInDir = arguments[argIdx++];

            else if (argument == "-32") 
               project.architectures.push(Architecture.X86);

            else if (argument.substr(0, 2) == "-D") 
               project.haxedefs.set(argument.substr(2), "");

            else if (argument == "-lib") 
               project.addLib(arguments[argIdx++],"lib","","",staticFlag?true:null);

            else if (argument == "-static" || argument=="-s") 
               staticFlag = true;

            else if (argument.substr(0, 2) == "-l") 
               project.includePaths.push(argument.substr(2));

            else if (argument == "-f")
               forceFlag = true;

            else if (argument == "-v" || argument == "-verbose") 
            {
               Sys.putEnv("HXCPP_VERBOSE","1");
               Log.mVerbose = true;
            }
            else if (argument == "-vv" || argument == "-vverbose") 
            {
               project.haxeflags.push("-v");
               Sys.putEnv("HXCPP_VERBOSE","1");
               Log.mVerbose = true;
            }
            else if (argument == "-args")
            {
               while(argIdx < arguments.length)
                   additionalArguments.push(arguments[argIdx++]);
            }
            else if (argument == "-notrace") 
               traceEnabled = false;

            else if (argument == "-debug") 
            {
               project.debug = debug = true;
            }
            else if (argument == "-megatrace") 
               project.megaTrace = project.debug = debug = true;

            else
               project.targetFlags.set(argument.substr(1), "");
         }
         // No '-'
         else
         {
            words.push(argument);
         }
      }

      for(w in 0...words.length)
      {
         if (isCommand(words[w]))
         {
            command = words[w];
            words.splice(w,1);
            break;
         }
      }

      if (command=="" && storeData.command!=null)
      {
         command = storeData.command;
         Log.verbose('Using command "$command" from settings');
      }

      if (binDirOverride=="" && storeData.bin!=null)
      {
         binDirOverride = storeData.bin;
         Log.verbose('Using binDir "$binDirOverride" from settings');
      }

      if (command=="")
      {
         displayInfo(true);
         command = "test";
         assumedTest = true;
      }

      project.setCommand(command);
   }
}


