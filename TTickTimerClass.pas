{   MMP: Minimalist Media Player
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
unit TTickTimerClass;

interface

uses
  system.classes,
  vcl.extCtrls;

type
  TTickTimer = class(TTimer)
  private
    procedure timerEvent(aSender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  winApi.windows,
  mmpConsts, mmpSingletons;

var
  gTT: TTickTimer;

{ TTickTimer }

constructor TTickTimer.Create;
begin
  inherited Create(NIL);
  interval := 999;
  onTimer := timerEvent;
end;

procedure TTickTimer.timerEvent(aSender: TObject);
begin
  postMessage(GV.appWnd, WM_TICK, 0, 0);
end;

initialization
   gTT := TTickTimer.create(NIL);

finalization
  case gTT <> NIL of TRUE: gTT.free; end;

end.
