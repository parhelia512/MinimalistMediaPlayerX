{   Minimalist Media Player
    Copyright (C) 2021-2024 Baz Cuda
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
unit mmpUtils;

interface

uses
  winApi.windows,
  system.classes,
  vcl.forms;

function mmpCancelDelay: boolean;
function mmpDelay(const dwMilliseconds: DWORD): boolean;
function mmpProcessMessages: boolean;
function mmpShiftState: TShiftState; // so we don't have to pull vcl.forms into every unit just for this

implementation

var
  gCancel: boolean;

function mmpCancelDelay: boolean;
begin
  gCancel := TRUE;
end;

function mmpDelay(const dwMilliseconds: DWORD): boolean;
// Used to delay an operation; "sleep()" would suspend the thread, which is not what is required
var
  iStart, iStop: DWORD;
begin
  gCancel := FALSE;
  iStart := GetTickCount;
  repeat
    iStop  := GetTickCount;
    mmpProcessMessages;
  until gCancel or ((iStop  -  iStart) >= dwMilliseconds);
end;

function mmpShiftState: TShiftState; // so we don't have to pull vcl.forms into every unit that needs this
var
  KeyState: TKeyBoardState;
begin
  GetKeyboardState(KeyState);
  Result := KeyboardStateToShiftState(KeyState);
end;

function mmpProcessMessages: boolean;
begin
  application.processMessages;
end;


end.
