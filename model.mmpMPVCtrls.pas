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
unit model.mmpMPVCtrls;

interface

uses
  winApi.windows,
  system.classes,
  MPVBasePlayer, MPVConst,
  model.mmpMPVFormatting;

function mpvCreate    (var mpv: TMPVBasePlayer): boolean;
function mpvInitPlayer(const mpv: TMPVBasePlayer; const sWinHandle: HWND; const sScrShotDir: string; const sConfigDir: string; const sLogFile: string = ''; fEventWait: double = 0.5): TMPVErrorCode;
function mpvOpenFile  (const mpv: TMPVBasePlayer; aURL: string): TMPVErrorCode;

function mpvBrightnessDn    (const mpv: TMPVBasePlayer): string;
function mpvBrightnessReset (const mpv: TMPVBasePlayer): string;
function mpvBrightnessUp    (const mpv: TMPVBasePlayer): string;
function mpvChapterNext     (const mpv: TMPVBasePlayer): boolean;
function mpvChapterPrev     (const mpv: TMPVBasePlayer): boolean;
function mpvContrastDn      (const mpv: TMPVBasePlayer): string;
function mpvContrastReset   (const mpv: TMPVBasePlayer): string;
function mpvContrastUp      (const mpv: TMPVBasePlayer): string;
function mpvCycleAudio      (const mpv: TMPVBasePlayer): boolean;
function mpvCycleSubs       (const mpv: TMPVBasePlayer): boolean;
function mpvFrameBackwards  (const mpv: TMPVBasePlayer): boolean;
function mpvFrameForwards   (const mpv: TMPVBasePlayer): boolean;
function mpvGammaDn         (const mpv: TMPVBasePlayer): string;
function mpvGammaReset      (const mpv: TMPVBasePlayer): string;
function mpvGammaUp         (const mpv: TMPVBasePlayer): string;
function mpvMute            (const mpv: TMPVBasePlayer; const aValue: boolean): string;
function mpvMuteUnmute      (const mpv: TMPVBasePlayer): string;
function mpvPanDn           (const mpv: TMPVBasePlayer): string;
function mpvPanLeft         (const mpv: TMPVBasePlayer): string;
function mpvPanReset        (const mpv: TMPVBasePlayer): string;
function mpvPanRight        (const mpv: TMPVBasePlayer): string;
function mpvPanUp           (const mpv: TMPVBasePlayer): string;
function mpvPause           (const mpv: TMPVBasePlayer): boolean;
function mpvPausePlay       (const mpv: TMPVBasePlayer): string;
function mpvResetAll        (const mpv: TMPVBasePlayer): string;
function mpvResume          (const mpv: TMPVBasePlayer): boolean;
function mpvRotateLeft      (const mpv: TMPVBasePlayer): string;
function mpvRotateReset     (const mpv: TMPVBasePlayer): string;
function mpvRotateRight     (const mpv: TMPVBasePlayer): string;
function mpvSaturationDn    (const mpv: TMPVBasePlayer): string;
function mpvSaturationReset (const mpv: TMPVBasePlayer): string;
function mpvSaturationUp    (const mpv: TMPVBasePlayer): string;
function mpvSeek            (const mpv: TMPVBasePlayer; const aValue: integer): boolean;
function mpvSpeedDn         (const mpv: TMPVBasePlayer): string;
function mpvSpeedReset      (const mpv: TMPVBasePlayer): string;
function mpvSpeedUp         (const mpv: TMPVBasePlayer): string;
function mpvStartOver       (const mpv: TMPVBasePlayer): string;
function mpvStop            (const mpv: TMPVBasePlayer): boolean;
function mpvTakeScreenshot  (const mpv: TMPVBasePlayer; const aFolder: string): boolean;
function mpvToggleRepeat    (const mpv: TMPVBasePlayer): string;
function mpvToggleSubtitles (const mpv: TMPVBasePlayer): string;
function mpvVolDown         (const mpv: TMPVBasePlayer): string;
function mpvVolUp           (const mpv: TMPVBasePlayer): string;
function mpvZoomIn          (const mpv: TMPVBasePlayer): string;
function mpvZoomOut         (const mpv: TMPVBasePlayer): string;
function mpvZoomReset       (const mpv: TMPVBasePlayer): string;

implementation

uses
  system.sysUtils,
  vcl.forms,
  mmpConsts, mmpKeyboardUtils,
  model.mmpConfigFile, model.mmpMPVProperties,
  _debugWindow;

function mpvCreate(var mpv: TMPVBasePlayer): boolean;
begin
  mpv    := TMPVBasePlayer.create;
  result := mpv <> NIL;
end;

function mpvInitPlayer(const mpv: TMPVBasePlayer; const sWinHandle: HWND; const sScrShotDir: string; const sConfigDir: string; const sLogFile: string = ''; fEventWait: double = 0.5): TMPVErrorCode;
begin
  result := mpv.initPlayer(intToStr(sWinHandle), sScrShotDir, sConfigDir, sLogFile, fEventWait);  // THIS RECREATES THE INTERNAL MPV OBJECT
end;

function mpvOpenFile(const mpv: TMPVBasePlayer; aURL: string): TMPVErrorCode;
begin
  result := 0;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.openFile(aURL);
end;

//==========

function mpvBrightnessDn(const mpv: TMPVBasePlayer): string;
var
  brightness: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('brightness', brightness);
  mpv.setPropertyInt64('brightness', brightness - 1);
  result := mpvFormattedBrightness(mpv);
end;

function mpvBrightnessReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyInt64('brightness', 0);
  result := 'Brightness reset';
end;

function mpvBrightnessUp(const mpv: TMPVBasePlayer): string;
var
  brightness: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('brightness', brightness);
  mpv.setPropertyInt64('brightness', brightness + 1);
  result := mpvFormattedBrightness(mpv);
end;

function mpvChapterNext(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.commandStr('add chapter 1') = MPV_ERROR_SUCCESS;
end;

function mpvChapterPrev(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.commandStr('add chapter -1') = MPV_ERROR_SUCCESS;
end;

function mpvContrastDn(const mpv: TMPVBasePlayer): string;
var
  contrast: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('contrast', contrast);
  mpv.setPropertyInt64('contrast', contrast - 1);
  result := mpvFormattedContrast(mpv);
end;

function mpvContrastReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyInt64('contrast', 0);
  result := 'Contrast reset';
end;

function mpvContrastUp(const mpv: TMPVBasePlayer): string;
var
  contrast: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('contrast', contrast);
  mpv.setPropertyInt64('contrast', contrast + 1);
  result := mpvFormattedContrast(mpv);
end;

function mpvCycleAudio(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.commandStr('cycle audio') = MPV_ERROR_SUCCESS;
end;

function mpvCycleSubs(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.commandStr('cycle sub') = MPV_ERROR_SUCCESS;
end;

function mpvFrameBackwards(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.commandStr(CMD_BACK_STEP) = MPV_ERROR_SUCCESS;
end;

function mpvFrameForwards(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.commandStr(CMD_STEP) = MPV_ERROR_SUCCESS;
end;

function mpvGammaDn(const mpv: TMPVBasePlayer): string;
var
  gamma: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('gamma', gamma);
  mpv.setPropertyInt64('gamma', gamma - 1);
  result := mpvFormattedgamma(mpv);
end;

function mpvGammaReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyInt64('gamma', 0);
  result := 'Gamma reset';
end;

function mpvGammaUp(const mpv: TMPVBasePlayer): string;
var
  gamma: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('gamma', gamma);
  mpv.setPropertyInt64('gamma', gamma + 1);
  result := mpvFormattedgamma(mpv);
end;

function mpvMute(const mpv: TMPVBasePlayer; const aValue: boolean): string;
var vValue: boolean;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpvSetMute(mpv, aValue);
  mpvGetMute(mpv, vValue);
  case vValue of    TRUE: result := 'muted';
                   FALSE: result := 'unmuted'; end;
  case vValue of    TRUE: CF[CONF_MUTED] := 'yes';
                   FALSE: CF[CONF_MUTED] := 'no'; end;
end;

function mpvMuteUnmute(const mpv: TMPVBasePlayer): string;
var vValue: boolean;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpvGetMute(mpv, vValue);
  mpvSetMute(mpv, NOT vValue);
  mpvGetMute(mpv, vValue);
  case vValue of    TRUE: result := 'muted';
                   FALSE: result := 'unmuted'; end;
  case vValue of    TRUE: CF[CONF_MUTED] := 'yes';
                   FALSE: CF[CONF_MUTED] := 'no'; end;
end;

function mpvPanDn(const mpv: TMPVBasePlayer): string;
var
  panY: double;
  multiplier: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;

  case ssShift in mmpShiftState of  TRUE: multiplier := 2;
                                   FALSE: multiplier := 1; end;

  mpv.getPropertyDouble('video-pan-y', panY);
  mpv.setPropertyDouble('video-pan-y', panY + (0.001 * multiplier));
  result := 'Pan down';
end;

function mpvPanLeft(const mpv: TMPVBasePlayer): string;
var
  panX: double;
  multiplier: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;

  case ssShift in mmpShiftState of  TRUE: multiplier := 2;
                                   FALSE: multiplier := 1; end;

  mpv.getPropertyDouble('video-pan-x', panX);
  mpv.setPropertyDouble('video-pan-x', panX - (0.001 * multiplier));
  result := 'Pan left';
end;

function mpvPanReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyDouble('video-pan-x', 0.0);
  mpv.setPropertyDouble('video-pan-y', 0.0);
  result := 'Pan reset';
end;

function mpvPanRight(const mpv: TMPVBasePlayer): string;
var
  panX: double;
  multiplier: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;

  case ssShift in mmpShiftState of  TRUE: multiplier := 2;
                                   FALSE: multiplier := 1; end;

  mpv.getPropertyDouble('video-pan-x', panX);
  mpv.setPropertyDouble('video-pan-x', panX + (0.001 * multiplier));
  result := 'Pan right';
end;

function mpvPanUp(const mpv: TMPVBasePlayer): string;
var
  panY: double;
  multiplier: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;

  case ssShift in mmpShiftState of  TRUE: multiplier := 2;
                                   FALSE: multiplier := 1; end;

  mpv.getPropertyDouble('video-pan-y', panY);
  mpv.setPropertyDouble('video-pan-y', panY - (0.001 * multiplier));
  result := 'Pan up';
end;

function mpvPause(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.pause = MPV_ERROR_SUCCESS;
end;

function mpvPausePlay(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  case mpvState(mpv) of
    mpsPlay:  mpvPause(mpv);
    mpsPause: mpvResume(mpv);
  end;
  case mpvState(mpv) of
    mpsPlay:  result := 'paused';
    mpsPause: result := 'unpaused';
  end;
end;

function mpvResetAll(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpvBrightnessReset(mpv);
  mpvContrastReset(mpv);
  mpvGammaReset(mpv);
  mpvPanReset(mpv);
  mpvRotateReset(mpv);
  mpvSaturationReset(mpv);
  mpvSpeedReset(mpv);
  mpvZoomReset(mpv);
  result := 'Reset All';
end;

function mpvResume(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.resume = MPV_ERROR_SUCCESS;
end;

function mpvRotateLeft(const mpv: TMPVBasePlayer): string;
var
  rot: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('video-rotate', rot);
  mpv.setPropertyInt64('video-rotate', rot - 45);
  result := 'Rotate left';
end;

function mpvRotateReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyInt64('video-rotate', 0);
  result := 'Rotate reset';
end;

function mpvRotateRight(const mpv: TMPVBasePlayer): string;
var
  rot: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('video-rotate', rot);
  mpv.setPropertyInt64('video-rotate', rot + 45);
  result := 'Rotate right';
end;

function mpvSaturationDn(const mpv: TMPVBasePlayer): string;
var
  saturation: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('saturation', saturation);
  mpv.setPropertyInt64('saturation', saturation - 1);
  result := mpvFormattedsaturation(mpv);
end;

function mpvSaturationReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyInt64('saturation', 0);
  result := 'Saturation reset';
end;

function mpvSeek(const mpv: TMPVBasePlayer; const aValue: integer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.Seek(aValue, FALSE) = MPV_ERROR_SUCCESS;
end;

function mpvSaturationUp(const mpv: TMPVBasePlayer): string;
var
  saturation: int64;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyInt64('saturation', saturation);
  mpv.setPropertyInt64('saturation', saturation + 1);
  result := mpvFormattedsaturation(mpv);
end;

function mpvSpeedDn(const mpv: TMPVBasePlayer): string;
var
  speed: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyDouble('speed', speed);
  mpv.setPropertyDouble('speed', speed - 0.01);
  result := mpvFormattedSpeed(mpv);
end;

function mpvSpeedReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyDouble('speed', 1.00);
  result := 'Speed reset';
end;

function mpvSpeedUp(const mpv: TMPVBasePlayer): string;
var
  speed: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyDouble('speed', speed);
  mpv.setPropertyDouble('speed', speed + 0.01);
  result := mpvFormattedSpeed(mpv);
end;

function mpvStartOver(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.seek(0, FALSE);
  result := 'Start over';
end;

function mpvStop(const mpv: TMPVBasePlayer): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  result := mpv.stop = MPV_ERROR_SUCCESS;
end;

function mpvTakeScreenshot(const mpv: TMPVBasePlayer; const aFolder: string): boolean;
begin
  result := FALSE;
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyString('screenshot-directory', aFolder);
  result := mpv.commandStr(CMD_SCREEN_SHOT + ' window') = MPV_ERROR_SUCCESS;
end;

function mpvToggleRepeat(const mpv: TMPVBasePlayer): string;
var vLoop: string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.getPropertyString('loop-file', vLoop);
  case vLoop = 'no' of  TRUE: mpv.setPropertyString('loop-file', 'yes');
                       FALSE: mpv.setPropertyString('loop-file', 'no'); end;
  mpv.getPropertyString('loop-file', vLoop);
  case vLoop = 'no' of  TRUE: result := 'repeat off';
                       FALSE: result := 'repeat on'; end;
end;

function mpvToggleSubtitles(const mpv: TMPVBasePlayer): string;
var vSid: string;
begin
  result := '';
  mpv.getPropertyString('sub', vSid);
  case vSid = 'no' of  TRUE: mpv.setPropertyString('sub', 'auto');
                      FALSE: mpv.setPropertyString('sub', 'no'); end;
  mpv.getPropertyString('sub', vSid);
  case vSid = 'no' of  TRUE: result := 'subtitles off';
                      FALSE: result := 'subtitles on'; end;
end;

function mpvVolDown(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpvMute(mpv, FALSE);
  mpv.volume := mpv.volume - 1;
  CF[CONF_VOLUME] := intToStr(trunc(mpv.volume));
  result := mpvFormattedVol(mpv);
end;

function mpvVolUp(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpvMute(mpv, FALSE);
  mpv.volume := mpv.volume + 1;
  CF[CONF_VOLUME] := intToStr(trunc(mpv.volume));
  result := mpvFormattedVol(mpv);
end;

function mpvZoomIn(const mpv: TMPVBasePlayer): string;
var
  zoomX, zoomY: double;
  dx: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;

  case ssShift in mmpShiftState of  TRUE: dx := 0.10;
                                   FALSE: dx := 0.01; end;

  mpv.getPropertyDouble('video-scale-x', zoomX);
  mpv.setPropertyDouble('video-scale-x', zoomX + dx);
  mpv.getPropertyDouble('video-scale-y', zoomY);
  mpv.setPropertyDouble('video-scale-y', zoomY + dx);
  result := 'Zoom in';
end;

function mpvZoomOut(const mpv: TMPVBasePlayer): string;
var
  zoomX, zoomY: double;
  dx: double;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;

  case ssShift in mmpShiftState of  TRUE: dx := 0.10;
                                   FALSE: dx := 0.01; end;

  mpv.getPropertyDouble('video-scale-x', zoomX);
  mpv.setPropertyDouble('video-scale-x', zoomX - dx);
  mpv.getPropertyDouble('video-scale-y', zoomY);
  mpv.setPropertyDouble('video-scale-y', zoomY - dx);
  result := 'Zoom out';
end;

function mpvZoomReset(const mpv: TMPVBasePlayer): string;
begin
  result := '';
  case mpv = NIL of TRUE: EXIT; end;
  mpv.setPropertyDouble('video-pan-x', 0.0);
  mpv.setPropertyDouble('video-pan-y', 0.0);
  mpv.setPropertyDouble('video-scale-x', 1.00);
  mpv.setPropertyDouble('video-scale-y', 1.00);
  result := 'Zoom reset';
end;


end.
