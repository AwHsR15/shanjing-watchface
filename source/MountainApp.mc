import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MountainApp extends Application.AppBase {
    hidden var view as MountainView or Null = null;

    function initialize() { AppBase.initialize(); }

    function onStart(state as Dictionary or Null) as Void { Settings.migrate(); }

    function getInitialView() {
        view = new MountainView();
        return [view];
    }

    function getSettingsView() {
        return [new SettingsMenu(), new SettingsDelegate()];
    }

    function onSettingsChanged() as Void {
        if (view != null) { view.settingsChanged(); }
    }
}

// On-watch settings: list settings open a page of choices, the current one ticked.
module Settings {
    const SKY = ["自动", "清晨", "白昼", "黄昏", "夜晚"];
    const MOTION = ["丰富", "简洁", "关闭"];
    const ACCENT = ["琥珀", "青", "樱", "雪"];
    const VERSION = 2;

    function get(key as String, fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        return v instanceof Number ? v : fallback;
    }

    function choices(id as Symbol) as Array<String> {
        return id == :sky ? SKY : (id == :motion ? MOTION : ACCENT);
    }

    function key(id as Symbol) as String {
        return id == :sky ? "Sky" : (id == :motion ? "Motion" : "Accent");
    }

    // v1's menu cycled a value on every tap, so motion was easy to switch off by accident: turn it back on once
    function migrate() as Void {
        var v = Application.Storage.getValue("settingsVersion");
        if (v instanceof Number && v >= VERSION) { return; }
        Application.Properties.setValue("Motion", 0);
        Application.Storage.setValue("settingsVersion", VERSION);
    }
}

class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "山境"});
        addItem(new WatchUi.MenuItem("天空", Settings.SKY[Settings.get("Sky", 0)], :sky, null));
        var fx = Application.Properties.getValue("WeatherFx");
        addItem(new WatchUi.ToggleMenuItem("天气入景", "雨雪云雾随实况", :weather, fx instanceof Boolean ? fx : true, null));
        addItem(new WatchUi.MenuItem("动效", Settings.MOTION[Settings.get("Motion", 0)], :motion, null));
        var fe = Application.Properties.getValue("Festivals");
        addItem(new WatchUi.ToggleMenuItem("节日天空", "22 个活动日", :festivals, fe instanceof Boolean ? fe : true, null));
        addItem(new WatchUi.MenuItem("强调色", Settings.ACCENT[Settings.get("Accent", 0)], :accent, null));
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :sky || id == :motion || id == :accent) {
            var labels = Settings.choices(id as Symbol);
            var current = Settings.get(Settings.key(id as Symbol), 0);
            var menu = new WatchUi.Menu2({:title => item.getLabel()});
            for (var i = 0; i < labels.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(labels[i], i == current ? "当前" : null, i, null));
            }
            menu.setFocus(current);
            WatchUi.pushView(menu, new ChoiceDelegate(item, id as Symbol), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :festivals && item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue("Festivals", item.isEnabled());
        } else if (id == :weather && item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue("WeatherFx", item.isEnabled());
        }
        (Application.getApp() as MountainApp).onSettingsChanged();
    }
}

// a page of choices for one list setting: picking one saves it and goes back
class ChoiceDelegate extends WatchUi.Menu2InputDelegate {
    hidden var parent as WatchUi.MenuItem;
    hidden var setting as Symbol;

    function initialize(item as WatchUi.MenuItem, id as Symbol) {
        Menu2InputDelegate.initialize();
        parent = item;
        setting = id;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var v = item.getId() as Number;
        Application.Properties.setValue(Settings.key(setting), v);
        parent.setSubLabel(Settings.choices(setting)[v]);
        (Application.getApp() as MountainApp).onSettingsChanged();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
