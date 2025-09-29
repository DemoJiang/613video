import {Platform} from 'react-native';

import RNVideoDecoderInfoModule from './specs/NativeVideoDecoderInfoModule';

const errMsgGen = (moduleName: string, propertyName: string) =>
  `The method or property ${moduleName}.${propertyName} is not available on ${Platform.OS}.`;

export const VideoDecoderProperties = {
  async getWidevineLevel() {
    if (Platform.OS !== 'android') {
      throw new Error(errMsgGen('VideoDecoderProperties', 'getWidevineLevel'));
    }
    if (!RNVideoDecoderInfoModule) {
      throw new Error('Native module not available on Android');
    }
    return RNVideoDecoderInfoModule.getWidevineLevel();
  },
  async isCodecSupported(
    ...args: Parameters<NonNullable<typeof RNVideoDecoderInfoModule>['isCodecSupported']>
  ) {
    if (Platform.OS !== 'android') {
      throw new Error(errMsgGen('VideoDecoderProperties', 'isCodecSupported'));
    }
    if (!RNVideoDecoderInfoModule) {
      throw new Error('Native module not available on Android');
    }
    return RNVideoDecoderInfoModule.isCodecSupported(...args);
  },
  async isHEVCSupported() {
    if (Platform.OS !== 'android') {
      throw new Error(errMsgGen('VideoDecoderProperties', 'isHEVCSupported'));
    }
    if (!RNVideoDecoderInfoModule) {
  throw new Error('Native module not available on Android');
}
    return RNVideoDecoderInfoModule.isHEVCSupported();
  },
};
