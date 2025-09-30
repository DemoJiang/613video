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

import { Descriptor, RNOHContext, ViewBaseProps, RNViewBase, } from '@rnoh/react-native-openharmony'
import media from '@ohos.multimedia.media';
import { PlayPlayer } from './view/PlayPlayer';
import { VideoController } from './controller/VideoController';
import { PlayConstants } from './common/constants/PlayConstants';
import { CommonConstants, ResizeMode } from './common/constants/CommonConstants';
import Logger from './common/util/Logger';
import { display } from '@kit.ArkUI';
import observer from '@ohos.arkui.observer';
import { RNC } from './generated/ts';

interface NavDestinationState {
  navigationId: string
  name: string
  state: number
  index: number
  param: string
}

class RNCVideoSrcRequestHeaders {
  key: string = ''
  value: string = ''
}

class RNCVideoSrc {
  uri: string = ''
  isNetwork: boolean = true
  isAsset: boolean = false
  shouldCache: boolean = false
  type: string = ''
  mainVer: number = 0
  patchVer: number = 0
  requestHeaders?: RNCVideoSrcRequestHeaders[]
}

export class RNCAudioTracks {
  index: number = -1
  title?: string = "" // 鸿蒙没有该字段
  language?: string = ""
  bitrate?: number = -1
  type?: string = ""
  selected?: boolean = false // 鸿蒙没有该字段
}

export class RNCVideoTracks {
  index: number = -1
  tracksId?: string = ""
  codecs?: string = ""
  width?: number = 0
  height?: number = 0
  bitrate?: number = 0
  selected?: boolean = false // 鸿蒙没有该字段
}

export class RNCTextTracks {
  index: number = -1
  title?: string = "" // 鸿蒙没有该字段
  language?: string = ""
  bitrate?: number = -1
  type?: string = ""
  selected?: boolean = false // 鸿蒙没有该字段
}

export class RNCSelectTrack {
  type?: string = ""
  value?: string = ""
}

export interface AutoLayoutViewState {}

export const RNC_VIDEO_TYPE: string = "RNCVideo"

export type VideoViewDescriptor = Descriptor<"RNCVideo", RNC.RNCVideo.Props>

const RNC_VIDEO_SEEK: string = 'seek'
const RNC_VIDEO_CMD_STATE: string = 'setPlayerPauseStateCmd'
const RNC_VIDEO_CMD_PIP_ENTER: string = 'enterPictureInPictureCmd'
const RNC_VIDEO_CMD_PIP_EXIT: string = 'exitPictureInPictureCmd'
const RNC_VIDEO_CMD_SEEK: string = 'seekCmd'
const RNC_VIDEO_CMD_FULLSCREEN: string = 'setFullScreenCmd'
const RNC_VIDEO_CMD_VOLUME: string = 'setVolumeCmd'

export interface IRNCVideo {
  videoMargin: string
  viewWidth: number
  viewHeight: number
  onVideoLoadStart: (cUri: string | media.AVFileDescriptor) => void
  onReadyForDisplay: () => void
  onVideoProgress: (currentTime: number, _playableDuration: number, _seekableDuration: number) => void
  onVideoLoad: (startSecond: number, length: number, widthIn: number, heightIn: number, orientationIn: string) => void
  onVideoBuffer: (isBufferingIn: boolean) => void
  onVideoPlaybackStalled: () => void
  onVideoPlaybackResume: () => void
  onVideoEnd: () => void
  onVideoError: (err: string) => void
  //=====6.13.0
  onVideoPlaybackStateChanged: (isPlaying: boolean, isSeeking: boolean) => void // 具体待实现，没有查明白鸿蒙的seeking
  onVolumeChange: (volume: number) => void
  onAudioTracks: (audioTracks: RNCAudioTracks[]) => void
  onVideoTracks: (audioTracks: RNCVideoTracks[]) => void
  onTextTracks: (audioTracks: RNCTextTracks[]) => void
  onPlaybackRateChange: (playbackRate: number) => void
  onPictureInPictureStatusChanged: (isActive: boolean) => void
  onVideoFullscreenPlayerWillPresent: () => void
  onVideoFullscreenPlayerDidPresent: () => void
  onVideoFullscreenPlayerWillDismiss: () => void
  onVideoFullscreenPlayerDidDismiss: () => void
  onAudioFocusChanged: (hasAudioFocus: boolean) => void
  onVideoIdle: () => void
}

const TAG: string = 'RNOH in RNCVideo'

@Component
export struct RNCVideo {
  ctx!: RNOHContext;
  tag: number = -1;
  @State descriptor: VideoViewDescriptor = Object() as VideoViewDescriptor;
  @State videoMargin: string = PlayConstants.PLAY_PAGE.MARGIN_ZERO;
  @Provide('controlsVar') controls: boolean = false;
  @Provide('srcVar') srcParam: string | media.AVFileDescriptor = ''; /*最终avplayer认识的 字符串*/
  @Provide index: number = 0;
  @Provide('mutedVar') muted: boolean = false;
  @Provide('fullscreenVar') fullscreen: boolean = false;
  @Provide('extFullscreenVar') @Watch("extFullscreenChanged") extFullscreen: boolean = false;
  @Provide('repeatVar') repeat: boolean = false;
  @Provide('pausedVar') paused: boolean = false;
  @Provide('resizeModeVar') resizeMode: string = "none"; /* */
  @Provide('volumeVar') volume: number = PlayConstants.PLAY_PAGE.VOLUME;
  @Provide('rateVar') rate: number = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  @Provide('disableFocusVar') disableFocus: boolean = false; /* RN侧默认是独占模式传递FALSE过来，鸿蒙默认未共享模式*/
  @Provide('preventsDisplaySleepDuringVideoPlaybackVar') preventsDisplaySleepDuringVideoPlayback: boolean =
    true; /* 默认true*/
  @State
  viewWidth: number = 0;
  @State
  viewHeight: number = 0;
  @Provide
  videoHeight: number | string = CommonConstants.FULL_PERCENT;
  @Provide
  videoWidth: number | string = CommonConstants.FULL_PERCENT;
  @Provide
  changedViewWidth: number = 0;
  @Provide
  changedViewHeight: number = 0;
  @Provide
  isUserPaused: boolean = false
  @Provide
  enterPictureInPictureOnLeave: boolean = false
  @Provide
  selectedAudioTrack: RNCSelectTrack = {}
  @Provide
  selectedVideoTrack: RNCSelectTrack = {}
  @Provide
  selectedTextTrack: RNCSelectTrack = {}
  @Provide
  pictureInPicture: boolean = false
  @Provide
  startSecond: number = 0
  @Provide
  preferredForwardBufferDuration: number = 0
  @Provide
  fullscreenAutorotate: boolean = true
  @Provide
  fullscreenOrientation: string = 'all'
  @Provide
  progressUpdateInterval: number = 250.0
  @Provide
  duration: number = 0
  private callbackList: Array<() => void> = []
  private playVideoModel: VideoController = new VideoController();
  private isResume: boolean = false;
  private eventEmitter: RNC.RNCVideo.EventEmitter | undefined = undefined

  aboutToAppear(): void {

    this.eventEmitter = new RNC.RNCVideo.EventEmitter(this.ctx.rnInstance, this.tag)
    this.descriptor = this.ctx.descriptorRegistry.getDescriptor<VideoViewDescriptor>(this.tag);
    this.callbackList.push(this.ctx.descriptorRegistry.subscribeToDescriptorChanges(this.tag,
      (newDescriptor) => {
        this.descriptor = (newDescriptor as VideoViewDescriptor);
        /*------ 当RN侧属性props有更改 -------*/
        this.updatePropFromDesc();
        this.videoWidth = this.viewWidth;

        if (display.getDefaultDisplaySync().orientation == 0 || display.getDefaultDisplaySync().orientation == 2) {
          this.videoWidth = CommonConstants.FULL_PERCENT;
          // this.videoHeight = CommonConstants.FULL_PERCENT;
        }
      }
    ))
    this.playVideoModel.initPlayPageThis(this as IRNCVideo);
    /*------ 初始化 -------*/
    this.updatePropFromDesc();
    this.registerCommandCallback();

    this.callbackList.push(this.ctx.rnInstance.subscribeToLifecycleEvents("BACKGROUND", () => {
      this.paused = true
    })
    )
    this.callbackList.push(this.ctx.rnInstance.subscribeToLifecycleEvents("FOREGROUND", () => {
      if (this.isUserPaused) {
        this.paused = true
      } else {
        this.paused = false
      }
    })
    )
    //注册 navDestinationCallback
    observer.on('navDestinationUpdate', this.navDestinationCallback);
  }

  aboutToDisappear(): void {
    this.cancellationCallback()
    this.playVideoModel.release();
    //销毁 navDestinationCallback
    observer.off('navDestinationUpdate', this.navDestinationCallback);
  }

  registerCommandCallback(): void {
    if (this.ctx) {
      this.callbackList.push(this.ctx.componentCommandReceiver.registerCommandCallback(
        this.tag,
        (command, args: (string | number | boolean)[]) => {
          if (command === RNC_VIDEO_SEEK) {
            this.playVideoModel.setSeekTime(Number(args[0]));
          } else if (command === RNC_VIDEO_CMD_SEEK){
            this.playVideoModel.setSeekTime(Number(args[0]));
          } else if (command === RNC_VIDEO_CMD_VOLUME){
            this.volume = Number(args[0]);
          } else if (command === RNC_VIDEO_CMD_FULLSCREEN){
            this.fullscreen = args[0] as boolean;
          } else if (command === RNC_VIDEO_CMD_STATE) {
            this.playVideoModel.switchPlayOrPause((args[0] as boolean))
          } else if (command === RNC_VIDEO_CMD_PIP_ENTER) {
            this.playVideoModel.startPip();
          } else if (command === RNC_VIDEO_CMD_PIP_EXIT) {
            this.playVideoModel.stopPip();
          }
        }))
    }
  }

  /* 更新属性变更  */
  updatePropFromDesc(): void {
    this.muted = this.descriptor.rawProps['muted']
    this.paused = this.descriptor.rawProps['paused']
    this.isUserPaused = this.descriptor.rawProps['paused']
    this.enterPictureInPictureOnLeave = this.descriptor.rawProps['enterPictureInPictureOnLeave']
    this.pictureInPicture = this.descriptor.rawProps['pictureInPicture']
    this.controls = this.descriptor.rawProps['controls']
    this.fullscreen = this.descriptor.rawProps['fullscreen']
    this.rate = this.descriptor.rawProps['rate'] !== undefined ? this.descriptor.rawProps['rate'] :
    media.PlaybackSpeed.SPEED_FORWARD_1_00_X
    this.resizeMode = this.descriptor.rawProps['resizeMode']
    this.repeat = this.descriptor.rawProps['repeat'] !== undefined ? this.descriptor.rawProps['repeat'] : false;
    this.volume = this.descriptor.rawProps['volume'] !== undefined ? this.descriptor.rawProps['volume'] : 1.0;
    this.volume = this.muted ? 0 : this.volume;
    this.srcParam = this.descriptor.rawProps['src'].uri
    this.disableFocus = this.descriptor.rawProps['disableFocu']
    this.preventsDisplaySleepDuringVideoPlayback = this.descriptor.rawProps['preventsDisplaySleepDuringVideoPlayback']
    this.selectedAudioTrack = this.descriptor.rawProps['selectedAudioTrack']
    this.selectedVideoTrack = this.descriptor.rawProps['selectedVideoTrack']
    this.selectedTextTrack = this.descriptor.rawProps['selectedTextTrack']
    this.preferredForwardBufferDuration = this.descriptor.rawProps['preferredForwardBufferDuration']
    this.fullscreenAutorotate = this.descriptor.rawProps['fullscreenAutorotate'] !== undefined ? this.descriptor.rawProps['fullscreenAutorotate'] : true
    this.fullscreenOrientation = this.descriptor.rawProps['fullscreenOrientation'] !== undefined ? this.descriptor.rawProps['fullscreenOrientation'] : 'all'
    this.progressUpdateInterval = this.descriptor.rawProps['progressUpdateInterval'] !== undefined ? this.descriptor.rawProps['progressUpdateInterval'] : 250.0
    this.viewWidth = this.descriptor.layoutMetrics.frame.size.width
    this.viewHeight = this.descriptor.layoutMetrics.frame.size.height
    this.changedViewWidth = this.viewWidth
    this.changedViewHeight = this.viewHeight
    if (this.resizeMode === ResizeMode.COVER) {
      this.videoHeight = this.viewHeight
    }
  }

  onVideoIdle(): void {
    this.eventEmitter!.emit("videoIdle",{})
  }

  onAudioFocusChanged(hasAudioFocus: boolean){
    this.eventEmitter!.emit("audioFocusChanged",{hasAudioFocus: hasAudioFocus})
  }

  onVideoFullscreenPlayerWillPresent(){
    this.eventEmitter!.emit("videoFullscreenPlayerWillPresent",{})
  }

  onVideoFullscreenPlayerDidPresent(){
    this.eventEmitter!.emit("videoFullscreenPlayerDidPresent",{})
  }

  onVideoFullscreenPlayerWillDismiss(){
    this.eventEmitter!.emit("videoFullscreenPlayerWillDismiss",{})
  }

  onVideoFullscreenPlayerDidDismiss(){
    this.eventEmitter!.emit("videoFullscreenPlayerDidDismiss",{})
  }

  /**
   * @brief onVideoLoad callback
   * @param startSecond 开始播放时间
   * @param length 视频长度
   * @param widthIn 视频width
   * @param heightIn 视频height
   * @param orientationIn 视频方向 对标安卓，通过视频宽高比对判断。
   * @return void
   */
  onVideoLoad(startSecond: number, length: number, widthIn: number, heightIn: number, orientationIn: string): void {
    this.eventEmitter?.emit("videoLoad", {
      currentTime: startSecond,
      duration: length,
      naturalSize: {
        width: widthIn,
        height: heightIn,
        orientation: orientationIn
      },
      audioTracks: this.playVideoModel.audioTracksBeanArr,
      textTracks: null

    });
    this.startSecond = startSecond
    this.duration = length
  }

  onVideoEnd(): void {
    if (this.repeat == undefined || this.repeat == false) {
      this.paused = true
    }
    this.eventEmitter!.emit("videoEnd", {})
  }

  /**
   *
   * @author hukang
   * @date 2023/10/18 11:49
   * @param cUri 当前视频URL
   * @return null
   */
  onVideoLoadStart(cUri: string | media.AVFileDescriptor): void {
    this.eventEmitter!.emit("videoLoadStart", {
      isNetwork: this.descriptor.rawProps['src'].isNetwork,
      type: this.descriptor.rawProps['src'].type,
      uri: cUri.toString()
    });
  }

  onReadyForDisplay(): void {
    this.eventEmitter!.emit("readyForDisplay",{});
  }

  onVideoError(err: string): void {
    this.eventEmitter!.emit("videoError",{error: {errorString:err}});
  }

  onVideoProgress(time: number, _playableDuration: number = 0, _seekableDuration: number = 0): void {
    this.eventEmitter!.emit("videoProgress", {
      currentTime: time,
      playableDuration: _playableDuration,
      seekableDuration: _seekableDuration
    });
    this.startSecond = time
  }

  onVideoBuffer(isBufferingIn: boolean): void {
    this.eventEmitter!.emit("videoBuffer",{isBuffering: isBufferingIn});
  }

  /**
   * 6.13.0该方法废弃,后面考虑兼容问题
   */
  onVideoPlaybackStalled(): void {
    if (this.ctx) {
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE, {
        type: "onPlaybackStalled"
      })
    }
  }

  /**
   * 6.13.0该方法废弃,后面考虑兼容问题
   */
  onVideoPlaybackResume(): void {
    if (this.ctx) {
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE, {
        type: "onPlaybackResume"
      })
    }
  }

  extFullscreenChanged(changedPropertyName: string) {

    if (this.extFullscreen) {
      this.eventEmitter!.emit("videoFullscreenPlayerDidDismiss",{});
      this.extFullscreen = false

    }
  }

  onVideoPlaybackStateChanged(isPlaying: boolean, isSeeking: boolean): void {
    this.eventEmitter!.emit("videoPlaybackStateChanged", { isPlaying: isPlaying, isSeeking: isSeeking });
  }

  onVolumeChange(volume: number): void {
    this.eventEmitter!.emit("volumeChange", { volume: volume });
  }

  onAudioTracks(audioTracks: RNCAudioTracks[]): void {
    this.eventEmitter!.emit("audioTracks", { audioTracks: audioTracks });
  }

  onVideoTracks(videoTracks: RNCVideoTracks[]): void {
    this.eventEmitter!.emit("videoTracks", { videoTracks: videoTracks });
  }

  onTextTracks(textTracks: RNCTextTracks[]): void {
    this.eventEmitter!.emit("textTracks", { textTracks: textTracks });
  }

  onPlaybackRateChange(playbackRate: number): void {
    this.eventEmitter!.emit("playbackRateChange", { playbackRate: playbackRate });
  }

  onPictureInPictureStatusChanged(isActive: boolean): void {
    this.eventEmitter!.emit("pictureInPictureStatusChanged", { isActive: isActive });
  }

  async getFd(): Promise<void> {
    // Logger.debug(TAG, `getFd, ${(this.src)}`);
  }

  onPageHide(): void {
    Logger.debug(TAG, `onPageHide.`);
    this.playVideoModel.pause();
    this.isResume = true;
  }

  cancellationCallback() {
    this.callbackList.forEach(
      callback => {
        callback?.()
      }
    )
  }

  build() {
    Column() {
      RNViewBase({ ctx: this.ctx, tag: this.tag }) {
        PlayPlayer({ playVideoModel: this.playVideoModel, viewWidth: this.viewWidth, viewHeight: this.viewHeight })
          .align(Alignment.Center)
          .height(this.viewHeight)
          .width(this.viewWidth)
      }

    }

  }

  private navDestinationCallback: Callback<NavDestinationInfo> = (info) => {
    let navDestinationInfo = JSON.stringify(info)
    let navDestinationState = JSON.parse(navDestinationInfo) as NavDestinationState
    let state = navDestinationState.state
    let index = navDestinationState.index
    //index 是 Navigation 的页面值  video 当前的页面 == 1, state表示当前页面的状态,ON_HIDDEN 为页面隐藏,ON_SHOWN为页面显示
    if ((index == 1 || index == 0) && state == observer.NavDestinationState.ON_HIDDEN) {
      this.paused = true
    }
    if ((index == 1 || index == 0) && state == observer.NavDestinationState.ON_SHOWN) {
      if (this.isUserPaused) {
        this.paused = true
      } else {
        this.paused = false
      }

    }
  }
}