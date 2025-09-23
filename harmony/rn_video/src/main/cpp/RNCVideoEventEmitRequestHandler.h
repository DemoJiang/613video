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
#pragma once
#include "RNOH/ArkJS.h"
#include "RNOH/EventEmitRequestHandler.h"
#include "EventEmitters.h"

#include <glog/logging.h>
#include "folly/json.h"

using namespace facebook;
namespace rnoh {

enum RNCVideoEventType {
    RNC_VIDEO_LOAD = 0,
    RNC_VIDEO_LOAD_START = 1,
    RNC_VIDEO_BUFFER = 2,
    RNC_VIDEO_ERROR = 3,
    RNC_VIDEO_PROGRESS = 4,
    RNC_VIDEO_BAND_WIDTH_UPDATE = 5,
    RNC_VIDEO_SEEK = 6,
    RNC_VIDEO_END = 7,
    RNC_VIDEO_PLAYBACK_STALLED = 8,
    RNC_VIDEO_PLAYBACK_RESUME = 9,
    RNC_VIDEO_READY_FOR_DISPLAY = 10,
    RNC_VIDEO_FULLSCREEN_PLAYER_DIDDISMISS = 11,
    RNC_VIDEO_PLAYBACK_STATE_CHANGED = 12,
    RNC_VIDEO_VOLUME_CHANGE = 13,
    RNC_VIDEO_TRACK_VIDEO = 14,
    RNC_VIDEO_TRACK_AUDIO = 15,
    RNC_VIDEO_TRACK_TEXT = 16,
    RNC_VIDEO_RATE_CHANGE = 17,
    RNC_VIDEO_PIP_CHANGE = 18,
};

RNCVideoEventType getRNCVideoEventType(ArkJS &arkJs, napi_value eventObject)
{
    auto eventType = arkJs.getString(arkJs.getObjectProperty(eventObject, "type"));
    if(eventType == "onVideoLoad"){
        return RNCVideoEventType::RNC_VIDEO_LOAD;
    }else if (eventType == "onVideoLoadStart"){
        return RNCVideoEventType::RNC_VIDEO_LOAD_START;
    }else if (eventType == "onVideoBuffer"){
        return RNCVideoEventType::RNC_VIDEO_BUFFER;
    }else if (eventType == "onVideoError"){
        return RNCVideoEventType::RNC_VIDEO_ERROR;
    }else if (eventType == "onVideoProgress"){
        return RNCVideoEventType::RNC_VIDEO_PROGRESS;
    }else if (eventType == "onBandwidthUpdate"){
        return RNCVideoEventType::RNC_VIDEO_BAND_WIDTH_UPDATE;
    }else if (eventType == "onVideoSeek"){
        return RNCVideoEventType::RNC_VIDEO_SEEK;
    }else if (eventType == "onVideoEnd"){
        return RNCVideoEventType::RNC_VIDEO_END;
    }else if (eventType == "onPlaybackStalled"){
        return RNCVideoEventType::RNC_VIDEO_PLAYBACK_STALLED;
    }else if (eventType == "onPlaybackResume"){
        return RNCVideoEventType::RNC_VIDEO_PLAYBACK_RESUME;
    }else if (eventType == "onReadyForDisplay"){
        return RNCVideoEventType::RNC_VIDEO_READY_FOR_DISPLAY;
    }else if (eventType == "videoFullscreenPlayerDidDismiss"){
        return RNCVideoEventType::RNC_VIDEO_FULLSCREEN_PLAYER_DIDDISMISS;
    }else if (eventType == "onVideoPlaybackStateChanged"){
        return RNCVideoEventType::RNC_VIDEO_PLAYBACK_STATE_CHANGED;
    }else if (eventType == "onVolumeChange"){
        return RNCVideoEventType::RNC_VIDEO_VOLUME_CHANGE;
    }else if (eventType == "onVideoTracks"){
        return RNCVideoEventType::RNC_VIDEO_TRACK_VIDEO;
    }else if (eventType == "onAudioTracks"){
        return RNCVideoEventType::RNC_VIDEO_TRACK_AUDIO;
    }else if (eventType == "onTextTracks"){
        return RNCVideoEventType::RNC_VIDEO_TRACK_TEXT;
    }else if (eventType == "onPlaybackRateChange"){
        return RNCVideoEventType::RNC_VIDEO_RATE_CHANGE;
    }else if (eventType == "onPictureInPictureStatusChanged"){
        return RNCVideoEventType::RNC_VIDEO_PIP_CHANGE;
    }
    else {
        throw std::runtime_error("Unknown Page event type");
    }
}

class RNCVideoEventEmitRequestHandler : public EventEmitRequestHandler {
public:
    void handleEvent(EventEmitRequestHandler::Context const &ctx) override
    {
        if(ctx.eventName != "RNCVideo") {
            return;
        }
        ArkJS arkJs(ctx.env);
        auto eventEmitter = ctx.shadowViewRegistry->getEventEmitter<react::RNCVideoEventEmitter>(ctx.tag);
        if(eventEmitter == nullptr) {
            return;
        }
        
        switch (getRNCVideoEventType(arkJs,ctx.payload)){
            case RNCVideoEventType::RNC_VIDEO_LOAD: {
                float currentPosition = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "currentPosition"));
                float duration = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "duration"));
                LOG(INFO) << "RNCVideoEventEmitRequestHandler RNC_VIDEO_LOAD float currentTime: " << currentPosition ;
                RNOHNapiObject naturalSizeObject = arkJs.getObject(arkJs.getObjectProperty(ctx.payload, "naturalSize"));
                
                float width = (float)arkJs.getDouble(naturalSizeObject.getProperty("width"));
                float height = (float)arkJs.getDouble(naturalSizeObject.getProperty("height"));
                std::string orientation = arkJs.getString(naturalSizeObject.getProperty("orientation"));
                
                LOG(INFO) << "RNCVideoEventEmitRequestHandler RNC_VIDEO_LOAD naturalSizeObject width : " << width ;
                
                facebook::react::RNCVideoEventEmitter::OnVideoLoadNaturalSize naturalSize {
                    width, height, orientation
                };
                react::RNCVideoEventEmitter::OnVideoLoad event{currentPosition, duration, naturalSize};
               
                auto audioTracks = arkJs.getObjectProperty(ctx.payload, "audioTracks");
                if(arkJs.getType(audioTracks) == napi_object) { // FixMe: 此处应该判断你是否是数组
                    int len = arkJs.getArrayLength(audioTracks);
                    for (int i = 0; i < len ; ++i) {
                        auto subAudioTracks = arkJs.getArrayElement(audioTracks, i);
                        auto _subAudioTracks = arkJs.getObject(subAudioTracks);
                        int index = (int)arkJs.getDouble(_subAudioTracks.getProperty("index"));
                        std::string title = arkJs.getString(_subAudioTracks.getProperty("title"));
                        std::string language = arkJs.getString(_subAudioTracks.getProperty("language"));
                        std::string type = arkJs.getString(_subAudioTracks.getProperty("type"));
                        event.audioTracks.push_back({index, title, language, type});
                    }
                }
                
                 auto videoTracks = arkJs.getObjectProperty(ctx.payload, "videoTracks");
                   if(arkJs.getType(videoTracks) == napi_object) { // FixMe: 此处应该判断你是否是数组
                    int len = arkJs.getArrayLength(videoTracks);
                    for (int i = 0; i < len ; ++i) {
                        auto subVideoTracks = arkJs.getArrayElement(videoTracks, i);
                        auto _subVideoTracks = arkJs.getObject(subVideoTracks);
                        int trackId = (int)arkJs.getDouble(_subVideoTracks.getProperty("trackId"));
                        float bitrate = (float)arkJs.getDouble(_subVideoTracks.getProperty("bitrate"));
                        std::string codecs = arkJs.getString(_subVideoTracks.getProperty("codecs"));
                        float height = (float)arkJs.getDouble(_subVideoTracks.getProperty("height"));
                        float width = (float)arkJs.getDouble(_subVideoTracks.getProperty("width"));
                        event.videoTracks.push_back({trackId, bitrate, codecs, height, width});
                    }
                }
                
                eventEmitter->onVideoLoad(event);
                break;
            }
            
            case RNCVideoEventType::RNC_VIDEO_LOAD_START: {
                bool isNetwork = arkJs.getBoolean(arkJs.getObjectProperty(ctx.payload, "isNetwork"));
                std::string type = arkJs.getString(arkJs.getObjectProperty(ctx.payload, "videoType"));
                std::string uri = arkJs.getString(arkJs.getObjectProperty(ctx.payload, "uri"));
                
                react::RNCVideoEventEmitter::OnVideoLoadStart event{isNetwork, type, uri};
                eventEmitter->onVideoLoadStart(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_BUFFER: {
                bool isBuffering = arkJs.getBoolean(arkJs.getObjectProperty(ctx.payload, "isBuffering"));
                
                react::RNCVideoEventEmitter::OnVideoBuffer event{isBuffering};
                eventEmitter->onVideoBuffer(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_ERROR: {
                std::string error = arkJs.getString(arkJs.getObjectProperty(ctx.payload, "error"));
                
                react::RNCVideoEventEmitter::OnVideoError event{ error };
                eventEmitter->onVideoError(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_END: {
                react::RNCVideoEventEmitter::OnVideoEnd event{ };
                eventEmitter->onVideoEnd(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_PROGRESS: {
                float currentTime = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "currentTime"));
                float playableDuration = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "playableDuration"));
                float seekableDuration = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "seekableDuration"));
                
                react::RNCVideoEventEmitter::OnVideoProgress event{ currentTime, playableDuration, seekableDuration };
                eventEmitter->onVideoProgress(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_PLAYBACK_STALLED : {
                react::RNCVideoEventEmitter::OnPlaybackStalled event{};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler OnPlaybackStalled:" ;
                eventEmitter->onPlaybackStalled(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_PLAYBACK_RESUME: {
                react::RNCVideoEventEmitter::OnPlaybackResume event{};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler OnPlaybackResume:" ;
                eventEmitter->onPlaybackResume(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_READY_FOR_DISPLAY: 
            {
                react::RNCVideoEventEmitter::OnReadyForDisplay event{};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler OnReadyForDisplay:" ;
                eventEmitter->onReadyForDisplay(event);
                break;
            }
             case RNCVideoEventType::RNC_VIDEO_FULLSCREEN_PLAYER_DIDDISMISS: 
            {
                react::RNCVideoEventEmitter::OnVideoFullscreenPlayerDidDismiss event{};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler onVideoFullscreenPlayerDidDismiss:" ;
                eventEmitter->onVideoFullscreenPlayerDidDismiss(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_PLAYBACK_STATE_CHANGED : {
                bool isPlaying = arkJs.getBoolean(arkJs.getObjectProperty(ctx.payload, "isPlaying"));
                bool isSeeking = arkJs.getBoolean(arkJs.getObjectProperty(ctx.payload, "isSeeking"));
                react::RNCVideoEventEmitter::OnVideoPlaybackStateChanged event{isPlaying, isSeeking};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler OnVideoPlaybackStateChanged:" ;
                eventEmitter->onVideoPlaybackStateChanged(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_VOLUME_CHANGE : {
                float volume = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "volume"));
                react::RNCVideoEventEmitter::OnVolumeChange event{volume};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler OnVolumeChange:" ;
                eventEmitter->onVolumeChange(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_RATE_CHANGE : {
                float playbackRate = (float)arkJs.getDouble(arkJs.getObjectProperty(ctx.payload, "playbackRate"));
                react::RNCVideoEventEmitter::OnPlaybackRateChange event{playbackRate};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler OnPlaybackRateChange:" ;
                eventEmitter->onPlaybackRateChange(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_PIP_CHANGE : {
                bool isActive = arkJs.getBoolean(arkJs.getObjectProperty(ctx.payload, "isActive"));
                react::RNCVideoEventEmitter::OnPictureInPictureStatusChanged event{isActive};
                LOG(INFO) << "RNCVideoEventEmitRequestHandler onPictureInPictureStatusChanged:" ;
                eventEmitter->onPictureInPictureStatusChanged(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_TRACK_VIDEO : {
                react::RNCVideoEventEmitter::OnVideoTracks event{};
                auto videoTracks = arkJs.getObjectProperty(ctx.payload, "videoTracks");
                   if(arkJs.getType(videoTracks) == napi_object) { // FixMe: 此处应该判断你是否是数组
                    int len = arkJs.getArrayLength(videoTracks);
                    for (int i = 0; i < len ; ++i) {
                        auto subVideoTracks = arkJs.getArrayElement(videoTracks, i);
                        auto _subVideoTracks = arkJs.getObject(subVideoTracks);
                        int index = (int)arkJs.getInteger(_subVideoTracks.getProperty("index"));
                        std::string trackId = arkJs.getString(_subVideoTracks.getProperty("tracksId"));
                        std::string codecs = arkJs.getString(_subVideoTracks.getProperty("codecs"));
                        float width = (float)arkJs.getDouble(_subVideoTracks.getProperty("width"));
                        float height = (float)arkJs.getDouble(_subVideoTracks.getProperty("height"));
                        float bitrate = (float)arkJs.getDouble(_subVideoTracks.getProperty("bitrate"));
                        bool selected = arkJs.getBoolean(_subVideoTracks.getProperty("selected"));
                        event.videoTracks.push_back({index,trackId, codecs,width, height,bitrate,selected});
                    }
                }
                LOG(INFO) << "RNCVideoEventEmitRequestHandler onVideoTracks:" ;
                eventEmitter->onVideoTracks(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_TRACK_AUDIO : {
                react::RNCVideoEventEmitter::OnAudioTracks event{};
                auto audioTracks = arkJs.getObjectProperty(ctx.payload, "audioTracks");
                   if(arkJs.getType(audioTracks) == napi_object) { // FixMe: 此处应该判断你是否是数组
                    int len = arkJs.getArrayLength(audioTracks);
                    for (int i = 0; i < len ; ++i) {
                        auto subAudioTracks = arkJs.getArrayElement(audioTracks, i);
                        auto _subAudioTracks = arkJs.getObject(subAudioTracks);
                        int index = (int)arkJs.getInteger(_subAudioTracks.getProperty("index"));
                        std::string title = arkJs.getString(_subAudioTracks.getProperty("title"));
                        std::string language = arkJs.getString(_subAudioTracks.getProperty("language"));
                        float bitrate = (float)arkJs.getDouble(_subAudioTracks.getProperty("bitrate"));
                        std::string type = arkJs.getString(_subAudioTracks.getProperty("type"));
                        bool selected = arkJs.getBoolean(_subAudioTracks.getProperty("selected"));
                        event.audioTracks.push_back({index,title, language,bitrate, type,selected});
                    }
                }
                LOG(INFO) << "RNCVideoEventEmitRequestHandler onAudioTracks:" ;
                eventEmitter->onAudioTracks(event);
                break;
            }
            case RNCVideoEventType::RNC_VIDEO_TRACK_TEXT : {
                react::RNCVideoEventEmitter::OnTextTracks event{};
                auto textTracks = arkJs.getObjectProperty(ctx.payload, "textTracks");
                   if(arkJs.getType(textTracks) == napi_object) { // FixMe: 此处应该判断你是否是数组
                    int len = arkJs.getArrayLength(textTracks);
                    for (int i = 0; i < len ; ++i) {
                        auto subTextsTracks = arkJs.getArrayElement(textTracks, i);
                        auto _subTextsTracks = arkJs.getObject(subTextsTracks);
                        int index = (int)arkJs.getInteger(_subTextsTracks.getProperty("index"));
                        std::string title = arkJs.getString(_subTextsTracks.getProperty("title"));
                        std::string language = arkJs.getString(_subTextsTracks.getProperty("language"));
                        std::string type = arkJs.getString(_subTextsTracks.getProperty("type"));
                        bool selected = arkJs.getBoolean(_subTextsTracks.getProperty("selected"));
                        event.textTracks.push_back({index,title,language,type,selected});
                    }
                }
                LOG(INFO) << "RNCVideoEventEmitRequestHandler onAudioTracks:" ;
                eventEmitter->onTextTracks(event);
                break;
            }
            default:
                break;
        }
    };
};
} //namespace rnoh