import haxe.macro.Expr;
import haxe.macro.Context;

class ApplicationBoot
{
   macro public static function canCallMain()
   {
      var p = Context.currentPos();

      switch(Context.getType("::APP_MAIN::"))
      {
         case TInst(tref,_):
            for(stat in tref.get().statics.get())
               if (stat.name == "main")
                  return Context.parse("true", p);

         default:
      }
      return Context.parse("false", p);
   }

   macro public static function createInstance()
   {
      var p = Context.currentPos();

      switch(Context.getType("::APP_MAIN::"))
      {
         case TInst(tref,_):
            for(stat in tref.get().statics.get())
               if (stat.name == "main")
                  return Context.parse("::APP_MAIN::.main()", p);

         default:
      }

      return Context.parse("new ApplicationDocument()", p);
   }

}
