package callkeep.fusion.example;

import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.PluginRegistry;
import co.doneservices.callkeep.FlutterCallkeepPlugin;

public class Application extends FlutterApplication implements PluginRegistry.PluginRegistrantCallback {
    @Override
    public void registerWith(PluginRegistry registry) {
        FlutterCallkeepPlugin.registerWith(registry.registrarFor("co.doneservices.callkeep.FlutterCallkeepPlugin"));
    }
}