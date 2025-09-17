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
 import type {WithDefault} from 'react-native/Libraries/Types/CodegenTypes';
import type { 
  OnBandwidthUpdateData, 
  OnBufferData, 
  OnLoadData, 
  OnLoadStartData,
  OnProgressData, 
  OnSeekData, 
  OnPlaybackData, 
  OnExternalPlaybackChangeData, 
  OnPictureInPictureStatusChangedData, 
  OnVideoErrorData, 
  OnAudioFocusChangedData, 
  OnTimedMetadataData,
  OnPlaybackStateChangedData,
  OnVolumeChangeData,
  OnAudioTracksData,
  OnVideoTracksData
} from 'src/fabric/VideoNativeComponent';

export type AudioTrack = OnAudioTracksData['audioTracks'][number];
export type TextTrack = OnTextTracksData['textTracks'][number];
export type VideoTrack = OnVideoTracksData['videoTracks'][number];

export type OnTextTracksData = Readonly<{
  textTracks: {
    index: number;
    title?: string;
    language?: string;
    /**
     * iOS only supports VTT, Android supports all 3
     */
    type?: WithDefault<string, 'srt'>;
    selected?: boolean;
  }[];
}>;

export interface ReactVideoEvents {
  onAudioBecomingNoisy?: () => void //Android, iOS
  onBandwidthUpdate?: (e: OnBandwidthUpdateData) => void //Android
  onAudioFocusChanged?: (e: OnAudioFocusChangedData) => void // Android
  onEnd?: () => void //All
  onBuffer?: (e: OnBufferData) => void //Android, iOS
  onError?: (e: OnVideoErrorData) => void //Android, iOS
  onExternalPlaybackChange?: (e: OnExternalPlaybackChangeData) => void //iOS
  onFullscreenPlayerWillPresent?: () => void //Android, iOS
  onFullscreenPlayerDidPresent?: () => void //Android, iOS
  onFullscreenPlayerWillDismiss?: () => void //Android, iOS
  onFullscreenPlayerDidDismiss?: () => void //Android, iOS
  onLoad?: (e: OnLoadData) => void //All
  onLoadStart?: (e: OnLoadStartData) => void //All
  onReadyForDisplay?: () => void //Android, iOS, Web
  onPictureInPictureStatusChanged?: (e: OnPictureInPictureStatusChangedData) => void //iOS
  onPlaybackRateChange?: (e: OnPlaybackData) => void //All
  onProgress?: (e: OnProgressData) => void //All
  onSeek?: (e: OnSeekData) => void //Android, iOS, Windows UWP
  onRestoreUserInterfaceForPictureInPictureStop?: () => void //iOS
  // @todo: fix type
  onTimedMetadata?: (e: OnTimedMetadataData) => void //Android, iOS
  onPlaybackStateChanged?: (e: OnPlaybackStateChangedData) => void; // Android, iOS
  onVolumeChange?: (e: OnVolumeChangeData) => void; //Android, iOS
  onAudioTracks?: (e: OnAudioTracksData) => void; // Android
  onTextTracks?: (e: OnTextTracksData) => void; //Android
  onVideoTracks?: (e: OnVideoTracksData) => void; //Android
}
