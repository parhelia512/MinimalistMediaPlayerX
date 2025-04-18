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
unit mmpWindowUtils;

interface

uses
  winApi.windows,
  system.classes, system.SyncObjs,
  mmpNotify.notices, mmpNotify.notifier, mmpNotify.subscriber,
  mmpConsts, mmpGlobalState;

function mmpAdjustAspectRatio (const aWND: HWND; const aHeight: integer): TPoint;
function mmpArrangeAll        (const aWND: HWND): boolean;
function mmpCalcWindowSize    (const aStartingHeight: integer; const bMaxSize: boolean): TPoint;
function mmpCenterWindow      (const aWND: HWND; const aPt: TPoint): boolean;
function mmpGreaterWindow     (const aWND: HWND; aShiftState: TShiftState): integer; overload;
function mmpGreaterWindow     (const aWND: HWND; const aShiftState: TShiftState; const aThumbSize: integer; const aHostType: THostType): boolean; overload;
function mmpPosWinXY          (const aWND: HWND; const x: integer; const y: integer): boolean;
function mmpSetWindowPos      (const aWND: HWND; aPt: TPoint): boolean;
function mmpSetWindowTop      (const aWND: HWND): boolean;
function mmpSetWindowTopmost  (const aWND: HWND): boolean;
function mmpSetWindowSize     (const aWND: HWND; aPt: TPoint): boolean;
function mmpWinXY             (const aWND: HWND): TPoint;

implementation

uses
  winApi.messages,
  system.types,
  mmpDesktopUtils, mmpFuncProg, mmpPostToAllUtils, mmpUtils,
  _debugWindow;

function mmpAdjustAspectRatio(const aWND: HWND; const aHeight: integer): TPoint;
var
  vWidth:  integer;

  MPmediaType:      TMediaType;
  MPvideoWidth:     integer;
  MPvideoHeight:    integer;

  function adjustWidthForAspectRatio: integer;
  begin
    case (MPvideoWidth <= 0) OR (MPvideoHeight <= 0) of TRUE: EXIT; end;
    result := round(aHeight / MPvideoHeight * MPvideoWidth);
  end;

  function getMediaInfo: boolean;
  begin
    result          := FALSE;
    MPmediaType     := GS.mediaType;
    MPvideoWidth    := mmp.cmd(evMPReqVideoWidth).integer;
    MPvideoHeight   := mmp.cmd(evMPReqVideoHeight).integer;
    result          := TRUE;
//    debugFormat('MP.x:%d, MP.y:%d', [MPvideoWidth, MPvideoHeight]);
  end;

begin
//  FUserJ := TRUE;
  result := point(0, 0);
  getMediaInfo;

  vWidth := adjustWidthForAspectRatio;

  vWidth  := vWidth  + 2;   // allow for the mysterious 1-pixel border that Windows insists on drawing around a borderless window

  result.x := vWidth;
  result.y := aHeight + 2;
end;

function mmpCalcWindowSize(const aStartingHeight: integer; const bMaxSize: boolean): TPoint;
{$J+} const vPrevVideoHeight: integer = 0; vPrevImageHeight: integer = 0; {$J-}
var
  vWidth:           integer;
  vHeight:          integer;
  dy:               integer;
  vStartingHeight:  integer;

  MPmediaType:      TMediaType;
  MPvideoWidth:     integer;
  MPvideoHeight:    integer;
  MIhasCoverArt:    boolean;

  function adjustWidthForAspectRatio: integer;
  begin
    case (MPvideoWidth = 0) or (MPvideoHeight = 0) of TRUE: EXIT; end;
    result := trunc(vHeight / MPvideoHeight * MPvideoWidth);
  end;

  function getMediaInfo: boolean;
  begin
    result          := FALSE;
    MPmediaType     := GS.mediaType;
    MPvideoWidth    := mmp.cmd(evMPReqVideoWidth).integer;
    MPvideoHeight   := mmp.cmd(evMPReqVideoHeight).integer;
    MIhasCoverArt   := mmp.cmd(evMIReqHasCoverArt).tf;
    result          := TRUE;
//    debugFormat('getMediaInfo MP.x:%d, MP.y:%d', [MPvideoWidth, MPvideoHeight]);
  end;

  function withinScreenLimits: boolean;
  begin
    var vDelta  := mmpIfThenElse(GS.showingTimeline, GS.widthStreamlist, GS.widthHelp + GS.widthPlaylist); // at least one of widthHelp and widthPlaylist will be zero
    result      := (vWidth + vDelta <= mmpScreenWidth) and (vHeight <= mmpScreenHeight);
  end;

begin
  MPvideoWidth := 0; MPvideoHeight := 0;
  getMediaInfo;

  case MPmediaType of   mtAudio:  begin case MIhasCoverArt of  TRUE: vWidth  := 600;
                                                              FALSE: vWidth  := 600; end;
                                        case MIhasCoverArt of  TRUE: vHeight := 400;
                                                              FALSE: vHeight := UI_DEFAULT_AUDIO_HEIGHT; end;
                                        case MIhasCoverArt of  TRUE: vWidth := adjustWidthForAspectRatio; end;
                                  end;

                        mtVideo:  begin
                                        vStartingHeight := aStartingHeight;
                                        case bMaxSize of TRUE: vStartingHeight := -1; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := vPrevVideoHeight; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := -1; end;

                                        case vStartingHeight = -1 of
                                                                       TRUE: vHeight := mmpScreenHeight - 30;
                                                                      FALSE: vHeight := vStartingHeight; end;

                                        vWidth := adjustWidthForAspectRatio;

                                        while NOT withinScreenLimits do
                                        begin
                                          vHeight := vHeight - 30;
                                          vWidth  := adjustWidthForAspectRatio;
                                        end;

                                        vPrevVideoHeight := vHeight;
                                  end;

                        mtImage:  begin
                                        vStartingHeight := aStartingHeight;
                                        case GS.maxSize of TRUE: vStartingHeight := -1; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := vPrevImageHeight; end;
                                        case (vStartingHeight <> -1) and (vStartingHeight <= UI_DEFAULT_AUDIO_HEIGHT) of TRUE: vStartingHeight := -1; end;

                                        case vStartingHeight = -1 of  TRUE: begin
                                                                              vWidth  := trunc((mmpScreenHeight - 100) * 1.5);
                                                                              vHeight := mmpScreenHeight - 100; end;
                                                                     FALSE: begin
                                                                              vWidth  := trunc(vStartingHeight * 1.5);
                                                                              vHeight := vStartingHeight; end;end;

                                        while NOT withinScreenLimits do
                                        begin
                                          vWidth  := vWidth  - 30;
                                          vHeight := vHeight - 30;
                                        end;

                                        vPrevImageHeight := vHeight;
                                  end;
  end;

  result.x := vWidth;
  result.y := vHeight;
end;

function mmpArrangeAll(const aWND: HWND): boolean;
var
  vCount:             integer;
  vWidth,
  vHeight:            integer;
  vScreenWidth,
  vScreenHeight:      integer;
  vZero:              integer;
  vHMiddle,
  vVMiddle:           integer;
begin
  result := FALSE;
  vCount := mmp.cmd(evPAReqCount).integer;

  mmp.cmd(evGSAutoCenter, vCount = 1);
  case GS.autoCenter of FALSE:  begin
                                  mmp.cmd(evPAPostToEvery, WIN_AUTOCENTER_OFF);
                                  mmp.cmd(evPAPostToEvery, WIN_MAX_SIZE_OFF); end;end;

  var vMsg: TMessage;
  vMsg := default(TMessage);
  case vCount of
    1:       vMsg.WParam := mmpScreenWidth;
    2:       vMsg.WParam := mmpScreenWidth  div 2;
    3, 4:    vMsg.LParam := mmpScreenHeight div 2;
    else     vMsg.WParam := mmpScreenWidth  div vCount;
  end;
  vMsg.msg := WIN_RESIZE;
  mmp.cmd(evPAPostToEveryEx, vMsg);

  mmpProcessMessages; // make sure this window has resized before continuing

  mmpWndWidthHeight(aWND, vWidth, vHeight);
  vScreenWidth  := mmpScreenWidth;
  vScreenHeight := mmpScreenHeight;
  vHMiddle      := vScreenWidth   div 2;
  vVMiddle      := vScreenHeight  div 2;
  vZero         := vHMiddle - vWidth;

  vCount    := mmp.cmd(evPAReqCount).integer;
  var vHWND := 0;

  case vCount = 2 of TRUE: begin
                             mmpPosWinXY(PA[1], vZero,    (vScreenHeight - vHeight) div 2);
                             mmpPosWinXY(PA[2], vHMiddle, (vScreenHeight - vHeight) div 2);
                             case mmpOffScreen(PA[1]) of TRUE: mmpPosWinXY(PA[1], vZero,    0); end;
                             case mmpOffScreen(PA[2]) of TRUE: mmpPosWinXY(PA[2], vHMiddle, 0); end;
                             vHWND := PA[1];
                           end;end;

  case vCount in [3, 4] of TRUE: begin
                             mmpPosWinXY(PA[1], vZero,     0 + 40);
                             mmpPosWinXY(PA[2], vHMiddle,  0 + 40); end;end;

  case vCount = 3 of TRUE: mmpPosWinXY(PA[3], vHMiddle - (vWidth div 2), vHeight + 40); end;

  case vCount = 4 of TRUE: begin
                              mmpPosWinXY(PA[3], vZero,     vHeight + 40);
                              mmpPosWinXY(PA[4], vHMiddle,  vHeight + 40); end;end;

  case vCount > 4 of TRUE: for var i := 1 to vCount do mmpPosWinXY(PA[i], ((mmpScreenWidth div vCount) * (i - 1)), 100); end;

  case vHWND <> 0 of TRUE: begin mmpDelay(100); mmpPosWinXY(vHWND, mmpScreenCentre - vWidth, mmpWinXY(vHWND).Y); end;end; // hack for tall, narrow, TikTok-type windows
  result := TRUE;
end;

function mmpCenterWindow(const aWND: HWND; const aPt: TPoint): boolean;
// aPt is optional and provides the calculated dimensions that a window is going to have
var
  vR:     TRect;
  vHPos:  integer;
  vVPos:  integer;

  function alreadyCentred: boolean;
  begin
    result      := FALSE;
    var vDelta  := mmpIfThenElse(GS.showingTimeline, GS.widthStreamlist, GS.widthHelp + GS.widthPlaylist); // one of either widthHelp or widthPlaylist will be zero
    vHPos       := (mmpScreenWidth  - vR.width - vDelta)  div 2;
    vVPos       := (mmpScreenHeight - vR.height)          div 2;
    result      := (vR.left = vHPos) and (vR.top = vVPos);
  end;

begin
  result := FALSE;
  getWindowRect(aWND, vR);

  case (aPt.x <> 0) and (aPt.y <> 0) of  TRUE:  begin // override the current dimensions with those provided
                                                  vR.width  := aPt.x;
                                                  vR.height := aPt.y; end;end;


  case alreadyCentred of TRUE: EXIT; end;

  case (vHPos > 0) and (vVPos > 0) of TRUE: mmpSetWindowPos(aWND, point(vHPos, vVPos)); end;

  mmp.cmd(evGSAutoCenter, TRUE);
  result := TRUE;
end;

function mmpGreaterWindow(const aWND: HWND; aShiftState: TShiftState): integer;
var
  vR: TRect;
begin
  getWindowRect(aWND, vR);

  GS.notify(newNotice(evGSMaxSize, FALSE)); // pressing [M] reinstates maxSize

  result := mmp.use(ssCtrl in aShiftState, vR.height - 30, vR.height + 30);
end;

function mmpGreaterWindow(const aWND: HWND; const aShiftState: TShiftState; const aThumbSize: integer; const aHostType: THostType): boolean;
var
  dx:   integer;
  dy:   integer;
  newW: integer;
  newH: integer;
  vR:   TRect;

  function calcDeltas: boolean;
  begin
    case aHostType of
      htMPVHost:    begin
                      dx := 50;
                      dy := 30;
                    end;
      htThumbsHost: begin
                      dx := aThumbSize + THUMB_MARGIN;
                      dy := aThumbSize + THUMB_MARGIN;
                    end;
    end;
  end;

  function checkDesktop: boolean;
  begin
    case ssCtrl in aShiftState of  TRUE:  begin
                                            case newW - dx < dx of TRUE: dx := 0; end;
                                            case newH - dy < dy of TRUE: dy := 0; end;end;
                                  FALSE:  begin
                                            case newW + dx > mmpScreenWidth  of TRUE: dx := 0; end;
                                            case newH + dy > mmpScreenHeight of TRUE: dy := 0; end;end;end;
  end;

  function calcDimensions: boolean;
  begin
    case ssCtrl in aShiftState of
      TRUE: begin
              newW := newW - dx;
              newH := newH - dy;
            end;
     FALSE: begin
              newW := newW + dx;
              newH := newH + dy;
            end;
    end;
  end;

begin
  getWindowRect(aWND, vR);
  newW := vR.Width;
  newH := vR.height;

  calcDeltas;
  checkDesktop;
  calcDimensions; // do what the user requested

  mmpSetWindowSize(aWND, point(newW, newH)); // resize the window
end;

function mmpPosWinXY(const aWND: HWND; const x: integer; const y: integer): boolean;
begin
  result := FALSE;
  mmpSetWindowPos(aWND, point(x, y));
  result := TRUE;
end;

function mmpSetWindowPos(const aWND: HWND; aPt: TPoint): boolean;
begin
  result := FALSE;
  setWindowPos(aWND, HWND_TOP, aPt.x, aPt.y, 0, 0, SWP_NOSIZE);
  result := TRUE;
end;

function mmpSetWindowSize(const aWND: HWND; aPt: TPoint): boolean;
begin
  result := FALSE;
  setWindowPos(aWND, HWND_TOP, 0, 0, aPt.x, aPt.y, SWP_NOMOVE);
  result := TRUE;
end;

function mmpSetWindowTop(const aWND: HWND): boolean;
begin
  setWindowPos(aWND, HWND_TOP, 0, 0, 0, 0, SWP_NOSIZE + SWP_NOMOVE);
end;

function mmpSetWindowTopmost(const aWND: HWND): boolean;
begin
  setWindowPos(aWND, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE + SWP_NOMOVE);
end;

function mmpWinXY(const aWND: HWND): TPoint;
var vR: TRect;
begin
  getWindowRect(aWnd, vR);
  result := vR.location;
end;

end.
