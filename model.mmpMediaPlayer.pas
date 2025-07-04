{   MMP: Minimalist Media Player
    Copyright (C) 2021-2099 Baz Cuda
    https://github.com/BazzaCuda/MinimalistMediaPlayerX

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307, USA
}
unit model.mmpMediaPlayer;

interface

uses
  winApi.windows,
  mmpNotify.notices, mmpNotify.notifier, mmpNotify.subscriber;

type
  IMediaPlayer = interface(ISubscribable)
    ['{7666FECA-9BF6-4422-BB68-8EEAF6A6E6F7}']
    function  initMediaPlayer(const aHWND: HWND): boolean;
    function  notify(const aNotice: INotice): INotice;
  end;

function newMediaPlayer: IMediaPlayer;

implementation

uses
  system.sysUtils,
  MPVBasePlayer,
  mmpConsts, mmpFileUtils, mmpFuncProg, mmpGlobalState, mmpTickTimer, mmpUtils,
  model.mmpConfigFile, model.mmpMediaTypes, model.mmpMPVCtrls, model.mmpMPVProperties,
  _debugWindow;

type
  TMediaPlayer = class(TInterfacedObject, IMediaPlayer)
  strict private
    mpv: IMPVBasePlayer;

    FCheckCount:              integer;
    FDimensionsDone:          boolean;
    FIgnoreTicks:             boolean;
    FImageDisplayDurationMs:  integer;
    FMediaType:               TMediaType;
    FMPVScreenshotDirectory:  string;
    FNotifier:                INotifier;
    FVideoHeight:             integer;
    FVideoWidth:              integer;
  private
    procedure   onFileOpen(Sender: TObject; const aFilePath: string);
    procedure   onInitMPV(sender: TObject);
    procedure   onStateChange(cSender: TObject; eState: TMPVPlayerState);

    function    onNotify(const aNotice: INotice):     INotice;
    function    onTickTimer(const aNotice: INotice):  INotice;

    function    openURL(const aURL: string):          boolean;
    function    pausePlay:                            string;
    function    pausePlayImages:                      string;
    function    sendOpInfo(const aOpInfo: string):    boolean;
  protected
    procedure   setPosition(const aValue: integer);
  public
    constructor create;
    destructor  Destroy; override;
    function    imageDisplayDurationMs(const aImageDisplayDurationMs: integer): integer;
    function    initMediaPlayer(const aHWND: HWND):   boolean;
    function    notify(const aNotice: INotice):       INotice;

    // ISubscribable
    function    subscribe(const aSubscriber: ISubscriber): ISubscriber;
    procedure   unsubscribe(const aSubscriber: ISubscriber);
    procedure   unsubscribeAll;

  end;

function newMediaPlayer: IMediaPlayer;
begin
  result := TMediaPlayer.create;
end;

{ TMediaPlayer }

constructor TMediaPlayer.create;
begin
  FNotifier := newNotifier;
  TT.subscribe(newSubscriber(onTickTimer));
  appEvents.subscribe(newSubscriber(onNotify));
end;

destructor TMediaPlayer.Destroy;
begin
  mpv := NIL;
  inherited;
end;

function TMediaPlayer.imageDisplayDurationMs(const aImageDisplayDurationMs: integer): integer;
begin
  case CF.asInteger[CONF_SLIDESHOW_INTERVAL_MS] <> 0 of  TRUE: result := CF.asInteger[CONF_SLIDESHOW_INTERVAL_MS];
                                                        FALSE: result := aImageDisplayDurationMs; end;
  FImageDisplayDurationMs := result;
end;

function TMediaPlayer.initMediaPlayer(const aHWND: HWND): boolean;
begin
  result := FALSE;

  case mpv = NIL of TRUE: mpvCreate(mpv); end;

  case mpv = NIL of TRUE: EXIT; end;

  mpv.OnFileOpen   := onFileOpen;
  mpv.OnStateChged := onStateChange;
  mpv.onInitMPV    := onInitMPV;

  mpvInitPlayer(mpv, aHWND, mmpExePath, mmpExePath);

  mpvGetPropertyString(mpv, 'screenshot-directory', FMPVScreenshotDirectory);
  mmp.cmd(evGSMPVScreenshotDirectory, FMPVScreenshotDirectory);

  var vImageDisplayDuration: string;
  mpvGetPropertyString(mpv, MPV_IMAGE_DISPLAY_DURATION, vImageDisplayDuration);
  vImageDisplayDuration   := mmp.use(vImageDisplayDuration = 'inf', IMAGE_DISPLAY_DURATION_STRING, vImageDisplayDuration); // if there's no image-display-duration= entry at all in mpv.conf, MPV defaults to 5
  FImageDisplayDurationMs := trunc(strToFloatDef(vImageDisplayDuration, IMAGE_DISPLAY_DURATION)) * MILLISECONDS;                  // if the image-display-duration= entry isn't a valid integer

  FImageDisplayDurationMs := imageDisplayDurationMs(FImageDisplayDurationMs); // let the minimalistmediaplayer.conf override mpv.conf

  mmp.cmd(evGSIDDms, FImageDisplayDurationMs);                // stored as milliseconds, 1000 * mpv.conf
  mpvSetPropertyString(mpv, MPV_IMAGE_DISPLAY_DURATION, 'inf');      // get the user's duration setting, if any, then override it. MMP controls how long an image is displayed for, not MPV

  pausePlayImages; // default is paused;

  mpvSetVolume(mpv, CF.asInteger[CONF_VOLUME]);
  mpvSetMute(mpv, CF.asBoolean[CONF_MUTED]);

  result := TRUE;
end;

function TMediaPlayer.notify(const aNotice: INotice): INotice;
begin
  result := onNotify(aNotice);
end;

function TMediaPlayer.onNotify(const aNotice: INotice): INotice;
begin
  result := aNotice;
  case aNotice = NIL of TRUE: EXIT; end;

  case aNotice.event of
    evMPOpenUrl:          openUrl(aNotice.text);
    evMPBrightnessDn:     sendOpInfo(mpvBrightnessDn(mpv));
    evMPBrightnessReset:  sendOpInfo(mpvBrightnessReset(mpv));
    evMPBrightnessUp:     sendOpInfo(mpvBrightnessUp(mpv));
    evMPContrastDn:       sendOpInfo(mpvContrastDn(mpv));
    evMPContrastReset:    sendOpInfo(mpvContrastReset(mpv));
    evMPContrastUp:       sendOpInfo(mpvContrastUp(mpv));
    evMPCycleAudio:       mpvCycleAudio(mpv);
    evMPCycleSubs:        mpvCycleSubs(mpv);
    evMPFrameBackwards:   mpvFrameBackwards(mpv);
    evMPFrameForwards:    mpvFrameForwards(mpv);
    evMPGammaDn:          sendOpInfo(mpvGammaDn(mpv));
    evMPGammaReset:       sendOpInfo(mpvGammaReset(mpv));
    evMPGammaUp:          sendOpInfo(mpvGammaUp(mpv));
    evMPKeepOpen:         mpvSetKeepOpen(mpv, aNotice.tf);
    evMPMuteUnmute:       sendOpInfo(mpvMuteUnmute(mpv));
    evMPNextChapter:      mpvChapterNext(mpv);
    evMPPanDn:            sendOpInfo(mpvPanDn(mpv));
    evMPPanLeft:          sendOpInfo(mpvPanLeft(mpv));
    evMPPanReset:         sendOpInfo(mpvPanReset(mpv));
    evMPPanRight:         sendOpInfo(mpvPanRight(mpv));
    evMPPanUp:            sendOpInfo(mpvPanUp(mpv));
    evMPPause:            mpvPause(mpv);
    evMPPausePlay:        sendOpInfo(pausePlay);
    evMPPrevChapter:      mpvChapterPrev(mpv);
    evMPResetAll:         sendOpInfo(mpvResetAll(mpv));
    evMPResume:           mpvResume(mpv);
    evMPRotateLeft:       sendOpInfo(mpvRotateLeft(mpv));
    evMPRotateReset:      sendOpInfo(mpvRotateReset(mpv));
    evMPRotateRight:      sendOpInfo(mpvRotateRight(mpv));
    evMPSaturationDn:     sendOpInfo(mpvSaturationDn(mpv));
    evMPSaturationReset:  sendOpInfo(mpvSaturationReset(mpv));
    evMPSaturationUp:     sendOpInfo(mpvSaturationUp(mpv));
    evMPScreenshot:       mpvTakeScreenshot(mpv, aNotice.text);
    evMPSeek:             mpvSeek(mpv, aNotice.integer);
    evMPSpeedDn:          sendOpInfo(mpvSpeedDn(mpv));
    evMPSpeedReset:       sendOpInfo(mpvSpeedReset(mpv));
    evMPSpeedUp:          sendOpInfo(mpvSpeedUp(mpv));
    evMPStartOver:        sendOpInfo(mpvStartOver(mpv));
    evMPStop:             mpvStop(mpv);
    evMPToggleRepeat:     sendOpInfo(mpvToggleRepeat(mpv));
    evMPToggleSubtitles:  sendOpInfo(mpvToggleSubtitles(mpv));
    evMPVolDn:            sendOpInfo(mpvVolDown(mpv));
    evMPVolUp:            sendOpInfo(mpvVolUp(mpv));
    evWheelDn:            sendOpInfo(mpvVolDown(mpv));
    evWheelUp:            sendOpInfo(mpvVolUp(mpv));
    evMPZoomIn:           sendOpInfo(mpvZoomIn(mpv));
    evMPZoomOut:          sendOpInfo(mpvZoomOut(mpv));
    evMPZoomReset:        sendOpInfo(mpvZoomReset(mpv));

    evPBClick:            setPosition(aNotice.integer);

//    evMPReqDuration:      aNotice.integer := mpvDuration(mpv); EXPERIMENTAL - always use MI's info
    evMPReqFileName:      aNotice.text    := mpvFileName(mpv);
    evMPReqIDDms:         aNotice.integer := imageDisplayDurationMs(aNotice.integer);
    evMPReqPlaying:       aNotice.tf      := mpvState(mpv) = mpsPlay;
    evMPReqPosition:      aNotice.integer := mpvPosition(mpv);
//    evMPReqPrecisePos:    aNotice.double  := mpvDoublePos(mpv);
    evMPReqVideoHeight:   aNotice.integer := mpvVideoHeight(mpv);
    evMPReqVideoWidth:    aNotice.integer := mpvVideoWidth(mpv);
  end;
end;

procedure TMediaPlayer.onInitMPV(sender: TObject);
//===== THESE CAN ALL BE OVERRIDDEN IN MPV.CONF =====
begin
  mpvSetDefaults(sender as TMPVBasePlayer, mmpExePath);
end;

procedure TMediaPlayer.onFileOpen(Sender: TObject; const aFilePath: string);
begin
  case FNotifier = NIL of TRUE: EXIT; end;
  case FMediaType of mtAudio, mtVideo:  begin
                                          FNotifier.notifySubscribers(mmp.cmd(evMPDuration, mpvDuration(mpv)));
                                          FNotifier.notifySubscribers(mmp.cmd(evMPPosition, 0)); end;end;

  case FMediaType of mtAudio, mtImage: mmp.cmd(evVMResizeWindow); end; // for mtImage, do it in onTickTimer

  var vNotice     := newNotice;
  vNotice.event   := evVMMPOnOpen;
  vNotice.text    := aFilePath;
  vNotice.integer := mpvDuration(mpv);
  FNotifier.notifySubscribers(vNotice);
end;

procedure TMediaPlayer.onStateChange(cSender: TObject; eState: TMPVPlayerState);
// no mpsStop event as yet
var vLoop: string;
begin
//  TDebug.debugEnum<TMPVPlayerState>('eState ' + extractFileName(mpvFileName(mpv)), eState);
  case eState of
    mpsLoading:   ; // FNotifier.notifySubscribers(mmp.cmd(evMPStateLoading)); {not currently used}
    mpsEnd:       begin
                    mpv.getPropertyString('loop-file', vLoop);
                    case vLoop = 'no' of   TRUE: FNotifier.notifySubscribers(mmp.cmd(evMPStateEnd));
                                          FALSE: mpv.seek(0, FALSE); end;end; // Fix --loop-file bug in libMPV-2 with some videos
    mpsPlay:      FNotifier.notifySubscribers(mmp.cmd(evMPStatePlay));
  end;
//  case eState of
//    mpsLoading:   debug('mpsLoading');
//    mpsEnd:       debug('mpsEnd');
//    mpsPlay:      debug('mpsPlay');
//  end;
end;

function TMediaPlayer.onTickTimer(const aNotice: INotice): INotice;
begin
  result := aNotice;
  case FNotifier = NIL  of TRUE: EXIT; end;
  case FIgnoreTicks     of TRUE: EXIT; end;
  case FMediaType       of mtAudio, mtVideo: FNotifier.notifySubscribers(mmp.cmd(evMPPosition, mpvPosition(mpv))); end;

  case FDimensionsDone of FALSE:  begin // only ever false for videos
    inc(FCheckCount);
    FDimensionsDone := FCheckCount >= 3; // that's quite enough of that!
    case (mpvVideoWidth(mpv) <> FVideoWidth) or (mpvVideoHeight(mpv) <> FVideoHeight) of TRUE:  begin
                                                                                                  FVideoWidth     := mpvVideoWidth(mpv);
                                                                                                  FVideoHeight    := mpvVideoHeight(mpv);
                                                                                                  mmp.cmd(evVMResizeWindow); end;end;end;
  end;
end;

function TMediaPlayer.openURL(const aURL: string): boolean;
begin
  result          := FALSE;
  FIgnoreTicks    := TRUE;

  FMediaType      := MT.mediaType(aURL);
  mmp.cmd(evMIGetMediaInfo, aURL, FMediaType);

  mpvSetKeepOpen(mpv, TRUE);  // VITAL! Prevents the slideshow from going haywire - so the next line won't immediately issue an mpsEnd for an image
  mpvOpenFile(mpv, aURL);     // let MPV issue an mpsEnd event for the current file before we change to the media type for the new file

//  FMediaType      := MT.mediaType(aURL);
  FDimensionsDone := FMediaType in [mtAudio, mtImage]; // only applies to video
  case FMediaType of mtAudio, mtVideo: mpvSetKeepOpen(mpv, FALSE); end; // ideally, we only want audio and video files to issue mpsEnd events at end of playback

  FVideoWidth   := 0;
  FVideoHeight  := 0;
  FCheckCount   := 0;
  FIgnoreTicks  := FALSE; // react in onTickTimer

  mmp.cmd(evGSMediaType, FMediaType);
//  mmp.cmd(evMIGetMediaInfo, aURL, FMediaType);
  mmp.cmd(evSTUpdateMetaData);
  mmp.cmd(evMCCaption, mmp.cmd(evPLReqFormattedItem).text);

  mmp.cmd(evGSOpeningURL, FALSE); // for TVM.reInitTimeline - set to TRUE in model.mmpPlaylistUtils.mmpPlayCurrent
  result := TRUE;
end;

function TMediaPlayer.pausePlay: string;
begin
  case FMediaType of
    mtImage:  result := pausePlayImages;
    mtAudio,
    mtVideo:  result := mpvPausePlay(mpv);
  end;
end;

function TMediaPlayer.pausePlayImages: string;
begin
  mmp.cmd(evGSImagesPaused, NOT GS.imagesPaused);

  case GS.imagesPaused of  TRUE: result := 'slideshow paused';
                        FALSE: result := 'slideshow unpaused'; end;
end;

function TMediaPlayer.sendOpInfo(const aOpInfo: string): boolean;
begin
  result := FALSE;
  mmp.cmd(evSTOpInfo, aOpInfo);
  result := TRUE;
end;

procedure TMediaPlayer.setPosition(const aValue: integer);
begin
  mpvSeek(mpv, aValue);
end;

function TMediaPlayer.subscribe(const aSubscriber: ISubscriber): ISubscriber;
begin
  result := FNotifier.subscribe(aSubscriber);
end;

procedure TMediaPlayer.unsubscribe(const aSubscriber: ISubscriber);
begin
  FNotifier.unsubscribe(aSubscriber);
  FNotifier := NIL;
end;

procedure TMediaPlayer.unsubscribeAll;
begin
  FNotifier.unsubscribeAll;
end;

end.
