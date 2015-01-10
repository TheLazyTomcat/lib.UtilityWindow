{==============================================================================}
{                                                                              }
{   Utility Window                                                             }
{                                                                              }
{   ©František Milt 2015-01-10                                                 }
{                                                                              }
{   Version 1.1                                                                }
{                                                                              }
{==============================================================================}
unit UtilityWindow;

interface

uses
  Windows, Messages, MulticastEvent;

type
  TMessageEvent = procedure(var Msg: TMessage; var Handled: Boolean) of object;

{==============================================================================}
{--- TMulticastMessageEvent declarationn --------------------------------------}
{==============================================================================}

  TMulticastMessageEvent = class(TMulticastEvent)
  public
    Function IndexOf(const Handler: TMessageEvent): Integer; reintroduce;
    Function Add(Handler: TMessageEvent; AllowDuplicity: Boolean = False): Integer; reintroduce;
    Function Remove(const Handler: TMessageEvent): Integer; reintroduce;
    procedure Call(var Msg: TMessage; var Handled: Boolean); reintroduce;
  end;

{==============================================================================}
{--- TUtilityWindow declarationn ----------------------------------------------}
{==============================================================================}

  TUtilityWindow = class(TObject)
  private
    fWindowHandle:  HWND;
    fOnMessage:     TMulticastMessageEvent;
  protected
    procedure WndProc(var Msg: TMessage); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ProcessMessages(Synchronous: Boolean = False); virtual;
  published
    property WindowHandle: HWND read fWindowHandle;
    property OnMessage: TMulticastMessageEvent read fOnMessage;
  end;

implementation

uses
  Classes, forms;

{$IFDEF FPC}
var
  UtilWindowClass: TWndClass = (
    style:          0;
    lpfnWndProc:    @DefWindowProc;
    cbClsExtra:     0;
    cbWndExtra:     0;
    hInstance:      0;
    hIcon:          0;
    hCursor:        0;
    hbrBackground:  0;
    lpszMenuName:   nil;
    lpszClassName:  'TUtilityWindow');

//------------------------------------------------------------------------------

Function AllocateHWnd(Method: TWndMethod): HWND;
var
  TempClass:      TWndClass;
  ClassRegistered: Boolean;
begin
  UtilWindowClass.hInstance := hInstance;
  UtilWindowClass.lpfnWndProc := @DefWindowProc;
  ClassRegistered := GetClassInfo(HInstance,UtilWindowClass.lpszClassName,{%H-}TempClass);
  If not ClassRegistered or (TempClass.lpfnWndProc <> @DefWindowProc) then
    begin
      If ClassRegistered then
        Windows.UnregisterClass(UtilWindowClass.lpszClassName,hInstance);
      Windows.RegisterClass(UtilWindowClass);
    end;
  Result := CreateWindowEx(WS_EX_TOOLWINDOW,UtilWindowClass.lpszClassName,'',WS_POPUP,0,0,0,0,0,0,hInstance,nil);
  If Assigned(Method) then
    SetWindowLongPtr(Result,GWL_WNDPROC,{%H-}LONG_PTR(MakeObjectInstance(Method)));
end;

//------------------------------------------------------------------------------

procedure DeallocateHWnd(Wnd: HWND);
var
  Instance: Pointer;
begin
  Instance := {%H-}Pointer(GetWindowLongPtr(Wnd,GWL_WNDPROC));
  DestroyWindow(Wnd);
  If Instance <> Pointer(@DefWindowProc) then FreeObjectInstance(Instance);
end;
{$ENDIF}

{==============================================================================}
{--- TMulticastMessageEvent implementation ------------------------------------}
{==============================================================================}

{=== TMulticastMessageEvent // public methods =================================}

Function TMulticastMessageEvent.IndexOf(const Handler: TMessageEvent): Integer;
begin
Result := inherited IndexOf(TEvent(Handler));
end;

//------------------------------------------------------------------------------

Function TMulticastMessageEvent.Add(Handler: TMessageEvent; AllowDuplicity: Boolean = False): Integer;
begin
Result := inherited Add(TEvent(Handler),AllowDuplicity);
end;

//------------------------------------------------------------------------------

Function TMulticastMessageEvent.Remove(const Handler: TMessageEvent): Integer;
begin
Result := inherited Remove(TEvent(Handler));
end;

//------------------------------------------------------------------------------

procedure TMulticastMessageEvent.Call(var Msg: TMessage; var Handled: Boolean);
var
  i:          Integer;
  Processed:  Boolean;
begin
Processed := False;
For i := 0 to Pred(Count) do
  begin
    TMessageEvent(Methods[i])(Msg,Processed);
    If Processed then Handled := True;
  end;
end;

{==============================================================================}
{--- TUtilityWindow implementation --------------------------------------------}
{==============================================================================}

{=== TUtilityWindow // protected methods ======================================}

procedure TUtilityWindow.WndProc(var Msg: TMessage);
var
  Handled:  Boolean;
begin
Handled := False;
fOnMessage.Call(Msg,Handled);
If not Handled then
  Msg.Result := DefWindowProc(fWindowHandle,Msg.Msg,Msg.wParam,Msg.lParam);
end;

{=== TUtilityWindow // public methods =========================================}

constructor TUtilityWindow.Create;
begin
inherited;
fOnMessage := TMulticastMessageEvent.Create(Self);
{$IFDEF FPC}
fWindowHandle := AllocateHWND(@WndProc);
{$ELSE}
fWindowHandle := Classes.AllocateHWND(WndProc);
{$ENDIF}
end;

//------------------------------------------------------------------------------

destructor TUtilityWindow.Destroy;
begin
fOnMessage.Clear;
{$IFDEF FPC}
DeallocateHWND(fWindowHandle);
{$ELSE}
Classes.DeallocateHWND(fWindowHandle);
{$ENDIF}
fOnMessage.Free;
inherited;
end;

//------------------------------------------------------------------------------

procedure TUtilityWindow.ProcessMessages(Synchronous: Boolean = False);
var
  Msg:  TagMSG;
begin
If Synchronous then
  begin
    while Integer(GetMessage({%H-}Msg,fWindowHandle,0,0)) <> 0 do
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
  end
else
  begin
    while Integer(PeekMessage(Msg,fWindowHandle,0,0,PM_REMOVE)) <> 0 do
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
  end;
end;

end.
