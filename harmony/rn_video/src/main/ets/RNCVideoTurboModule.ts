/**
 * MIT License
 *
 * Copyright (C) 2023 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import { TurboModuleContext, UITurboModule } from '@rnoh/react-native-openharmony/ts';
import { TM } from './generated/ts';
import { drm } from '@kit.DrmKit';

export class RNCVideoTurboModule extends UITurboModule implements TM.RNVideoDecoderInfoModule.Spec {
  /**
   * 没找到获取CodecMimeType集合的API，暂时统计到这里
   */
  static readonly OHOS_SUPPORTED_CODEC: Array<string> =
    ['video/h263', 'video/avc', 'video/mpeg2', 'video/mp4v-es', 'video/mpeg4', 'video/x-vnd.on2.vp8', 'video/hevc',
      'audio/mp4a-latm', 'audio/vorbis', 'audio/flac', 'audio/mpeg', 'audio/g711mu'];

  constructor(protected ctx: TurboModuleContext) {
    super(ctx);
    // console.log('[RNOH]:RNCVideoTurboModule constructor');
  }

  getWidevineLevel(): Promise<number> {
    let promise: Promise<number> = new Promise((resolve, reject) => {
      // com.widevine.alpha/edef8ba9-79d6-4ace-a3c8-27dcd51d21ed  目前只在手表上支持，暂不支持手机，手机目前只com.wiseplay.drm
      let widevineLevel: number = 0; // 鸿蒙获取的模式级别的意思和android对不上，android只有三种，基础1，中等2，高级3
      let level: drm.ContentProtectionLevel =
        drm.createMediaKeySystem('com.wiseplay.drm').getMaxContentProtectionLevel()
      if (level === drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_UNKNOWN) { //设备解密和解码类型未知。
        widevineLevel = 0;
      } else if (level === drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_SW_CRYPTO) { //  设备使用软件级。
        widevineLevel = 1;
      } else if (level === drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_HW_CRYPTO) { //  设备使用硬件级别。
        widevineLevel = 2;
      } else if (level === drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_ENHANCED_HW) { //  设备使用增强的硬件级别。
        widevineLevel = 3;
      } else if (level === drm.ContentProtectionLevel.CONTENT_PROTECTION_LEVEL_MAX) { //  最大级别模式。
        widevineLevel = 4;
      }
      resolve(widevineLevel);
    });
    return promise;
  }

  isCodecSupported(mimeType: string, width: number, height: number): Promise<string> {
    let promise: Promise<string> = new Promise((resolve, reject) => {
      if (RNCVideoTurboModule.OHOS_SUPPORTED_CODEC.indexOf(mimeType) === -1) {
        resolve("unsupported");
      }
      resolve("hardware");
    });
    return promise;

  }

  isHEVCSupported(): Promise<string> {
    let promise: Promise<string> = new Promise((resolve, reject) => {
      if (RNCVideoTurboModule.OHOS_SUPPORTED_CODEC.indexOf("video/hevc") === -1) {
        resolve("unsupported");
      }
      resolve("hardware");
    });
    return promise;
  }
}
