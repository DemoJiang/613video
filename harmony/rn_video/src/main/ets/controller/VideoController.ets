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

import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import Logger from '../common/util/Logger';
import { AvplayerStatus, CommonConstants, Events, ResizeMode, CurrentTime } from '../common/constants/CommonConstants';
import { PlayConstants } from '../common/constants/PlayConstants';
import { AudioTracksBean, VideoTracksBean } from '../common/bean/AudioTracksBean';
import { IPlayPlayer } from '../view/PlayPlayer';
import { IRNCVideo, RNCAudioTracks, RNCSelectTrack, RNCTextTracks, RNCVideoTracks } from '../RNCVideo';
import Matrix4 from '@ohos.matrix4'
import { display } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'
import { window } from '@kit.ArkUI';

const TAG: string = 'RNOH in ctrl'

@Observed
export class VideoController {
  private avPlayer!: media.AVPlayer;
  private duration: number = 0; /* 视频时间长度 */
  private status: number = 0; /* 这个是自定义的 ，avplayer状态可以获取字符串状态 */
  private loop: boolean = false;
  private index: number = 0;
  private url: string | media.AVFileDescriptor = '';
  private surfaceId: number = 0;
  private playSpeed: number = PlayConstants.PLAY_PAGE.PLAY_SPEED;
  private seekTime: number = PlayConstants.PLAY_PROGRESS.SEEK_TIME;
  private playerThis!: IPlayPlayer;
  private playPageThis!: IRNCVideo;
  private preMutedVolume: number = 1.0;
  private mMuted: boolean = false;
  private flagtd: boolean = false;
  private mVideoBufferedDuration: number =
    0; // 对标安卓，获取缓冲时间， mVideoBufferedDuration = (int) Math.round((double) (mVideoDuration * percent) / 100.0); playableDuration =  mVideoBufferedDuration / 1000.0
  public audioTracksBeanArr?: AudioTracksBean[];
  public videoTracksBeanArr?: VideoTracksBean[];
  private mPreventsDisplaySleepDuringVideoPlayback: boolean = true; /* 默认true*/

  // 记录媒体服务监听的当前播放时间，用于最后刷新 onVideoProgress
  private avplayerCurrentTime: number = 0;

  constructor() {
    this.createAVPlayer();
  }

  startPip(){
    this.playerThis.startPip();
  }

  stopPip(){
    this.playerThis.stopPip();
  }

  /**
   * Creates a videoPlayer object.
   */
  createAVPlayer(): void {
    media.createAVPlayer().then((avPlayer) => {
      if (avPlayer) {
        Logger.debug(TAG, `createAVPlayer isNull: ${avPlayer == null}`);
        this.avPlayer = avPlayer;
        this.bindState();
        this.onAudioFocusChange();
        Logger.debug(TAG, `createAVPlayer after bind`);
        if (this.flagtd) {
          this.flagtd = false;
          if (typeof this.url === "string") {
            this.avPlayer.url = this.url;
          } else {
            this.avPlayer.fdSrc = this.url;
          }
          Logger.debug(TAG, `createAVPlayer need toplay url,after bind:` + this.url);
        } else {
          Logger.debug(TAG, `createAVPlayer noneed toplay url,after bind`);
        }
      } else {
        Logger.error(TAG, '[PlayVideoModel] createAvPlayer fail!');
      }
    });
  }

  /**
   * 监听音频焦点变化
   */
  onAudioFocusChange(){
    this.avPlayer?.on('audioInterrupt', (info: audio.InterruptEvent) => {
      console.info('audioInterrupt called,and InterruptEvent info.eventType:' + info.eventType + ', forceType:' + info.forceType + ', hintType:' + info.hintType)
      if (info.eventType === audio.InterruptType.INTERRUPT_TYPE_BEGIN) {
        this.playPageThis.onAudioFocusChanged(false);
      } else if (info.eventType === audio.InterruptType.INTERRUPT_TYPE_END) {
        this.playPageThis.onAudioFocusChanged(true);
      }
    })
  }

  /**
   * AVPlayer binding event.
   */
  bindState(): void {
    Logger.debug(TAG, `bindState`);
    let lastCalledTime = 0;
    if (this.avPlayer) {
      this.onStateChange();
      this.avPlayer.on(Events.TIME_UPDATE, (time: number) => {
        this.avplayerCurrentTime = time;
        const currentTime = new Date().getTime();
        if(currentTime-lastCalledTime >= this.playerThis.progressUpdateInterval){
          this.onVideoProgress(time);
          lastCalledTime = currentTime;
        }
      });

      this.avPlayer.on(Events.DURATION_UPDATE, (durationA) => {
        Logger.debug(TAG, `durationUpdate success,new duration is=${durationA}`);
        this.duration = durationA == 0 ? 0 : durationA / 1000; // ms->s
      })

      this.avPlayer.on(Events.ERROR, (error) => {
        Logger.debug(TAG, `event error： ${JSON.stringify(error)}`);
        this.playError(JSON.stringify(error));
      })

      this.avPlayer.on(Events.END_OF_STREAM, () => {
        Logger.debug(TAG, 'END_OF_STREAM');
        this.onVideoEnd();
      })

      this.avPlayer.on(Events.RATE_CHANGE, (bitrate:number) => {
        Logger.debug(TAG, 'RATE_CHANGE bitrate: ' + bitrate);
        this.onPlaybackRateChange(bitrate);
      })

      this.avPlayer.on(Events.BUFFERING_UPDATE, (infoType: media.BufferingInfoType, value: number) => {
        /* 播放缓存事件回调方法。BufferingInfoType为BUFFERING_PERCENT或CACHED_DURATION时，value值有效，否则固定为0。 */
        Logger.debug(TAG, 'BUFFERING_UPDATE');
        switch (infoType) {
          case media.BufferingInfoType.BUFFERING_START: // 表示缓存开始，
            this.onVideoPlaybackStalled();
            this.onVideoBuffer(true);
            break;
          case media.BufferingInfoType.BUFFERING_END: // 表示缓存结束，
            this.onVideoPlaybackResume();
            this.onVideoBuffer(false);
            break;
          case media.BufferingInfoType.BUFFERING_PERCENT: // 表示缓存百分比
            /* 此时的value有值，表示缓存百分比*/
            break;
          case media.BufferingInfoType.CACHED_DURATION: // 表示缓存时长，毫秒（ms）。
            Logger.debug(TAG, `onVideoProgress CACHED_DURATION value = ${value}`);
            this.mVideoBufferedDuration = Math.floor(value / 1000); // ms--?s
            break;
          default:
            break;
        }
      })

      this.avPlayer.on(Events.SEEK_DONE, (seekDoneTime: number) => {
        Logger.debug(TAG, `seekDone success,and seek time is: ${seekDoneTime} `);
        this.playPageThis.onVideoSeek(this.avplayerCurrentTime, seekDoneTime);
      })

      this.avPlayer.on(Events.AUDIO_OUTPUT_DEVICE_CHANGE_WITH_INFO, (data: audio.AudioStreamDeviceChangeInfo) => {
        console.info(`音频流输出设备发生变化：${JSON.stringify(data)}`);
        this.playPageThis.onVideoAudioBecomingNoisy();
      });

      this.avPlayer.on(Events.VIDEO_SIZE_CHANGE, (width: number, height: number) => {
        console.info('videoSizeChange called,and width is:' + width + ', height is :' + height);
        this.playPageThis.onVideoAspectRatio(width, height);
      })

      // 2025.10.10 监听字幕变化，当发现外挂字幕变化时，则更新字幕（注意：这里监听的是外挂字幕变化，
      // 可能要先添加外挂字幕文件后，这里才会有触发场景，如果是内置字幕轨，要先选择字幕轨之后，这里才会触发）
      this.avPlayer.on(Events.SUBTITLE_UPDATE, async (info: media.SubtitleInfo) => {
        if (info) {
          let text = (!info.text) ? '' : info.text
          let startTime = (!info.startTime) ? 0 : info.startTime
          let duration = (!info.duration) ? 0 : info.duration
          this.playPageThis.onTextTrackDataChanged(text);
          console.info('subtitleUpdate info: text=' + text + ' startTime=' + startTime +' duration=' + duration)
        } else {
          console.info('subtitleUpdate info is null')
        }
      })
    }
    Logger.debug(TAG, `bindState end`);
  }

  /**
   *
   * @author huKang
   * @param null
   * @return null
   */
  onStateChange(): void {
    this.avPlayer.on(Events.STATE_CHANGE, async (state) => {
      switch (state) {
        case AvplayerStatus.IDLE:
          if (typeof this.url === "string") {
            this.avPlayer.url = this.url;
          } else {
            this.avPlayer.fdSrc = this.url;
          }
          this.onVideoLoadStart(JSON.stringify(this.url));
          this.playPageThis.onVideoIdle();
          break;
        case AvplayerStatus.INITIALIZED:
          if (this.playerThis.disableFocus) {
            let audioRendererInfo = {
              usage: audio.StreamUsage.STREAM_USAGE_GAME,
              rendererFlags: 0
            } as audio.AudioRendererInfo;
            this.avPlayer.audioRendererInfo = audioRendererInfo;
          }
          this.onVideoLoadStart(JSON.stringify(this.url));
          this.avPlayer.surfaceId = String(this.surfaceId);
          this.avPlayer.prepare();
          this.status = CommonConstants.STATUS_INITIALIZED;
          this.watchStatus();
          break;
        case AvplayerStatus.PREPARED:
          this.avPlayer.videoScaleType = 0;
          this.status = CommonConstants.STATUS_PREPARED;
          this.initProps();
          this.watchStatus();
          if (this.playerThis.paused) {
            this.avPlayer.pause();
          } else {
            this.avPlayer.play();
          }
          let startSecond =
            (this.avPlayer.currentTime == CurrentTime.CURRENTTIME_MINUS_ONE ? CurrentTime.CURRENTTIME_ZERO :
            this.avPlayer.currentTime);
          this.onVideoLoad(startSecond);
          this.onReadyForDisplay();
          break;
        case AvplayerStatus.PLAYING:
          this.onReadyForDisplay();
          this.status = CommonConstants.STATUS_START;
          this.watchStatus();
          break;
        case AvplayerStatus.PAUSED:
          this.status = CommonConstants.STATUS_PAUSE;
          this.watchStatus();
          break;
        case AvplayerStatus.COMPLETED:
          //this.duration = PlayConstants.PLAY_PLAYER.DURATION;
          this.status = CommonConstants.STATUS_COMPLETED;
          this.watchStatus();
          /* 20231227 - reset重置是为切换上下一个资源，以及列表序列播放场景下对AVplayer重置，使AVplayer进入idle状态，这里不用 */
          // this.avPlayer.reset();
          break;
        case AvplayerStatus.RELEASED:
          this.avPlayer.release();
          this.status = CommonConstants.STATUS_STOP;
          this.watchStatus();
          break;
        case AvplayerStatus.STOPPED:
          break;
        default:
          break;
      }
      // 监听播放状态 --只关注播放状态，其余状态均按照没有播放状态处理
      if(state === AvplayerStatus.PLAYING){
        this.onVideoPlaybackStateChanged(true, false);
      } else {
        this.onVideoPlaybackStateChanged(false, false);
      }
      // 设置屏幕常亮 --满足播放状态同时外部属性需要设置常亮时保持屏幕常亮，否则false
      if(state === AvplayerStatus.PLAYING && this.mPreventsDisplaySleepDuringVideoPlayback){
        this.setScreenState(true);
      } else {
        this.setScreenState(false);
      }
      // 获取媒体轨道信息 --包括音频、视频、字幕
      this.getTrackDescription();
    });
  }

  setScreenState(isKeepScreenOn: boolean) {
    // 获取当前窗口实例
    window.getLastWindow(getContext(this)).then((curWindow) => {
      // 设置屏幕是否常亮
      curWindow.setWindowKeepScreenOn(isKeepScreenOn, (err: BusinessError) => {
        if (err.code) {
          console.error(`Failed to set the screen. Cause code: ${err.code}, message: ${err.message}`);
          return;
        }
        console.info(`Succeeded in setting the screen ${isKeepScreenOn}.`);
      });
    }).catch((err: string) => {
      console.error(`Failed to obtain the top window.. Cause code:: ${err}`);
    });
  }

  onVideoPlaybackStateChanged(isPlaying: boolean, isSeeking: boolean){
    this.playPageThis.onVideoPlaybackStateChanged(isPlaying, isSeeking);
  }

  onVolumeChange(volume: number): void {
    this.playPageThis.onVolumeChange(volume);
  }

  /**
   * 音频轨道选择
   * @param selectedAudioTrack
   */
  selectAudioTrack(selectedAudioTrack: RNCSelectTrack){
    if (selectedAudioTrack == null || selectedAudioTrack.type == '' || selectedAudioTrack.type == undefined ||
      selectedAudioTrack.value == '' || selectedAudioTrack.value == undefined) {
      return;
    }
    this.setSelectTrack(CommonConstants.TRACK_TYPE_AUDIO, selectedAudioTrack.type, selectedAudioTrack.value)
  }

  /**
   * 视频轨道选择
   * @param selectedVideoTrack
   */
  selectVideoTrack(selectedVideoTrack: RNCSelectTrack){
    if (selectedVideoTrack == null || selectedVideoTrack.type == '' || selectedVideoTrack.type == undefined ||
      selectedVideoTrack.value == '' || selectedVideoTrack.value == undefined) {
      return;
    }
    this.setSelectTrack(CommonConstants.TRACK_TYPE_VIDEO, selectedVideoTrack.type, selectedVideoTrack.value)
  }

  /**
   * 字幕轨道选择
   * @param selectedTextTrack
   */
  selectTextTrack(selectedTextTrack: RNCSelectTrack){
    if (selectedTextTrack == null || selectedTextTrack.type == '' || selectedTextTrack.type == undefined ||
      selectedTextTrack.value == '' || selectedTextTrack.value == undefined) {
      return;
    }
    this.setSelectTrack(CommonConstants.TRACK_TYPE_TEXT, selectedTextTrack.type, selectedTextTrack.value)
  }

  setSelectTrack(trackType: number, filterType: string, filterValue: string){
    /**
     * 1、先获取所有音视频字幕轨道信息；
     * 2、根据轨道信息的track_type先区分音频0、视频1、字幕2轨道；
     * 3、然后再根据入参filterType决定筛选条件
     * 4、然后再根据入参filterValue确定轨道索引
     * 5、最后调用avPlayer.selectTrack(trackId)方法进行音视频轨道切换
     */
    this.avPlayer.getTrackDescription((error: BusinessError, arrList: Array<media.MediaDescription>) => {
      if ((arrList) != null) {
        for (let i = 0; i < arrList.length; i++) {
          // type: 0->音频   1->视频   2->字幕
          let type = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] as number;
          if(type == trackType){
            // 处理相关逻辑
            if(filterType == 'system'){

            } else if(filterType == 'disabled'){

            } else if(filterType == 'title'){

            } else if(filterType == 'language'){
              let language = arrList[i][media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string;
              if (language === filterValue) {
                let trackId = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number;
                this.avPlayer.selectTrack(trackId);
              }
            } else if(filterType == 'index'){
              let trackId = (arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number).toString();
              if (trackId === filterValue) {
                this.avPlayer.selectTrack(parseInt(trackId));
              }
            }
          }
        }
      }
    })
  }

   /**
   * 获取音视频轨道信息
   */
  getTrackDescription(): void {
    if (CommonConstants.GET_AUDIO_TRACKS.indexOf(this.avPlayer.state) === -1) {
      console.error('状态不对，无法获取轨道信息');
      return;
    }

    this.avPlayer.getSelectedTracks().then((arrList: Array<number>) => {
      console.info('Succeeded in getting SelectedTracks:' + arrList.length);
    }).catch((error: BusinessError) => {
      console.error(`Failed to get SelectedTracks, error:${error}`);
    });

    this.avPlayer.getTrackDescription((error: BusinessError, arrList: Array<media.MediaDescription>) => {
      if ((arrList) != null) {
        console.info('getTrackDescription arrList.length: ' + arrList.length)
        let audioTracksArr: RNCAudioTracks[] = [];
        let videoTracksArr: RNCVideoTracks[] = [];
        let textTracksArr: RNCTextTracks[] = [];
        for (let i = 0; i < arrList.length; i++) {
          // type: 0->音频   1->视频   2->字幕
          let type = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_TYPE];
          if(type == 0){
            let audioTrc = new RNCAudioTracks();
            // 暂时屏蔽，鸿蒙API中TrackInfo中的track_id字段和业务中的轨道索引需明确
            //let index = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number;
            let language = arrList[i][media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string;
            let bitrate = arrList[i][media.MediaDescriptionKey.MD_KEY_BITRATE] as number;

            audioTrc.index = i;
            audioTrc.language = language;
            audioTrc.bitrate = bitrate;
            audioTrc.type = "audio_track";
            audioTracksArr.push(audioTrc);

            this.playPageThis.onAudioTracks(audioTracksArr);
            console.info('音频轨道信息 index: ' + i + ", type: " + type + ", language: " + language + ", bitrate: " + bitrate);
          } else if (type == 1){
            let videoTrc = new RNCVideoTracks();
            let tracksId = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number;
            let codec = arrList[i][media.MediaDescriptionKey.MD_KEY_CODEC_MIME] as string;
            let width = arrList[i][media.MediaDescriptionKey.MD_KEY_WIDTH] as number;
            let height = arrList[i][media.MediaDescriptionKey.MD_KEY_HEIGHT] as number;
            let bitrate = arrList[i][media.MediaDescriptionKey.MD_KEY_BITRATE] as number;

            videoTrc.index = i;
            videoTrc.tracksId = tracksId.toString();
            videoTrc.codecs = codec;
            videoTrc.width = width;
            videoTrc.height = height;
            videoTrc.bitrate = bitrate;
            videoTracksArr.push(videoTrc);

            this.playPageThis.onVideoTracks(videoTracksArr);
            console.info('视频轨道信息 tracksId: ' + tracksId + ", codec: " + codec + ", width: " + width + ", height: " + height  + ", bitrate: " + bitrate);
          } else if (type == 2){
            let textTrc = new RNCTextTracks();
            let index = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number;
            let language = arrList[i][media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string;
            let bitrate = arrList[i][media.MediaDescriptionKey.MD_KEY_BITRATE] as number;

            textTrc.index = index;
            textTrc.language = language;
            textTrc.bitrate = bitrate;
            textTrc.type = "text_track";
            textTracksArr.push(textTrc);

            this.playPageThis.onTextTracks(textTracksArr);
            console.info('字幕轨道信息 index: ' + index + ", language: " + language + ", bitrate: " + bitrate);
          }
        }
      } else {
        console.error(`Failed to do getTrackDescription, error:${error}`);
      }
    });
  }

  /**
   * This method is triggered when the video playback page is displayed on the video list page.
   *
   * @param index Video object subscript in the video list.
   * @param url Playback Path.
   * @param surfaceId Indicates the surface ID of the surfaceId.
   */
  firstPlay(index: number, url: string | media.AVFileDescriptor, surfaceId: number): void {
    this.index = index;
    this.url = url;
    this.surfaceId = surfaceId;
    if (this.avPlayer && this.avPlayer.state == AvplayerStatus.IDLE) {
      if (typeof this.url === "string") {
        this.avPlayer.url = this.url;
      } else {
        this.avPlayer.fdSrc = this.url;
      }
    } else {
      this.flagtd = true;
    }
  }

  setBufferDuration(bufferDuration: number){
    let playStrategy: media.PlaybackStrategy = {preferredBufferDuration: bufferDuration};
    this.avPlayer?.setPlaybackStrategy(playStrategy)
  }

  /**
   * Release the video player.
   */
  release(): void {
    this.avPlayer?.release();
  }

  /**
   * Pause Playing.
   */
  pause(): void {
    this.avPlayer?.pause();
  }

  /**
   * Playback mode. The options are as follows: true: playing a single video; false: playing a cyclic video.
   */
  setLoop(): void {
    this.loop = !this.loop;
  }

  transformPlaybackSpeed(rawSpeed: number): number {
    switch(rawSpeed){
      case 0.75:
        return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
      case 1:
        return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
      case 1.25:
        return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
      case 1.75:
        return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
      case 2:
        return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
      case 0.50:
        return media.PlaybackSpeed.SPEED_FORWARD_0_50_X;
      case 1.5:
        return media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
      case 3:
        return media.PlaybackSpeed.SPEED_FORWARD_3_00_X;
      case 0.25:
        return media.PlaybackSpeed.SPEED_FORWARD_0_25_X;
      case 0.125:
        return media.PlaybackSpeed.SPEED_FORWARD_0_125_X;
      default:
        return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    }
  }
  /**
   * Set the playback speed.
   *
   * @param playSpeed Current playback speed.
   */
  setSpeed(playSpeed: number): void {
    if (CommonConstants.OPERATE_STATE.indexOf(this.avPlayer.state) === -1) {
      return;
    }
    if(deviceInfo.sdkApiVersion < 20) {
      const PlaybackSpeed = this.transformPlaybackSpeed(playSpeed)
      this.avPlayer?.setSpeed(PlaybackSpeed);
      return
    }
    this.playSpeed = playSpeed;
    this.avPlayer?.setSpeed(this.playSpeed);
  }

  onPictureInPictureStatusChanged(isActive: boolean): void{
    this.playPageThis.onPictureInPictureStatusChanged(isActive);
  }

  onRestoreUserInterfaceForPictureInPictureStop(): void{
    this.playPageThis.onRestoreUserInterfaceForPictureInPictureStop();
  }

  /**
   * @brief 切换视频播放
   * @return
   */
  switchVideo(newUrl: string | media.AVFileDescriptor): void {
    this.bindState();
    this.url = newUrl;
    if (this.surfaceId == 0 || this.surfaceId == undefined) {
      return;
    }
    if (AvplayerStatus.IDLE == this.avPlayer.state) {
      if (typeof this.url === "string") {
        this.avPlayer.url = this.url;
      } else {
        this.avPlayer.fdSrc = this.url;
      }
    } else {
      this.avPlayer.stop().then(
        ()=>{
          this.avPlayer.reset();
        }
      )

    }
    Logger.debug(TAG, `switchVideo,  state11 ${JSON.stringify(this.avPlayer.state)}`);
  }

  /**
   * Switching Between Video Play and Pause.
   */
  switchPlayOrPause(paused: boolean): void {
    Logger.debug(TAG, `switchPlayOrPause,state out= ${this.avPlayer?.state};paused= ${JSON.stringify(paused)}`);
    if (paused) {
      this.avPlayer?.pause();
    } else {
      this.avPlayer?.play();
    }
  }

  switchRepeat(repeat: boolean): void {
    this.loop = repeat;
    if (this.status === CommonConstants.STATUS_PREPARED ||
      this.status === CommonConstants.STATUS_START ||
      this.status === CommonConstants.STATUS_PAUSE ||
      this.status === CommonConstants.STATUS_COMPLETED
    ) {
      this.avPlayer.loop = this.loop;
      Logger.debug(TAG, `switchRepeat2, ${JSON.stringify(repeat)}`);
    }
  }
  handleBoundaryVolume(volume: number): number {
    if(volume>1){
      return 1
    }else if(volume<0){
      return 0
    }
    return volume
  }

  /**
   * Switching Between Video muted and voice.
   */
  switchMuted(muted: boolean): void {
    this.mMuted = muted;
    let currentVolume = this.playerThis.volume;
    if (muted) {
      currentVolume = 0;
    } else {
      if (this.preMutedVolume > 0) {
        currentVolume = this.preMutedVolume;
      } else {
        currentVolume = 1.0;
      }
    }
    if (this.status === CommonConstants.STATUS_PREPARED ||
      this.status === CommonConstants.STATUS_START ||
      this.status === CommonConstants.STATUS_PAUSE ||
      this.status === CommonConstants.STATUS_COMPLETED
    ) {
      this.avPlayer.setVolume(this.handleBoundaryVolume(currentVolume));
      Logger.debug(TAG, `switchMuted2,currentVolume= ${JSON.stringify(currentVolume)}`);
    }

    this.avPlayer.on('volumeChange', (vol: number) => {
      Logger.debug(TAG, `volumeChange success,and new volume is= ${vol}`);
      this.onVolumeChange(vol);
    })
  }

  onVideoFullscreenPlayerWillPresent(){
    this.playPageThis.onVideoFullscreenPlayerWillPresent();
  }

  onVideoFullscreenPlayerDidPresent(){
    this.playPageThis.onVideoFullscreenPlayerDidPresent();
  }

  onVideoFullscreenPlayerWillDismiss(){
    this.playPageThis.onVideoFullscreenPlayerWillDismiss();
  }

  onVideoFullscreenPlayerDidDismiss(){
    this.playPageThis.onVideoFullscreenPlayerDidDismiss();
  }

  /* 设置播放时屏幕不息屏*/
  setPreventsDisplaySleepDuringVideoPlaybackModifier(preventsDisplaySleepDuringVideoPlayback: boolean): void {
    this.mPreventsDisplaySleepDuringVideoPlayback = preventsDisplaySleepDuringVideoPlayback;
  }

  /**
   * @brief do seek
   * @param value 目标位置，毫秒
   * @return
   */
  setSeekTime(value: number): void {
    Logger.debug(TAG, `setSeekTime== ${JSON.stringify(value)}`);
    this.seekTime = value * 1000;
    Logger.debug(TAG, `setSeekTime== ${this.seekTime}`);
    /* seek 只能在prepared/playing/paused/complete状态调用 毫秒（ms）*/
    if (this.status === CommonConstants.STATUS_PREPARED ||
      this.status === CommonConstants.STATUS_START ||
      this.status === CommonConstants.STATUS_PAUSE ||
      this.status === CommonConstants.STATUS_COMPLETED
    ) {
      this.avPlayer.seek(this.seekTime, media.SeekMode.SEEK_CLOSEST);
    }
  }

  /* 初始化播放器状态 */
  initProps(): void {
    Logger.debug(TAG, `initProps repeat, ${JSON.stringify(this.playerThis.repeat)}`);
    this.avPlayer.loop = this.playerThis.repeat;
    this.mMuted = this.playerThis.muted;
    this.preMutedVolume = this.playerThis.volume;
    /* 更新音量 静音 -20231227 */
    this.switchMuted(this.mMuted);
    this.setSpeed(this.playerThis.rate)
    /* 更新resizeMode */
    this.convertResizeMode(this.playerThis.resizeMode);
  }

  /* 更新属性 */
  updateProp(): void {
    /* 设置 需要特定状态下设置*/
    if (this.avPlayer != null) {
      if(
        this.status === CommonConstants.STATUS_PREPARED ||
        this.status === CommonConstants.STATUS_START ||
        this.status === CommonConstants.STATUS_PAUSE ||
        this.status === CommonConstants.STATUS_COMPLETED
      ){
        let currentVolume = this.playerThis.volume
        if(currentVolume>1){
          currentVolume = 1
        }else if(currentVolume<0){
          currentVolume = 0
        }
        Logger.debug(TAG, `updateProp volume, ${JSON.stringify(this.playerThis.volume)}`);
        this.avPlayer.setVolume(this.handleBoundaryVolume(this.playerThis.volume)); /* 更新音量 */
        this.setSpeed(this.playerThis.rate)
        Logger.debug(TAG, `updateProp resizeMode, ${JSON.stringify(this.playerThis.resizeMode)}`);
        /* 更新 resizeMode */
        this.convertResizeMode(this.playerThis.resizeMode);
      }

      /* 更新音频流类型 */
      this.watchStatus();
    } else {
      Logger.debug(TAG, `updateProp :  ${JSON.stringify(this.avPlayer)}`);
    }

  }

  convertResizeMode(resizeModeB: string): void {
    this.playerThis.videoJustifyContent = FlexAlign.Center;
    this.playerThis.videoAlignItems = HorizontalAlign.Center;
    this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP;
    this.playerThis.matrix = Matrix4.identity();
    switch (resizeModeB) {
      case ResizeMode.NONE:
        this.playerThis.videoJustifyContent = FlexAlign.Start;
        this.playerThis.videoAlignItems = HorizontalAlign.Start;
        this.playerThis.videoWidth = `${px2vp(this.avPlayer.width).toFixed(2)}`;
        this.playerThis.videoHeight = `${px2vp(this.avPlayer.height).toFixed(2)}`;
        break;
      case ResizeMode.CONTAIN: {
        this.playerThis.videoJustifyContent = FlexAlign.Center;
        this.playerThis.videoAlignItems = HorizontalAlign.Center;
        this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP;
        const viewWidth = this.playPageThis.viewWidth
        const viewHeight = this.playPageThis.viewHeight
        const playerWidth = this.avPlayer.width
        const playerHeight = this.avPlayer.height
        if (playerWidth != 0 && playerHeight != 0 && viewHeight != 0) {
          const videoRatio = playerWidth / playerHeight
          const viewRatio = viewWidth / viewHeight
          if (viewRatio > videoRatio) {
            this.playerThis.videoHeight = `${viewHeight}`;
            this.playerThis.videoWidth = `${viewHeight * videoRatio}`;
          } else {
            this.playerThis.videoWidth = `${viewWidth}`;
            this.playerThis.videoHeight = `${viewWidth / videoRatio}`;
          }
        } else {
          Logger.error(TAG, `ResizeMode contain playerWidth or playerHeight or viewHeight = 0 `);
        }
        break;
      }
      case ResizeMode.COVER: // 保持视频宽高比拉伸至填满窗口，内容可能会有裁剪。
        this.playerThis.videoJustifyContent = FlexAlign.Center;
        this.playerThis.videoAlignItems = HorizontalAlign.Center;
        /* 这种模式，取视频最小的边同窗口比进行缩放，最小边填满窗口最小边 */
        this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP;
        if (this.avPlayer.height > this.avPlayer.width) { // 视频为竖屏
          this.playerThis.videoWidth = CommonConstants.FULL_PERCENT; // 竖屏则宽度满屏，进行高度比例放大
          let height = (CommonConstants.ONE_HUNDRED * this.avPlayer.height / this.avPlayer.width).toFixed(2);
          this.playerThis.videoHeight = CommonConstants.FULL_PERCENT;
          this.playerThis.matrix = Matrix4.identity()
            .scale({ x: 1, y: Number.parseFloat(height) / 100 });
        } else {
          this.playerThis.videoHeight = CommonConstants.FULL_PERCENT; // 横屏则高度满屏，进行宽度比例放大
          let width = (CommonConstants.ONE_HUNDRED * this.avPlayer.width / this.avPlayer.height).toFixed(2);
          this.playerThis.videoWidth = CommonConstants.FULL_PERCENT;
          this.playerThis.matrix = Matrix4.identity()
            .scale({ x: Number.parseFloat(width) / 100, y: 1 });
        }
        break;
      case ResizeMode.STRETCH:
        this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
        /* 这里则不分横竖屏，直接视频尺寸等于窗口尺寸*/
        this.playerThis.videoWidth = CommonConstants.FULL_PERCENT;
        this.playerThis.videoHeight = CommonConstants.FULL_PERCENT;
        break;
      default:
        break;
    }
  }

  /**
   * Obtains the current video playing status.
   */
  getStatus(): number {
    return this.status;
  }

  /**
   * Pass this on the playback page.
   *
   * @param playerThis PlayPlayer this object.
   *
   */
  initPlayerThis(playerThis: IPlayPlayer): void {
    if (playerThis == null) {
      Logger.debug(TAG, `initPlayerThis is null .`);
    }
    this.playerThis = playerThis;
  }

  /**
   * Callback function that is called when the media starts loading.
   * setSrc()->mEventEmitter.receiveEvent
   * @param cUri: 当前视频URL
   */
  onVideoLoadStart(cUri: string | media.AVFileDescriptor): void {
    Logger.debug(TAG, `onVideoLoadStart URL: ${cUri}`);
    this.playPageThis.onVideoLoadStart(cUri);
  }

  /**
   * Callback function that is called when the first video frame is ready for display. This is when the poster is removed.
   * @author huKang
   * @date 2023/10/19 17:44
   * @return null
   */
  onReadyForDisplay(): void {
    Logger.debug(TAG, `onReadyForDisplay`);
    this.playPageThis.onReadyForDisplay();
  }

  /**
   * Initialization progress bar.
   * currentTime is ms
   * @param time Current video playback time.
   */
  onVideoProgress(currentTime: number): void {
    let sec = currentTime == 0 ? 0 : currentTime / 1000;
    let playableDuration = this.mVideoBufferedDuration == 0 ? 0 : this.mVideoBufferedDuration;
    let seekableDuration = this.duration == 0 ? 0 : this.duration;
    this.playPageThis.onVideoProgress(sec, playableDuration, seekableDuration);
  }

  /**
   * video completed call
   */
  onVideoEnd(): void {
    this.playPageThis.onVideoEnd();
    // 当时视频播放完成时，最后给播放器一个onVideoProgress回调，用于更新进度条
    this.onVideoProgress(this.avplayerCurrentTime);
  }

  onPlaybackRateChange(rate: number): void {
    this.playPageThis.onPlaybackRateChange(rate);
  }

  /**
   *
   * @param time Current video playback time.
   * getTrackDescription 可以在prepared/playing/paused状态调用。
   */
  onVideoLoad(time: number): void {
    let startSecond = time == 0 ? 0 : Math.floor(time / 1000);
    let orientationIn = "landscape"; // 对标安卓 if (mp.getVideoWidth() > mp.getVideoHeight())
    if (this.avPlayer.width > this.avPlayer.height) {
      orientationIn = "landscape";
    } else {
      orientationIn = "portrait";
    }

    this.avPlayer.getTrackDescription((error, arrList) => {
      if ((arrList) != null) {

        /* 获取到音视频轨道信息后 回传*/
        this.playPageThis.onVideoLoad(startSecond, this.duration, this.avPlayer.width, this.avPlayer.height,
          orientationIn);

      } else {
        Logger.debug(TAG, `getTrackDescription fail, error:${error}`);
      }
    });
  }


  /**
   *
   * @param isBuffering Boolean indicating whether buffering is active
   */
  onVideoBuffer(isBuffering: boolean): void {
    Logger.debug(TAG, `onVideoBuffer out：${JSON.stringify(isBuffering)}`);
    this.playPageThis.onVideoBuffer(isBuffering);
  }

  /**
   * event video onBuffering start
   */
  onVideoPlaybackStalled(): void {
    Logger.debug(TAG, `onVideoPlaybackStalled`);
    this.playPageThis.onVideoPlaybackStalled();
  }

  /**
   * event video onBuffering end
   */
  onVideoPlaybackResume(): void {
    Logger.debug(TAG, `onVideoPlaybackResume`);
    this.playPageThis.onVideoPlaybackResume();
  }

  /**
   * Reset progress bar data.
   * @Deprecated luoxf 0707
   */
  resetProgress(): void {
    this.seekTime = PlayConstants.PLAY_PROGRESS.SEEK_TIME;
  }

  /**
   * Sets whether the screen is a constant based on the playback status.
   * Add avplayer InterruptMode based on the playback status.
   */
  watchStatus(): void {
    /* disableFocus 属性触发 1、屏幕常亮 2、申请音频焦点--鸿蒙系统管理音频焦点，只需注入音频streamtype*/
    // if (this.status === CommonConstants.STATUS_START && this.playerThis.disableFocus) {
    //   globalThis.windowClass.setWindowKeepScreenOn(true);
    // } else {
    //   globalThis.windowClass.setWindowKeepScreenOn(false);
    // }
    /* 设置音频渲染信息，默认值contentType为CONTENT_TYPE_MUSIC，streamUsage为STREAM_USAGE_MEDIA。
       只允许在initialized状态下设置 */
    if (this.status === CommonConstants.STATUS_INITIALIZED) {
      if (this.avPlayer) {
        if (this.playerThis.disableFocus) {
          /* 设置音频流类型为视频，获取视频 音视频打断*/
          let audioRendererInfo = {
            content: audio.ContentType.CONTENT_TYPE_MOVIE,
            usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
            rendererFlags: 0
          } as audio.AudioRendererInfo;
          this.avPlayer.audioRendererInfo = audioRendererInfo;
        }
      }
    } else if (this.status === CommonConstants.STATUS_PREPARED ||
      this.status === CommonConstants.STATUS_START ||
      this.status === CommonConstants.STATUS_PAUSE ||
      this.status === CommonConstants.STATUS_COMPLETED
    ) {
      /* setVolume 只能在prepared/playing/paused/complete状态调用 */
      /* 20231227 - 不重复调用静音设置，在点击变更时再设置，switchMuted */
      // this.switchMuted(this.mMuted);
    }

  }

  /**
   * Obtains the this object of the PlayPage.
   *
   * @param playPageThis This object of PlayPage.
   */
  initPlayPageThis(playPageThis: IRNCVideo): void {
    this.playPageThis = playPageThis;
  }

  /**
   * An error is reported during network video playback.
   */
  playError(errMsg: string): void {
    Logger.debug(TAG, `onVideoError：${JSON.stringify(errMsg)}`);
    if (this.playPageThis) {
      this.playPageThis.onVideoError(errMsg);
    }
  }
}
