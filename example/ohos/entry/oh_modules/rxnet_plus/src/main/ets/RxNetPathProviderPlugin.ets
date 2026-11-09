import common from '@ohos.app.ability.common';
import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import PathUtils from '@ohos/flutter_ohos/src/main/ets/util/PathUtils';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import { PathProviderApi, StorageDirectory } from './Messages';
import fs from '@ohos.file.fs';

const TAG: string = "RxNetPathProviderPlugin";

export default class RxNetPathProviderPlugin extends PathProviderApi implements FlutterPlugin {
  private pluginBinding: FlutterPluginBinding | null = null;
  private context: common.Context | null = null;

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = binding;
    this.context = this.pluginBinding.getApplicationContext();
    this.setup(binding.getBinaryMessenger());
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = null;
  }

  setup(messenger: BinaryMessenger) {
    try {
      PathProviderApi.setup(messenger, this);
    } catch (err) {
      Log.e(TAG, "Received exception while setting up RxNetPathProviderPlugin", err);
    }
  }

  getTemporaryPath(): string {
    return this.getPathProviderTemporaryDirectory();
  }

  getApplicationSupportPath(): string {
    return this.getApplicationSupportDirectory();
  }

  getApplicationDocumentsPath(): string {
    return this.getPathProviderApplicationDocumentsDirectory();
  }

  getApplicationCachePath(): string {
    return this.context?.cacheDir ?? "";
  }

  getExternalStoragePath(): string {
    return this.getPathProviderStorageDirectory();
  }

  getExternalCachePaths(): Array<string> {
    return this.getPathProviderExternalCacheDirectories();
  }

  getExternalStoragePaths(directory: StorageDirectory): Array<string> {
    return this.getPathProviderExternalStorageDirectories(directory);
  }

  private getPathProviderTemporaryDirectory(): string {
    return this.context?.cacheDir ?? "";
  }

  private getApplicationSupportDirectory(): string {
    return PathUtils.getFilesDir(this.context!);
  }

  private getPathProviderApplicationDocumentsDirectory(): string {
    return PathUtils.getDataDirectory(this.context!) ?? "";
  }

  private getPathProviderStorageDirectory(): string {
    return this.context?.filesDir ?? "";
  }

  private getPathProviderExternalCacheDirectories(): Array<string> {
    const paths = new Array<string>();
    if (this.context) {
      paths.push(this.context.cacheDir);
    }
    return paths;
  }

  private getStorageDirectoryString(directory: StorageDirectory): string {
    switch (directory) {
      case StorageDirectory.MUSIC:
        return "music";
      case StorageDirectory.PODCASTS:
        return "podcasts";
      case StorageDirectory.RINGTONES:
        return "ringtones";
      case StorageDirectory.ALARMS:
        return "alarms";
      case StorageDirectory.NOTIFICATIONS:
        return "notifications";
      case StorageDirectory.PICTURES:
        return "pictures";
      case StorageDirectory.MOVIES:
        return "movies";
      case StorageDirectory.DOWNLOADS:
        return "downloads";
      case StorageDirectory.DCIM:
        return "dcim";
      case StorageDirectory.DOCUMENTS:
        return "documents";
      default:
        return "";
    }
  }

  private getPathProviderExternalStorageDirectories(directory: StorageDirectory): Array<string> {
    const paths = new Array<string>();
    if (this.context) {
      const filePath = this.context.filesDir + "/" + this.getStorageDirectoryString(directory);
      if (!fs.accessSync(filePath)) {
        try {
          fs.mkdirSync(filePath);
          paths.push(filePath);
        } catch (err) {
          Log.e(TAG, "mkdirSync failed err:" + err);
        }
      } else {
        paths.push(filePath);
      }
    }
    return paths;
  }
}