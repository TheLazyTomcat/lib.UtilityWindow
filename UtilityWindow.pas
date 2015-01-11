{==============================================================================}
{                                                                              }
{   Utility Window                                                             }
{                                                                              }
{   ©František Milt 2015-01-11                                                 }
{                                                                              }
{   Version 1.1                                                                }
{                                                                              }
{==============================================================================}
unit UtilityWindow;

interface

uses
  Windows, Messages,{$IFDEF FPC}SyncObjs,{$ENDIF} MulticastEvent;

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
  SysUtils, Classes;

{$IFDEF FPC}
const
  GWL_METHODCODE = SizeOf(pointer) * 0;
  GWL_METHODDATA = SizeOf(pointer) * 1;

  UtilityWindowClassName = 'TUtilityWindow';

var
  WndHandlerCritSect: TCriticalSection;
  WndHandlerCount:    Integer;

  //------------------------------------------------------------------------------

Function WndProcWrapper(Window: HWND; Message: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  InstanceWndProc:  TMethod;
  Msg:              TMessage;
begin
InstanceWndProc.Code := {%H-}Pointer(GetWindowLongPtr(Window,GWL_METHODCODE));
InstanceWndProc.Data := {%H-}Pointer(GetWindowLongPtr(Window,GWL_METHODDATA));
If Assigned(TWndMethod(InstanceWndProc)) then
  begin
    Msg.msg := Message;
    Msg.wParam := wParam;
    Msg.lParam := lParam;
    TWndMethod(InstanceWndProc)(Msg);
    Result := Msg.Result
  end
else Result := DefWindowProc(Window,Message,wParam,lParam);
end;

//------------------------------------------------------------------------------

Function UWAllocateHWND(Method: TWndMethod): HWND;
var
  Registered:         Boolean;
  TempClass:          TWndClass;
  UtilityWindowClass: TWndClass;
begin
Result := 0;
ZeroMemory(@UtilityWindowClass,SizeOf(UtilityWindowClass));
WndHandlerCritSect.Enter;
try
  Registered := Windows.GetClassInfo(hInstance,UtilityWindowClassName,{%H-}TempClass);
  If not Registered or (TempClass.lpfnWndProc <> @WndProcWrapper) then
    begin
      If Registered then Windows.UnregisterClass(UtilityWindowClassName,hInstance);
      UtilityWindowClass.lpszClassName := UtilityWindowClassName;
      UtilityWindowClass.hInstance := hInstance;
      UtilityWindowClass.lpfnWndProc := @WndProcWrapper;
      UtilityWindowClass.cbWndExtra := SizeOf(TMethod);
      If Windows.RegisterClass(UtilityWindowClass) = 0 then
        raise Exception.CreateFmt('Unable to register hidden window class. %s',[SysErrorMessage(GetLastError)]);
    end;
  Result := CreateWindowEx(WS_EX_TOOLWINDOW,UtilityWindowClassName,'',WS_POPUP,0,0,0,0,0,0,hInstance,nil);
  If Result = 0 then
    raise Exception.CreateFmt('Unable to create hidden window. %s',[SysErrorMessage(GetLastError)]);
  SetWindowLongPtr(Result,GWL_METHODDATA,{%H-}LONG_PTR(TMethod(Method).Data));
  SetWindowLongPtr(Result,GWL_METHODCODE,{%H-}LONG_PTR(TMethod(Method).Code));
  Inc(WndHandlerCount);
finally
  WndHandlerCritSect.Leave;
end;
end;

//------------------------------------------------------------------------------

procedure UWDeallocateHWND(Wnd: HWND);
begin
DestroyWindow(Wnd);
WndHandlerCritSect.Enter;
try
  Dec(WndHandlerCount);
  If WndHandlerCount <= 0 then
    Windows.UnregisterClass(UtilityWindowClassName,hInstance);
finally
  WndHandlerCritSect.Leave;
end;
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
fWindowHandle := UWAllocateHWND(@WndProc);
{$ELSE}
fWindowHandle := Classes.AllocateHWND(WndProc);
{$ENDIF}
end;

//------------------------------------------------------------------------------

destructor TUtilityWindow.Destroy;
begin
fOnMessage.Clear;
{$IFDEF FPC}
UWDeallocateHWND(fWindowHandle);
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

{$IFDEF FPC}
initialization
  WndHandlerCritSect := TCriticalSection.Create;

finalization
  WndHandlerCritSect.Free;
{$ENDIF}

end.
