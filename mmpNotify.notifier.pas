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
unit mmpNotify.notifier;

interface

uses
  winApi.windows,
  system.classes, system.generics.collections,
  mmpNotify.notices;

function appNotifier: INotifier;
function newNotifier: INotifier;

function notifyApp(const aNotice: INotice): INotice;
function notifySubscribers(const aNotifier: INotifier; const aNotice: INotice): INotice; overload;

implementation

uses
  _debugWindow;

type
 TNotifier = class (TInterfacedObject, INotifier)
  private
    FSubscribers: TList<ISubscriber>;
  public
    procedure   subscribe(const aSubscriber: ISubscriber);
    procedure   unsubscribe(const aSubscriber: ISubscriber);
    procedure   notifySubscribers(const aNotice: INotice);

    constructor create;
    destructor  Destroy; override;
  end;

function newNotifier: INotifier;
begin
  result := TNotifier.create;
end;

var gAppNotifier: INotifier;
function appNotifier: INotifier;
begin
  case gAppNotifier = NIL of TRUE: gAppNotifier := newNotifier; end;
  result := gAppNotifier;
end;

function notifyApp(const aNotice: INotice): INotice;
begin
  result := aNotice;
  case aNotice  = NIL of TRUE: EXIT; end;
//  TDebug.debugEnum<TNoticeEvent>('notifyApp', aNotice.event);
  appNotifier.notifySubscribers(aNotice);
end;

function notifySubscribers(const aNotifier: INotifier; const aNotice: INotice): INotice;
begin
  result := aNotice;
  case (aNotifier = NIL) or (aNotice = NIL) of TRUE: EXIT; end;
  aNotifier.notifySubscribers(aNotice);
end;

{ TNotifier }

constructor TNotifier.create;
begin
  inherited;
  FSubscribers := TList<ISubscriber>.Create;
end;

destructor TNotifier.Destroy;
var
  vSubscriber: ISubscriber;
begin
  for vSubscriber in FSubscribers do unsubscribe(vSubscriber);
  FSubscribers.free;
  inherited;
end;

procedure TNotifier.notifySubscribers(const aNotice: INotice);
var
  vSubscriber: ISubscriber;
begin
//  result := aNotice;
  case aNotice  = NIL of TRUE: EXIT; end;
  for vSubscriber in FSubscribers do vSubscriber.notifySubscriber(aNotice);
end;

procedure TNotifier.subscribe(const aSubscriber: ISubscriber);
begin
  FSubscribers.add(aSubscriber);
end;

procedure TNotifier.unsubscribe(const aSubscriber: ISubscriber);
begin
  FSubscribers.remove(aSubscriber);
end;

initialization
  gAppNotifier := NIL;

finalization
  gAppNotifier := NIL;

end.
